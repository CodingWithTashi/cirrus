/**
 * Shared UGC classification for posts and replies (docs/04 §6).
 *
 * Lives here rather than in a handler because App Store Guideline 1.2 applies
 * to every piece of user content, and two copies of a moderation rule is how
 * one of them ends up more permissive than the other.
 *
 * Fail-CLOSED throughout, for real this time: an unreachable model, an
 * unparseable verdict, or ANY other failure becomes `hold` — the content
 * stays invisible and lands in the founder's queue. The Aug 31 2026 field
 * test found the previous version returned `flag` on outage, which the
 * triggers mapped to `live`: a model outage published every post. A delayed
 * post is a bug report; an unmoderated one is an app removal.
 *
 * `prefilter` (a deterministic wordlist) runs before the model: a slur blocks
 * even when the model is down, and never spends a token.
 */
import {GEMINI_API_KEY, MODEL_MODERATION} from '../config';
import {geminiModel} from './gemini';
import {prefilter} from './prefilter';
import {MODERATION_PROMPT} from './prompts';
import {log} from '../lib/logger';

export type ModerationAction = 'allow' | 'flag' | 'hold' | 'block';

export interface Verdict {
  action: ModerationAction;
  reason: string;
  /**
   * True only when the hold is the PIPELINE's own failure — the model was
   * unreachable, or its answer did not parse — so asking again later may
   * produce a real verdict. `remoderateHeld` re-runs exactly these. A hold
   * the model chose never carries it: that is a judgment for a human.
   */
  retryable?: boolean;
}

/**
 * Classifies one piece of user content.
 *
 * `tag` is the post's server-validated enum value (`asEnum` in `createPost`),
 * never free text — it lets the model catch a celebratory WIN tag pasted onto
 * a hostile rant. Replies pass no tag.
 *
 * Never throws: every failure is a `hold` verdict, so a trigger can map the
 * result to a status without its own catch — an uncaught throw here used to
 * strand content `pending` with no queue row, invisible to everyone forever.
 */
export async function classify(text: string, tag?: string): Promise<Verdict> {
  const pre = prefilter(text);
  if (pre !== null) return pre;

  try {
    // Inside the try on purpose: `GEMINI_API_KEY.value()` itself throws when
    // the secret is unbound (a config edit, an emulator without .env), and a
    // throw here escaped the "never throws" promise — the trigger died
    // uncaught and the content stranded pending with no queue row.
    const model = geminiModel(GEMINI_API_KEY.value());
    const result = await model.generate({
      model: MODEL_MODERATION.value(),
      systemInstruction: MODERATION_PROMPT,
      turns: [
        {role: 'user', text: tag === undefined ? text : `Tag: ${tag}\nPost: ${text}`},
      ],
      maxOutputTokens: 200,
      temperature: 0, // classification, not creativity
      json: true,
    });
    return parseVerdict(result.text);
  } catch (error) {
    log.error('moderation.unavailable', {error: String(error)});
    return {
      action: 'hold',
      reason: 'moderation unavailable — held for human review',
      retryable: true,
    };
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
    if (
      action !== 'allow' &&
      action !== 'flag' &&
      action !== 'hold' &&
      action !== 'block'
    ) {
      throw new Error('unknown action');
    }
    return {action, reason: typeof reason === 'string' ? reason : ''};
  } catch {
    // Unparseable verdict is not consent — and not publication either.
    return {action: 'hold', reason: 'unparseable moderation response', retryable: true};
  }
}
