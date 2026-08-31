/**
 * Deterministic wordlist gate that runs BEFORE the moderation model.
 *
 * Exists for one guarantee the model cannot give: a slur never publishes,
 * even mid model outage — the Aug 31 2026 field test proved the model path
 * alone lets hostile content straight through, and `classify` fails closed to
 * `hold` only when it gets to run at all. A hit here also skips the model
 * call entirely, so the worst content is also the cheapest to refuse.
 *
 * Precision over recall, deliberately:
 * - Every entry must be unambiguous in ALL five app locales (en/es/fr/de/pt).
 *   Cross-language false friends are real ("dick" is German for "thick",
 *   "retard" is French for "delay", "fag" is British for cigarette — none of
 *   them are on these lists). The model remains the multilingual, contextual
 *   backstop; this list is the hard floor, not the fence.
 * - Matching is word-boundary (Unicode letter/number lookarounds), never
 *   substring — `violatesCommunityRules` on the client shows how a naive
 *   `contains` blocklist goes wrong (the Scunthorpe problem).
 * - Input is normalized once: lowercased, NFD-decomposed with combining marks
 *   stripped (defeats diacritic obfuscation), common leetspeak mapped back
 *   (n1gger → nigger). The original text is never altered — normalization is
 *   for matching only.
 */
import type {Verdict} from './moderation';

/**
 * The policy knob (founder decision, Aug 31 2026: contextual moderation).
 *
 * `null`: ordinary profanity falls through to the model, whose prompt holds
 * hostile rants and allows self-directed venting ("so fucking proud").
 * `'hold'`: any profanity hit is held for founder review before publishing.
 * Flipping this is a one-word edit; nothing else in the pipeline changes.
 */
export const PROFANITY_ACTION: 'hold' | null = null;

/** Unambiguous slurs/hate terms — a hit blocks without a model call. */
const SLURS: readonly string[] = [
  'nigger',
  'niggers',
  'nigga',
  'niggas',
  'faggot',
  'faggots',
  'kike',
  'kikes',
  'spic',
  'spics',
  'wetback',
  'wetbacks',
  'gook',
  'gooks',
  'tranny',
  'trannies',
  'beaner',
  'beaners',
  'towelhead',
  'towelheads',
  'raghead',
  'ragheads',
];

/**
 * Ordinary profanity — consulted only when [PROFANITY_ACTION] is not null.
 * Starred forms cover the self-censored spellings the leet map cannot.
 */
const PROFANITY: readonly string[] = [
  'fuck',
  'fucking',
  'fucked',
  'fucker',
  'motherfucker',
  'f*ck',
  'f**k',
  'shit',
  'shitty',
  'bullshit',
  'sh*t',
  'asshole',
  'assholes',
  'a*shole',
  'bitch',
  'bitches',
  'b*tch',
  'cunt',
  'cunts',
  'c*nt',
  'bastard',
  'bastards',
  'wanker',
  'wankers',
];

const LEET: Record<string, string> = {
  '0': 'o',
  '1': 'i',
  '3': 'e',
  '4': 'a',
  '5': 's',
  '7': 't',
  '@': 'a',
  $: 's',
};

function normalize(text: string): string {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[013457@$]/g, (c) => LEET[c] ?? c);
}

function escapeRegExp(term: string): string {
  return term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * `\b` misbehaves next to accented letters, so boundaries are explicit
 * Unicode lookarounds: a term matches only when not glued to another letter
 * or digit on either side. "Scunthorpe" stays innocent; "you CUNT" does not.
 */
function boundaryRegex(term: string): RegExp {
  return new RegExp(
    `(?<![\\p{L}\\p{N}])${escapeRegExp(term)}(?![\\p{L}\\p{N}])`,
    'u',
  );
}

const SLUR_MATCHERS = SLURS.map(boundaryRegex);
const PROFANITY_MATCHERS = PROFANITY.map(boundaryRegex);

/**
 * The deterministic verdict, or null to let the model decide.
 *
 * Reasons are prefixed `prefilter:` so the founder's queue shows at a glance
 * that no model was involved.
 */
export function prefilter(text: string): Verdict | null {
  const normalized = normalize(text);
  if (SLUR_MATCHERS.some((m) => m.test(normalized))) {
    return {action: 'block', reason: 'prefilter: slur'};
  }
  if (
    PROFANITY_ACTION !== null &&
    PROFANITY_MATCHERS.some((m) => m.test(normalized))
  ) {
    return {action: PROFANITY_ACTION, reason: 'prefilter: profanity'};
  }
  return null;
}
