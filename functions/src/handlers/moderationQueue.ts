/**
 * The founder's review queue (docs/03 §9, App Store Guideline 1.2).
 *
 * `moderation/{postId}` has been written to since day one and read by
 * nothing — no admin UI, no admin claim, no function. Guideline 1.2 requires
 * a means of acting on reported content and docs/03 promises review inside 24
 * hours; neither is possible against a collection nobody can open.
 *
 * Access is by a custom claim on the auth token, set out of band with the
 * Admin SDK. NOT a uid allowlist in config and definitely not a flag in the
 * request payload: this endpoint returns content that was flagged or blocked,
 * so the check has to be on something the caller cannot author.
 *
 * The rules keep `moderation` server-only, so this callable is the only door.
 */
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {REGION} from '../config';
import {db, FieldValue, mirrorPostStatus, postsCol} from '../lib/firestore';
import {asEnum, requireCaller, requireText} from '../lib/guards';
import {log} from '../lib/logger';
import {notifyPostAuthor} from './moderateReply';

/** How many flags one page returns. The queue is a daily chore, not a feed. */
const PAGE_SIZE = 50;

const RESOLUTIONS = ['allow', 'block'] as const;
type Resolution = (typeof RESOLUTIONS)[number];

export interface QueueItem {
  /**
   * The moderation document's own id, and the ONLY thing `resolveModeration`
   * should be handed back.
   *
   * A reply flag is stored at `moderation/{replyId}` and carries `postId` as a
   * field. Resolving by `postId` therefore wrote to a *different document* —
   * the parent post's — so the reply's flag stayed `reviewed: false` forever
   * and came back in the queue every day, while the parent post's status got
   * flipped in its place.
   */
  flagId: string;
  postId: string;
  /** Set only for reply flags. */
  replyId: string | null;
  action: string;
  reason: string;
  /** Null when the content is already gone — the flag outlives its subject. */
  text: string | null;
  status: string | null;
  alias: string | null;
  kind: string;
}

/**
 * Throws unless the caller carries `admin: true` on their token.
 *
 * Reading `request.auth.token` rather than `request.data`: the token is signed
 * by Firebase, the payload is whatever the client typed.
 */
function requireAdmin(request: Parameters<typeof requireCaller>[0]): string {
  const caller = requireCaller(request);
  if (request.auth?.token['admin'] !== true) {
    // Deliberately not "you are not an admin" — the existence of this queue
    // is not something an ordinary user needs confirmed.
    throw new HttpsError('not-found', 'Not found.');
  }
  return caller.uid;
}

export const moderationQueue = onCall(
  {region: REGION, enforceAppCheck: true, memory: '256MiB'},
  async (request): Promise<{items: QueueItem[]}> => {
    const uid = requireAdmin(request);
    const data = (request.data ?? {}) as Record<string, unknown>;
    const includeReviewed = data['includeReviewed'] === true;

    let query = db
      .collection('moderation')
      .orderBy('createdAt', 'asc')
      .limit(PAGE_SIZE);
    if (!includeReviewed) {
      query = db
        .collection('moderation')
        .where('reviewed', '==', false)
        .orderBy('createdAt', 'asc')
        .limit(PAGE_SIZE);
    }

    const flags = await query.get();

    // Sequential rather than a 50-wide Promise.all: this runs once a day for
    // one person, and a burst against Firestore buys nothing here.
    const items: QueueItem[] = [];
    for (const flag of flags.docs) {
      const postId = (flag.get('postId') as string | undefined) ?? flag.id;
      const kind = (flag.get('kind') as string | undefined) ?? 'post';
      const replyId = (flag.get('replyId') as string | undefined) ?? null;

      // Hydrate from the thing that was actually flagged. Reply flags used to
      // be hydrated from their PARENT POST, so the founder reviewed innocent
      // text and either cleared a reply they never read or blocked a post
      // nobody reported.
      const target =
        kind === 'reply' && replyId !== null
          ? await postsCol().doc(postId).collection('replies').doc(replyId).get()
          : await postsCol().doc(postId).get();

      items.push({
        flagId: flag.id,
        postId,
        replyId,
        action: (flag.get('action') as string | undefined) ?? 'flag',
        reason: (flag.get('reason') as string | undefined) ?? '',
        kind,
        text: target.exists
          ? ((target.get('text') as string | null) ?? null)
          : null,
        status: target.exists
          ? ((target.get('status') as string | null) ?? null)
          : null,
        alias: target.exists
          ? ((target.get('alias') as string | null) ?? null)
          : null,
      });
    }

    log.info('moderation.queue_opened', {reviewer: uid, count: items.length});
    return {items};
  },
);

