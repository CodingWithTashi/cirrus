/**
 * The card eval's own parts: what it asks, how it grades, what it costs.
 * All of it without a model: nothing here spends anything.
 *
 * `npm run eval:cards` is how the follow-up call's choice of exercise is
 * judged (`followUpPrompt` in `src/ai/prompts.ts`). An eval that asked a
 * different question from production, or graded a wrong card as right, would
 * be worse than none, so both are pinned here.
 */
import {describe, expect, it} from 'vitest';
import {followUpRequest} from '../src/ai/prompts';
import {EXERCISE_IDS, exerciseById} from '../src/domain/exercises';
import {
  CASES,
  callFor,
  cardsFor,
  grade,
  judgeRun,
  MODEL_ID,
  type Case,
} from '../tools/cardsEval';
import {DEFAULT_BUDGET_USD} from '../tools/evalBudget';
import {EvalCache} from '../tools/evalCache';
import {estimateCalls} from '../tools/evalExec';

const NOW = new Date('2026-11-28T12:00:00');

const byId = (id: string): Case => {
  const found = CASES.find((c) => c.id === id);
  if (found === undefined) throw new Error(`no case ${id}`);
  return found;
};

const answer = (...exercises: string[]): string =>
  JSON.stringify({followUps: ['that helped'], exercises});

describe('the cases', () => {
  it('have unique ids, and both kinds of answer are asked for', () => {
    const ids = CASES.map((c) => c.id);
    expect(new Set(ids).size).toBe(ids.length);
    // A suite of only "show a card" cases is passed by a model that always
    // names one, and a suite of only "show nothing" by one that never does.
    expect(CASES.filter((c) => c.expect.cards === 'none').length).toBeGreaterThanOrEqual(6);
    expect(
      CASES.filter((c) => c.expect.cards === 'lead' || c.expect.cards === 'kinds').length,
    ).toBeGreaterThanOrEqual(6);
    // A case that accepts either answer proves nothing by itself: keep them few.
    expect(CASES.filter((c) => c.expect.cards === 'optional').length).toBeLessThanOrEqual(2);
  });

  it('expect only what the list they were shown could produce', () => {
    for (const c of CASES) {
      const nameable = c.nameable ?? EXERCISE_IDS;
      for (const id of nameable) expect(exerciseById(id), c.id).not.toBeNull();
      if (c.expect.cards === 'lead') {
        expect(nameable, c.id).toContain(c.expect.lead);
        for (const id of c.expect.also ?? []) expect(nameable, c.id).toContain(id);
      }
      if (c.expect.cards === 'optional') {
        for (const id of c.expect.only) expect(nameable, c.id).toContain(id);
      }
    }
  });

  it('ask exactly what production asks', () => {
    for (const c of CASES) {
      expect(callFor(c, 2), c.id).toEqual({
        request: followUpRequest({
          model: MODEL_ID,
          userText: c.user,
          reply: c.coach,
          exercises: c.nameable ?? EXERCISE_IDS,
        }),
        sample: 2,
        expectOutputTokens: expect.any(Number),
      });
    }
  });
});

describe('cardsFor', () => {
  it('is the cards a subscriber would see: the production parser, then the policy', () => {
    expect(cardsFor(byId('accept-breath'), answer('breathing'))).toEqual(['breathing']);
    // One per kind, calm first, as the policy lays a menu out.
    expect(cardsFor(byId('options'), answer('orbs', 'tiles', 'sos', 'breathing'))).toEqual([
      'breathing', 'orbs', 'sos',
    ]);
    // A name outside the list this case was shown becomes one of its kind.
    expect(cardsFor(byId('game-free-list'), answer('tiles'))).toEqual(['orbs']);
    // And an answer that is not one is no card.
    expect(cardsFor(byId('accept-breath'), 'the model rambled')).toEqual([]);
  });
});

describe('grade', () => {
  it('nothing expected: only nothing passes', () => {
    const c = byId('progress');
    expect(grade(c, [])).toBe(true);
    expect(grade(c, ['breathing'])).toBe(false);
  });

  it('a lead expected: it must come first, and anything after it must be allowed', () => {
    const strict = byId('accept-breath');
    expect(grade(strict, ['breathing'])).toBe(true);
    expect(grade(strict, [])).toBe(false);
    expect(grade(strict, ['orbs'])).toBe(false);
    expect(grade(strict, ['breathing', 'orbs'])).toBe(false);

    const loose = byId('typed-craving');
    expect(grade(loose, ['breathing', 'sos'])).toBe(true);
    expect(grade(loose, ['sos', 'breathing'])).toBe(false);
  });

  it('a judgment call: nothing, or one card from the short list', () => {
    const c = byId('vent');
    expect(grade(c, [])).toBe(true);
    expect(grade(c, ['breathing'])).toBe(true);
    expect(grade(c, ['orbs'])).toBe(false);
    expect(grade(c, ['breathing', 'sos'])).toBe(false);
  });

  it('kinds expected: exactly those kinds, in any order', () => {
    const c = byId('options');
    expect(grade(c, ['breathing', 'orbs', 'sos'])).toBe(true);
    expect(grade(c, ['sos', 'tiles', 'breathing'])).toBe(true);
    expect(grade(c, ['breathing', 'sos'])).toBe(false);
    expect(grade(c, [])).toBe(false);
  });
});

describe('judgeRun', () => {
  const rolls = (failed: Record<string, number>, perCase: number) =>
    CASES.flatMap((c) =>
      Array.from({length: perCase}, (_, i) => ({
        case: c.id,
        pass: i >= (failed[c.id] ?? 0),
      })),
    );

  it('meets the bar when every roll passes', () => {
    expect(judgeRun(rolls({}, 3), 3).met).toBe(true);
  });

  it('one wobble in three is inside the bar; a case that fails most of its rolls is not', () => {
    expect(judgeRun(rolls({progress: 1}, 3), 3).met).toBe(true);
    const lost = judgeRun(rolls({progress: 2}, 3), 3);
    expect(lost.met).toBe(false);
    expect(lost.failing).toEqual([['progress', 2]]);
  });

  it('many small wobbles are a failure too: at most one roll in ten', () => {
    const everywhere = Object.fromEntries(CASES.map((c) => [c.id, 1]));
    expect(judgeRun(rolls(everywhere, 3), 3).met).toBe(false);
  });

  it('a run with nothing in it meets nothing', () => {
    expect(judgeRun([], 3).met).toBe(false);
  });
});

describe('what a run costs', () => {
  it('three rolls of the whole suite are a small part of the daily eval cap', () => {
    const calls = CASES.flatMap((c) => [1, 2, 3].map((roll) => callFor(c, roll)));
    const estimate = estimateCalls(calls, new EvalCache(null), {batch: false, at: NOW});
    expect(estimate.paidCalls).toBe(CASES.length * 3);
    // The cap is shared with the coach and moderation evals for the day. A
    // card eval that ate a third of it would crowd out the one that gates
    // the coach prompt.
    expect(estimate.usd).toBeLessThan(DEFAULT_BUDGET_USD / 3);
  });
});
