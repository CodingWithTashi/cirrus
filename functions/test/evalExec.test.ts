/**
 * The one door every eval call goes through. Tested with a fake model, so
 * these cost nothing: what is reused, what is paid for, what is charged to
 * the day's budget, and when a run stops instead of spending on.
 */
import {mkdtempSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {describe, expect, it} from 'vitest';
import {
  ModelUnavailableError,
  type BatchModel,
  type BatchOutcome,
  type GenerateRequest,
  type GenerateResult,
} from '../src/ai/model';
import {EvalBudget} from '../tools/evalBudget';
import {EvalCache} from '../tools/evalCache';
import {costUsd} from '../tools/evalCost';
import {estimateCalls, runCalls, type EvalCall, type ExecDeps} from '../tools/evalExec';

const NOW = new Date('2026-11-27T12:00:00');
const LITE = 'gemini-3.5-flash-lite';
const PREMIUM = 'gemini-3.6-flash';

function call(model: string, text: string, sample: number | null = 1): EvalCall {
  return {
    request: {
      model,
      systemInstruction: 'You are Ember. '.repeat(40),
      turns: [{role: 'user', text}],
      maxOutputTokens: 500,
    },
    sample,
    expectOutputTokens: 100,
  };
}

interface FakeModel {
  readonly asked: GenerateRequest[];
  generate(request: GenerateRequest): Promise<GenerateResult>;
}

function fakeModel(
  answer: (request: GenerateRequest, n: number) => GenerateResult | Error = () => ({
    text: 'ok',
    inputTokens: 1000,
    outputTokens: 50,
  }),
): FakeModel {
  const asked: GenerateRequest[] = [];
  return {
    asked,
    generate(request) {
      asked.push(request);
      const result = answer(request, asked.length);
      return result instanceof Error ? Promise.reject(result) : Promise.resolve(result);
    },
  };
}

interface FakeBatch extends BatchModel {
  readonly submitted: GenerateRequest[][];
  readonly collected: string[];
}

function fakeBatch(pollsBeforeDone = 0, fail: (r: GenerateRequest) => boolean = () => false): FakeBatch {
  const submitted: GenerateRequest[][] = [];
  const collected: string[] = [];
  const polls = new Map<string, number>();
  return {
    submitted,
    collected,
    submit(requests) {
      submitted.push([...requests]);
      return Promise.resolve(`batches/job-${submitted.length}`);
    },
    collect(job) {
      collected.push(job);
      const seen = polls.get(job) ?? 0;
      polls.set(job, seen + 1);
      if (seen < pollsBeforeDone) return Promise.resolve(null);
      const index = Number(job.split('-')[1]) - 1;
      const outcomes: BatchOutcome[] = (submitted[index] ?? []).map((r) =>
        fail(r)
          ? {ok: false, error: 'INTERNAL'}
          : {ok: true, result: {text: `batched ${r.turns[0]?.text ?? ''}`, inputTokens: 1000, outputTokens: 50}},
      );
      return Promise.resolve(outcomes);
    },
  };
}

function deps(over: Partial<ExecDeps> & {model: ExecDeps['model']}): ExecDeps {
  const dir = mkdtempSync(join(tmpdir(), 'eval-exec-'));
  return {
    batch: null,
    cache: new EvalCache(join(dir, 'cache'), () => NOW),
    budget: new EvalBudget(join(dir, 'spend.jsonl'), 0.35, () => NOW),
    tool: 'test',
    now: () => NOW,
    sleep: () => Promise.resolve(),
    log: () => undefined,
    pendingFile: join(dir, 'pending.json'),
    pollMs: 1,
    timeoutMs: 1000,
    ...over,
  };
}

describe('one call at a time', () => {
  it('asks the model once per call and charges what each one really used', async () => {
    const model = fakeModel();
    const d = deps({model});
    const report = await runCalls([call(LITE, 'a'), call(PREMIUM, 'b')], d);

    expect(model.asked).toHaveLength(2);
    expect(report.outcomes.map((o) => o.ok)).toEqual([true, true]);
    expect(report.paidCalls).toBe(2);
    expect(report.cacheHits).toBe(0);
    const expected =
      costUsd({model: LITE, inputTokens: 1000, outputTokens: 50, batch: false, at: NOW}) +
      costUsd({model: PREMIUM, inputTokens: 1000, outputTokens: 50, batch: false, at: NOW});
    expect(report.costUsd).toBeCloseTo(expected, 12);
    expect(d.budget.spentToday()).toBeCloseTo(expected, 12);
    expect(report.stoppedBy).toBeNull();
  });

  it('charges thinking tokens as output, because that is how they are billed', async () => {
    const model = fakeModel(() => ({text: 'ok', inputTokens: 1000, outputTokens: 50, thoughtTokens: 400}));
    const d = deps({model});
    const report = await runCalls([call(PREMIUM, 'a')], d);
    expect(report.costUsd).toBeCloseTo(
      costUsd({model: PREMIUM, inputTokens: 1000, outputTokens: 450, batch: false, at: NOW}),
      12,
    );
  });

  it('buys nothing the second time: the same calls come back from the cache', async () => {
    const model = fakeModel();
    const d = deps({model});
    const calls = [call(LITE, 'a'), call(LITE, 'b')];
    await runCalls(calls, d);
    const spent = d.budget.spentToday();

    const again = await runCalls(calls, d);
    expect(model.asked).toHaveLength(2);
    expect(again.cacheHits).toBe(2);
    expect(again.paidCalls).toBe(0);
    expect(again.costUsd).toBe(0);
    expect(again.outcomes.every((o) => o.ok && o.cached)).toBe(true);
    expect(d.budget.spentToday()).toBe(spent);
  });

  it('never keeps a blank answer: it is graded this once and asked again next time', async () => {
    const model = fakeModel(() => ({text: '   ', inputTokens: 1000, outputTokens: 20}));
    const d = deps({model});
    const first = await runCalls([call(LITE, 'a')], d);
    expect(first.outcomes[0]).toMatchObject({ok: true, cached: false});
    await runCalls([call(LITE, 'a')], d);
    expect(model.asked).toHaveLength(2);
  });

  it('a new roll of the same question is a new purchase', async () => {
    const model = fakeModel();
    const d = deps({model});
    await runCalls([call(LITE, 'a', 1)], d);
    await runCalls([call(LITE, 'a', 2)], d);
    expect(model.asked).toHaveLength(2);
  });

  it('refuses to start a run that will not fit in what is left of the day', async () => {
    const model = fakeModel();
    const d = deps({model});
    d.budget.charge(0.3499, 1, 'earlier');
    const report = await runCalls([call(PREMIUM, 'a'), call(PREMIUM, 'b')], d);

    expect(model.asked).toHaveLength(0);
    expect(report.stoppedBy).toBe('budget');
    expect(report.outcomes.every((o) => !o.ok && o.notRun)).toBe(true);
    expect(report.note).toMatch(/budget/i);
  });

  it('stops mid-run when calls cost more than expected, before the one that would pass the limit', async () => {
    // Each call uses far more than the estimate allowed for.
    const model = fakeModel(() => ({text: 'ok', inputTokens: 150_000, outputTokens: 500}));
    const d = deps({model});
    const calls = [1, 2, 3, 4, 5, 6].map((n) => call(PREMIUM, `q${n}`));
    const report = await runCalls(calls, d);

    expect(report.stoppedBy).toBe('budget');
    expect(model.asked.length).toBeGreaterThan(0);
    expect(model.asked.length).toBeLessThan(6);
    expect(d.budget.spentToday()).toBeLessThanOrEqual(0.35);
    const notRun = report.outcomes.filter((o) => !o.ok && o.notRun);
    expect(notRun).toHaveLength(6 - model.asked.length);
  });

  it('stops at the billing wall instead of sending the rest into it', async () => {
    const wall = new ModelUnavailableError(
      new Error('{"error":{"code":402,"message":"Your prepayment credits are depleted."}}'),
    );
    const model = fakeModel((_, n) => (n === 2 ? wall : {text: 'ok', inputTokens: 1000, outputTokens: 50}));
    const d = deps({model});
    const report = await runCalls([call(LITE, 'a'), call(LITE, 'b'), call(LITE, 'c')], d);

    expect(model.asked).toHaveLength(2);
    expect(report.stoppedBy).toBe('billing');
    expect(report.outcomes.map((o) => o.ok)).toEqual([true, false, false]);
    const third = report.outcomes[2];
    expect(third !== undefined && !third.ok && third.notRun).toBe(true);
  });

  it('reads the monthly spending cap as the same wall', async () => {
    const cap = new ModelUnavailableError(
      new Error('{"error":{"code":429,"message":"Your project has exceeded its monthly spending cap."}}'),
    );
    const model = fakeModel(() => cap);
    const report = await runCalls([call(LITE, 'a'), call(LITE, 'b')], deps({model}));
    expect(model.asked).toHaveLength(1);
    expect(report.stoppedBy).toBe('billing');
  });

  it('records an ordinary failure against its own call and carries on', async () => {
    const busy = new ModelUnavailableError(new Error('{"error":{"code":503,"status":"UNAVAILABLE"}}'));
    const model = fakeModel((_, n) => (n === 1 ? busy : {text: 'ok', inputTokens: 1000, outputTokens: 50}));
    const report = await runCalls([call(LITE, 'a'), call(LITE, 'b')], deps({model}));

    expect(model.asked).toHaveLength(2);
    expect(report.stoppedBy).toBeNull();
    expect(report.errors).toBe(1);
    const first = report.outcomes[0];
    expect(first !== undefined && !first.ok && !first.notRun && /503/.test(first.error)).toBe(true);
    expect(report.outcomes[1]?.ok).toBe(true);
  });
});

describe('through the batch API', () => {
  it('sends one job per model, keeps the answers in order, and pays half price', async () => {
    const model = fakeModel();
    const batch = fakeBatch();
    const d = deps({model, batch});
    const calls = [call(LITE, 'a'), call(PREMIUM, 'b'), call(LITE, 'c')];
    const report = await runCalls(calls, d);

    expect(model.asked).toHaveLength(0);
    expect(batch.submitted.map((group) => group.map((r) => r.model))).toEqual([
      [LITE, LITE],
      [PREMIUM],
    ]);
    expect(report.outcomes.map((o) => (o.ok ? o.text : o.error))).toEqual([
      'batched a',
      'batched b',
      'batched c',
    ]);
    const expected =
      2 * costUsd({model: LITE, inputTokens: 1000, outputTokens: 50, batch: true, at: NOW}) +
      costUsd({model: PREMIUM, inputTokens: 1000, outputTokens: 50, batch: true, at: NOW});
    expect(report.costUsd).toBeCloseTo(expected, 12);
    // The reservation was settled down to what the job really used.
    expect(d.budget.spentToday()).toBeCloseTo(expected, 12);
  });

  it('does not send what the cache already holds', async () => {
    const batch = fakeBatch();
    const d = deps({model: fakeModel(), batch});
    await runCalls([call(LITE, 'a')], d);
    const report = await runCalls([call(LITE, 'a'), call(LITE, 'b')], d);

    expect(batch.submitted).toHaveLength(2);
    expect(batch.submitted[1]?.map((r) => r.turns[0]?.text)).toEqual(['b']);
    expect(report.cacheHits).toBe(1);
    expect(report.paidCalls).toBe(1);
  });

  it('does not keep a blank row from a job either', async () => {
    const batch: FakeBatch = {
      ...fakeBatch(),
      collect: () => Promise.resolve([{ok: true, result: {text: '', inputTokens: 1000, outputTokens: 20}}]),
    };
    const d = deps({model: fakeModel(), batch});
    await runCalls([call(LITE, 'a')], d);
    await runCalls([call(LITE, 'a')], d);
    expect(batch.submitted).toHaveLength(2);
  });

  it('keeps the money set aside for a row a finished job did not return', async () => {
    // Whether that row was billed is unknown, so the ledger errs toward spent.
    const batch: FakeBatch = {...fakeBatch(), collect: () => Promise.resolve([])};
    const d = deps({model: fakeModel(), batch});
    const report = await runCalls([call(LITE, 'a')], d);
    expect(report.errors).toBe(1);
    expect(report.paidCalls).toBe(0);
    expect(d.budget.spentToday()).toBeGreaterThan(0);
  });

  it('waits for a job that is still running', async () => {
    const batch = fakeBatch(3);
    const report = await runCalls([call(LITE, 'a')], deps({model: fakeModel(), batch}));
    expect(batch.collected).toHaveLength(4);
    expect(report.outcomes[0]?.ok).toBe(true);
  });

  it('refuses a job whose estimate does not fit, and submits nothing', async () => {
    const batch = fakeBatch();
    const d = deps({model: fakeModel(), batch});
    d.budget.charge(0.3499, 1, 'earlier');
    const report = await runCalls([call(PREMIUM, 'a')], d);

    expect(batch.submitted).toHaveLength(0);
    expect(report.stoppedBy).toBe('budget');
  });

  it('gives up waiting without paying twice: the next run collects the same job', async () => {
    const batch = fakeBatch(1_000_000);
    const d = deps({model: fakeModel(), batch, timeoutMs: 0});
    const calls = [call(LITE, 'a'), call(LITE, 'b')];
    const first = await runCalls(calls, d);
    expect(first.stoppedBy).toBe('batch-timeout');
    expect(first.outcomes.every((o) => !o.ok && o.notRun)).toBe(true);
    const reserved = d.budget.spentToday();
    expect(reserved).toBeGreaterThan(0);

    // Same calls again: no second submit, and no second reservation.
    const second = await runCalls(calls, {...d, timeoutMs: 0});
    expect(batch.submitted).toHaveLength(1);
    expect(second.stoppedBy).toBe('batch-timeout');
    expect(d.budget.spentToday()).toBeCloseTo(reserved, 12);
  });

  it('marks the one request a job could not answer, and still charges the rest', async () => {
    const batch = fakeBatch(0, (r) => r.turns[0]?.text === 'b');
    const d = deps({model: fakeModel(), batch});
    const report = await runCalls([call(LITE, 'a'), call(LITE, 'b')], d);
    expect(report.outcomes.map((o) => o.ok)).toEqual([true, false]);
    expect(report.errors).toBe(1);
    expect(report.paidCalls).toBe(1);
  });
});

describe('estimateCalls', () => {
  it('counts only what would be bought, at the price it would be bought at', () => {
    const d = deps({model: fakeModel()});
    const calls = [call(LITE, 'a'), call(PREMIUM, 'b')];
    const full = estimateCalls(calls, d.cache, {batch: false, at: NOW});
    expect(full.paidCalls).toBe(2);
    expect(full.usd).toBeGreaterThan(0);

    const half = estimateCalls(calls, d.cache, {batch: true, at: NOW});
    expect(half.usd).toBeCloseTo(full.usd / 2, 12);

    const first = calls[0];
    if (first === undefined) throw new Error('unreachable');
    d.cache.put(d.cache.key(first.request, first.sample), {text: 'ok', inputTokens: 1, outputTokens: 1});
    const warm = estimateCalls(calls, d.cache, {batch: false, at: NOW});
    expect(warm.paidCalls).toBe(1);
    expect(warm.cacheHits).toBe(1);
    expect(warm.usd).toBeLessThan(full.usd);
  });
});
