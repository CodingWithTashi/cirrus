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
import {buildMemoryCard, wholeDollars} from '../src/ai/memoryCard';
import {addDays, dayKeyIn} from '../src/domain/dateKey';
import {dayNumber, limitFor} from '../src/domain/taperEngine';
import type {QuitPlan} from '../src/domain/types';

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
    expect(card.text).toContain('plan day: 12 of 30 (taper)');
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

  it('carries the reason in the words they used', () => {
    // The chips say "health, money". This says what they actually meant, and
    // it is the only sentence in the card the user wrote themselves.
    const card = buildMemoryCard(
      journey({
        profile: {
          alias: 'SteadyFalcon42',
          avatarEmoji: 'E',
          tier: 'premium',
          email: null,
          gender: 'woman',
          birthYear: 2001,
          whys: ['health', 'money'],
          worries: ['cravings'],
          attempts: 'twoToFive',
          frequency: 'always',
          firstPuff: 'withinFive',
          whyWords: 'so I can run with her without stopping',
        },
      }),
      NOW,
      TZ,
    );
    expect(card.text).toContain('so I can run with her without stopping');
  });

  it('says nothing was given rather than inventing a reason', () => {
    // The seed fixture skipped the question, which is the common case and the
    // one where a card that guessed would be worst.
    const card = buildMemoryCard(journey(), NOW, TZ);
    expect(card.text).toContain('not given');
  });

  it('names the nicotine strength they are actually vaping', () => {
    // Stored since onboarding, typed on both sides, and never shown to the
    // model — so Ember gave a 50mg salt user the same withdrawal picture as a
    // 20mg one. The cheapest tailoring on the shelf.
    const card = buildMemoryCard(journey(), NOW, TZ);
    expect(card.text).toContain('50mg');
  });

  it('describes the device, never a dose', () => {
    // HARD SAFETY RULES (docs/04 §4): no dosing guidance of any kind. What
    // the coach needs is what they are vaping, not milligrams per day — a
    // figure that reads as a dose is one Ember may end up discussing as one.
    const card = buildMemoryCard(journey(), NOW, TZ);
    expect(card.text).not.toMatch(/mg\s*(a|per)\s*day/i);
    expect(card.text.toLowerCase()).not.toContain('dose');
    expect(card.text.toLowerCase()).not.toContain('nicotine intake');
  });

  it('admits it when they did not know their strength', () => {
    // "notSure" is a real answer and the honest thing is to pass it through.
    // Defaulting it to 50mg in the card would have Ember state a fact about
    // someone that they explicitly declined to give us.
    const card = buildMemoryCard(
      journey({
        plan: {
          method: 'taper',
          paceDays: 30,
          startDate: '2026-08-04',
          baselinePuffsPerDay: 200,
          weeklySpend: 70.0,
          strength: 'notSure',
          stretchDays: 0,
        },
      }),
      NOW,
      TZ,
    );
    expect(card.text).toContain('strength unknown');
    expect(card.text).not.toContain('50mg');
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
    expect(utc.text).toContain('their local time: 22:14');
    expect(toronto.text).toContain('their local time: 18:14');
  });

  it("states today's date and weekday outright", () => {
    // The model once congratulated a day-1 user on "day two" because a
    // "good morning" after older messages read like a new day. The date is
    // stated so the day never has to be inferred from conversation shape.
    const card = buildMemoryCard(journey(), NOW, TZ);
    expect(card.text).toContain("today's date: 2026-08-15 (Saturday)");
  });

  it('exposes the plan day for the reply envelope', () => {
    // `aiCoachChat` once sent `args: {day: card.streak}` — a fallback client
    // would have rendered the streak as the day number.
    const card = buildMemoryCard(journey(), NOW, TZ);
    expect(card.day).toBe(12);
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

describe('the whole journey on the card', () => {
  it('states when they started and where that puts them', () => {
    // "How long have I been trying?" must be answerable with a date, not a
    // shrug — day 12 of a 30-day plan started 2026-08-04.
    const card = buildMemoryCard(journey(), NOW, TZ);
    expect(card.text).toContain(
      'started: 2026-08-04 · week 2 of 5 · 18 days left in plan',
    );
  });

  it('carries one exact line per week, current week included', () => {
    const card = buildMemoryCard(journey(), NOW, TZ);
    expect(card.text).toContain(
      'weekly history (w1 = first week of plan; today not counted):',
    );
    // Nothing was logged in week one — say so rather than skipping the week,
    // or "compare my week 1 to now" silently loses its baseline.
    expect(card.text).toContain('w1: no days logged');
    // Week 2 is in progress: Aug 13 (120/140) and Aug 14 (130/138) hold, the
    // 11th and 12th were never logged, and today (the 15th) is excluded.
    expect(card.text).toContain(
      'w2 (current, 4 completed days; today is plan day 12): avg 125 puffs/day · 2/4 on target · 2 unlogged · best day 120',
    );
  });

  it('flags a slip week with the slip counted, not hidden in the average', () => {
    const card = buildMemoryCard(
      journey({
        days: {
          '2026-08-11': day({puffs: 170, limit: 142}), // over, no token
          '2026-08-12': day({puffs: 120, limit: 141}),
        },
      }),
      NOW,
      TZ,
    );
    expect(card.text).toContain('1 slip');
  });

  it('switches to maintenance phrasing once the plan is finished', () => {
    const longAgo = journey({
      plan: {
        method: 'taper', paceDays: 30, startDate: '2026-03-02',
        baselinePuffsPerDay: 200, weeklySpend: 70.0, strength: 'mg50',
        stretchDays: 0,
      },
    });
    const card = buildMemoryCard(longAgo, NOW, TZ);
    // Day 167: 137 days past the 30-day plan, week 24 of tenure.
    expect(card.text).toContain(
      'started: 2026-03-02 · week 24 · finished the 30-day plan 137 days ago (maintenance)',
    );
  });

  it('caps a long tenure at twelve week lines and says what was skipped', () => {
    // 24 weeks of fully-logged history: the card keeps w1 (the baseline every
    // "how far have I come" needs), marks the omission, and carries the last
    // ten in full — the budget survives a loyal user.
    const days: Record<string, unknown> = {};
    for (let i = 0; i < 167; i++) {
      const key = addDays('2026-03-02', i);
      days[key] = day({puffs: 60 + (i % 40), limit: 150, hourBuckets: {'21': 30}});
    }
    const card = buildMemoryCard(
      journey({
        plan: {
          method: 'taper', paceDays: 30, startDate: '2026-03-02',
          baselinePuffsPerDay: 200, weeklySpend: 70.0, strength: 'mg50',
          stretchDays: 0,
        },
        days,
      }),
      NOW,
      TZ,
    );
    const weekLines = card.text.match(/^w\d+/gm) ?? [];
    expect(weekLines.length).toBe(11); // w1 + the last 10
    expect(card.text).toContain('omitted');
    expect(card.text).toContain('w24');
    // The budget alarm for the worst realistic case: ~2K tokens at four
    // characters each. The short-fixture test above keeps the tight bound.
    expect(card.text.length).toBeLessThan(8000);
  });
});

describe('the day and the money, exactly as Home shows them', () => {
  // Sat Sep 5 2026, 14:12 in New York: Home said "Day 2 of 30" and "$3 saved",
  // Ember said "day one" and "2.74 dollars". Same journey, same instant. This
  // is the card that turn was built from. The twin of this fixture lives in
  // `test/domain/today_snapshot_test.dart` (parity suite) — keep them equal.
  const SEP5_PLAN: QuitPlan = {
    method: 'taper',
    paceDays: 30,
    startDate: '2026-09-04',
    baselinePuffsPerDay: 100,
    weeklySpend: 30.0,
    strength: 'mg50',
    stretchDays: 0,
  };
  const SEP5_NOW = new Date('2026-09-05T18:12:00.000Z');
  const NY = 'America/New_York';
  const sep5 = (over: Record<string, unknown> = {}) =>
    journey({
      plan: {...SEP5_PLAN},
      days: {'2026-09-04': day({puffs: 36, limit: 95, hourBuckets: {'14': 36}})},
      cravingsSurvivedTotal: 1,
      repairTokens: 0,
      longestStreak: 1,
      lastPuffAt: '2026-09-04T20:10:00.000',
      ...over,
    });

  it('the fixture is on the engine curve', () => {
    expect(limitFor(SEP5_PLAN, 1)).toBe(95);
    expect(limitFor(SEP5_PLAN, 2)).toBe(90);
  });

  it('the Sep 5 screenshot: day 2, $3, and no stray "one"', () => {
    const card = buildMemoryCard(sep5(), SEP5_NOW, NY);
    expect(card.day).toBe(2);
    expect(card.text).toContain(
      "today's date: 2026-09-05 (Saturday) · their local time: 14:12",
    );
    expect(card.text).toContain('plan day: 2 of 30 (taper)');
    expect(card.text).toContain('today: 0/90');
    expect(card.text).toContain('streak: 1d');
    // 64 puffs under a 100 baseline at $30/week = 2.742857…, shown as $3.
    expect(card.text).toContain('money saved: $3 ·');
    expect(card.text).toContain('w1 (current, 1 completed day; today is plan day 2)');
    expect(card.text).not.toContain('2.74');
    expect(card.text).not.toMatch(/\b1 days? so far\b/);
    expect(card.text).not.toMatch(/money saved: \$?\d+\.\d/);
  });

  it('derives the plan day from the caller timezone, not UTC', () => {
    // 03:30Z on Aug 15 is still Aug 14 in Los Angeles and already Aug 15 in
    // Tokyo; the plan day follows the user's calendar, never the server's.
    const early = new Date('2026-08-15T03:30:00.000Z');
    const plan = journey()['plan'] as QuitPlan;
    const cases: readonly (readonly [string, number])[] = [
      ['Asia/Tokyo', 12],
      ['America/Los_Angeles', 11],
      ['UTC', 12],
    ];
    for (const [tz, expected] of cases) {
      const card = buildMemoryCard(journey(), early, tz);
      expect(card.day).toBe(expected);
      expect(card.day).toBe(dayNumber(plan, dayKeyIn(early, tz)));
      expect(card.text).toContain(`plan day: ${expected} of 30`);
    }
  });

  it('rounds money the way LpFormat.money does', () => {
    // 100 puffs/day at $35/week is 5¢ a puff; a 50-puff day keeps exactly
    // $2.50, and both sides round it half away from zero to $3.
    const halfway = journey({
      plan: {...SEP5_PLAN, weeklySpend: 35.0},
      days: {'2026-09-04': day({puffs: 50, limit: 95})},
    });
    expect(buildMemoryCard(halfway, SEP5_NOW, NY).text).toContain('money saved: $3 ·');
    // 56 under at 3/70 a puff = 2.4 → $2.
    const under = sep5({days: {'2026-09-04': day({puffs: 44, limit: 95})}});
    expect(buildMemoryCard(under, SEP5_NOW, NY).text).toContain('money saved: $2 ·');
    expect(wholeDollars(2.5)).toBe('$3');
    expect(wholeDollars(2.4)).toBe('$2');
    expect(wholeDollars(1234.4)).toBe('$1,234');
    expect(wholeDollars(0)).toBe('$0');
  });

  it('an unconfirmed zero-puff day saves nothing', () => {
    // `InitialJourney` mints day 1 as a 0-puff, UNCONFIRMED log. It used to
    // count as a full baseline day saved — "$4 saved" before the first puff.
    // Same rule as the streak now: an unknown day is unknown.
    const fresh = sep5({
      days: {
        '2026-09-05': day({
          puffs: 0, limit: 90, hourBuckets: {}, vapeFreeConfirmed: false,
        }),
      },
      lastPuffAt: null,
    });
    expect(buildMemoryCard(fresh, SEP5_NOW, NY).text).toContain('money saved: $0 ·');
    // A CONFIRMED vape-free day keeps the whole baseline: 100 × 30/700 = $4.29.
    const confirmed = sep5({
      days: {
        '2026-09-04': day({
          puffs: 0, limit: 95, hourBuckets: {}, vapeFreeConfirmed: true,
        }),
      },
    });
    expect(buildMemoryCard(confirmed, SEP5_NOW, NY).text).toContain('money saved: $4 ·');
  });

  it('a day after today is not money already saved', () => {
    // A puff filed by a device clock that was a day ahead. Home drops it
    // (`TodaySnapshot`); the card must agree, or Ember quotes a saving the
    // Money screen does not show.
    const withFuture = sep5({
      days: {
        '2026-09-04': day({puffs: 36, limit: 95, hourBuckets: {'14': 36}}),
        '2026-09-06': day({
          puffs: 0, limit: 85, hourBuckets: {}, vapeFreeConfirmed: true,
        }),
      },
    });
    expect(buildMemoryCard(withFuture, SEP5_NOW, NY).text).toContain('money saved: $3 ·');
  });

  it('never says "day 167 of 30" once the plan is finished', () => {
    // Home says "137 days past Freedom Day"; a card reading "day 167 of 30"
    // hands the model a contradiction to resolve on its own.
    const longAgo = journey({
      plan: {
        method: 'taper', paceDays: 30, startDate: '2026-03-02',
        baselinePuffsPerDay: 200, weeklySpend: 70.0, strength: 'mg50',
        stretchDays: 0,
      },
    });
    const card = buildMemoryCard(longAgo, NOW, TZ);
    expect(card.day).toBe(167);
    expect(card.text).toContain(
      'plan day: 167 · 137 days past Freedom Day (30-day plan finished, maintenance)',
    );
    expect(card.text).not.toMatch(/day 167 of 30/);
  });
});
