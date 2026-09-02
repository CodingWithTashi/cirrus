/**
 * The identifiers the RevenueCat dashboard, Google Play Console and App Store
 * Connect were configured with (docs/08, "RevenueCat naming sheet"). Mirrors
 * `lib/domain/logic/billing_catalog.dart` name-for-name; parity pinned by
 * `test/plans.test.ts` and `test/domain/billing_catalog_test.dart` with the
 * same fixtures. A product added on the stores lands in both files and both
 * tests, or the server files the purchase under the wrong plan while the app
 * shows the right one.
 */

/**
 * The single RevenueCat entitlement every plan unlocks — the dashboard's
 * identifier (created Aug 30 2026); the user-facing word is "Premium".
 */
export const ENTITLEMENT_ID = 'cirrus_pro';

export const PLAN_PERIODS = ['yearly', 'monthly', 'weekly'] as const;
export type PlanPeriod = (typeof PLAN_PERIODS)[number];

/**
 * Play models one subscription with a base plan per duration; RevenueCat
 * reports it as `subscription:basePlan`.
 */
export const PLAY_SUBSCRIPTION_ID = 'cirrus_premium';

/**
 * The last path segment of every store product id on sale, by period. App
 * Store ids use underscores; Play base-plan ids may only use hyphens.
 */
const PERIOD_BY_SKU: Readonly<Record<string, PlanPeriod>> = {
  yearly_3999: 'yearly',
  monthly_799: 'monthly',
  weekly_299: 'weekly',
  // `yearly-399` is the yearly base plan's id AS CREATED in Play Console
  // (Sep 2 2026); base-plan ids cannot change once activated.
  'yearly-399': 'yearly',
  'yearly-3999': 'yearly',
  'monthly-799': 'monthly',
  'weekly-299': 'weekly',
  // RevenueCat's Test Store products (debug builds only).
  yearly: 'yearly',
  monthly: 'monthly',
  weekly: 'weekly',
};

/**
 * The plan a store product id belongs to, or null for anything not in the
 * catalogue — a promotional grant, a future product this deploy predates.
 * Accepts `yearly_3999`, `cirrus_premium:yearly-3999` and a bare `yearly-3999`.
 */
export function periodOf(productId: string | null | undefined): PlanPeriod | null {
  if (!productId) return null;
  const sku = productId.slice(productId.lastIndexOf(':') + 1);
  return PERIOD_BY_SKU[sku] ?? null;
}
