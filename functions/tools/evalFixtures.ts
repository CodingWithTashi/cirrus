/**
 * The deterministic journey `coachEval.ts` grades against.
 *
 * A synthetic day-32 taper user with enough texture for every scenario the
 * suite asks about: a slip in week 1, a repair-token save in week 3, one
 * unlogged day in week 2, evening danger hours, a savings goal, and their own
 * why. Stored day limits come from the real `limitFor`, so the fixture can
 * never drift from the engine the card recomputes with.
 *
 * Lives in `tools/` (outside the deploy bundle) beside the script that uses
 * it — the vitest fixtures under `test/` are not importable from here.
 */
import {addDays} from '../src/domain/dateKey';
import {limitFor} from '../src/domain/taperEngine';
import type {QuitPlan} from '../src/domain/types';

export const EVAL_NOW = new Date('2026-08-27T21:00:00.000Z');
/** 17:00 on 2026-08-27 in New York — day 32 of the plan, week 5. */
export const EVAL_TZ = 'America/New_York';

export const EVAL_PLAN: QuitPlan = {
  method: 'taper',
  paceDays: 60,
  startDate: '2026-07-27',
  baselinePuffsPerDay: 200,
  weeklySpend: 70.0,
  strength: 'mg35',
  stretchDays: 0,
};

const TODAY_DAY_NUMBER = 32;

export function evalJourney(): Record<string, unknown> {
  const days: Record<string, unknown> = {};
  for (let d = 1; d <= TODAY_DAY_NUMBER; d++) {
    if (d === 9) continue; // the unlogged day in week 2
    const key = addDays(EVAL_PLAN.startDate, d - 1);
    const limit = limitFor(EVAL_PLAN, d);
    const slip = d === 4; // over limit, no token — week 1's slip
    const tokenSave = d === 17; // over limit, token used — still on target
    const today = d === TODAY_DAY_NUMBER;
    const puffs = today
      ? 20
      : slip
        ? limit + 30
        : tokenSave
          ? limit + 12
          : Math.max(0, limit - 5);
    days[key] = {
      date: key,
      puffs,
      limit,
      hourBuckets: {'18': 10, '21': Math.min(puffs, 30)},
      cravingsSurvived: d % 3 === 0 ? 2 : 1,
      mood: null,
      moodNote: d === 30 ? 'work has been brutal this week' : null,
      slipTrigger: slip ? 'stress' : null,
      vapeFreeConfirmed: false,
      repairTokenUsed: tokenSave,
    };
  }

  return {
    profile: {
      alias: 'EvalFalcon',
      avatarEmoji: '🦅',
      tier: 'premium',
      email: null,
      gender: 'man',
      birthYear: 1998,
      whys: ['health', 'money'],
      worries: ['cravings', 'weight'],
      attempts: 'once',
      frequency: 'always',
      firstPuff: 'fiveToThirty',
      whyWords: 'so my daughter never sees me vape',
    },
    plan: {...EVAL_PLAN},
    days,
    cravingsSurvivedTotal: 41,
    repairTokens: 1,
    longestStreak: 14,
    goals: [
      {id: 'g1', emoji: '✈️', name: 'Japan trip', price: 1500, fromOnboarding: false},
    ],
    earnedBadges: [],
    lastPuffAt: '2026-08-27T19:30:00.000',
  };
}
