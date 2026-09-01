/**
 * Parity suite against `test/domain/streak_and_money_test.dart`.
 *
 * Two implementations of the same rules WILL drift — this pair already had,
 * in two places, and the symptom would have been Ember quoting a streak the
 * Home screen contradicts. Every case below mirrors a Dart test one-for-one,
 * same fixtures, same expected numbers. If you change one engine, change both
 * and keep these aligned.
 */
import {describe, expect, it} from 'vitest';
import {currentStreak, flameFor, repairTokens} from '../src/domain/streakEngine';
import {addDays} from '../src/domain/dateKey';
import type {DayLog} from '../src/domain/types';

const TODAY = '2026-08-16';

/** `day(2)` is two days before today, matching the Dart helper. */
function day(offset: number): string {
  const d = new Date(Date.UTC(2026, 7, 16));
  d.setUTCDate(d.getUTCDate() - offset);
  return d.toISOString().slice(0, 10);
}

function log(
  date: string,
  puffs: number,
  limit: number,
  extra: {token?: boolean; vapeFree?: boolean} = {},
): DayLog {
  return {
    date,
    puffs,
    limit,
    hourBuckets: {},
    cravingsSurvived: 0,
    mood: null,
    moodNote: null,
    slipTrigger: null,
    vapeFreeConfirmed: extra.vapeFree ?? false,
    repairTokenUsed: extra.token ?? false,
  };
}

const days = (...entries: DayLog[]): Record<string, DayLog> =>
  Object.fromEntries(entries.map((d) => [d.date, d]));

describe('currentStreak — parity with the Dart engine', () => {
  it('counts consecutive confirmed under-limit days', () => {
    const d = days(
      log(day(2), 80, 100),
      log(day(1), 90, 100),
      log(day(0), 10, 100),
    );
    expect(currentStreak(d, TODAY)).toBe(3);
  });

  // docs/03 §5: a token absorbs one over-limit day. The flame dims; it does
  // not die. The TS port originally omitted this entirely.
  it('a repair token keeps an over-limit day alive', () => {
    const d = days(
      log(day(2), 80, 100),
      log(day(1), 130, 100, {token: true}),
      log(day(0), 10, 100),
    );
    expect(currentStreak(d, TODAY)).toBe(3);
  });

  it('over limit without a token breaks the streak', () => {
    const d = days(
      log(day(2), 80, 100),
      log(day(1), 130, 100),
      log(day(0), 10, 100),
    );
    expect(currentStreak(d, TODAY)).toBe(1);
  });

  it('a zero-puff day counts only when confirmed', () => {
    expect(currentStreak(days(log(day(0), 0, 100)), TODAY)).toBe(0);
    expect(
      currentStreak(days(log(day(0), 0, 100, {vapeFree: true})), TODAY),
    ).toBe(1);
  });

  it('an unconfirmed in-progress today dims, never zeroes, the flame', () => {
    const d = days(log(day(1), 1, 76), log(day(0), 0, 72));
    expect(currentStreak(d, TODAY)).toBe(1);
  });

  // The second divergence: the TS port anchored on `isConfirmed` alone, so a
  // slipped today was counted and then failed the clean check, returning 0 —
  // a user who slipped once saw their whole streak vanish from Ember's view.
  it('a slip today also anchors to yesterday rather than zeroing', () => {
    const d = days(log(day(1), 1, 76), log(day(0), 90, 72));
    expect(currentStreak(d, TODAY)).toBe(1);
  });

  it('a streak survives a DST change in both directions', () => {
    // Parity case with the Dart suite. This side walks STRING keys through
    // `addDays`, so it was always immune — the Dart side walked DateTimes with
    // `subtract(Duration(days: 1))`, i.e. 24 absolute hours, and lost the
    // streak twice a year. Pinned here so the fixed client cannot re-drift.
    for (const anchor of ['2026-11-04', '2026-10-28', '2026-03-11', '2026-04-01']) {
      const days: Record<string, DayLog> = {};
      for (let back = 0; back < 10; back++) {
        const key = addDays(anchor, -back);
        days[key] = log(key, 10, 100);
      }
      expect(currentStreak(days, anchor)).toBe(10);
    }
  });

  it('a slip today with a token counts today too', () => {
    const d = days(log(day(1), 1, 76), log(day(0), 90, 72, {token: true}));
    expect(currentStreak(d, TODAY)).toBe(2);
  });
});

