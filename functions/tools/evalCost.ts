/**
 * What an eval call costs. Pure arithmetic over a price list, so the eval
 * budget (`evalBudget.ts`) can count dollars instead of calls.
 *
 * The rates are USD per million tokens on the paid tier of the Gemini API,
 * read from the price list on Nov 27 2026 (ai.google.dev/gemini-api/docs/pricing).
 * Three things that list says, and this file follows:
 *
 *  - Output is priced "including thinking tokens", so a caller adds thought
 *    tokens to the output count before asking for a cost.
 *  - The batch API is half the standard price, input and output alike.
 *  - `gemini-3.6-flash` DOUBLES on Jan 1 2027 ($0.75/$3.75 becomes
 *    $1.50/$7.50). It is the premium coach model and the eval judge, so
 *    every figure in the eval's header doubles for that model on that day.
 *
 * A model with no row here is refused, never guessed: a cap computed from a
 * made-up rate is not a cap. Add the row when a `MODEL_*` id moves.
 *
 * The check on this table is the bill itself. After a session, the day's
 * total in the ledger should match that day's bar on the AI Studio Spend
 * page (which is in the account's currency, CAD, and lags by hours).
 */

interface Rate {
  /** First UTC day the rate applies, `yyyy-MM-dd`. */
  readonly from: string;
  readonly inputPerM: number;
  readonly outputPerM: number;
}

const RATES: Readonly<Record<string, readonly Rate[]>> = {
  'gemini-3.5-flash-lite': [{from: '2026-01-01', inputPerM: 0.3, outputPerM: 2.5}],
  'gemini-3.6-flash': [
    {from: '2026-01-01', inputPerM: 0.75, outputPerM: 3.75},
    {from: '2027-01-01', inputPerM: 1.5, outputPerM: 7.5},
  ],
};

/** The batch API's price, as a share of the standard one. */
export const BATCH_FACTOR = 0.5;

export class UnknownPriceError extends Error {
  constructor(model: string) {
    super(
      `no price for model "${model}". Add its rates to functions/tools/evalCost.ts ` +
        'before running an eval on it: the spend cap cannot count a call it cannot price.',
    );
  }
}

export function rateFor(model: string, at: Date): Rate {
  const rates = RATES[model];
  if (rates === undefined) throw new UnknownPriceError(model);
  const day = at.toISOString().slice(0, 10);
  let current: Rate | undefined;
  for (const rate of rates) {
    if (rate.from <= day) current = rate;
  }
  // Before the first row's date: the first row is still the best answer.
  const chosen = current ?? rates[0];
  if (chosen === undefined) throw new UnknownPriceError(model);
  return chosen;
}

export function costUsd(args: {
  readonly model: string;
  readonly inputTokens: number;
  /** Thought tokens included: they are billed as output. */
  readonly outputTokens: number;
  readonly batch: boolean;
  readonly at: Date;
}): number {
  const rate = rateFor(args.model, args.at);
  const standard =
    (args.inputTokens * rate.inputPerM + args.outputTokens * rate.outputPerM) / 1_000_000;
  return args.batch ? standard * BATCH_FACTOR : standard;
}

/**
 * Tokens in [text], guessed high on purpose.
 *
 * The estimate decides whether a run may start, so it has to err toward
 * "too expensive". English prose runs near four characters a token; the
 * coach prompt, with its headings, numbers and short lines, runs denser.
 */
export function estimateTokens(text: string): number {
  return Math.ceil(text.length / 3.5);
}
