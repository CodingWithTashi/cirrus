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
import {FieldValue, moderationDoc} from '../lib/firestore';
import {log} from '../lib/logger';
import {notifyReply} from '../lib/notifyReply';
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
        retryable: verdict.retryable === true,
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
    // silence. `flag` publishes (VERDICT_STATUS maps it to 'live') and so
    // notifies: a flagged reply is visible while the founder reviews it, and
    // withholding the push would leave the author reading it in the feed
    // having never been told.
    if (verdict.action === 'allow' || verdict.action === 'flag') {
      await notifyReply(postId, replyId);
    }
  },
);
