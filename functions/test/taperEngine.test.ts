/**
 * PARITY SUITE. These expectations are copied from
 * `test/domain/taper_engine_test.dart`. If this file and that one ever
 * disagree, the app and the server are quoting different limits to the same
 * user on the same day — the worst class of bug this product can have.
 */
import {describe, expect, it} from 'vitest';
import {
  adherenceRatio,
  adviseTomorrow,
  classify,
  curve,
  dayNumber,
  limitFor,
} from '../src/domain/taperEngine';
import type {QuitPlan} from '../src/domain/types';

const plan = (over: Partial<QuitPlan> = {}): QuitPlan => ({
  method: 'taper',
  paceDays: 30,
  startDate: '2026-08-04',
  baselinePuffsPerDay: 200,
  weeklySpend: 45,
  strength: 'mg50',
  stretchDays: 0,
  ...over,
});

describe('base curve', () => {
  // docs/03 §3.1 worked example — the QA gate in §12 pins this table.
  it('matches the spec worked example exactly', () => {
    const p = plan();
    expect(limitFor(p, 1)).toBe(190);
    expect(limitFor(p, 7)).toBe(134);
    expect(limitFor(p, 15)).toBe(71);
    expect(limitFor(p, 21)).toBe(33);
    expect(limitFor(p, 27)).toBe(6);
    expect(limitFor(p, 28)).toBe(3);
    expect(limitFor(p, 29)).toBe(1);
    expect(limitFor(p, 30)).toBe(0);
  });

  it('is never increasing day over day', () => {
    const c = curve(plan({baselinePuffsPerDay: 320, paceDays: 60}));
    for (let i = 1; i < c.length; i++) {
      expect(c[i]!).toBeLessThanOrEqual(c[i - 1]!);
    }
  });

  it('small baselines still land on zero', () => {
    const c = curve(plan({baselinePuffsPerDay: 20, paceDays: 14}));
    expect(c.at(-1)).toBe(0);
    expect(c[0]!).toBeLessThanOrEqual(20);
  });

  it('cold turkey is zero from day one', () => {
    expect(limitFor(plan({method: 'coldTurkey'}), 1)).toBe(0);
  });

  it('stretch days extend the runway', () => {
    // A stretched plan is a LONGER plan, so each day sits higher on the curve.
    expect(limitFor(plan({stretchDays: 2}), 15)).toBeGreaterThan(limitFor(plan(), 15));
  });
});

describe('dayNumber', () => {
  it('is 1-based from the plan start date', () => {
    expect(dayNumber(plan(), '2026-08-04')).toBe(1);
    expect(dayNumber(plan(), '2026-08-10')).toBe(7);
  });

  it('survives a DST boundary without drifting a day', () => {
    // US DST ends 2026-11-01; pure day-key math must not notice.
    const p = plan({startDate: '2026-10-25'});
    expect(dayNumber(p, '2026-11-02')).toBe(9);
  });
});

describe('adaptive layer (docs/03 §3.3)', () => {
  it('ignores zero-limit days rather than dividing by them', () => {
    // A single tail day would otherwise pin the ratio at Infinity and stretch
    // every plan forever.
    expect(adherenceRatio([{puffs: 3, limit: 0}])).toBeNull();
    expect(adherenceRatio([{puffs: 5, limit: 10}, {puffs: 2, limit: 0}])).toBe(0.5);
  });

  it('classifies against the spec thresholds', () => {
    expect(classify(0.85)).toBe('crushing');
    expect(classify(0.9)).toBe('onTrack');
    expect(classify(1.1)).toBe('onTrack');
    expect(classify(1.11)).toBe('struggling');
    expect(classify(null)).toBe('onTrack');
  });

  it('rides momentum when crushing it, but never above the curve', () => {
    const p = plan();
    const window = [
      {puffs: 90, limit: 140},
      {puffs: 85, limit: 138},
      {puffs: 80, limit: 136},
    ];
    const advice = adviseTomorrow(p, 7, window);
    expect(advice.adherence).toBe('crushing');
    expect(advice.limitTomorrow).toBeLessThanOrEqual(limitFor(p, 8));
    expect(advice.stretchDelta).toBe(0);
  });

  it('bends the plan and stretches Freedom Day when struggling twice', () => {
    const p = plan();
    const window = [
      {puffs: 200, limit: 140},
      {puffs: 190, limit: 138},
      {puffs: 180, limit: 136},
    ];
    const advice = adviseTomorrow(p, 7, window, true);
    expect(advice.adherence).toBe('struggling');
    expect(advice.limitTomorrow).toBeGreaterThanOrEqual(limitFor(p, 8));
    expect(advice.stretchDelta).toBe(1);
  });

  it('caps total stretch at +50% of pace', () => {
    // paceDays 30 → cap 15. Already at the cap, so no further stretch.
    const p = plan({stretchDays: 15});
    const window = [
      {puffs: 200, limit: 100},
      {puffs: 200, limit: 100},
    ];
    expect(adviseTomorrow(p, 7, window, true).stretchDelta).toBe(0);
  });

  it('follows the curve with no history', () => {
    const p = plan();
    const advice = adviseTomorrow(p, 5, []);
    expect(advice.adherence).toBe('onTrack');
    expect(advice.limitTomorrow).toBe(limitFor(p, 6));
  });

  it('never advises a limit above today (except when struggling)', () => {
    const p = plan();
    for (let d = 1; d < 29; d++) {
      const advice = adviseTomorrow(p, d, [{puffs: 1, limit: 100}]);
      expect(advice.limitTomorrow).toBeLessThanOrEqual(limitFor(p, d));
    }
  });
});
