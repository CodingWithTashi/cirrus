/**
 * The USER CARD is the string Ember actually reads, and nothing pinned it.
 *
 * Everything that makes this coach different from a chatbot is in these ten
 * lines: the day number, the streak, the money, the danger hours, and the
 * user's own words. It is also the file where a silent regression is most
 * expensive — a card that quietly stops carrying the onboarding answers does
 * not fail, it just makes Ember generic, which is indistinguishable from the
 * model having a bad day and was in fact exactly what happened once.
 *
 * These are cheap deterministic assertions on a pure function. The point is
 * that the facts are PRESENT and correct, not that the prose is exact.
 */
import {describe, expect, it} from 'vitest';
import {buildMemoryCard} from '../src/ai/memoryCard';

const NOW = new Date('2026-08-15T22:14:00.000Z');
const TZ = 'UTC';

const day = (over: Partial<Record<string, unknown>> = {}) => ({
  puffs: 100,
  limit: 150,
  hourBuckets: {'22': 60},
  cravingsSurvived: 1,
  mood: null,
  moodNote: null,
  vapeFreeConfirmed: false,
  slipTrigger: null,
  repairTokenUsed: false,
  ...over,
});

const journey = (over: Record<string, unknown> = {}): Record<string, unknown> => ({
  profile: {
    alias: 'SteadyFalcon42',
    avatarEmoji: '🦅',
    tier: 'premium',
    email: null,
    gender: 'woman',
    birthYear: 2001,
    whys: ['health', 'money'],
    worries: ['cravings'],
    attempts: 'twoToFive',
    frequency: 'always',
    firstPuff: 'withinFive',
  },
  plan: {
    method: 'taper',
    paceDays: 30,
    startDate: '2026-08-04',
    baselinePuffsPerDay: 200,
    weeklySpend: 70.0,
    strength: 'mg50',
    stretchDays: 0,
  },
  days: {
    '2026-08-13': day({puffs: 120, limit: 140}),
    '2026-08-14': day({puffs: 130, limit: 138}),
    '2026-08-15': day({puffs: 40, limit: 136}),
  },
  cravingsSurvivedTotal: 23,
  repairTokens: 1,
  longestStreak: 12,
  goals: [],
  earnedBadges: [],
  lastPuffAt: '2026-08-15T22:14:00.000',
  ...over,
});

describe('the user card', () => {
  it('opens with who they are and where they are in the plan', () => {
    const card = buildMemoryCard(journey(), NOW, TZ);
    expect(card.text).toContain('day 12 of 30');
    expect(card.text).toContain('SteadyFalcon42');
    expect(card.text).toContain('taper');
  });

  it("carries today's numbers, not just the plan's", () => {
    const card = buildMemoryCard(journey(), NOW, TZ);
    // baseline / today / limit — the three numbers Ember quotes most. The
    // limit is the ENGINE's, deliberately, not the one stored on the day: the
    // card must never be able to quote a figure the Home screen disagrees
    // with, so it recomputes from the same `limitFor` the app renders.
    expect(card.text).toContain('baseline: 200 puffs/day');
    expect(card.text).toMatch(/today: 40\/\d+/);
  });

  it('carries the nineteen-step answers, not only the counters', () => {
    // These were decoded by the app and DROPPED by the server, so Ember could
    // not tell a first-time quitter from someone on their sixth attempt, or an
    // all-day vaper from a social one — the two facts that most change what is
    // worth saying.
    const card = buildMemoryCard(journey(), NOW, TZ);
    expect(card.text).toContain('25yo');
    expect(card.text).toContain('woman');
    expect(card.text).toContain('vapes always');
    expect(card.text).toContain('first puff within 5 min of waking');
    expect(card.text).toContain('tried 2-5 times before');
  });

  it('never phrases prior attempts as a failure', () => {
    // docs/04's voice rule. "tried 2-5 times before" is history; a count with
    // the word "failed" attached is a scoreboard.
    const card = buildMemoryCard(journey(), NOW, TZ);
    expect(card.text.toLowerCase()).not.toContain('fail');
    expect(card.text.toLowerCase()).not.toContain('relapse');
  });

  it('says what the money is for when a goal exists', () => {
    const card = buildMemoryCard(
      journey({
        goals: [
          {id: 'g1', emoji: '✈️', name: 'Tokyo flight', price: 1300, fromOnboarding: false},
        ],
      }),
      NOW,
      TZ,
    );
    expect(card.text).toContain('Tokyo flight');
    expect(card.text).toMatch(/Tokyo flight \(\d+% of 1300\)/);
  });

  it('says so plainly when there is no goal, rather than inventing one', () => {
    // `InitialJourney` used to mint "Tokyo flight, $1300" for every account,
    // and once the card learned to read goals it began quoting that holiday
    // back as if the user had chosen it.
    const card = buildMemoryCard(journey(), NOW, TZ);
    expect(card.text).toContain('saving toward: no goal set');
  });

  it("carries the user's own words", () => {
    // The most personal thing in the document, and the card ignored it: Ember
    // could see a bad day but not "work party tonight, nervous" beside it.
    const card = buildMemoryCard(
      journey({
        // Both in the TRAILING window, which excludes today — the same rule
        // `taperRecalc` depends on.
        days: {
          '2026-08-13': day({moodNote: 'work party tonight, nervous'}),
          '2026-08-14': day({slipTrigger: 'stress'}),
          '2026-08-15': day(),
        },
      }),
      NOW,
      TZ,
    );
    expect(card.text).toContain('work party tonight, nervous');
    expect(card.text).toContain('blamed stress');
  });

  it('admits when it does not know the danger hours yet', () => {
    const card = buildMemoryCard(journey({days: {}}), NOW, TZ);
    expect(card.text).toContain('not enough data yet');
    expect(card.text).toContain('no logs yet');
  });

  it('flags a slip so Ember can open with it', () => {
    const card = buildMemoryCard(
      journey({
        days: {
          '2026-08-14': day({puffs: 160, limit: 138}),
          '2026-08-15': day({puffs: 10, limit: 136}),
        },
      }),
      NOW,
      TZ,
    );
    expect(card.text).toContain('slipped yesterday (+22 over)');
  });

  it('reports the local time in the caller timezone, not UTC', () => {
    // A coach that thinks it is 22:14 when the user is having a 5pm craving
    // gives advice about the wrong part of the day.
    const utc = buildMemoryCard(journey(), NOW, 'UTC');
    const toronto = buildMemoryCard(journey(), NOW, 'America/Toronto');
    expect(utc.text).toContain('local time now: 22:14');
    expect(toronto.text).toContain('local time now: 18:14');
  });

  it('derives the day key from the caller timezone', () => {
    // Late-evening UTC is already the next day east of it. Getting this wrong
    // moves every quota and every streak by a day for half the world.
    const late = new Date('2026-08-15T23:30:00.000Z');
    expect(buildMemoryCard(journey(), late, 'UTC').todayKey).toBe('2026-08-15');
    expect(buildMemoryCard(journey(), late, 'Asia/Tokyo').todayKey).toBe(
      '2026-08-16',
    );
  });

  it('stays inside its token budget', () => {
    // docs/04 §3 budgets ~1.5K input tokens for the card. Roughly four
    // characters to a token, so this is a smoke alarm rather than a precise
    // measure — it exists so a future addition that doubles the card is
    // noticed here rather than on the bill.
    const card = buildMemoryCard(journey(), NOW, TZ);
    expect(card.text.length).toBeLessThan(2000);
  });
});