describe('repairTokens — parity with the Dart engine', () => {
  // QA H2 (Aug 31 2026): the client re-derived the wallet as `streak / 7` on
  // every mutation, so a spent token was re-minted at once and over-limit
  // days 15, 20, 21 and 22 were all "absorbed". The wallet is now derived
  // from history on both sides — same walk, same numbers — so Ember never
  // quotes a token count the Home screen contradicts.
  // Chains end YESTERDAY: a token is earned by finishing a day, so the
  // wallet on `today` is a function of the completed days before it.
  function chain(
    length: number,
    opts: {
      overrides?: Record<number, {puffs: number; token: boolean}>;
      unlogged?: number[];
      endingAt?: string;
    } = {},
  ): Record<string, DayLog> {
    const end = opts.endingAt ?? day(1);
    const out: Record<string, DayLog> = {};
    for (let i = 1; i <= length; i++) {
      if (opts.unlogged?.includes(i)) continue;
      const key = addDays(end, i - length);
      const o = opts.overrides?.[i];
      out[key] = log(key, o?.puffs ?? 10, 100, {token: o?.token ?? false});
    }
    return out;
  }

  it('mints one token per seven holding days, capped at two', () => {
    expect(repairTokens(chain(6), TODAY)).toBe(0);
    expect(repairTokens(chain(7), TODAY)).toBe(1);
    expect(repairTokens(chain(13), TODAY)).toBe(1);
    expect(repairTokens(chain(14), TODAY)).toBe(2);
    expect(repairTokens(chain(21), TODAY)).toBe(2);
    expect(repairTokens(chain(28), TODAY)).toBe(2);
  });

  it('a spent token stays spent', () => {
    const d = chain(8, {overrides: {8: {puffs: 130, token: true}}});
    expect(currentStreak(d, TODAY)).toBe(8);
    expect(repairTokens(d, TODAY)).toBe(0);
  });

  it('today can spend a token but never mint one', () => {
    expect(repairTokens(chain(7, {endingAt: TODAY}), TODAY)).toBe(0);
    const spentToday = {
      ...chain(7),
      [TODAY]: log(TODAY, 130, 100, {token: true}),
    };
    expect(currentStreak(spentToday, TODAY)).toBe(8);
    expect(repairTokens(spentToday, TODAY)).toBe(0);
  });

  it('the QA 22-day scenario funds exactly two absorbs', () => {
    const d = chain(22, {
      endingAt: TODAY,
      overrides: {
        15: {puffs: 130, token: true},
        20: {puffs: 130, token: true},
        21: {puffs: 130, token: false},
        22: {puffs: 130, token: false},
      },
    });
    const planDay = (n: number): string => addDays(TODAY, n - 22);
    const upTo = (n: number): Record<string, DayLog> =>
      Object.fromEntries(Object.entries(d).filter(([key]) => key <= planDay(n)));
    expect(repairTokens(upTo(15), planDay(15))).toBe(1);
    expect(repairTokens(upTo(20), planDay(20))).toBe(0);
    expect(repairTokens(upTo(21), planDay(21))).toBe(0);
    expect(repairTokens(d, TODAY)).toBe(0);
    expect(currentStreak(d, TODAY)).toBe(0);
  });

  it('an unspent wallet survives a break in the chain', () => {
    const d = chain(9, {unlogged: [8]});
    expect(currentStreak(d, TODAY)).toBe(1);
    expect(repairTokens(d, TODAY)).toBe(1);
  });

  it('a new chain after a break mints on its own seventh day', () => {
    expect(repairTokens(chain(15, {unlogged: [8]}), TODAY)).toBe(2);
  });

  it('a token used with no history to fund it counts as zero', () => {
    const d = days(log(day(0), 130, 100, {token: true}));
    expect(currentStreak(d, TODAY)).toBe(1);
    expect(repairTokens(d, TODAY)).toBe(0);
  });
});

describe('flameFor — thresholds match docs/03 §5', () => {
  it('maps streak length to flame state', () => {
    expect(flameFor(1)).toBe('spark');
    expect(flameFor(3)).toBe('flicker');
    expect(flameFor(7)).toBe('flame');
    expect(flameFor(14)).toBe('blaze');
    expect(flameFor(30)).toBe('inferno');
  });

  it('holds at the boundaries either side', () => {
    expect(flameFor(2)).toBe('spark');
    expect(flameFor(6)).toBe('flicker');
    expect(flameFor(13)).toBe('flame');
    expect(flameFor(29)).toBe('blaze');
  });
});
