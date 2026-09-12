/**
 * Request validation for callables. Everything a client sends is untrusted,
 * so every handler starts here.
 *
 * On timezone and locale: a callable request carries no ambient timezone, so
 * the client supplies both and this module sanitizes them. That is safe
 * precisely because neither is a privilege — the worst a lying client gets is
 * its own day boundary in the wrong place. Anything that IS a privilege
 * (tier, quota) is read server-side from `users/{uid}`, never from `data`.
 */
import {HttpsError} from 'firebase-functions/v2/https';
import type {CallableRequest} from 'firebase-functions/v2/https';

export interface Caller {
  readonly uid: string;
  /** Validated IANA zone; 'UTC' when the client sends nothing usable. */
  readonly timeZone: string;
  /** BCP-47 tag, used to pin Ember's reply language. */
  readonly locale: string;
}

const DEFAULT_TIME_ZONE = 'UTC';
const DEFAULT_LOCALE = 'en';

/** BCP-47 subset: a language subtag plus optional script/region subtags. */
const LOCALE_PATTERN = /^[a-z]{2,3}(-[a-z0-9]{2,8})*$/i;

/**
 * Authenticated caller, or a thrown `unauthenticated`. Anonymous Firebase
 * accounts pass — guest onboarding is a real session (docs/05 §1).
 */
export function requireCaller(request: CallableRequest<unknown>): Caller {
  const uid = request.auth?.uid;
  if (uid === undefined || uid.length === 0) {
    throw new HttpsError('unauthenticated', 'Sign in to continue.');
  }

  const data = (request.data ?? {}) as Record<string, unknown>;
  return {
    uid,
    timeZone: normalizeTimeZone(data['timeZone'] ?? data['tz']),
    locale: normalizeLocale(data['locale']),
  };
}

/**
 * A required, non-empty, length-capped string field. Returns it trimmed —
 * callers store the return value, never the raw input.
 */
export function requireText(
  value: unknown,
  field: string,
  maxChars: number,
): string {
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', `"${field}" must be text.`);
  }
  const trimmed = value.trim();
  if (trimmed.length === 0) {
    throw new HttpsError('invalid-argument', `"${field}" cannot be empty.`);
  }
  // A wire backstop before the real count: graphemes are unbounded in code
  // units (one family emoji is eleven), so a pathological payload could be
  // enormous while counting as 500 "characters". Four times the limit is far
  // past anything a person types and far short of anything that matters.
  if (trimmed.length > maxChars * MAX_WIRE_MULTIPLIER) {
    throw new HttpsError(
      'invalid-argument',
      `"${field}" must be ${maxChars} characters or fewer.`,
    );
  }
  if (countChars(trimmed) > maxChars) {
    throw new HttpsError(
      'invalid-argument',
      `"${field}" must be ${maxChars} characters or fewer.`,
    );
  }
  return trimmed;
}

const MAX_WIRE_MULTIPLIER = 4;

/** Long enough for any id we mint, short enough to be obviously an id. */
const MAX_DOC_ID_CHARS = 200;

/**
 * A document id that arrived from a client and is about to be concatenated
 * into a Firestore path.
 *
 * Firestore refuses four shapes, and it refuses them by THROWING a plain
 * Error rather than returning one — so an unguarded id leaves the callable
 * with an unhandled rejection and the caller gets `internal`, a 500 that
 * pages as a server fault, for what is only a bad argument.
 *
 * A slash is the one that is not merely untidy: `.doc('a/b')` addresses a
 * different path entirely.
 *
 * `forgetCoachMemory` guarded the slash and nothing else; the other five
 * client-supplied ids in the codebase — `createReply`'s postId,
 * `reportPost`'s, `reportReply`'s pair and `moderationQueue`'s flagId —
 * guarded nothing at all. One helper so the next one cannot be forgotten.
 */
export function requireDocId(value: unknown, field: string): string {
  const id = requireText(value, field, MAX_DOC_ID_CHARS);
  if (
    id.includes('/') ||
    id === '.' ||
    id === '..' ||
    /^__.*__$/.test(id)
  ) {
    throw new HttpsError('invalid-argument', `Bad ${field}.`);
  }
  return id;
}

/**
 * Characters as a PERSON counts them, which is what every limit here is
 * expressed in and what the app's own counter shows.
 *
 * This counted `String.length` — UTF-16 code units — while the composer's
 * `maxLength` counts grapheme clusters (Flutter's `characters` package) and
 * `CoachName` counts code points. So the three layers measured three
 * different things and the server was always the meanest: a 500-character
 * post containing emoji is 750 code units, and it was refused after the
 * composer's counter had said 500/500. The refusal is not even legible as
 * one — `createPost`'s caller files it under `PostStatus.failed`, which draws
 * a Retry button that re-sends identical text forever.
 *
 * `Intl.Segmenter` is the same segmentation the client uses, so the two now
 * agree exactly. It needs full ICU, which the nodejs22 runtime has; the
 * fallback counts code points, which is still far closer than code units.
 */
const segmenter =
  typeof Intl !== 'undefined' && typeof Intl.Segmenter === 'function'
    ? new Intl.Segmenter('en', {granularity: 'grapheme'})
    : null;

export function countChars(text: string): number {
  if (segmenter === null) return [...text].length;
  let n = 0;
  for (const _ of segmenter.segment(text)) n += 1;
  return n;
}

/** The longest alias we will store. Client aliases are ~14 chars. */
export const MAX_ALIAS_CHARS = 32;

/** Anything outside this is dropped before an alias is stored or displayed. */
const ALIAS_ALLOWED = /[^A-Za-z0-9_@[\]. -]/g;

