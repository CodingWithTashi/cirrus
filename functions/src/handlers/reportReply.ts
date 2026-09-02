/**
 * `reportReply` — a reader flagging a reply.
 *
 * The button existed and did nothing. `community_screens.dart` rendered a flag
 * icon whose entire handler was `showLpSnack(context, 'Reported')`, under a
 * comment claiming "flagging a reply is one tap" — so the app told people
 * their report had been filed and filed nothing. Guideline 1.2 requires a
 * means of reporting objectionable content; a snackbar is not one, and an SOS
 * thread is exactly where the worst replies land.
 *
 * It is a callable rather than a client write because `firestore.rules` denies
 * every client write to a reply, and rightly so: a reader must be able to
 * raise a count without being able to touch the text, the author or the
 * status. The Admin SDK bypasses rules, so the decision of what a report may
 * change lives here, in one place, on the server.
 */
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {REGION} from '../config';
import {db, FieldValue, moderationDoc, postsCol} from '../lib/firestore';
import {requireCaller, requireText} from '../lib/guards';
import {log} from '../lib/logger';

/**
 * Reports needed before a reply hides itself pending review.
 *
 * Matches the posts rule so the two surfaces behave the same way. Three is a
 * deliberate compromise: low enough that genuinely bad content disappears
 * fast, high enough that one angry reader cannot silence somebody alone.
 */
const AUTO_HIDE_AT = 3;

export const reportReply = onCall(
  {region: REGION, enforceAppCheck: true, memory: '256MiB'},
  async (request): Promise<{ok: true}> => {
    const caller = requireCaller(request);
    const data = (request.data ?? {}) as Record<string, unknown>;
    const postId = requireText(data['postId'], 'postId', 200);
    const replyId = requireText(data['replyId'], 'replyId', 200);

    const ref = postsCol().doc(postId).collection('replies').doc(replyId);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError('not-found', 'Not found.');

    // One document per reporter, so reporting twice cannot drive the count to
    // the auto-hide threshold on its own. `CommunityStore.reportPost` had the
    // mirror of this bug on the client — a single counter across the whole
    // feed — and the lesson is the same: a counter that gates a decision has
    // to be keyed by the thing it counts.
    //
    // The dedupe read happens INSIDE the transaction — a pre-check alone
    // loses the race to three rapid taps, each in flight before any commits.
    const reporter = ref.collection('reporters').doc(caller.uid);
    const applied = await db.runTransaction(async (tx) => {
      const [fresh, rep] = await Promise.all([tx.get(ref), tx.get(reporter)]);
      if (!fresh.exists || rep.exists) return false;
      const count = ((fresh.get('reportCount') as number | undefined) ?? 0) + 1;
      tx.set(reporter, {reportedAt: FieldValue.serverTimestamp()});
      tx.update(ref, {
        reportCount: count,
        // Hidden pending review, never deleted: the founder still has to be
        // able to read it and disagree.
        ...(count >= AUTO_HIDE_AT ? {status: 'pending'} : {}),
      });
      return true;
    });
    if (!applied) return {ok: true};

    // Keyed by replyId, and carrying postId as a field, so the queue can
    // hydrate the reply itself rather than its parent. A report re-opens an
    // existing row but never rewrites the classifier's `action`/`reason`
    // evidence or bumps `createdAt` (the oldest-first queue position).
    const rowRef = moderationDoc(replyId);
    if ((await rowRef.get()).exists) {
      // ...and takes it out of the sweeper's reach: a report is a human
      // signal, and a row the cron could re-classify and republish would
      // undo the auto-hide with nobody having read the reports.
      await rowRef.set({reviewed: false, retryable: false}, {merge: true});
    } else {
      await rowRef.set({
        postId,
        replyId,
        kind: 'reply',
        action: 'flag',
        reason: 'user_report',
        retryable: false,
        reviewed: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    log.info('moderation.reply_reported', {postId, replyId});
    return {ok: true};
  },
);
