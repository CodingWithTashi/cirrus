/**
 * The eval spend cap.
 *
 * Why it exists: evals run on the production Gemini key and share its
 * balance with the live coach. On Nov 13 and Nov 25 2026 eval rolls spent
 * CA$7.15 of a CA$7.28 month, tripped the spend cap and then the prepaid
 * balance, and real people got "Signal dropped" from Ember three times.
 * Nothing in the harness knew what a session had spent.
 *
 * What it is: an append-only ledger of dollars, one line per charge, and a
 * limit per calendar day. Every eval call asks it first.
 *
 *  - ONE ledger for the machine (`~/.cirrus-eval/spend.jsonl`), not one per
 *    checkout. An old-versus-new comparison runs from two working copies
 *    side by side; a ledger inside `functions/evals/` would give each its
 *    own cap.
 *  - Append-only, so two runs writing at once cannot lose each other's
 *    charge the way a read-modify-write total would.
 *  - It fails CLOSED. A ledger it cannot read stops the run; it is never
 *    read as "nothing spent".
 *  - The limit is raised only by saying so (`--budget`, `EVAL_BUDGET_USD`),
 *    which makes spending more a decision instead of a habit.
 *
 * The default is US$0.33 a day. The founder's number is "under 50 cents",
 * the price list is in USD and the bill is in CAD: 33 US cents stays under
 * 50 Canadian ones at any rate up to 1.51. Five rolls of the coach suite on
 * both models through the batch API cost about US$0.30, so one full session
 * fits and a second one the same day has to be asked for.
 */
import {appendFileSync, existsSync, mkdirSync, readFileSync} from 'node:fs';
import {homedir} from 'node:os';
import {dirname, join} from 'node:path';

export const DEFAULT_BUDGET_USD = 0.33;

/** Where the ledger, the cache and pending batch jobs live. `EVAL_HOME` moves it. */
export function evalHome(env: Readonly<Record<string, string | undefined>>): string {
  const override = env['EVAL_HOME'];
  return override !== undefined && override.trim().length > 0
    ? override
    : join(homedir(), '.cirrus-eval');
}

export class BudgetExceededError extends Error {
  constructor(
    readonly needUsd: number,
    readonly spentUsd: number,
    readonly limitUsd: number,
    what: string,
  ) {
    super(
      `eval budget: ${what} needs about ${usd(needUsd)}, and ${usd(spentUsd)} of today's ` +
        `${usd(limitUsd)} is already spent. Use --batch (half price), fewer --rolls or ` +
        `--only, or raise today's limit on purpose with --budget <usd>.`,
    );
  }
}

interface Entry {
  readonly day: string;
  readonly usd: number;
}

export function usd(amount: number): string {
  return `$${amount.toFixed(amount < 0.1 ? 4 : 2)}`;
}

/** The machine's own calendar day: a budget is "today's", read by a person. */
function localDay(at: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${at.getFullYear()}-${pad(at.getMonth() + 1)}-${pad(at.getDate())}`;
}

export class EvalBudget {
  constructor(
    private readonly file: string,
    readonly limitUsd: number,
    private readonly now: () => Date = () => new Date(),
  ) {}

  spentToday(): number {
    const today = localDay(this.now());
    let total = 0;
    for (const entry of this.read()) {
      if (entry.day === today) total += entry.usd;
    }
    // Reservations and their corrections are floats; never report -0.0000001.
    return Math.max(0, Math.round(total * 1e9) / 1e9);
  }

  remaining(): number {
    return Math.max(0, this.limitUsd - this.spentToday());
  }

  /** Throws unless [amount] more fits under today's limit. Spends nothing. */
  require(amount: number, what: string): void {
    const spent = this.spentToday();
    if (spent + amount > this.limitUsd + 1e-9) {
      throw new BudgetExceededError(amount, spent, this.limitUsd, what);
    }
  }

  /** Records money already spent. */
  charge(amount: number, calls: number, what: string): void {
    this.append({kind: 'charge', usd: amount, calls, what});
  }

  /**
   * Counts [amount] as spent before it is: a batch job bills whether or not
   * this process is still alive to see it finish.
   */
  reserve(amount: number, what: string): void {
    this.require(amount, what);
    this.append({kind: 'reserve', usd: amount, calls: 0, what});
  }

  /** Corrects a reservation to what the job really used. */
  settle(reserved: number, actual: number, calls: number, what: string): void {
    this.append({kind: 'settle', usd: actual - reserved, calls, what});
  }

  private append(entry: {kind: string; usd: number; calls: number; what: string}): void {
    const at = this.now();
    mkdirSync(dirname(this.file), {recursive: true});
    appendFileSync(
      this.file,
      JSON.stringify({at: at.toISOString(), day: localDay(at), ...entry}) + '\n',
    );
  }

  private read(): Entry[] {
    if (!existsSync(this.file)) return [];
    const entries: Entry[] = [];
    const lines = readFileSync(this.file, 'utf8').split('\n');
    lines.forEach((line, index) => {
      if (line.trim().length === 0) return;
      let parsed: unknown;
      try {
        parsed = JSON.parse(line);
      } catch {
        parsed = null;
      }
      const row = parsed as {day?: unknown; usd?: unknown} | null;
      if (row === null || typeof row.day !== 'string' || typeof row.usd !== 'number') {
        throw new Error(
          `eval budget: line ${index + 1} of the spend ledger (${this.file}) is unreadable. ` +
            'The cap will not guess what was spent: fix or remove that line and run again.',
        );
      }
      entries.push({day: row.day, usd: row.usd});
    });
    return entries;
  }
}

/** Today's limit: `--budget <usd>`, else `EVAL_BUDGET_USD`, else the default. */
export function budgetLimit(
  argv: readonly string[],
  env: Readonly<Record<string, string | undefined>>,
): number {
  const flag = argv.indexOf('--budget');
  const raw = flag !== -1 ? argv[flag + 1] : env['EVAL_BUDGET_USD'];
  if (flag === -1 && raw === undefined) return DEFAULT_BUDGET_USD;
  const value = Number(raw);
  if (raw === undefined || raw.trim().length === 0 || !Number.isFinite(value) || value <= 0) {
    throw new Error(
      `eval budget: "${raw ?? ''}" is not a limit. Give a positive number of US dollars, ` +
        'for example --budget 0.60.',
    );
  }
  return value;
}
