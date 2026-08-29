/**
 * `taperRecalc` — the nightly adaptive layer (docs/03 §3.3).
 *
 * The engine itself is pinned by `test/taperEngine.test.ts`. What is tested
 * here is the thing that engine test could never catch: WHICH DAY the stored
 * advice is for.
 *
 * The cron fires just after the user's local 01:00, and `trailingDays`
 * excludes today, so the window is the three completed days D-1..D-3 and the
 * day being advised is D — the one that just started. `adviseTomorrow`
 * advises for `todayDayNumber + 1`, so it has to be handed `D - 1`. Handing
 * it `D` produced advice for D+1 stamped `forDay: D`; the next night's run
 * overwrote it before D+1 ever arrived, so the client's limit came from a
 * window it never matched.
 */
import {beforeEach, describe, expect, it} from 'vitest';
import {recalcOne} from '../../src/handlers/taperRecalc';
import {journeyDoc, userDoc} from '../../src/lib/firestore';
import {limitFor} from '../../src/domain/taperEngine';
import type {QuitPlan} from '../../src/domain/types';

const PROJECT = process.env['GCLOUD_PROJECT'] ?? 'demo-cirrus';
const HOST = process.env['FIRESTORE_EMULATOR_HOST'] ?? '127.0.0.1:8080';

async function clearFirestore(): Promise<void> {
  const res = await fetch(
    `http://${HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`,
    {method: 'DELETE'},
  );
  if (!res.ok) throw new Error(`emulator clear failed: ${res.status}`);
}

/** `yyyy-MM-dd` for `offset` days from today, in UTC (the test's timezone). */
function dayKey(offset: number): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + offset);
  return d.toISOString().slice(0, 10);
}

const PLAN: QuitPlan = {
  method: 'taper',
  paceDays: 30,
  startDate: dayKey(-9), // today is day 10
  baselinePuffsPerDay: 200,
  weeklySpend: 25,
  strength: 'mg50',
  stretchDays: 0,
};

const TODAY_DAY_NUMBER = 10;

/**
 * Writes a journey whose three completed days ran at `ratio` × their limit.
 * The limits are the real curve values, so the adherence maths here is the
 * same arithmetic the app does.
 */
async function seedJourney(uid: string, ratio: number): Promise<void> {
  const days: Record<string, unknown> = {};
  for (let back = 3; back >= 1; back--) {
    const limit = limitFor(PLAN, TODAY_DAY_NUMBER - back);
    days[dayKey(-back)] = {
      puffs: Math.round(limit * ratio),
      limit,
      hourBuckets: {},
      cravingsSurvived: 0,
      vapeFreeConfirmed: false,
      repairTokenUsed: false,
    };
  }
  await journeyDoc(uid).set({
    profile: {alias: 'SteadyFalcon42', avatarEmoji: '🦊', tier: 'free'},
    plan: PLAN,
    days,
    cravingsSurvivedTotal: 0,
    repairTokens: 0,
    longestStreak: 0,
    goals: [],
    earnedBadges: [],
    buddy: {alias: '@sam', avatarEmoji: '🐝', name: 'Sam', streakDays: 3},
    day1TasksDone: [],
    moodCheckIns: 0,
  });
}

describe('taperRecalc.recalcOne', () => {
  beforeEach(clearFirestore);

  it('advises the day it stamps, not the day after', async () => {
    // On track: the advice is the curve value, so the assertion is purely
    // about WHICH day's curve value was stored.
    await seedJourney('alice', 1);
    await recalcOne('alice', 'UTC');

    const advice = (await userDoc('alice').get()).get('planAdvice');
    expect(advice.forDay).toBe(dayKey(0));
    expect(advice.limit).toBe(limitFor(PLAN, TODAY_DAY_NUMBER));
    // The old bug: tomorrow's number stored under today's key. The curve is
    // strictly decreasing here, so the two are genuinely different.
    expect(advice.limit).not.toBe(limitFor(PLAN, TODAY_DAY_NUMBER + 1));
  });

  it('bends the limit up and stretches the runway for two hard days', async () => {
    await seedJourney('bob', 1.4);
    await recalcOne('bob', 'UTC');

    const advice = (await userDoc('bob').get()).get('planAdvice');
    expect(advice.adherence).toBe('struggling');
    // Meets reality at 90% of yesterday rather than holding a line the user
    // has now missed three days running (docs/03 §3.3).
    expect(advice.limit).toBeGreaterThan(limitFor(PLAN, TODAY_DAY_NUMBER));
    expect(advice.stretchDelta).toBe(1);
  });

  it('rides the momentum down when the user is crushing it', async () => {
    await seedJourney('cass', 0.5);
    await recalcOne('cass', 'UTC');

    const advice = (await userDoc('cass').get()).get('planAdvice');
    expect(advice.adherence).toBe('crushing');
    expect(advice.limit).toBeLessThan(limitFor(PLAN, TODAY_DAY_NUMBER));
    expect(advice.stretchDelta).toBe(0);
  });

  it('writes nothing on day 1 — there is no completed day to read', async () => {
    await journeyDoc('dev').set({
      profile: {alias: 'New', avatarEmoji: '🔥', tier: 'free'},
      plan: {...PLAN, startDate: dayKey(0)},
      days: {},
      cravingsSurvivedTotal: 0,
      repairTokens: 0,
      longestStreak: 0,
      goals: [],
      earnedBadges: [],
      buddy: {alias: '@sam', avatarEmoji: '🐝', name: 'Sam', streakDays: 0},
      day1TasksDone: [],
      moodCheckIns: 0,
    });
    await recalcOne('dev', 'UTC');
    expect((await userDoc('dev').get()).exists).toBe(false);
  });

  it('leaves no user document for a uid with no journey', async () => {
    await recalcOne('ghost', 'UTC');
    expect((await userDoc('ghost').get()).exists).toBe(false);
  });
});
