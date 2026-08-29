/**
 * Structured logging. `console` is banned by eslint because Cloud Logging
 * reads severity off the entry, not off the string — a `console.log` of an
 * error is invisible to an alert policy.
 *
 * Convention: the first argument is a dotted event name (`coach.turn`,
 * `rcWebhook.handled`) so logs are greppable and can back a metric. Payloads
 * are structured fields, never interpolated into the message.
 */
import {logger} from 'firebase-functions/v2';

export type LogMeta = Record<string, unknown>;

export const log = {
  debug: (event: string, meta: LogMeta = {}): void => logger.debug(event, meta),
  info: (event: string, meta: LogMeta = {}): void => logger.info(event, meta),
  warn: (event: string, meta: LogMeta = {}): void => logger.warn(event, meta),
  error: (event: string, meta: LogMeta = {}): void => logger.error(event, meta),
};

/**
 * Fields that must never reach Cloud Logging in the clear. Coach text is the
 * important one: transcripts are the most sensitive thing this app holds, and
 * a log line is exactly the place they leak from (docs/05 §9, and our own
 * "we never sell your data" promise is worth nothing if we log it instead).
 */
const REDACTED_KEYS = new Set([
  'text', 'reply', 'message', 'prompt', 'systemInstruction',
  'email', 'alias', 'token', 'fcmToken', 'authorization', 'apiKey',
]);

/**
 * Scrubs a log payload: sensitive fields are dropped, and `uid` is replaced
 * by a short stable digest so sessions stay correlatable without the log
 * becoming a user index.
 */
export function safeMeta(meta: LogMeta): LogMeta {
  const out: LogMeta = {};
  for (const [key, value] of Object.entries(meta)) {
    if (REDACTED_KEYS.has(key)) {
      out[key] = '[redacted]';
    } else if (key === 'uid' && typeof value === 'string') {
      out['uidHash'] = shortHash(value);
    } else {
      out[key] = value;
    }
  }
  return out;
}

/**
 * Not a security boundary — uids are not secret — just enough indirection
 * that a log export isn't a ready-made list of accounts. FNV-1a keeps this
 * dependency-free and off the crypto module's cold-start cost.
 */
function shortHash(value: string): string {
  let hash = 0x811c9dc5;
  for (let i = 0; i < value.length; i++) {
    hash ^= value.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash.toString(16).padStart(8, '0');
}
