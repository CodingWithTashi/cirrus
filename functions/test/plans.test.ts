/**
 * Parity suite with `test/domain/billing_catalog_test.dart` — same fixtures,
 * same answers. The server files a purchase under the plan this table says;
 * the app shows the plan its own copy says. They must agree.
 */
import {describe, expect, it} from 'vitest';
import {
  ENTITLEMENT_ID,
  PLAY_SUBSCRIPTION_ID,
  periodOf,
} from '../src/domain/plans';

describe('periodOf', () => {
  it('App Store product ids', () => {
    expect(periodOf('yearly_3999')).toBe('yearly');
    expect(periodOf('monthly_799')).toBe('monthly');
    expect(periodOf('weekly_299')).toBe('weekly');
  });

  it('Play subscription:basePlan ids as RevenueCat reports them', () => {
    // The yearly base plan exists in Play Console as `yearly-399`.
    expect(periodOf('cirrus_premium:yearly-399')).toBe('yearly');
    expect(periodOf('cirrus_premium:yearly-3999')).toBe('yearly');
    expect(periodOf('cirrus_premium:monthly-799')).toBe('monthly');
    expect(periodOf('cirrus_premium:weekly-299')).toBe('weekly');
  });

  it('a bare Play base-plan id', () => {
    expect(periodOf('weekly-299')).toBe('weekly');
  });

  it("RevenueCat's Test Store products (debug builds)", () => {
    expect(periodOf('yearly')).toBe('yearly');
    expect(periodOf('monthly')).toBe('monthly');
  });

  it('anything outside the catalogue is null, never a guess', () => {
    expect(periodOf(null)).toBeNull();
    expect(periodOf(undefined)).toBeNull();
    expect(periodOf('')).toBeNull();
    expect(periodOf('cirrus_premium')).toBeNull();
    expect(periodOf('rc_promo')).toBeNull();
    expect(periodOf('weekly_399')).toBeNull();
  });
});

it('the dashboard identifiers are the ones on the naming sheet', () => {
  expect(ENTITLEMENT_ID).toBe('cirrus_pro');
  expect(PLAY_SUBSCRIPTION_ID).toBe('cirrus_premium');
});
