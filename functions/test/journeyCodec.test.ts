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

  it('keeps the rest of the 19-step quiz', () => {
    // These were in the fixture — the app has always sent them — but the
    // decoder dropped them on the floor, so the coach could not tell a
    // first-time quitter from someone on their sixth attempt.
    const j = decodeJourney(fixture());
    expect(j.profile.gender).toBe('woman');
    expect(j.profile.attempts).toBe('twoToFive');
    expect(j.profile.frequency).toBe('always');
    expect(j.profile.firstPuff).toBe('withinFive');
  });

  it("keeps the user's own words and what they blamed a slip on", () => {
    const raw = fixture();
    raw['days']['2026-08-05'].slipTrigger = 'stress';
    const j = decodeJourney(raw);
    expect(j.days['2026-08-05']?.moodNote).toBe('better');
    expect(j.days['2026-08-05']?.slipTrigger).toBe('stress');
    expect(j.days['2026-08-04']?.moodNote).toBeNull();
  });

  it('caps a mood note — it goes into a prompt', () => {
    const raw = fixture();
    raw['days']['2026-08-05'].moodNote = 'x'.repeat(500);
    expect(decodeJourney(raw).days['2026-08-05']?.moodNote).toHaveLength(280);
  });

  it('keeps the savings goals, which are what the money is FOR', () => {
    const j = decodeJourney(fixture());
    expect(j.goals).toHaveLength(1);
    expect(j.goals[0]?.name).toBe('AirPods');
    expect(j.goals[0]?.price).toBe(129);
    expect(j.earnedBadges).toEqual(['first_day']);
  });

  it('drops a malformed goal rather than failing the read', () => {
    const raw = fixture();
    raw['goals'] = [{id: 'g1'}, 'nope', {id: 'g2', name: 'Trip', price: 900}];
    const goals = decodeJourney(raw).goals;
    expect(goals).toHaveLength(1);
    expect(goals[0]?.name).toBe('Trip');
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

describe('coachName', () => {
  it('is null when nobody renamed the coach', () => {
    const journey = decodeJourney(fixture());
    expect(journey.profile.coachName).toBeNull();
  });

  it('is trimmed, de-controlled and capped', () => {
    // Client-owned free text headed for a prompt. Parity with the Dart
    // validator, which caps at 20 grapheme clusters.
    const cases: [unknown, string | null][] = [
      ['  Wren  ', 'Wren'],
      [`Wr${String.fromCharCode(0)}en`, 'Wren'],
      ['W'.repeat(40), 'W'.repeat(20)],
      ['   ', null],
      ['', null],
      [42, null],
      [null, null],
      [undefined, null],
    ];
    for (const [raw, expected] of cases) {
      const raw_ = fixture();
      raw_['profile'] = {...raw_['profile'], coachName: raw};
      const journey = decodeJourney(raw_);
      expect(journey.profile.coachName).toBe(expected);
    }
  });
});
