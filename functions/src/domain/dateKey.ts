/**
 * Day keys are `'yyyy-MM-dd'` at the USER's local midnight — never epoch math
 * (mirrors `lib/data/dto/codec_helpers.dart`). The server has no local
 * timezone worth trusting, so every helper takes an IANA zone explicitly.
 */

const KEY = /^(\d{4})-(\d{2})-(\d{2})$/;

/** `Date` → `yyyy-MM-dd` as observed in [timeZone]. */
export function dayKeyIn(instant: Date, timeZone: string): string {
  // en-CA formats as yyyy-MM-dd, which is exactly the wire shape.
  return new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(instant);
}

/** Hour 0–23 as observed in [timeZone]. */
export function hourIn(instant: Date, timeZone: string): number {
  const hour = new Intl.DateTimeFormat('en-GB', {
    timeZone,
    hour: '2-digit',
    hour12: false,
  }).format(instant);
  return Number.parseInt(hour, 10) % 24;
}

/** Whole days from [from] to [to], both `yyyy-MM-dd`. Negative if [to] precedes. */
export function daysBetween(from: string, to: string): number {
  const MS_PER_DAY = 86_400_000;
  return Math.round((utcMillis(to) - utcMillis(from)) / MS_PER_DAY);
}

/** Shifts a `yyyy-MM-dd` key by [delta] days. */
export function addDays(key: string, delta: number): string {
  const d = new Date(utcMillis(key) + delta * 86_400_000);
  return d.toISOString().slice(0, 10);
}

/** Validates the wire shape before it reaches a Firestore path or Date. */
export function isDayKey(value: unknown): value is string {
  return typeof value === 'string' && KEY.test(value);
}

/**
 * Parses a day key as UTC midnight. Safe for differencing keys against each
 * other (both sides share the fiction); never use it to render a wall clock.
 */
function utcMillis(key: string): number {
  const m = KEY.exec(key);
  if (!m) throw new RangeError(`not a yyyy-MM-dd day key: ${key}`);
  return Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
}