/**
 * A well-formed client alias: `@quietfox42`, as `_randomAlias()` mints them.
 *
 * Only aliases of this exact shape can be the target of an @mention. That is
 * narrower than what [sanitizeAlias] will STORE, and deliberately so: storage
 * has to stay permissive enough for the seed fixtures and for
 * `[departed quitter]`, while mention matching is a lookup key and wants the
 * tightest shape it can get.
 */
const MENTIONABLE_ALIAS = /^@[a-z]{3,24}\d{1,3}$/i;

/**
 * An alias safe to store and to render.
 *
 * `alias` arrives as completely untrusted free text — it is whatever the
 * client claimed, and the server has never verified that a caller owns the
 * alias it posts under. Until this existed it was written verbatim onto the
 * post, with no type check, no length cap and no charset: a 10KB alias, a
 * newline-stuffed one that breaks the feed's layout, or one shaped to be
 * mistaken for somebody else were all accepted.
 *
 * This does not make an alias *trustworthy* — it cannot, while aliases are
 * minted client-side from 5,760 combinations with no uniqueness check — it
 * only makes it safe to handle. See `resolveMentions` for how the
 * impersonation half is contained.
 */
export function sanitizeAlias(value: unknown): string {
  if (typeof value !== 'string') return DEFAULT_ALIAS;
  const cleaned = value.replace(ALIAS_ALLOWED, '').trim().slice(0, MAX_ALIAS_CHARS);
  return cleaned.length > 0 ? cleaned : DEFAULT_ALIAS;
}

/** Whether [alias] can be the target of an @mention. See [MENTIONABLE_ALIAS]. */
export function isMentionableAlias(alias: string): boolean {
  return MENTIONABLE_ALIAS.test(alias);
}

/**
 * An avatar safe to store: at most a couple of glyphs.
 *
 * Same untrusted-free-text bug as [sanitizeAlias] and fixed in the same pass
 * because it is the adjacent field on the same two writes. `Array.from`
 * rather than `slice` so a surrogate pair is one glyph and is never cut in
 * half — a lone surrogate is what turns a feed row into a replacement box.
 */
export function sanitizeEmoji(value: unknown): string {
  if (typeof value !== 'string') return DEFAULT_EMOJI;
  // Only actual pictographs. This took the first two code points of ANY
  // string, so `"ab"`, `"<s"`, `"99"` and — the one that matters — two
  // right-to-left overrides all became somebody's avatar, rendered on every
  // post they ever wrote, to every reader. The alias beside it has had an
  // ASCII allowlist all along; this had nothing.
  //
  // Safe to be this strict: the avatar is not typed, it is drawn from the
  // fixed animal list in `_randomAlias()`, so it is always one plain emoji.
  // A variation selector rides along only when a pictograph is already there.
  const kept = Array.from(value.trim()).filter(
    (c) => PICTOGRAPHIC.test(c) || c === '️',
  );
  const glyphs = kept.slice(0, MAX_EMOJI_GLYPHS).join('');
  return PICTOGRAPHIC.test(glyphs) ? glyphs : DEFAULT_EMOJI;
}

/**
 * A day number fit to render as "Day N".
 *
 * `dayN` arrived as `typeof x === 'number' ? x : 0`, which let a caller post
 * as day `-5`, day `3.7` or day `1000000000000000` — in a public feed, beside
 * everyone else's honest count. `NaN` and `Infinity` are numbers too, and
 * Firestore stores both as null.
 *
 * Clamped rather than refused: the number is decoration on somebody's post,
 * not a claim anything depends on, so a nonsense value should cost the post
 * its badge, never the post itself.
 */
export function sanitizeDayN(value: unknown): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) return 0;
  const n = Math.trunc(value);
  if (n < 0) return 0;
  return n > MAX_DAY_N ? MAX_DAY_N : n;
}

const DEFAULT_ALIAS = 'quitter';
const DEFAULT_EMOJI = '\u{1F525}';
const MAX_EMOJI_GLYPHS = 2;

/** Anything drawn as a picture rather than read as a letter. */
const PICTOGRAPHIC = /\p{Extended_Pictographic}/u;

/**
 * Twenty-seven years of plan days. Not a real ceiling anyone reaches — just
 * high enough that no honest counter meets it and low enough that the badge
 * stays a badge.
 */
const MAX_DAY_N = 9999;

/**
 * Narrows an untrusted value to one of `allowed`, or null. Null rather than a
 * throw because several callers treat absence as a legitimate branch (a coach
 * turn has either a chip or free text, never both).
 */
export function asEnum<T extends string>(
  value: unknown,
  allowed: readonly string[],
): T | null {
  return typeof value === 'string' && allowed.includes(value)
    ? (value as T)
    : null;
}

/** An unrecognized zone falls back rather than throwing — a bad clock hint is not worth failing a panic request over. */
function normalizeTimeZone(value: unknown): string {
  if (typeof value !== 'string' || value.length === 0) {
    return DEFAULT_TIME_ZONE;
  }
  try {
    const resolved = Intl.DateTimeFormat('en-US', {
      timeZone: value,
    }).resolvedOptions().timeZone;
    return resolved.length > 0 ? value : DEFAULT_TIME_ZONE;
  } catch {
    return DEFAULT_TIME_ZONE;
  }
}

function normalizeLocale(value: unknown): string {
  if (typeof value !== 'string') return DEFAULT_LOCALE;
  const tag = value.trim();
  return LOCALE_PATTERN.test(tag) ? tag : DEFAULT_LOCALE;
}
