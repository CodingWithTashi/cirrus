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

export const isConfirmed = (log: DayLog): boolean =>
  log.puffs > 0 || log.vapeFreeConfirmed;

/**
 * Whether a day keeps the chain alive. Mirrors `StreakEngine` in
 * `lib/domain/logic/streak_engine.dart`:
 *
 *   holds = isConfirmed && (!isOverLimit || repairTokenUsed)
 *
 * The repair-token clause is load-bearing (docs/03 §5) — a token absorbs one
 * over-limit day so the flame dims rather than dying. Omitting it here made
 * the server disagree with the app about the user's own streak.
 *
 * Exported for `weekStats.ts` — week aggregates must count a token-saved day
 * as on-target exactly the way the flame does.
 */
export const holds = (log: DayLog): boolean =>
  isConfirmed(log) && (log.puffs <= log.limit || log.repairTokenUsed);

/**
 * Consecutive holding days ending today, or yesterday when today does not
 * hold — an in-progress OR slipped today dims the flame instead of zeroing it
 * (pinned by the Dart unit test; don't "fix" it to include today).
 *
 * Anchoring on `holds` rather than `isConfirmed` matters: a confirmed but
 * over-limit today would otherwise be counted, fail the check on the first
 * iteration, and return 0 — erasing the whole streak over a single slip.
 */
export function currentStreak(
  days: Readonly<Record<string, DayLog>>,
  todayKey: string,
): number {
  const today = days[todayKey];
  let cursor = today && holds(today) ? todayKey : addDays(todayKey, -1);
  let streak = 0;
  for (;;) {
    const log = days[cursor];
    if (!log || !holds(log)) return streak;
    streak++;
    cursor = addDays(cursor, -1);
  }
}

/** docs/03 §5: one token per seven holding days, wallet capped at two. */
export const TOKEN_EVERY_DAYS = 7;
export const TOKEN_WALLET_CAP = 2;

/**
 * The repair-token wallet, derived from history. Mirrors
 * `StreakEngine.repairTokens` in `lib/domain/logic/streak_engine.dart`
 * line for line — parity cases in both suites.
 *
 * Walks every calendar day from the first log through YESTERDAY: a holding
 * day extends a run, every seventh day of a run mints (never past the cap),
 * a day that used a token spends one. A non-holding day ends the run; the
 * wallet carries over. Today can only spend — a token is earned by finishing
 * the seventh day, not by starting it. Clamped at zero so a
 * `repairTokenUsed` day the old client leak let through still holds without
 * the wallet going negative.
 *
 * The app used to STORE this and re-derive it as `streak / 7` on every
 * mutation, re-minting spent tokens (QA H2, Aug 31 2026). The memory card
 * reads this rather than `journey.repairTokens` for the same reason it
 * recomputes the streak: Ember must never quote a number the app contradicts.
 */
export function repairTokens(
  days: Readonly<Record<string, DayLog>>,
  todayKey: string,
): number {
  const keys = Object.keys(days);
  if (keys.length === 0) return 0;
  let cursor = keys.reduce((a, b) => (a < b ? a : b));
  let run = 0;
  let tokens = 0;
  while (cursor < todayKey) {
    const log = days[cursor];
    if (log && holds(log)) {
      run++;
      if (run % TOKEN_EVERY_DAYS === 0 && tokens < TOKEN_WALLET_CAP) tokens++;
      if (log.repairTokenUsed && tokens > 0) tokens--;
    } else {
      run = 0;
    }
    cursor = addDays(cursor, 1);
  }
  const today = days[todayKey];
  if (today?.repairTokenUsed === true && tokens > 0) tokens--;
  return tokens;
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
