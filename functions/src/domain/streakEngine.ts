/**
 * Port of the streak rules in `lib/domain/logic/streak_engine.dart` +
 * docs/03 §5, for the fields the coach's memory card and the weekly insight
 * need. The client remains the authority on streak *mutation*; this is a
 * read-side recomputation so Ember never quotes a number the app isn't showing.
 */
import {addDays} from './dateKey';
import type {DayLog, FlameState} from './types';

export function flameFor(streakDays: number): FlameState {
  if (streakDays >= 30) return 'inferno';
  if (streakDays >= 14) return 'blaze';
  if (streakDays >= 7) return 'flame';
  if (streakDays >= 3) return 'flicker';
  return 'spark';
}

const isConfirmed = (log: DayLog): boolean =>
  log.puffs > 0 || log.vapeFreeConfirmed;

const isClean = (log: DayLog): boolean =>
  log.puffs <= log.limit && isConfirmed(log);

/**
 * Consecutive clean days ending today, or yesterday when today is still
 * unconfirmed — an in-progress day dims the flame instead of zeroing it
 * (pinned by the Dart unit test; don't "fix" it to include today).
 */
export function currentStreak(
  days: Readonly<Record<string, DayLog>>,
  todayKey: string,
): number {
  const today = days[todayKey];
  let cursor = today && isConfirmed(today) ? todayKey : addDays(todayKey, -1);
  let streak = 0;
  for (;;) {
    const log = days[cursor];
    if (!log || !isClean(log)) return streak;
    streak++;
    cursor = addDays(cursor, -1);
  }
}

/** Trailing [count] days ending at [todayKey], oldest → newest. */
export function trailingDays(
  days: Readonly<Record<string, DayLog>>,
  todayKey: string,
  count: number,
): DayLog[] {
  const out: DayLog[] = [];
  for (let i = count; i >= 1; i--) {
    const log = days[addDays(todayKey, -i)];
    if (log) out.push(log);
  }
  return out;
}

/**
 * The top-2 puff hours across the window (docs/03 §8). Returns [] until at
 * least three days carry hour data — the app falls back to the onboarding
 * `firstPuff` window before that.
 */
export function dangerHours(window: readonly DayLog[]): number[] {
  const withHours = window.filter((d) => Object.keys(d.hourBuckets).length > 0);
  if (withHours.length < 3) return [];
  const totals = new Map<number, number>();
  for (const day of withHours) {
    for (const [hour, puffs] of Object.entries(day.hourBuckets)) {
      const h = Number.parseInt(hour, 10);
      totals.set(h, (totals.get(h) ?? 0) + puffs);
    }
  }
  return [...totals.entries()]
    .sort((a, b) => b[1] - a[1] || a[0] - b[0])
    .slice(0, 2)
    .map(([hour]) => hour);
}
