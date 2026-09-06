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
  if (trimmed.length > maxChars) {
    throw new HttpsError(
      'invalid-argument',
      `"${field}" must be ${maxChars} characters or fewer.`,
    );
  }
  return trimmed;
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
  const glyphs = Array.from(value.trim()).slice(0, MAX_EMOJI_GLYPHS).join('');
  return glyphs.length > 0 ? glyphs : DEFAULT_EMOJI;
}

const DEFAULT_ALIAS = 'quitter';
const DEFAULT_EMOJI = '\u{1F525}';
const MAX_EMOJI_GLYPHS = 2;

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
