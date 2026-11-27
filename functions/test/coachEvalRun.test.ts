/**
 * What a coach eval run asks for, what it costs, and when it is not an
 * answer. All of it with a fake model: nothing here spends anything.
 *
 * The cost pins are the point. Nov 13 and Nov 25 2026 spent CA$7.15 on eval
 * rolls because nobody had the number: one roll is 98 calls, a five-against-
 * five comparison is ten of those. These tests keep the number written down
 * and fail when a change to the suite, the prompt or the price list moves
 * a five-roll session over the daily cap.
 */
import {mkdtempSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {describe, expect, it} from 'vitest';
import {ModelUnavailableError, type GenerateRequest, type GenerateResult} from '../src/ai/model';
import {
  estimateRun,
  failureCounts,
  parseOptions,
  pickScenarios,
  planReplies,
  runCoachEval,
  scenarios,
} from '../tools/coachEval';
import {DEFAULT_BUDGET_USD, EvalBudget} from '../tools/evalBudget';
import {EvalCache} from '../tools/evalCache';
import {estimateCalls, type ExecDeps} from '../tools/evalExec';
import {JUDGE_PROMPT} from '../tools/evalJudge';

const NOW = new Date('2026-11-27T12:00:00');
const LITE = 'gemini-3.5-flash-lite';
const PREMIUM = 'gemini-3.6-flash';
const BOTH = [LITE, PREMIUM];

function emptyCache(): EvalCache {
  return new EvalCache(join(mkdtempSync(join(tmpdir(), 'coach-run-')), 'cache'), () => NOW);
}

describe('what one run asks for', () => {
  it('is 98 calls: 50 replies and 48 judge calls', () => {
    const jobs = planReplies(scenarios(), BOTH, 1);
    expect(jobs).toHaveLength(50);
    const estimate = estimateRun(jobs, emptyCache(), {batch: false, at: NOW, judgeModelId: PREMIUM});
    expect(estimate.calls).toBe(98);
    expect(estimate.paidCalls).toBe(98);
  });

  it('reports roll by roll, model by model, scenario by scenario', () => {
    const jobs = planReplies(scenarios(), BOTH, 2);
    expect(jobs).toHaveLength(100);
    expect(jobs[0]).toMatchObject({roll: 1, modelId: LITE});
    expect(jobs[25]).toMatchObject({roll: 1, modelId: PREMIUM});
    expect(jobs[50]).toMatchObject({roll: 2, modelId: LITE});
    expect(jobs[0]?.scenario.id).toBe('01-craving-2am');
    // Each roll is its own draw.
    expect(jobs[0]?.call.sample).toBe(1);
    expect(jobs[50]?.call.sample).toBe(2);
  });

  it('sends the output cap and the settings the suite has always sent', () => {
    const request = planReplies(scenarios(), [LITE], 1)[0]?.call.request;
    expect(request?.maxOutputTokens).toBe(500);
    expect(request?.temperature).toBeUndefined();
    expect(request?.json).toBeUndefined();
    expect(request?.turns).toEqual([{role: 'user', text: "craving so bad rn it's 2am"}]);
  });
});

describe('what it costs, at the Nov 27 2026 price list', () => {
  const price = (rolls: number, batch: boolean, at: Date = NOW) =>
    estimateRun(planReplies(scenarios(), BOTH, rolls), emptyCache(), {
      batch,
      at,
      judgeModelId: PREMIUM,
    }).usd;

  it('one roll is about ten US cents, estimated a little high on purpose', () => {
    expect(price(1, false)).toBeGreaterThan(0.09);
    expect(price(1, false)).toBeLessThan(0.14);
  });

  it('five rolls of the whole suite fit under the daily cap through the batch API', () => {
    expect(price(5, true)).toBeLessThanOrEqual(DEFAULT_BUDGET_USD);
  });

  it('and do not fit one call at a time, which is why the run says so before it spends', () => {
    expect(price(5, false)).toBeGreaterThan(DEFAULT_BUDGET_USD);
  });

  it('from Jan 1 2027 even the batch session is over: the premium model doubles', () => {
    expect(price(5, true, new Date('2027-01-02T12:00:00'))).toBeGreaterThan(DEFAULT_BUDGET_USD);
  });

  it('four fifths of a run is the premium model: half the replies and all the judging', () => {
    const cache = emptyCache();
    const all = estimateRun(planReplies(scenarios(), BOTH, 1), cache, {
      batch: false,
      at: NOW,
      judgeModelId: PREMIUM,
    }).usd;
    // The lite model's own replies. Everything else in a run is the premium
    // model: its replies, and the judge reading both models' answers.
    const lite = estimateCalls(
      planReplies(scenarios(), [LITE], 1).map((job) => job.call),
      cache,
      {batch: false, at: NOW},
    ).usd;
    expect((all - lite) / all).toBeGreaterThan(0.75);
  });
});

describe('the options', () => {
  it('default to one roll of everything, one call at a time, cache on', () => {
    expect(parseOptions([], {})).toMatchObject({
      rolls: 1,
      only: null,
      modelIds: BOTH,
      batch: false,
      cache: true,
      dryRun: false,
      firestore: false,
      budgetUsd: DEFAULT_BUDGET_USD,
    });
  });

  it('read rolls, cases, models and the money flags', () => {
    expect(
      parseOptions(
        ['--rolls', '5', '--only', '23,24', '--models', 'free', '--batch', '--budget', '0.6', '--no-cache'],
        {},
      ),
    ).toMatchObject({
      rolls: 5,
      only: ['23', '24'],
      modelIds: [LITE],
      batch: true,
      cache: false,
      budgetUsd: 0.6,
    });
  });

  it('follow the model ids the environment pins', () => {
    expect(parseOptions([], {MODEL_PREMIUM: 'gemini-9'}).modelIds).toEqual([LITE, 'gemini-9']);
  });

  it('refuse an argument they do not know, so a typo cannot send a run', () => {
    expect(() => parseOptions(['--dryrun'], {})).toThrow(/unknown argument "--dryrun"/);
    expect(() => parseOptions(['--rolls', 'many'], {})).toThrow(/--rolls/);
    expect(() => parseOptions(['--models', 'cheap'], {})).toThrow(/--models/);
    expect(() => parseOptions(['--only', ''], {})).toThrow(/--only/);
  });
});

describe('pickScenarios', () => {
  it('takes a number or a whole id, and keeps the suite order', () => {
    const picked = pickScenarios(scenarios(), ['23', '15-panic-mode']);
    expect(picked.map((s) => s.id)).toEqual(['15-panic-mode', '23-what-helps']);
  });

  it('refuses a case that does not exist', () => {
    expect(() => pickScenarios(scenarios(), ['99'])).toThrow(/no scenario "99"/);
  });

  it('is the whole suite when nothing is named', () => {
    expect(pickScenarios(scenarios(), null)).toHaveLength(25);
  });
});

interface Asked {
  readonly replies: GenerateRequest[];
  readonly judged: GenerateRequest[];
}

function fakeDeps(
  reply: (request: GenerateRequest) => string | Error,
  verdict: (request: GenerateRequest) => string | Error = () => '{"pass": true, "reason": "meets it"}',
  limitUsd = 0.35,
): {deps: ExecDeps; asked: Asked} {
  const dir = mkdtempSync(join(tmpdir(), 'coach-run-'));
  const asked: Asked = {replies: [], judged: []};
  const deps: ExecDeps = {
    model: {
      generate(request): Promise<GenerateResult> {
        const isJudge = request.systemInstruction === JUDGE_PROMPT;
        (isJudge ? asked.judged : asked.replies).push(request);
        const answer = isJudge ? verdict(request) : reply(request);
        return answer instanceof Error
          ? Promise.reject(answer)
          : Promise.resolve({text: answer, inputTokens: 2000, outputTokens: 60});
      },
    },
    batch: null,
    cache: new EvalCache(join(dir, 'cache'), () => NOW),
    budget: new EvalBudget(join(dir, 'spend.jsonl'), limitUsd, () => NOW),
    tool: 'coach-test',
    now: () => NOW,
    sleep: () => Promise.resolve(),
    log: () => undefined,
    pendingFile: join(dir, 'pending.json'),
    pollMs: 1,
    timeoutMs: 1000,
  };
  return {deps, asked};
}

/** `20-what-day` is graded mechanically only; `02-slip-40-hits` has a judge. */
const two = () => pickScenarios(scenarios(), ['02', '20']);

describe('a run', () => {
  it('judges only the cases that have criteria, on the judge model', async () => {
    const {deps, asked} = fakeDeps(() => 'You are on day 32. What set it off?');
    const report = await runCoachEval(planReplies(two(), BOTH, 1), PREMIUM, deps);

    expect(asked.replies).toHaveLength(4);
    expect(asked.judged).toHaveLength(2);
    expect(asked.judged.every((r) => r.model === PREMIUM && r.temperature === 0 && r.json === true)).toBe(true);
    expect(report.complete).toBe(true);
    expect(report.rolls.map((r) => [r.roll, r.modelId, r.passed])).toEqual([
      [1, LITE, 2],
      [1, PREMIUM, 2],
    ]);
  });

  it('fails a case on its mechanical check or on the judge, as it always has', async () => {
    const {deps} = fakeDeps(
      () => 'You are on day 31.',
      () => '{"pass": false, "reason": "asks no question"}',
    );
    const report = await runCoachEval(planReplies(two(), [LITE], 1), PREMIUM, deps);
    const [slip, day] = report.rolls[0]?.results ?? [];

    expect(slip?.pass).toBe(false);
    expect(slip?.checks.find((c) => c.name === 'judge')).toMatchObject({
      pass: false,
      detail: 'asks no question',
    });
    expect(day?.pass).toBe(false);
    expect(day?.checks.some((c) => !c.pass && c.name.startsWith('must'))).toBe(true);
    // A wrong answer is still an answer.
    expect(report.complete).toBe(true);
  });

  it('a verdict the judge garbled fails the case and still counts as a roll', async () => {
    const {deps} = fakeDeps(
      () => 'You are on day 32.',
      () => 'I think this is fine',
    );
    const report = await runCoachEval(planReplies(two(), [LITE], 1), PREMIUM, deps);
    expect(report.rolls[0]?.results[0]?.checks.find((c) => c.name === 'judge')).toMatchObject({
      pass: false,
      detail: 'malformed judge verdict',
    });
    expect(report.complete).toBe(true);
  });

  it('buys nothing the second time', async () => {
    const {deps, asked} = fakeDeps(() => 'You are on day 32. What set it off?');
    const jobs = planReplies(two(), BOTH, 1);
    const first = await runCoachEval(jobs, PREMIUM, deps);
    const spent = deps.budget.spentToday();
    const second = await runCoachEval(jobs, PREMIUM, deps);

    expect(asked.replies).toHaveLength(4);
    expect(asked.judged).toHaveLength(2);
    expect(deps.budget.spentToday()).toBe(spent);
    expect(second.rolls).toEqual(first.rolls);
    expect(second.reports.every((r) => r.paidCalls === 0)).toBe(true);
  });

  it('draws again for a second roll, and tells the rolls apart', async () => {
    let n = 0;
    const {deps, asked} = fakeDeps(() => `You are on day 32. Draw ${++n}.`);
    const report = await runCoachEval(planReplies(two(), [LITE], 2), PREMIUM, deps);

    expect(asked.replies).toHaveLength(4);
    expect(report.rolls.map((r) => r.roll)).toEqual([1, 2]);
    expect(report.rolls[0]?.results[1]?.reply).not.toBe(report.rolls[1]?.results[1]?.reply);
  });

  it('is not an answer when the budget stops it, and says so on every case it did not reach', async () => {
    const {deps, asked} = fakeDeps(() => 'You are on day 32.', undefined, 0.000001);
    const report = await runCoachEval(planReplies(two(), BOTH, 1), PREMIUM, deps);

    expect(asked.replies).toHaveLength(0);
    expect(asked.judged).toHaveLength(0);
    expect(report.complete).toBe(false);
    expect(report.note).toMatch(/eval budget/);
    for (const roll of report.rolls) {
      for (const result of roll.results) {
        expect(result.checks).toEqual([
          {name: 'model', pass: false, detail: expect.stringMatching(/^not run/) as string},
        ]);
      }
    }
  });

  it('is not an answer when a call failed on its own, and does not judge what is missing', async () => {
    const busy = new ModelUnavailableError(new Error('{"error":{"code":503}}'));
    let n = 0;
    const {deps, asked} = fakeDeps(() => (++n === 1 ? busy : 'You are on day 32.'));
    const report = await runCoachEval(planReplies(two(), [LITE], 1), PREMIUM, deps);

    expect(report.complete).toBe(false);
    // The 02 reply never arrived, and 20 has no judge.
    expect(asked.judged).toHaveLength(0);
    expect(report.rolls[0]?.results[0]?.checks[0]).toMatchObject({name: 'model', pass: false});
  });

  it('is not an answer when the judge could not be reached', async () => {
    const busy = new ModelUnavailableError(new Error('{"error":{"code":503}}'));
    const {deps} = fakeDeps(
      () => 'You are on day 32. What set it off?',
      () => busy,
    );
    const report = await runCoachEval(planReplies(two(), [LITE], 1), PREMIUM, deps);
    expect(report.complete).toBe(false);
    expect(report.rolls[0]?.results[0]?.checks.find((c) => c.name === 'judge')?.detail).toMatch(
      /^judge failed: /,
    );
  });

  it('stops at the billing wall and buys no verdicts for a run it has to throw away', async () => {
    const wall = new ModelUnavailableError(new Error('Your prepayment credits are depleted.'));
    let n = 0;
    const {deps, asked} = fakeDeps(() => (++n === 2 ? wall : 'You are on day 32. What set it off?'));
    const report = await runCoachEval(planReplies(two(), BOTH, 1), PREMIUM, deps);

    expect(asked.replies).toHaveLength(2);
    expect(asked.judged).toHaveLength(0);
    expect(report.complete).toBe(false);
    expect(report.note).toMatch(/billing/);
  });
});

describe('failureCounts', () => {
  it('counts failures per case and model across the rolls', async () => {
    let n = 0;
    // Draws 1 and 3 name the wrong day.
    const {deps} = fakeDeps(() => (++n % 2 === 1 ? 'You are on day 31.' : 'You are on day 32.'));
    const report = await runCoachEval(
      planReplies(pickScenarios(scenarios(), ['20']), [LITE], 4),
      PREMIUM,
      deps,
    );
    const counts = failureCounts(report.rolls);
    expect(counts.get('20-what-day')?.get(LITE)).toBe(2);
    expect(counts.size).toBe(1);
  });
});
