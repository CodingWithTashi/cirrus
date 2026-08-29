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

    await snap.ref.update({
      status: verdict.action === 'block' ? 'blocked' : 'live',
      moderatedAt: FieldValue.serverTimestamp(),
    });

    // Flagged content stays visible but joins the founder's daily queue.
    // Keyed by replyId so a flagged reply cannot overwrite its parent's row.
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

    log.info('moderation.verdict', {
      postId,
      replyId,
      kind: 'reply',
      action: verdict.action,
    });
  },
);
