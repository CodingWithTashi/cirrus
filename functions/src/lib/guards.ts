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
