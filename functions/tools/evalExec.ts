/**
 * The one door every eval call goes through.
 *
 * `coachEval` and `moderationEval` used to call the model directly, one call
 * after another, with nothing between them and the bill. They hand their
 * calls here instead, and each call is, in this order:
 *
 *  1. answered from the cache if this exact request was already bought
 *     (`evalCache.ts`);
 *  2. checked against what is left of the day's budget, before it is sent
 *     (`evalBudget.ts`): a run that will not fit does not start, and a run
 *     that turns out dearer than its estimate stops before the call that
 *     would pass the limit;
 *  3. sent, either one at a time or as a half-price batch job (`--batch`);
 *  4. charged at what it really used, and stored.
 *
 * A run also stops at the billing wall. On Nov 25 2026 the monthly spend cap
 * closed mid-run and the harness sent every remaining call into it; those
 * refusals then had to be told apart from real answers by hand.
 *
 * What comes back says which answers are real: an outcome is a reply, a
 * failure of its own call, or `notRun`. A caller must never grade a run that
 * has `notRun` outcomes as if it were whole.
 */
import {createHash} from 'node:crypto';
import {existsSync, mkdirSync, readFileSync, renameSync, writeFileSync} from 'node:fs';
import {dirname, join} from 'node:path';
import {geminiBatch, geminiModel} from '../src/ai/gemini';
import {
  ModelUnavailableError,
  type BatchModel,
  type GenerateRequest,
  type GenerateResult,
  type TextModel,
} from '../src/ai/model';
import {BudgetExceededError, EvalBudget, budgetLimit, evalHome, usd} from './evalBudget';
import {EvalCache} from './evalCache';
import {costUsd, estimateTokens} from './evalCost';

export interface EvalCall {
  readonly request: GenerateRequest;
  /**
   * The roll this call belongs to when its answer is a draw (a coach reply);
   * null when the same request should always get the same answer (the judge).
   */
  readonly sample: number | null;
  /** A realistic reply size, for the estimate only. */
  readonly expectOutputTokens: number;
}

export type EvalOutcome =
  | {readonly ok: true; readonly text: string; readonly cached: boolean}
  | {readonly ok: false; readonly error: string; readonly notRun: boolean};

export type StopReason = 'budget' | 'billing' | 'batch-timeout';

export interface RunReport {
  readonly outcomes: readonly EvalOutcome[];
  readonly paidCalls: number;
  readonly cacheHits: number;
  /** Calls that were sent and failed on their own (a 503, a bad batch row). */
  readonly errors: number;
  readonly costUsd: number;
  readonly stoppedBy: StopReason | null;
  /** Why it stopped, in a sentence; empty when it did not. */
  readonly note: string;
}

export interface ExecDeps {
  readonly model: Pick<TextModel, 'generate'>;
  /** Null sends one call at a time; a batch model sends jobs. */
  readonly batch: BatchModel | null;
  readonly cache: EvalCache;
  readonly budget: EvalBudget;
  /** Names the tool in the ledger. */
  readonly tool: string;
  readonly now: () => Date;
  readonly sleep: (ms: number) => Promise<void>;
  readonly log: (line: string) => void;
  readonly pendingFile: string;
  readonly pollMs: number;
  readonly timeoutMs: number;
}

function inputTokensOf(request: GenerateRequest): number {
  return estimateTokens(
    request.systemInstruction + request.turns.map((turn) => turn.text).join(''),
  );
}

/** What a call is expected to cost. */
function expectedUsd(call: EvalCall, batch: boolean, at: Date): number {
  return costUsd({
    model: call.request.model,
    inputTokens: inputTokensOf(call.request),
    outputTokens: call.expectOutputTokens,
    batch,
    at,
  });
}

/** The most a call can cost if the model fills its whole output cap. */
function worstUsd(call: EvalCall, at: Date): number {
  return costUsd({
    model: call.request.model,
    inputTokens: inputTokensOf(call.request),
    outputTokens: call.request.maxOutputTokens,
    batch: false,
    at,
  });
}

function billedUsd(model: string, result: GenerateResult, batch: boolean, at: Date): number {
  return costUsd({
    model,
    inputTokens: result.inputTokens,
    outputTokens: result.outputTokens + (result.thoughtTokens ?? 0),
    batch,
    at,
  });
}

/** What [calls] would cost now: nothing for those the cache already holds. */
export function estimateCalls(
  calls: readonly EvalCall[],
  cache: EvalCache,
  opts: {readonly batch: boolean; readonly at: Date},
): {paidCalls: number; cacheHits: number; usd: number} {
  let paidCalls = 0;
  let cacheHits = 0;
  let total = 0;
  for (const call of calls) {
    if (cache.has(cache.key(call.request, call.sample))) {
      cacheHits++;
    } else {
      paidCalls++;
      total += expectedUsd(call, opts.batch, opts.at);
    }
  }
  return {paidCalls, cacheHits, usd: total};
}

