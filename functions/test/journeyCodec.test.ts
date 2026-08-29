/**
 * The fixture below is the exact JSON `lib/data/dto/journey_codec.dart`
 * writes. When a field is added to the Dart codec it must be added here too
 * (the same rule `test/data/dto_roundtrip_test.dart` enforces on the app side).
 */
import {describe, expect, it} from 'vitest';
import {decodeJourney, JourneyDecodeError} from '../src/domain/journeyCodec';

const fixture = (): Record<string, any> => ({
  profile: {
    alias: 'SteadyFalcon42',
    avatarEmoji: '🦅',
    tier: 'premium',
    email: 'maya@quitmail.com',
    gender: 'woman',
    birthYear: 2001,
    whys: ['health', 'money'],
    worries: ['cravings', 'stress'],
    attempts: 'twoToFive',
    frequency: 'always',
    firstPuff: 'withinFive',
  },
  plan: {
    method: 'taper',
    paceDays: 30,
    startDate: '2026-08-04',
    baselinePuffsPerDay: 200,
    weeklySpend: 45.0,
    strength: 'mg50',
    stretchDays: 0,
  },
  days: {
    '2026-08-04': {
      puffs: 190, limit: 190, hourBuckets: {'9': 40, '22': 60},
      cravingsSurvived: 2, mood: 'okay', moodNote: null,
      vapeFreeConfirmed: false, slipTrigger: null, repairTokenUsed: false,
    },
    '2026-08-05': {
      puffs: 168, limit: 183, hourBuckets: {'22': 55},
      cravingsSurvived: 1, mood: 'good', moodNote: 'better',
      vapeFreeConfirmed: false, slipTrigger: null, repairTokenUsed: false,
    },
  },
  cravingsSurvivedTotal: 23,
  repairTokens: 1,
  longestStreak: 12,
  goals: [{id: 'g1', emoji: '🎧', name: 'AirPods', price: 129.0, fromOnboarding: false}],
  earnedBadges: ['first_day'],
  buddy: {alias: 'quietfox', avatarEmoji: '🦊', name: 'Fox', streakDays: 9},
  lastPuffAt: '2026-08-05T22:14:00.000',
  day1TasksDone: [1, 2],
  pendingSlipCleanDays: null,
  moodCheckIns: 4,
});

describe('decodeJourney', () => {
  it('reads the Dart codec output', () => {
    const j = decodeJourney(fixture());
    expect(j.profile.alias).toBe('SteadyFalcon42');
    expect(j.profile.whys).toEqual(['health', 'money']);
    expect(j.plan.baselinePuffsPerDay).toBe(200);
    expect(j.days['2026-08-04']?.puffs).toBe(190);
    expect(j.days['2026-08-04']?.hourBuckets[22]).toBe(60);
    expect(j.longestStreak).toBe(12);
    expect(j.lastPuffAt).toBe('2026-08-05T22:14:00.000');
  });

  it('re-derives each day log date from its map key', () => {
    expect(decodeJourney(fixture()).days['2026-08-05']?.date).toBe('2026-08-05');
  });

  it('falls back on unknown enum members instead of throwing', () => {
    // Forward compatibility: a newer app shipping a new mood must not take
    // the coach down for everyone mid-rollout.
    const raw = fixture();
    raw['profile']['tier'] = 'platinum_v2';
    raw['days']['2026-08-04']['mood'] = 'ecstatic';
    const j = decodeJourney(raw);
    expect(j.profile.tier).toBe('free');
    expect(j.days['2026-08-04']?.mood).toBeNull();
  });

  it('drops malformed day keys rather than failing the whole read', () => {
    const raw = fixture();
    raw['days']['not-a-date'] = {puffs: 1, limit: 1};
    const j = decodeJourney(raw);
    expect(Object.keys(j.days).sort()).toEqual(['2026-08-04', '2026-08-05']);
  });

  it('rejects a journey with no usable plan', () => {
    const raw = fixture();
    raw['plan']['startDate'] = 'whenever';
    expect(() => decodeJourney(raw)).toThrow(JourneyDecodeError);
  });

  it('rejects a non-object', () => {
    expect(() => decodeJourney(null)).toThrow(JourneyDecodeError);
    expect(() => decodeJourney('nope')).toThrow(JourneyDecodeError);
  });
});
