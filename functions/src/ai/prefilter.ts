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

/**
 * Is there actually a message here?
 *
 * A different question from `prefilter`, which asks whether something may be
 * said. This asks whether anything WAS said, and it is the floor under the
 * composer's own check: the client refuses first so the words are still there
 * to edit, and this refuses a client that skipped it.
 *
 * It exists because the panic flow opens the composer pre-tagged `sos`, so a
 * post is one tap away with the tag already chosen — and a live SOS pins to
 * the top of the feed for an hour. `"a"` used to publish, and it pinned.
 *
 * Runs BEFORE any allowance is claimed, like the slur check above: junk never
 * costs its author a slot.
 *
 * Mirrors `PostQuality` in `lib/domain/logic/community_rules.dart`
 * value-for-value; `test/domain/post_quality_test.dart` reads this file and
 * fails if the two drift, the same discipline the slur lists are held to.
 *
 * **Assumes a space-separated script**, as all five shipped locales are. The
 * word rules would need to become script-aware before shipping zh/ja/th.
 */
export const POST_QUALITY = {
  minPostChars: 12,
  /**
   * An SOS asks for less. This gate is reached from the composer the panic
   * flow opens pre-tagged `sos`, and a wrongly-refused cry for help costs far
   * more than the junk post it would have caught. Only the character floor
   * moves — every anti-noise rule still applies.
   */
  minSosChars: 10,
  /** A reply is allowed to be "thanks". */
  minReplyChars: 6,
  minPostWords: 3,
  /** Two, not three, so "i cant i cant" still reaches the feed. */
  minDistinctWords: 2,
  minLetters: 3,
  minPostDistinctLetters: 4,
  minReplyDistinctLetters: 3,
} as const;

export type PostQualityIssue = 'tooShort' | 'repetitive';

function checkQuality(
  text: string,
  minChars: number,
  minWords: number,
  minDistinctLetters: number,
): PostQualityIssue | null {
  const collapsed = text.trim().replace(/\s+/gu, ' ');
  if (collapsed.length < minChars) return 'tooShort';

  const words = collapsed.split(' ').filter((w) => w.length > 0);
  if (words.length < minWords) return 'tooShort';

  // Only meaningful once there are enough words for repetition to BE
  // repetition — a two-word reply is not "the same thing over and over".
  if (
    words.length >= POST_QUALITY.minPostWords &&
    new Set(words.map((w) => w.toLowerCase())).size <
      POST_QUALITY.minDistinctWords
  ) {
    return 'repetitive';
  }

  const letters = [...collapsed.toLowerCase()].filter((c) => /\p{L}/u.test(c));
  if (letters.length < POST_QUALITY.minLetters) return 'tooShort';
  if (new Set(letters).size < minDistinctLetters) return 'repetitive';
  return null;
}

/**
 * The issue with [text] as a post, or null when it is fine to publish.
 *
 * `sos` lowers only the character floor (see `minSosChars`).
 */
export function postQuality(text: string, sos = false): PostQualityIssue | null {
  return checkQuality(
    text,
    sos ? POST_QUALITY.minSosChars : POST_QUALITY.minPostChars,
    POST_QUALITY.minPostWords,
    POST_QUALITY.minPostDistinctLetters,
  );
}

/** The issue with [text] as a reply. Lower bar in every dimension. */
export function replyQuality(text: string): PostQualityIssue | null {
  return checkQuality(
    text,
    POST_QUALITY.minReplyChars,
    1,
    POST_QUALITY.minReplyDistinctLetters,
  );
}