/**
 * Stores an answer, unless it is blank.
 *
 * A blank reply is still an answer for this run and is graded as one. It is
 * never kept: the first real batch job returned every reply empty because
 * of a reader bug, and a cache that had kept those would have served blanks
 * to every later roll as if the model had said nothing.
 */
function keep(cache: EvalCache, key: string, result: GenerateResult): void {
  if (result.text.trim().length > 0) cache.put(key, result);
}

function describe(error: unknown): string {
  if (error instanceof ModelUnavailableError) return `model unavailable: ${String(error.cause)}`;
  return String(error);
}

/**
 * The account has stopped paying: the prepaid balance is gone (402) or the
 * monthly spend cap has closed (a 429 that says so). Every later call would
 * get the same answer, and the live coach is being refused too.
 */
export function isBillingWall(error: string): boolean {
  return /prepayment credits|spending cap|payment required|"code":\s*402/i.test(error);
}

interface Tally {
  paidCalls: number;
  errors: number;
  costUsd: number;
  stoppedBy: StopReason | null;
  note: string;
}

async function oneAtATime(
  calls: readonly EvalCall[],
  keys: readonly string[],
  todo: readonly number[],
  outcomes: (EvalOutcome | undefined)[],
  tally: Tally,
  deps: ExecDeps,
): Promise<void> {
  const at = deps.now();
  let expected = 0;
  for (const i of todo) expected += expectedUsd(calls[i] as EvalCall, false, at);
  try {
    deps.budget.require(expected, `these ${todo.length} calls`);
  } catch (error) {
    if (!(error instanceof BudgetExceededError)) throw error;
    tally.stoppedBy = 'budget';
    tally.note = error.message;
    return;
  }

  // What a call on each model has really cost so far. An estimate that was
  // too low is corrected by the first bill, not trusted for the whole run.
  const dearest = new Map<string, number>();
  for (const i of todo) {
    const call = calls[i] as EvalCall;
    const model = call.request.model;
    try {
      deps.budget.require(Math.max(worstUsd(call, at), dearest.get(model) ?? 0), 'the next call');
    } catch (error) {
      if (!(error instanceof BudgetExceededError)) throw error;
      tally.stoppedBy = 'budget';
      tally.note = error.message;
      return;
    }
    try {
      const result = await deps.model.generate(call.request);
      const cost = billedUsd(model, result, false, at);
      deps.budget.charge(cost, 1, deps.tool);
      keep(deps.cache, keys[i] as string, result);
      dearest.set(model, Math.max(dearest.get(model) ?? 0, cost));
      outcomes[i] = {ok: true, text: result.text, cached: false};
      tally.paidCalls++;
      tally.costUsd += cost;
    } catch (error) {
      const text = describe(error);
      outcomes[i] = {ok: false, error: text, notRun: false};
      tally.errors++;
      if (isBillingWall(text)) {
        tally.stoppedBy = 'billing';
        tally.note =
          'the Gemini account refused the call for billing (prepaid balance or monthly ' +
          'spend cap). Nothing more was sent. The live coach is being refused too: top up ' +
          'or raise the cap before anything else.';
        return;
      }
    }
  }
}

interface PendingJob {
  readonly job: string;
  readonly model: string;
  readonly calls: number;
  readonly reservedUsd: number;
  readonly at: string;
}

function readPending(file: string): Record<string, PendingJob> {
  if (!existsSync(file)) return {};
  try {
    return JSON.parse(readFileSync(file, 'utf8')) as Record<string, PendingJob>;
  } catch {
    return {};
  }
}

function writePending(file: string, jobs: Record<string, PendingJob>): void {
  mkdirSync(dirname(file), {recursive: true});
  const temp = `${file}.${process.pid}.tmp`;
  writeFileSync(temp, JSON.stringify(jobs, null, 2));
  renameSync(temp, file);
}