/**
 * Marks a flag reviewed, optionally changing the post's fate.
 *
 * Resolving without an action means "I looked, it is fine as it is" — the
 * common case, and the reason `action` is optional. The one exception: a
 * `pending` (held/auto-hidden) target refuses a no-action resolve, because
 * "fine as it is" on invisible content means invisible forever.
 */
export const resolveModeration = onCall(
  {region: REGION, enforceAppCheck: true, memory: '256MiB'},
  async (request): Promise<{ok: true}> => {
    const uid = requireAdmin(request);
    const data = (request.data ?? {}) as Record<string, unknown>;
    // The flag's own id. `postId` was accepted here, which for a reply flag
    // named the wrong document in both directions — see QueueItem.flagId.
    const flagId = requireText(data['flagId'], 'flagId', 200);
    const action = asEnum<Resolution>(data['action'], RESOLUTIONS);

    const flagRef = db.collection('moderation').doc(flagId);
    const flag = await flagRef.get();
    if (!flag.exists) throw new HttpsError('not-found', 'Not found.');

    const postId = (flag.get('postId') as string | undefined) ?? flagId;
    const replyId = (flag.get('replyId') as string | undefined) ?? null;
    const kind = (flag.get('kind') as string | undefined) ?? 'post';
    const target =
      kind === 'reply' && replyId !== null
        ? postsCol().doc(postId).collection('replies').doc(replyId)
        : postsCol().doc(postId);
    const targetSnap = await target.get();
    const wasPending = targetSnap.exists && targetSnap.get('status') === 'pending';

    // Held content cannot be shrugged at. Dismiss only marks the row
    // reviewed, and on a `pending` target that strands it invisible with
    // nothing left pointing at it. The client hides Dismiss for held rows;
    // this is the server-side guarantee behind that UX.
    if (action === null && wasPending) {
      throw new HttpsError(
        'failed-precondition',
        'Held content needs a decision — allow or block it.',
      );
    }

    // Content fate FIRST, review mark second: if the second write fails the
    // row stays in the queue and the founder retries — the reverse order
    // dropped the row from the queue with the content's status unchanged.
    if (action !== null && targetSnap.exists) {
      const status = action === 'block' ? 'blocked' : 'live';
      await target.update({status});
      // A post's author learns the founder's decision the same way they
      // learned the classifier's: through their own mirror row.
      if (kind !== 'reply') await mirrorPostStatus(postId, status);
      // A held reply the founder just published: the SOS author is owed the
      // "someone answered" push the trigger rightly skipped while the reply
      // was invisible. Only on a pending→live transition — a `flag` reply
      // was already live and already pushed.
      if (action === 'allow' && kind === 'reply' && wasPending) {
        await notifyPostAuthor(postId);
      }
    }

    await flagRef.set(
      {
        reviewed: true,
        reviewedAt: FieldValue.serverTimestamp(),
        reviewedBy: uid,
        resolution: action,
        // A person has decided. A later report re-opens the row with
        // reviewed:false, and without this the sweeper would treat an old
        // outage-hold as its own again and re-classify past the decision.
        retryable: false,
      },
      {merge: true},
    );

    log.info('moderation.resolved', {reviewer: uid, flagId, action});
    return {ok: true};
  },
);
