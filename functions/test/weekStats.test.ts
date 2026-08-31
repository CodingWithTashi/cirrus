/**
 * `weekStats` is the engine behind the card's weekly-history block — the
 * numbers Ember quotes when someone asks "compare my week 2 to my week 5".
 *
 * The semantics under test are the ones that keep it consistent with the rest
 * of the product: today never counts (the same in-progress stance the streak
 * takes), a repair-token day is on-target exactly the way the flame reads it,
 * an unlogged day is unlogged rather than a slip, and every step of date math
 * is `dateKey` string arithmetic — never Duration math, which is the DST bug
 * that once reset every user's streak twice a year.
 */
import {describe, expect, it} from 'vitest';
import {weekStats} from '../src/domain/weekStats';
import type {DayLog} from '../src/domain/types';

const day = (over: Partial<DayLog> = {}): DayLog => ({
  date: '2026-01-05',
  puffs: 100,
  limit: 150,
  hourBuckets: {},
  cravingsSurvived: 0,
  mood: null,
  moodNote: null,
  slipTrigger: null,
  vapeFreeConfirmed: false,
  repairTokenUsed: false,
  ...over,
});

describe('week bucketing', () => {
  it('buckets plan-relative weeks from startDate, oldest first', () => {
    const stats = weekStats(
      {
        '2026-01-06': day({puffs: 90}), // week 1
        '2026-01-13': day({puffs: 80}), // week 2
      },
      '2026-01-05',
      '2026-01-19', // first day of week 3
    );
    expect(stats.map((s) => s.week)).toEqual([1, 2, 3]);
    expect(stats.map((s) => s.startKey)).toEqual([
      '2026-01-05',
      '2026-01-12',
      '2026-01-19',
    ]);
    expect(stats[0]!.logged).toBe(1);
    expect(stats[1]!.logged).toBe(1);
    expect(stats.map((s) => s.current)).toEqual([false, false, true]);
  });

  it('returns [] when today precedes the plan start', () => {
    expect(weekStats({}, '2026-01-05', '2026-01-04')).toEqual([]);
  });

  it('returns the zero-elapsed current week so callers can choose to omit it', () => {
    const [only] = weekStats({}, '2026-01-05', '2026-01-05');
    expect(only).toMatchObject({week: 1, elapsed: 0, logged: 0, current: true});
  });
});

describe('what counts', () => {
  it("excludes today — it's still in progress, like the streak says", () => {
    const stats = weekStats(
      {
        '2026-01-05': day({puffs: 90}),
        '2026-01-06': day({puffs: 999}), // today: must not touch the average
      },
      '2026-01-05',
      '2026-01-06',
    );
    expect(stats[0]!.elapsed).toBe(1);
    expect(stats[0]!.logged).toBe(1);
    expect(stats[0]!.avgPuffs).toBe(90);
  });

  it('counts a repair-token day as on target, exactly like the flame', () => {
    const stats = weekStats(
      {'2026-01-05': day({puffs: 160, limit: 150, repairTokenUsed: true})},
      '2026-01-05',
      '2026-01-12',
    );
    expect(stats[0]!.onTarget).toBe(1);
    expect(stats[0]!.slips).toBe(0);
  });

  it('counts a confirmed over-limit day as a slip', () => {
    const stats = weekStats(
      {'2026-01-05': day({puffs: 180, limit: 150})},
      '2026-01-05',
      '2026-01-12',
    );
    expect(stats[0]!.slips).toBe(1);
    expect(stats[0]!.onTarget).toBe(0);
  });

  it('reports a missing day as unlogged, never as a slip', () => {
    const stats = weekStats(
      {'2026-01-05': day({puffs: 90})},
      '2026-01-05',
      '2026-01-12',
    );
    expect(stats[0]!.elapsed).toBe(7);
    expect(stats[0]!.logged).toBe(1);
    expect(stats[0]!.slips).toBe(0);
  });

  it('treats an unconfirmed zero-puff day as unlogged too', () => {
    // puffs 0 without vapeFreeConfirmed is "the app was never opened", not a
    // perfect day — the same isConfirmed rule the streak applies.
    const stats = weekStats(
      {'2026-01-05': day({puffs: 0})},
      '2026-01-05',
      '2026-01-12',
    );
    expect(stats[0]!.logged).toBe(0);
    expect(stats[0]!.avgPuffs).toBeNull();
  });

  it('rounds the average and names the best day', () => {
    const stats = weekStats(
      {
        '2026-01-05': day({puffs: 100}),
        '2026-01-06': day({puffs: 91}),
      },
      '2026-01-05',
      '2026-01-12',
    );
    expect(stats[0]!.avgPuffs).toBe(96); // 95.5 rounds up
    expect(stats[0]!.best).toEqual({date: '2026-01-06', puffs: 91});
  });

  it('caps a partial current week at the days actually elapsed', () => {
    const stats = weekStats(
      {
        '2026-01-12': day({puffs: 70}),
        '2026-01-13': day({puffs: 60}),
      },
      '2026-01-05',
      '2026-01-15', // 3 days of week 2 are over
    );
    const w2 = stats[1]!;
    expect(w2.current).toBe(true);
    expect(w2.elapsed).toBe(3);
    expect(w2.logged).toBe(2);
    expect(w2.avgPuffs).toBe(65);
  });
});

describe('life after the plan', () => {
  it('keeps counting maintenance weeks from the stored day limits', () => {
    // A finished plan stores limit 0 and days confirmed vape-free. holds()
    // reads the stored limit, so these aggregate with no taper dependency.
    const stats = weekStats(
      {
        '2026-03-02': day({puffs: 0, limit: 0, vapeFreeConfirmed: true}),
        '2026-03-03': day({puffs: 0, limit: 0, vapeFreeConfirmed: true}),
      },
      '2026-01-05',
      '2026-03-09',
    );
    const w9 = stats.find((s) => s.startKey === '2026-03-02')!;
    expect(w9.week).toBe(9);
    expect(w9.onTarget).toBe(2);
    expect(w9.avgPuffs).toBe(0);
  });
});

describe('DST safety', () => {
  it('stays contiguous across the 2026 US spring-forward (calendar math only)', () => {
    // 2026-03-08 is the US DST jump. Every day 03-01..03-14 is logged; if any
    // step used 24-absolute-hour math the key walk would skip or double a day
    // and one of these weeks would come up short.
    const days: Record<string, DayLog> = {};
    for (let d = 1; d <= 14; d++) {
      const key = `2026-03-${String(d).padStart(2, '0')}`;
      days[key] = day({date: key, puffs: 50});
    }
    const stats = weekStats(days, '2026-03-01', '2026-03-15');
    expect(stats[0]!).toMatchObject({elapsed: 7, logged: 7, onTarget: 7});
    expect(stats[1]!).toMatchObject({elapsed: 7, logged: 7, onTarget: 7});
    expect(stats[1]!.startKey).toBe('2026-03-08');
  });
});
