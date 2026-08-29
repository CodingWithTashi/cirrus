/**
 * Shared UGC classification for posts and replies (docs/04 §6).
 *
 * Lives here rather than in a handler because App Store Guideline 1.2 applies
 * to every piece of user content, and two copies of a moderation rule is how
 * one of them ends up more permissive than the other.
 *
 * Fail-CLOSED throughout: an unreachable model or an unparseable verdict
 * becomes `flag`, never `allow`. A delayed post is a bug report; an
 * unmoderated one is an app removal.
 */
import {GEMINI_API_KEY, MODEL_MODERATION} from '../config';
import {geminiModel} from './gemini';
import {ModelUnavailableError} from './model';
import {MODERATION_PROMPT} from './prompts';
import {log} from '../lib/logger';

export type ModerationAction = 'allow' | 'flag' | 'block';

export interface Verdict {
  action: ModerationAction;
  reason: string;
}

export async function classify(text: string): Promise<Verdict> {
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
