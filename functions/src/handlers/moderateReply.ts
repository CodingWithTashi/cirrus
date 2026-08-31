/**
 * `moderateReply` — the same gate as `moderatePost`, for replies.
 *
 * `moderatePost` triggers on `posts/{postId}` only, so before this existed a
 * reply would never have been classified at all. Guideline 1.2 does not stop
 * applying because the user content is nested one level deeper, and an SOS
 * thread is exactly where the worst replies would land.
 */
import {onDocumentCreated} from 'firebase-functions/v2/firestore';
import {GEMINI_API_KEY, REGION} from '../config';
import {classify} from '../ai/moderation';
import {db, FieldValue, moderationDoc, postsCol} from '../lib/firestore';
import {log} from '../lib/logger';
import {sendLocalized} from '../lib/push';
import {VERDICT_STATUS} from './moderatePost';

export const moderateReply = onDocumentCreated(
  {
    region: REGION,
    document: 'posts/{postId}/replies/{replyId}',
    secrets: [GEMINI_API_KEY],
    memory: '256MiB',
    retry: false, // a retry storm on a bad reply just re-spends tokens
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const text = snap.get('text') as unknown;
    const {postId, replyId} = event.params;

    if (typeof text !== 'string' || text.trim().length === 0) {
      await snap.ref.update({
        status: 'blocked',
        moderatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    const verdict = await classify(text);

    // Queue row BEFORE the status flip — same retry:false reasoning as
    // moderatePost. Keyed by replyId so a flagged reply cannot overwrite its
    // parent's row.
    if (verdict.action !== 'allow') {
      await moderationDoc(replyId).set({
        postId,
        replyId,
        kind: 'reply',
        action: verdict.action,
        reason: verdict.reason,
        reviewed: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    await snap.ref.update({
      status: VERDICT_STATUS[verdict.action],
      moderatedAt: FieldValue.serverTimestamp(),
    });

    log.info('moderation.verdict', {
      postId,
      replyId,
      kind: 'reply',
      action: verdict.action,
    });

    // Only once the reply is actually visible — telling someone they have
    // support and then blocking OR holding the message would be worse than
    // silence.
    if (verdict.action === 'allow' || verdict.action === 'flag') {
      await notifyPostAuthor(postId);
    }
  },
);

/**
 * Tells the author of an SOS post that a real person answered it.
 *
 * This is the community half of docs/03 §7's "someone else pulls you out" —
 * the stage the deleted buddy system used to hold. It only fires for `sos`
 * posts: a reply on an ordinary post is nice, but it is not the thing somebody
 * mid-craving is waiting for, and a push that is merely nice is how an app
 * teaches people to turn its pushes off.
 *
 * The author's uid lives in `postAuthors/{postId}` rather than on the post,
 * which is exactly what keeps the feed anonymous — so the lookup is a separate
 * read by design, not an oversight.
 *
 * Exported for `resolveModeration`: a held reply the founder later approves
 * still owes the SOS author this push — the trigger rightly skipped it while
 * the reply was invisible.
 */
export async function notifyPostAuthor(postId: string): Promise<void> {
  try {
    const post = await postsCol().doc(postId).get();
    if (post.get('tag') !== 'sos') return;

    const author = await db.collection('postAuthors').doc(postId).get();
    const uid: unknown = author.get('uid');
    if (typeof uid !== 'string' || uid.length === 0) return;

    await sendLocalized(uid, 'sosReply', '/community');
  } catch (error) {
    log.warn('push.sos_reply_failed', {postId, error: String(error)});
  }
}
