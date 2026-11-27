/**
 * What an eval call costs, pinned to the price list as it was read on
 * Nov 27 2026. The eval budget is only as honest as this table: a rate that
 * is half the real one lets a run spend twice its cap.
 */
import {describe, expect, it} from 'vitest';
import {
  BATCH_FACTOR,
  UnknownPriceError,
  costUsd,
  estimateTokens,
  rateFor,
} from '../tools/evalCost';

const NOV_2026 = new Date('2026-11-27T12:00:00Z');
const JAN_2027 = new Date('2027-01-01T12:00:00Z');

describe('the price list', () => {
  it('prices the free model at $0.30 in and $2.50 out per million tokens', () => {
    expect(rateFor('gemini-3.5-flash-lite', NOV_2026)).toMatchObject({
      inputPerM: 0.3,
      outputPerM: 2.5,
    });
  });

  it('prices the premium model at $0.75 in and $3.75 out until the end of 2026', () => {
    expect(rateFor('gemini-3.6-flash', NOV_2026)).toMatchObject({
      inputPerM: 0.75,
      outputPerM: 3.75,
    });
  });

  it('doubles the premium model on Jan 1 2027, as the price list announces', () => {
    expect(rateFor('gemini-3.6-flash', JAN_2027)).toMatchObject({
      inputPerM: 1.5,
      outputPerM: 7.5,
    });
  });

  it('refuses a model it has no price for, rather than guessing', () => {
    expect(() => rateFor('gemini-9-ultra', NOV_2026)).toThrow(UnknownPriceError);
  });
});

describe('costUsd', () => {
  it('is input plus output at the list rate', () => {
    // One premium coach reply: 2,000 in, 100 out.
    const usd = costUsd({
      model: 'gemini-3.6-flash',
      inputTokens: 2000,
      outputTokens: 100,
      batch: false,
      at: NOV_2026,
    });
    expect(usd).toBeCloseTo(0.0015 + 0.000375, 9);
  });

  it('is half that through the batch API', () => {
    expect(BATCH_FACTOR).toBe(0.5);
    const args = {
      model: 'gemini-3.5-flash-lite',
      inputTokens: 10_000,
      outputTokens: 1_000,
      at: NOV_2026,
    };
    expect(costUsd({...args, batch: true})).toBeCloseTo(
      costUsd({...args, batch: false}) / 2,
      12,
    );
  });
});

describe('estimateTokens', () => {
  it('never guesses lower than four characters a token', () => {
    const text = 'x'.repeat(4000);
    expect(estimateTokens(text)).toBeGreaterThanOrEqual(1000);
  });

  it('is zero for nothing and grows with the text', () => {
    expect(estimateTokens('')).toBe(0);
    expect(estimateTokens('a'.repeat(700))).toBeGreaterThan(estimateTokens('a'.repeat(70)));
  });
});
