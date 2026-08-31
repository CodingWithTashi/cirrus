/**
 * Plan-relative week aggregates for the coach's USER CARD.
 *
 * Why this exists: "compare my week 2 to my week 5" was a question the card
 * could not answer — it carried only the last seven days of puffs. These
 * aggregates are derived from the SAME primitives the app renders from
 * (`holds`, each day's stored limit, `dateKey` calendar math), so Ember can
 * quote them without ever contradicting a screen.
 *
 * NO DART TWIN, deliberately. CLAUDE.md's engine-drift rule exists so the
 * coach never quotes a number a screen contradicts — and no screen renders
 * these aggregates; every input (`holds`, stored limits, day keys) is already
 * parity-pinned at the primitive level. If Stats ever renders them, port this
 * to `lib/domain/logic/week_stats.dart` with parity fixtures in BOTH test
 * suites first.
 */
import {addDays, daysBetween} from './dateKey';
import {holds, isConfirmed} from './streakEngine';
import type {DayLog} from './types';

export interface WeekStat {
  /** 1-based; week 1 starts on `plan.startDate`. */
  readonly week: number;
  /** `yyyy-MM-dd` of the week's first day. */
  readonly startKey: string;
  /** Days of this week already over (strictly before today). 0–7. */
  readonly elapsed: number;
  /** Elapsed days with a confirmed log. */
  readonly logged: number;
  /** Confirmed days that held the chain (a repair token counts). */
  readonly onTarget: number;
  /** Confirmed days that did NOT hold — over limit, no token. */
  readonly slips: number;
  /** Mean puffs across confirmed days, rounded; null when nothing was logged. */
  readonly avgPuffs: number | null;
  /** The lowest-puff confirmed day. */
  readonly best: {readonly date: string; readonly puffs: number} | null;
  /** True for the in-progress week (today caps its `elapsed`). */
  readonly current: boolean;
}

/**
 * Every plan-relative week from `startDate` through `todayKey`, oldest first.
 *
 * Today is EXCLUDED everywhere — the same "today is still in progress" stance
 * `currentStreak` and `trailingDays` take; the card's `today: X/Y` line
 * carries the live number. An unlogged day is reported as unlogged
 * (`elapsed - logged`), never as a slip: breaking a chain on silence is
 * `currentStreak`'s business, a week summary reports what is known. Weeks
 * keep counting past the plan's end (maintenance tenure) — `holds` reads each
 * day's own stored limit, so post-plan days aggregate with no dependence on
 * the taper curve. Returns [] when `todayKey` precedes `startDate`.
 */
export function weekStats(
  days: Readonly<Record<string, DayLog>>,
  startDate: string,
  todayKey: string,
): WeekStat[] {
  const total = daysBetween(startDate, todayKey);
  if (total < 0) return [];

  const weekCount = Math.floor(total / 7) + 1;
  const out: WeekStat[] = [];
  for (let week = 1; week <= weekCount; week++) {
    const startKey = addDays(startDate, (week - 1) * 7);
    const elapsed = Math.min(7, daysBetween(startKey, todayKey));

    let logged = 0;
    let onTarget = 0;
    let slips = 0;
    let puffSum = 0;
    let best: {date: string; puffs: number} | null = null;
    for (let i = 0; i < elapsed; i++) {
      const key = addDays(startKey, i);
      const log = days[key];
      if (!log || !isConfirmed(log)) continue;
      logged++;
      puffSum += log.puffs;
      if (holds(log)) {
        onTarget++;
      } else {
        slips++;
      }
      if (best === null || log.puffs < best.puffs) {
        best = {date: key, puffs: log.puffs};
      }
    }

    out.push({
      week,
      startKey,
      elapsed,
      logged,
      onTarget,
      slips,
      avgPuffs: logged === 0 ? null : Math.round(puffSum / logged),
      best,
      current: week === weekCount,
    });
  }
  return out;
}
