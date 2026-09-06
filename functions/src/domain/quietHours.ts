/**
 * Whether it is the middle of the recipient's night.
 *
 * Mirrors `ReminderPlanner.isQuiet` in `lib/domain/logic/reminder_planner.dart`
 * — same wrap-midnight rule, same 23:00–08:00 default — because the two sides
 * describe one user-facing idea and the app lets people edit it in Settings.
 * Any change to the rule lands in both, or a user's quiet hours mean two
 * different things depending on which half of the system is talking.
 *
 * ## Quiet never suppresses, and that is what makes it safe
 *
 * A quiet-hours push is delivered silently rather than withheld. That choice
 * is what makes an imperfect timezone cheap: the worst a wrong zone can do is
 * deliver something without a sound that could have rung, and the message is
 * still sitting in the shade when the person picks the phone up. Withholding
 * would have made the same mistake cost the notification entirely.
 */

/** docs/03 §8, and the same defaults the client's `SettingsState` carries. */
export const DEFAULT_QUIET_START = 23;
export const DEFAULT_QUIET_END = 8;

/**
 * The recipient's local hour, or null when we have no usable zone.
 *
 * Null rather than a UTC fallback: guessing UTC for somebody in Sydney would
 * silence them through their working afternoon, and "we do not know" is a
 * fact the caller can act on correctly by simply not going quiet.
 */
export function localHour(nowMs: number, timeZone: string | undefined): number | null {
  if (typeof timeZone !== 'string' || timeZone.length === 0) return null;
  try {
    const hour = new Intl.DateTimeFormat('en-US', {
      timeZone,
      hour: 'numeric',
      hour12: false,
    }).format(new Date(nowMs));
    const parsed = Number.parseInt(hour, 10);
    if (Number.isNaN(parsed)) return null;
    // `hour12: false` yields 24 for midnight in some ICU versions.
    return parsed % 24;
  } catch {
    return null;
  }
}

/**
 * Whether [hour] falls in the window [start, end).
 *
 * The window normally wraps midnight (23 → 8), so this cannot be a simple
 * range test. A start equal to the end is treated as no quiet hours at all
 * rather than as a whole silent day — the destructive reading of an
 * ambiguous setting is never the right default.
 */
export function isQuietHour(hour: number, start: number, end: number): boolean {
  const s = ((start % 24) + 24) % 24;
  const e = ((end % 24) + 24) % 24;
  const h = ((hour % 24) + 24) % 24;
  if (s === e) return false;
  return s < e ? h >= s && h < e : h >= s || h < e;
}

/** Whether a push to somebody in [timeZone] would land during their night. */
export function inQuietHours(
  nowMs: number,
  timeZone: string | undefined,
  start: number = DEFAULT_QUIET_START,
  end: number = DEFAULT_QUIET_END,
): boolean {
  const hour = localHour(nowMs, timeZone);
  if (hour === null) return false;
  return isQuietHour(hour, start, end);
}
