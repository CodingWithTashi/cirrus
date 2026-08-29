import {describe, expect, it} from 'vitest';
import {addDays, dayKeyIn, daysBetween, hourIn, isDayKey} from '../src/domain/dateKey';

describe('dayKeyIn', () => {
  it('resolves the LOCAL day, not the UTC one', () => {
    // 03:30 UTC is still the previous evening in Los Angeles. Getting this
    // wrong rolls a user's streak over at the wrong moment.
    const instant = new Date('2026-08-28T03:30:00Z');
    expect(dayKeyIn(instant, 'UTC')).toBe('2026-08-28');
    expect(dayKeyIn(instant, 'America/Los_Angeles')).toBe('2026-08-27');
    expect(dayKeyIn(instant, 'Asia/Tokyo')).toBe('2026-08-28');
  });

  it('handles a zone east of the date line', () => {
    const instant = new Date('2026-08-27T13:00:00Z');
    expect(dayKeyIn(instant, 'Pacific/Auckland')).toBe('2026-08-28');
  });
});

describe('hourIn', () => {
  it('reports the local hour for danger-hour bucketing', () => {
    const instant = new Date('2026-08-28T03:30:00Z');
    expect(hourIn(instant, 'UTC')).toBe(3);
    expect(hourIn(instant, 'America/New_York')).toBe(23);
  });

  it('maps local midnight to 0, not 24', () => {
    expect(hourIn(new Date('2026-08-28T00:00:00Z'), 'UTC')).toBe(0);
  });
});

describe('day-key arithmetic', () => {
  it('adds and subtracts across month boundaries', () => {
    expect(addDays('2026-08-31', 1)).toBe('2026-09-01');
    expect(addDays('2026-03-01', -1)).toBe('2026-02-28');
  });

  it('counts whole days regardless of DST', () => {
    expect(daysBetween('2026-10-25', '2026-11-02')).toBe(8);
    expect(daysBetween('2026-08-28', '2026-08-28')).toBe(0);
    expect(daysBetween('2026-08-28', '2026-08-27')).toBe(-1);
  });

  it('rejects anything that is not a yyyy-MM-dd key', () => {
    expect(isDayKey('2026-08-28')).toBe(true);
    expect(isDayKey('2026-8-28')).toBe(false);
    expect(isDayKey('../../etc/passwd')).toBe(false);
    expect(isDayKey(20260828)).toBe(false);
  });
});