async function asBatchJobs(
  calls: readonly EvalCall[],
  keys: readonly string[],
  todo: readonly number[],
  outcomes: (EvalOutcome | undefined)[],
  tally: Tally,
  deps: ExecDeps,
  batch: BatchModel,
): Promise<void> {
  const at = deps.now();
  // A job is one model.
  const groups = new Map<string, number[]>();
  for (const i of todo) {
    const model = (calls[i] as EvalCall).request.model;
    const group = groups.get(model);
    if (group === undefined) groups.set(model, [i]);
    else group.push(i);
  }

  interface Live {
    readonly model: string;
    readonly indexes: readonly number[];
    readonly id: string;
    readonly job: string;
    readonly reserved: number;
  }
  const live: Live[] = [];
  const pending = readPending(deps.pendingFile);

  for (const [model, indexes] of groups) {
    // The job for exactly these requests. A run that gave up waiting left it
    // here, and the same command collects it instead of paying for it twice.
    const id = createHash('sha256')
      .update(indexes.map((i) => keys[i] as string).join('\n'))
      .digest('hex');
    const known = pending[id];
    if (known !== undefined) {
      deps.log(`  collecting ${known.job} (${model}, ${indexes.length} calls), sent ${known.at}`);
      live.push({model, indexes, id, job: known.job, reserved: known.reservedUsd});
      continue;
    }

    let estimate = 0;
    for (const i of indexes) estimate += expectedUsd(calls[i] as EvalCall, true, at);
    const what = `a batch of ${indexes.length} ${model} calls`;
    try {
      deps.budget.reserve(estimate, what);
    } catch (error) {
      if (!(error instanceof BudgetExceededError)) throw error;
      tally.stoppedBy = 'budget';
      tally.note = error.message;
      break;
    }
    let job: string;
    try {
      job = await batch.submit(
        indexes.map((i) => (calls[i] as EvalCall).request),
        `${deps.tool}-${model}`,
      );
    } catch (error) {
      // Nothing was sent, so nothing will be billed: hand the reservation back.
      deps.budget.settle(estimate, 0, 0, what);
      const text = describe(error);
      for (const i of indexes) outcomes[i] = {ok: false, error: text, notRun: false};
      tally.errors += indexes.length;
      if (isBillingWall(text)) {
        tally.stoppedBy = 'billing';
        tally.note = 'the Gemini account refused the batch job for billing. Nothing more was sent.';
        break;
      }
      continue;
    }
    pending[id] = {job, model, calls: indexes.length, reservedUsd: estimate, at: at.toISOString()};
    writePending(deps.pendingFile, pending);
    deps.log(`  sent ${job} (${model}, ${indexes.length} calls, about ${usd(estimate)})`);
    live.push({model, indexes, id, job, reserved: estimate});
  }

  let waiting = live;
  let waited = 0;
  while (waiting.length > 0) {
    const still: Live[] = [];
    for (const group of waiting) {
      const what = `the ${group.model} batch`;
      let done;
      try {
        done = await batch.collect(group.job);
      } catch (error) {
        // The whole job failed. Whether any of it was billed is unknown, so
        // the reservation stands: the ledger errs toward "spent".
        const text = describe(error);
        for (const i of group.indexes) outcomes[i] = {ok: false, error: text, notRun: false};
        tally.errors += group.indexes.length;
        delete pending[group.id];
        writePending(deps.pendingFile, pending);
        continue;
      }
      if (done === null) {
        still.push(group);
        continue;
      }
      let actual = 0;
      let answered = 0;
      // Set aside for rows that came back failed or not at all. Whether the
      // provider billed them is unknown, so they stay counted as spent.
      let unknown = 0;
      group.indexes.forEach((i, position) => {
        const item = done[position];
        if (item === undefined || !item.ok) {
          outcomes[i] = {
            ok: false,
            error: item === undefined ? 'the job returned no row for this request' : item.error,
            notRun: false,
          };
          tally.errors++;
          unknown += expectedUsd(calls[i] as EvalCall, true, at);
          return;
        }
        actual += billedUsd(group.model, item.result, true, at);
        answered++;
        keep(deps.cache, keys[i] as string, item.result);
        outcomes[i] = {ok: true, text: item.result.text, cached: false};
      });
      deps.budget.settle(group.reserved, actual + unknown, answered, what);
      tally.paidCalls += answered;
      tally.costUsd += actual;
      delete pending[group.id];
      writePending(deps.pendingFile, pending);
      deps.log(`  ${group.job} done: ${answered}/${group.indexes.length} answered, ${usd(actual)}`);
    }
    waiting = still;
    if (waiting.length === 0) break;
    if (waited >= deps.timeoutMs) {
      // A budget refusal is the more useful thing to report if both happened.
      if (tally.stoppedBy === null) {
        tally.stoppedBy = 'batch-timeout';
        tally.note =
          `still running after ${Math.round(waited / 60_000)} min: ` +
          `${waiting.map((g) => g.job).join(', ')}. Run the same command again to collect ` +
          'the answers; nothing is sent or paid for twice.';
      }
      return;
    }
    await deps.sleep(deps.pollMs);
    waited += deps.pollMs;
  }
}

