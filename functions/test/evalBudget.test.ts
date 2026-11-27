/**
 * The eval spend cap. On Nov 13 and Nov 25 2026 eval rolls on the production
 * key spent CA$7.15 of a CA$7.28 month and took the live coach down twice;
 * nothing counted what a session had spent. This ledger is that count, and
 * these tests pin the properties the cap depends on: one ledger for every
 * working copy, a day that resets, and a guard that fails closed.
 */
import {appendFileSync, mkdtempSync, readFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {describe, expect, it} from 'vitest';
import {
  BudgetExceededError,
  DEFAULT_BUDGET_USD,
  EvalBudget,
  budgetLimit,
} from '../tools/evalBudget';

function ledgerFile(): string {
  return join(mkdtempSync(join(tmpdir(), 'eval-budget-')), 'spend.jsonl');
}

const noon = (day: string) => () => new Date(`${day}T12:00:00`);

describe('the eval budget', () => {
  it('defaults to 33 US cents a day, which is under 50 Canadian cents', () => {
    expect(DEFAULT_BUDGET_USD).toBe(0.33);
    // Up to an exchange rate of 1.51, well past anything the bill has shown.
    expect(DEFAULT_BUDGET_USD * 1.51).toBeLessThan(0.5);
  });

  it('starts a day with nothing spent', () => {
    const budget = new EvalBudget(ledgerFile(), 0.35, noon('2026-11-27'));
    expect(budget.spentToday()).toBe(0);
    expect(budget.remaining()).toBeCloseTo(0.35, 9);
  });

  it('counts what was charged, and a second working copy sees it', () => {
    const file = ledgerFile();
    new EvalBudget(file, 0.35, noon('2026-11-27')).charge(0.1, 98, 'coach');
    const other = new EvalBudget(file, 0.35, noon('2026-11-27'));
    expect(other.spentToday()).toBeCloseTo(0.1, 9);
    expect(other.remaining()).toBeCloseTo(0.25, 9);
  });

  it('refuses spend that would pass the limit, and says by how much', () => {
    const budget = new EvalBudget(ledgerFile(), 0.35, noon('2026-11-27'));
    budget.charge(0.3, 300, 'coach');
    expect(() => budget.require(0.04, 'the next call')).not.toThrow();
    expect(() => budget.require(0.06, 'the next call')).toThrow(BudgetExceededError);
    try {
      budget.require(0.06, 'the next call');
    } catch (error) {
      expect(String(error)).toMatch(/\$0\.30/);
      expect(String(error)).toMatch(/\$0\.35/);
      expect(String(error)).toMatch(/the next call/);
    }
  });

  it('starts again from zero on the next calendar day', () => {
    const file = ledgerFile();
    new EvalBudget(file, 0.35, noon('2026-11-27')).charge(0.34, 300, 'coach');
    const tomorrow = new EvalBudget(file, 0.35, noon('2026-11-28'));
    expect(tomorrow.spentToday()).toBe(0);
  });

  it('counts a reservation as spent until it is settled to what was really used', () => {
    const file = ledgerFile();
    const budget = new EvalBudget(file, 0.35, noon('2026-11-27'));
    budget.reserve(0.2, 'coach batch');
    expect(budget.spentToday()).toBeCloseTo(0.2, 9);
    budget.settle(0.2, 0.12, 125, 'coach batch');
    expect(budget.spentToday()).toBeCloseTo(0.12, 9);
    // An audit trail, never a rewritten total.
    expect(readFileSync(file, 'utf8').trim().split('\n')).toHaveLength(2);
  });

  it('fails closed on a ledger it cannot read', () => {
    const file = ledgerFile();
    appendFileSync(file, 'not json\n');
    const budget = new EvalBudget(file, 0.35, noon('2026-11-27'));
    expect(() => budget.spentToday()).toThrow(/ledger/i);
  });
});

describe('budgetLimit', () => {
  it('is the default when nothing is said', () => {
    expect(budgetLimit([], {})).toBe(DEFAULT_BUDGET_USD);
  });

  it('is raised only by saying so: --budget, or EVAL_BUDGET_USD', () => {
    expect(budgetLimit(['--budget', '0.6'], {})).toBe(0.6);
    expect(budgetLimit([], {EVAL_BUDGET_USD: '1.25'})).toBe(1.25);
    expect(budgetLimit(['--budget', '0.6'], {EVAL_BUDGET_USD: '1.25'})).toBe(0.6);
  });

  it('refuses a limit that is not a positive number', () => {
    expect(() => budgetLimit(['--budget', 'lots'], {})).toThrow(/budget/i);
    expect(() => budgetLimit(['--budget', '0'], {})).toThrow(/budget/i);
    expect(() => budgetLimit(['--budget'], {})).toThrow(/budget/i);
  });
});
