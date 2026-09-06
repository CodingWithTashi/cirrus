import {describe, expect, it} from 'vitest';
import {
  DEFAULT_QUIET_END,
  DEFAULT_QUIET_START,
  inQuietHours,
  isQuietHour,
  localHour,
} from '../src/domain/quietHours';

describe('isQuietHour', () => {
  it('covers a window that wraps midnight', () => {
    for (const h of [23, 0, 3, 7]) {
      expect(isQuietHour(h, 23, 8), `${h}:00`).toBe(true);
    }
    for (const h of [8, 12, 18, 22]) {
      expect(isQuietHour(h, 23, 8), `${h}:00`).toBe(false);
    }
  });

  it('is half-open, so the end hour is already awake', () => {
    expect(isQuietHour(8, 23, 8)).toBe(false);
    expect(isQuietHour(23, 23, 8)).toBe(true);
  });

  it('covers a window that does not wrap', () => {
    expect(isQuietHour(14, 13, 16)).toBe(true);
    expect(isQuietHour(12, 13, 16)).toBe(false);
    expect(isQuietHour(16, 13, 16)).toBe(false);
  });

  it('reads an empty window as no quiet hours, never as a silent day', () => {
    for (const h of [0, 6, 12, 23]) {
      expect(isQuietHour(h, 9, 9), `${h}:00`).toBe(false);
    }
  });

  it('normalises hours outside 0..23', () => {
    expect(isQuietHour(24, 23, 8)).toBe(true);
    expect(isQuietHour(-1, 23, 8)).toBe(true);
  });
});

describe('localHour', () => {
  it('reads the hour in the named zone, not ours', () => {
    // 2024-01-01T12:00:00Z
    const noonUtc = Date.UTC(2024, 0, 1, 12, 0, 0);
    expect(localHour(noonUtc, 'UTC')).toBe(12);
    expect(localHour(noonUtc, 'Asia/Tokyo')).toBe(21);
    expect(localHour(noonUtc, 'America/Los_Angeles')).toBe(4);
  });

  it('reports midnight as 0, never 24', () => {
    const midnightUtc = Date.UTC(2024, 0, 1, 0, 0, 0);
    expect(localHour(midnightUtc, 'UTC')).toBe(0);
  });

  it('answers null rather than guessing when the zone is missing or junk', () => {
    expect(localHour(Date.now(), undefined)).toBeNull();
    expect(localHour(Date.now(), '')).toBeNull();
    expect(localHour(Date.now(), 'Not/AZone')).toBeNull();
  });
});

describe('inQuietHours', () => {
  it('is quiet at 3am where the recipient actually is', () => {
    // 18:00 UTC is 03:00 the next day in Tokyo.
    const ms = Date.UTC(2024, 0, 1, 18, 0, 0);
    expect(inQuietHours(ms, 'Asia/Tokyo')).toBe(true);
    expect(inQuietHours(ms, 'UTC')).toBe(false);
  });

  it('never goes quiet when we do not know the zone', () => {
    // Silencing an Australian through their working afternoon because we
    // guessed UTC is the failure this guards.
    const ms = Date.UTC(2024, 0, 1, 2, 0, 0);
    expect(inQuietHours(ms, 'UTC')).toBe(true);
    expect(inQuietHours(ms, undefined)).toBe(false);
    expect(inQuietHours(ms, 'Nonsense/Zone')).toBe(false);
  });

  it('honours a window the user chose over the default', () => {
    const ms = Date.UTC(2024, 0, 1, 14, 0, 0);
    expect(inQuietHours(ms, 'UTC', DEFAULT_QUIET_START, DEFAULT_QUIET_END)).toBe(false);
    expect(inQuietHours(ms, 'UTC', 13, 16)).toBe(true);
  });
});