export async function runCalls(calls: readonly EvalCall[], deps: ExecDeps): Promise<RunReport> {
  const outcomes: (EvalOutcome | undefined)[] = calls.map(() => undefined);
  const keys = calls.map((call) => deps.cache.key(call.request, call.sample));
  const todo: number[] = [];
  let cacheHits = 0;
  calls.forEach((_, i) => {
    const hit = deps.cache.get(keys[i] as string);
    if (hit === null) {
      todo.push(i);
    } else {
      outcomes[i] = {ok: true, text: hit.text, cached: true};
      cacheHits++;
    }
  });

  const tally: Tally = {paidCalls: 0, errors: 0, costUsd: 0, stoppedBy: null, note: ''};
  if (todo.length > 0) {
    if (deps.batch === null) await oneAtATime(calls, keys, todo, outcomes, tally, deps);
    else await asBatchJobs(calls, keys, todo, outcomes, tally, deps, deps.batch);
  }

  return {
    outcomes: outcomes.map(
      (outcome): EvalOutcome =>
        outcome ?? {ok: false, error: `not run: ${tally.note || 'the run stopped'}`, notRun: true},
    ),
    paidCalls: tally.paidCalls,
    cacheHits,
    errors: tally.errors,
    costUsd: tally.costUsd,
    stoppedBy: tally.stoppedBy,
    note: tally.note,
  };
}

/** The flags both eval tools share. */
export interface CommonFlags {
  readonly batch: boolean;
  readonly cache: boolean;
  readonly dryRun: boolean;
  readonly budgetUsd: number;
  /** How long to wait for batch jobs before leaving them for the next run. */
  readonly batchWaitMin: number;
}

const COMMON_BARE = ['--batch', '--no-cache', '--dry-run'];
const COMMON_VALUED = ['--budget', '--batch-wait'];

/**
 * Refuses an argument the tool does not know.
 *
 * A flag that is silently ignored is how a run gets sent by accident:
 * `--dryrun` used to be read as nothing at all, and the eval then went on
 * to the real API. [valued] flags take the next argument as their value.
 */
export function checkArgs(
  argv: readonly string[],
  valued: readonly string[],
  bare: readonly string[],
): void {
  const takesValue = new Set([...COMMON_VALUED, ...valued]);
  const known = new Set([...COMMON_BARE, ...bare]);
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i] as string;
    if (takesValue.has(arg)) {
      i++;
      continue;
    }
    if (!known.has(arg)) {
      throw new Error(
        `unknown argument "${arg}". Known: ${[...known, ...takesValue].sort().join(', ')}. ` +
          'Nothing was sent.',
      );
    }
  }
}

export function commonFlags(
  argv: readonly string[],
  env: Readonly<Record<string, string | undefined>>,
): CommonFlags {
  const waitAt = argv.indexOf('--batch-wait');
  const wait = waitAt === -1 ? 30 : Number(argv[waitAt + 1]);
  if (!Number.isFinite(wait) || wait < 0) {
    throw new Error('--batch-wait takes a number of minutes, for example --batch-wait 45');
  }
  return {
    batch: argv.includes('--batch'),
    cache: !argv.includes('--no-cache'),
    dryRun: argv.includes('--dry-run'),
    budgetUsd: budgetLimit(argv, env),
    batchWaitMin: wait,
  };
}

/** The budget and the cache alone: all a `--dry-run` needs, and no API key. */
export function openLedger(
  flags: CommonFlags,
  env: Readonly<Record<string, string | undefined>>,
): {budget: EvalBudget; cache: EvalCache; home: string} {
  const home = evalHome(env);
  return {
    home,
    budget: new EvalBudget(join(home, 'spend.jsonl'), flags.budgetUsd),
    cache: new EvalCache(flags.cache ? join(home, 'cache') : null),
  };
}

/** Everything `runCalls` needs, against the real API. */
export function openDeps(args: {
  readonly apiKey: string;
  readonly flags: CommonFlags;
  readonly env: Readonly<Record<string, string | undefined>>;
  readonly tool: string;
  readonly log: (line: string) => void;
}): ExecDeps {
  const {budget, cache, home} = openLedger(args.flags, args.env);
  return {
    model: geminiModel(args.apiKey),
    batch: args.flags.batch ? geminiBatch(args.apiKey) : null,
    cache,
    budget,
    tool: args.tool,
    now: () => new Date(),
    sleep: (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
    log: args.log,
    pendingFile: join(home, 'pending-batches.json'),
    pollMs: 20_000,
    timeoutMs: args.flags.batchWaitMin * 60_000,
  };
}

/** One line on what a run spent and what is left of the day. */
export function spendLine(reports: readonly RunReport[], budget: EvalBudget): string {
  let paid = 0;
  let reused = 0;
  let cost = 0;
  for (const report of reports) {
    paid += report.paidCalls;
    reused += report.cacheHits;
    cost += report.costUsd;
  }
  return (
    `spent ${usd(cost)} on ${paid} calls (${reused} reused from the cache). ` +
    `Today: ${usd(budget.spentToday())} of ${usd(budget.limitUsd)}.`
  );
}
