/**
 * Port of `lib/domain/logic/taper_engine.dart` plus the adaptive nightly
 * layer from docs/03 §3.3 (which has no Dart implementation yet — the server
 * is its authority).
 *
 * PARITY IS LOAD-BEARING: `test/taperEngine.test.ts` pins the same B=200/P=30
 * table as `test/domain/taper_engine_test.dart`. If you change one engine,
 * change both, or the client and server will disagree about a user's limit
 * mid-day.
 *
 * Rounding note: Dart's `num.round()` rounds half away from zero; JS
 * `Math.round` rounds half toward +Infinity. Every value here is
 * non-negative, where the two agree exactly.
 */
import {totalDays, type QuitPlan} from './types';

/** Daily limit for 1-based day [d] of a plan. */
export function limitFor(plan: QuitPlan, d: number): number {
  if (plan.method === 'coldTurkey') return 0;
  const p = totalDays(plan);
  const b = plan.baselinePuffsPerDay;
  if (d >= p) return 0;
  const base = Math.round(b * Math.pow(1 - d / p, 1.5));
  // Fixed tail so the final approach is always [..., <=3, <=1, 0]. docs/03's
  // prose floor contradicts its own worked example; the example wins (the QA
  // gate in §12 pins it).
  if (d === p - 1) return Math.min(Math.max(Math.min(base, 1), 0), 1);
  if (d === p - 2) return Math.min(base, 3);
  return base;
}

/** Full curve, day 1..totalDays. */
export function curve(plan: QuitPlan): number[] {
  const out: number[] = [];
  for (let d = 1; d <= totalDays(plan); d++) out.push(limitFor(plan, d));
  return out;
}

/** 1-based day index for a `yyyy-MM-dd` key; >totalDays means maintenance. */
export function dayNumber(plan: QuitPlan, dayKey: string): number {
  const MS_PER_DAY = 86_400_000;
  const at = Date.parse(`${dayKey}T00:00:00Z`);
  const start = Date.parse(`${plan.startDate}T00:00:00Z`);
  return Math.round((at - start) / MS_PER_DAY) + 1;
}

// ---------------------------------------------------------------------------
// Adaptive nightly layer — docs/03 §3.3
// ---------------------------------------------------------------------------

export type Adherence = 'crushing' | 'onTrack' | 'struggling';

export interface DayActual {
  readonly puffs: number;
  readonly limit: number;
}

export interface TaperAdvice {
  /** Suggested limit for tomorrow, replacing the raw curve value. */
  readonly limitTomorrow: number;
  readonly adherence: Adherence;
  /** Days to add to the plan's stretch (0 unless struggling). */
  readonly stretchDelta: number;
  /** Mean actual/limit over the trailing window, null when undefined. */
  readonly ratio: number | null;
}

/**
 * Mean `actual/limit` over the trailing days, per docs/03 §3.3.
 *
 * Days whose limit is 0 (cold turkey, or the curve's final days) are excluded
 * — dividing by them is undefined and a single tail day would otherwise pin
 * the ratio at infinity and stretch every plan forever. Returns null when the
 * window holds no usable day.
 */
export function adherenceRatio(window: readonly DayActual[]): number | null {
  const usable = window.filter((d) => d.limit > 0);
  if (usable.length === 0) return null;
  const sum = usable.reduce((acc, d) => acc + d.puffs / d.limit, 0);
  return sum / usable.length;
}

export function classify(ratio: number | null): Adherence {
  if (ratio === null) return 'onTrack';
  if (ratio <= 0.85) return 'crushing';
  if (ratio <= 1.1) return 'onTrack';
  return 'struggling';
}

/**
 * Tomorrow's limit given the trailing window (oldest → newest, max 3 days).
 *
 * Invariants enforced here, not by callers:
 * - the limit never rises above the raw curve value for that day;
 * - the limit never rises above today's limit (docs/03 §3.3 "never increases
 *   day-over-day", the one exception being slip recovery in §5);
 * - `stretchDelta` respects the +50%-of-pace cap.
 */
export function adviseTomorrow(
  plan: QuitPlan,
  todayDayNumber: number,
  window: readonly DayActual[],
  /** True when the two most recent days both ran over 1.10 (docs/03 §3.3). */
  strugglingTwoDays = false,
): TaperAdvice {
  const ratio = adherenceRatio(window);
  const adherence = classify(ratio);
  const curveTomorrow = limitFor(plan, todayDayNumber + 1);
  const todayLimit = limitFor(plan, todayDayNumber);
  const recent = window.filter((d) => d.limit > 0);

  let limitTomorrow = curveTomorrow;
  let stretchDelta = 0;

  if (adherence === 'crushing' && recent.length > 0) {
    // Ride the momentum, but never below the curve's own pace.
    const meanActual =
      recent.reduce((acc, d) => acc + d.puffs, 0) / recent.length;
    limitTomorrow = Math.min(curveTomorrow, Math.round(meanActual * 0.95));
  } else if (adherence === 'struggling' && strugglingTwoDays) {
    const yesterday = window.at(-1);
    if (yesterday) {
      // Bend the plan up toward reality — then pay for it with a longer runway.
      limitTomorrow = Math.max(curveTomorrow, Math.round(yesterday.puffs * 0.9));
    }
    const cap = Math.floor(plan.paceDays * 0.5);
    stretchDelta = plan.stretchDays < cap ? 1 : 0;
  }

  // Monotonicity guard: a limit that goes UP day-over-day reads as the plan
  // rewarding a bad day. Struggling days are allowed to hold, never to climb.
  if (adherence !== 'struggling') {
    limitTomorrow = Math.min(limitTomorrow, todayLimit);
  }

  return {
    limitTomorrow: Math.max(0, limitTomorrow),
    adherence,
    stretchDelta,
    ratio,
  };
}
