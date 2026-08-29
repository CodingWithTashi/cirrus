/**
 * `moderatePost` — every community post and reply passes through a model
 * before it can be seen (docs/03 §9, docs/04 §6).
 *
 * This is an App Store gate, not a nicety: Guideline 1.2 requires a method
 * for filtering objectionable UGC. A client-side check would satisfy nobody —
 * it ships in the binary and can simply be skipped.
 *
 * Fail-CLOSED: if the model is unreachable, the post stays pending rather
 * than going live unreviewed. A delayed post is a bug report; an unmoderated
 * one is an app removal.
 */
import {onDocumentCreated} from 'firebase-functions/v2/firestore';
import {GEMINI_API_KEY, REGION} from '../config';
import {classify} from '../ai/moderation';
import {FieldValue, moderationDoc} from '../lib/firestore';
import {log} from '../lib/logger';

/**
 * Posts are created with `status: 'pending'` by the client and flipped here.
 * The security rules only let clients READ `status == 'live'`, so "pending"
 * is genuinely invisible rather than merely unrendered.
 */
export const moderatePost = onDocumentCreated(
  {
    region: REGION,
    document: 'posts/{postId}',
    secrets: [GEMINI_API_KEY],
    memory: '256MiB',
    retry: false, // a retry storm on a bad post would just re-spend tokens
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const text = snap.get('text') as unknown;
    const postId = event.params.postId;

    if (typeof text !== 'string' || text.trim().length === 0) {
      await snap.ref.update({status: 'blocked', moderatedAt: FieldValue.serverTimestamp()});
      return;
    }

    const verdict = await classify(text);

    await snap.ref.update({
      status: verdict.action === 'block' ? 'blocked' : 'live',
      moderatedAt: FieldValue.serverTimestamp(),
    });

    // Flagged content stays visible but lands in the founder's daily queue
    // (docs/03 §9, target < 24h review).
    if (verdict.action !== 'allow') {
      await moderationDoc(postId).set({
        postId,
        action: verdict.action,
        reason: verdict.reason,
        reviewed: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    log.info('moderation.verdict', {postId, action: verdict.action});
  },
);

// Re-exported so `test/parsers.test.ts` keeps its import path while the
// implementation lives in ai/moderation.ts alongside the reply classifier.
export {parseVerdict} from '../ai/moderation';
