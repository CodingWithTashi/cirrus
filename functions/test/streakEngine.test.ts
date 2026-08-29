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
import {currentStreak, flameFor} from '../src/domain/streakEngine';
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

  it('a slip today with a token counts today too', () => {
    const d = days(log(day(1), 1, 76), log(day(0), 90, 72, {token: true}));
    expect(currentStreak(d, TODAY)).toBe(2);
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
