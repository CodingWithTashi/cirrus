/**
 * `remoderateHeld` — re-asks the classifier about holds the pipeline itself
 * caused, so a model outage never parks clean posts in the founder's queue.
 *
 * `classify` fails CLOSED: when Gemini is down, or answers something that
 * does not parse, the content is held and a queue row is filed. That is the
 * right call for App Store Guideline 1.2 — but on its own it turns a
 * five-minute outage into a queue of innocent posts waiting for a human,
 * and their authors staring at "In review" for hours. The Sep 1 field test's
 * "why does every post need review?" is exactly what that looks like from
 * the phone (docs/09 issue 6).
 *
 * So every outage-hold carries `retryable: true` on its queue row, and this
 * cron picks those rows up, runs the very same `classify`, and applies the
 * answer: a clean post goes live and its row is closed as resolved by the
 * sweeper; anything else gets its real verdict and stays for the founder.
 * A hold the MODEL chose is never retryable — that one is a judgment call,
 * and re-rolling a judgment call until it flips is not moderation.
 *
 * A row is re-asked at most [MAX_ATTEMPTS] times. A text that makes the
 * model answer garbage every time (temperature 0 answers the same way twice)
 * is not an outage; without the cap it would cost a call every tick forever
 * and, at fifty such rows, crowd every genuine outage-hold out of the batch.
 *
 * SCALE PATTERN: the query is two equality filters on the queue collection
 * (`reviewed == false`, `retryable == true`), which Firestore serves from
 * its automatic single-field indexes with no composite index to forget. The
 * batch is capped, and a run that only finds the model still down stops
 * early rather than burning the whole batch on a dead endpoint.
 */
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {GEMINI_API_KEY, REGION} from '../config';
import {classify} from '../ai/moderation';
import {FieldValue, db, mirrorPostStatus, postsCol} from '../lib/firestore';
import {log} from '../lib/logger';
import {MIRROR_STATUS, VERDICT_STATUS} from './moderatePost';
import {notifyPostAuthor} from './moderateReply';

/** Rows re-asked per run. Bounds the model spend of one cron tick. */
export const REMODERATE_BATCH = 50;

/**
 * Consecutive "still down" answers with nothing decided before the run gives
 * up. Three is enough to tell an outage from one unlucky call.
 */
const GIVE_UP_AFTER = 3;

/** Who closes a row the sweeper resolved — distinguishable from a person. */
export const SWEEPER_REVIEWER = 'remoderate';

/** Re-asks per row before it is left to the founder: two hours of ticks. */
export const MAX_ATTEMPTS = 8;

export interface RemoderateResult {
  scanned: number;
  /** Clean on the second look: now live, row closed. */
  published: number;
  /** Got a real verdict that was not allow: status applied, row stays. */
  decided: number;
  /** The model was still unavailable; row left for the next run. */
  stillDown: number;
  /** Still down on the [MAX_ATTEMPTS]th ask: handed to the founder for good. */
  gaveUp: number;
  /** Rows whose subject is gone or already decided by a person. */
  dropped: number;
}

export const remoderateHeld = onSchedule(
  {
    region: REGION,
    schedule: 'every 15 minutes',
    timeZone: 'UTC',
    secrets: [GEMINI_API_KEY],
    memory: '256MiB',
    timeoutSeconds: 300,
    retryCount: 0, // the next tick is the retry
  },
  async () => {
    const result = await remoderateOnce(REMODERATE_BATCH);
    log.info('remoderate.done', {...result});
  },
);

/**
 * One sweep over up to [limit] retryable rows. Returns what it did.
 *
 * Exported for the integration suite — the scheduled wrapper is untestable,
 * the same arrangement `pruneDevices` makes for `pruneStaleDevices`.
 */
export async function remoderateOnce(limit: number): Promise<RemoderateResult> {
  const result: RemoderateResult = {
    scanned: 0,
    published: 0,
    decided: 0,
    stillDown: 0,
    gaveUp: 0,
    dropped: 0,
  };

  const rows = await db
    .collection('moderation')
    .where('reviewed', '==', false)
    .where('retryable', '==', true)
    .limit(limit)
    .get();

  for (const row of rows.docs) {
    result.scanned++;
    const postId = (row.get('postId') as string | undefined) ?? row.id;
    const kind = (row.get('kind') as string | undefined) ?? 'post';
    const replyId = (row.get('replyId') as string | undefined) ?? null;
    const isReply = kind === 'reply' && replyId !== null;
    const target = isReply
      ? postsCol().doc(postId).collection('replies').doc(replyId)
      : postsCol().doc(postId);

    const snap = await target.get();
    // The subject is gone (author deleted their account) or a person already
    // decided it through resolveModeration. Either way there is nothing left
    // to re-ask; stop selecting the row.
    if (!snap.exists || snap.get('status') !== 'pending') {
      await row.ref.set({retryable: false}, {merge: true});
      result.dropped++;
      continue;
    }

    const text = snap.get('text') as unknown;
    const tag = isReply ? undefined : (snap.get('tag') as unknown);
    const verdict = await classify(
      typeof text === 'string' ? text : '',
      typeof tag === 'string' ? tag : undefined,
    );

    if (verdict.retryable === true) {
      result.stillDown++;
      const attempts =
        ((row.get('retryAttempts') as number | undefined) ?? 0) + 1;
      const exhausted = attempts >= MAX_ATTEMPTS;
      await row.ref.set(
        exhausted
          ? {
              retryAttempts: attempts,
              retryable: false,
              retryGaveUpAt: FieldValue.serverTimestamp(),
            }
          : {retryAttempts: attempts},
        {merge: true},
      );
      if (exhausted) result.gaveUp++;
      // Nothing decided yet and the model keeps failing: this is an outage,
      // not a bad post. Leave the rest for the next tick.
      if (
        result.stillDown >= GIVE_UP_AFTER &&
        result.published + result.decided === 0
      ) {
        break;
      }
      continue;
    }

    // Content fate FIRST, row second — the same order resolveModeration
    // keeps: if the second write fails, the row is still selected next run
    // and the sweep is idempotent over an already-flipped status (it drops
    // the row above).
    await target.update({
      status: VERDICT_STATUS[verdict.action],
      moderatedAt: FieldValue.serverTimestamp(),
    });
    if (!isReply) await mirrorPostStatus(postId, MIRROR_STATUS[verdict.action]);

    if (verdict.action === 'allow') {
      await row.ref.set(
        {
          action: 'allow',
          reason: verdict.reason,
          retryable: false,
          reviewed: true,
          reviewedAt: FieldValue.serverTimestamp(),
          reviewedBy: SWEEPER_REVIEWER,
          resolution: 'allow',
        },
        {merge: true},
      );
      result.published++;
    } else {
      // A real verdict now, for a human to weigh: the row keeps its place in
      // the queue with the reason the model actually gave.
      await row.ref.set(
        {action: verdict.action, reason: verdict.reason, retryable: false},
        {merge: true},
      );
      result.decided++;
    }

    // A reply that just became visible on an SOS post owes its author the
    // "someone answered" push the trigger rightly skipped while it was held.
    if (isReply && (verdict.action === 'allow' || verdict.action === 'flag')) {
      await notifyPostAuthor(postId);
    }

    log.info('remoderate.verdict', {
      postId,
      replyId,
      kind,
      action: verdict.action,
    });
  }

  return result;
}
