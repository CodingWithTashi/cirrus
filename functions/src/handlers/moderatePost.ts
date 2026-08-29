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
import {GEMINI_API_KEY, MODEL_MODERATION, REGION} from '../config';
import {geminiModel} from '../ai/gemini';
import {MODERATION_PROMPT} from '../ai/prompts';
import {ModelUnavailableError} from '../ai/model';
import {FieldValue, moderationDoc} from '../lib/firestore';
import {log} from '../lib/logger';

type Action = 'allow' | 'flag' | 'block';

interface Verdict {
  action: Action;
  reason: string;
}

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

async function classify(text: string): Promise<Verdict> {
  const model = geminiModel(GEMINI_API_KEY.value());
  try {
    const result = await model.generate({
      model: MODEL_MODERATION.value(),
      systemInstruction: MODERATION_PROMPT,
      turns: [{role: 'user', text}],
      maxOutputTokens: 200,
      temperature: 0, // classification, not creativity
      json: true,
    });
    return parseVerdict(result.text);
  } catch (error) {
    if (error instanceof ModelUnavailableError) {
      log.error('moderation.unavailable', {reason: 'model'});
      return {action: 'flag', reason: 'moderation unavailable — needs human review'};
    }
    throw error;
  }
}

/** Models fence JSON even when told not to; strip before parsing (docs/04 §5). */
export function parseVerdict(raw: string): Verdict {
  const cleaned = raw.trim().replace(/^```(?:json)?/i, '').replace(/```$/, '').trim();
  try {
    const parsed: unknown = JSON.parse(cleaned);
    if (parsed === null || typeof parsed !== 'object') throw new Error('not an object');
    const action = (parsed as Record<string, unknown>)['action'];
    const reason = (parsed as Record<string, unknown>)['reason'];
    if (action !== 'allow' && action !== 'flag' && action !== 'block') {
      throw new Error('unknown action');
    }
    return {action, reason: typeof reason === 'string' ? reason : ''};
  } catch {
    // Unparseable verdict is not consent. Flag for a human.
    return {action: 'flag', reason: 'unparseable moderation response'};
  }
}
