/**
 * `reportPost` — a reader flagging a post.
 *
 * The mirror of `reportReply`, and it closes the same class of bug that one
 * did: the client used to write a raw `FieldValue.increment(1)` onto
 * `posts/{id}.reportCount` through a rules carve-out, and NO server code ever
 * read the counter — no auto-hide, no queue row, nothing. Reporting a post
 * raised a number nobody was watching (found in the Aug 31 2026 field test;
 * backlog S3-10).
 *
 * A callable rather than a client write for the same reason as `reportReply`:
 * a reader must be able to raise a count without being able to touch the
 * text, the author or the status, and the Admin SDK bypasses rules — so what
 * a report may change is decided here, in one place, on the server.
 */
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {REGION} from '../config';
import {db, FieldValue, mirrorPostStatus, moderationDoc, postsCol} from '../lib/firestore';
import {requireCaller, requireText} from '../lib/guards';
import {log} from '../lib/logger';

/**
 * Reports needed before a post hides itself pending review. Matches
 * `reportReply`'s threshold so the two surfaces behave the same way.
 */
const AUTO_HIDE_AT = 3;

export const reportPost = onCall(
  {region: REGION, enforceAppCheck: true, memory: '256MiB'},
  async (request): Promise<{ok: true}> => {
    const caller = requireCaller(request);
    const data = (request.data ?? {}) as Record<string, unknown>;
    const postId = requireText(data['postId'], 'postId', 200);

    const ref = postsCol().doc(postId);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError('not-found', 'Not found.');

    // One document per reporter, so reporting twice cannot drive the count to
    // the auto-hide threshold on its own — a counter that gates a decision
    // has to be keyed by the thing it counts. (`reporters` is a sibling of
    // the `reactors` and `replies` subcollections; the rules' default deny
    // keeps it server-only without a rules edit.)
    //
    // The dedupe read happens INSIDE the transaction. A pre-check alone loses
    // the race: the client fires this callable on every tap, so three rapid
    // taps put three calls in flight that all see "no reporter doc yet" and
    // each increment — one angry reader auto-hiding a post alone.
    const reporter = ref.collection('reporters').doc(caller.uid);
    const applied = await db.runTransaction(async (tx) => {
      const [fresh, rep] = await Promise.all([tx.get(ref), tx.get(reporter)]);
      if (!fresh.exists || rep.exists) return 'skipped' as const;
      const count = ((fresh.get('reportCount') as number | undefined) ?? 0) + 1;
      tx.set(reporter, {reportedAt: FieldValue.serverTimestamp()});
      const hide = count >= AUTO_HIDE_AT;
      tx.update(ref, {
        reportCount: count,
        // Hidden pending review, never deleted: the founder still has to be
        // able to read it and disagree.
        ...(hide ? {status: 'pending'} : {}),
      });
      return hide ? ('hidden' as const) : ('counted' as const);
    });
    if (applied === 'skipped') return {ok: true};
    // The author sees their post go back "in review" rather than watching it
    // silently disappear from everyone else's feed.
    if (applied === 'hidden') await mirrorPostStatus(postId, 'pending');

    // A report re-opens an existing queue row but never rewrites it: the
    // classifier's `action`/`reason` are the evidence the founder reads, and
    // `createdAt` is the oldest-first queue position — clobbering either
    // would replace a verdict with "user_report" and send the row to the back
    // of the line.
    const rowRef = moderationDoc(postId);
    if ((await rowRef.get()).exists) {
      await rowRef.set({reviewed: false}, {merge: true});
    } else {
      await rowRef.set({
        postId,
        kind: 'post',
        action: 'flag',
        reason: 'user_report',
        reviewed: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    log.info('moderation.post_reported', {postId});
    return {ok: true};
  },
);
