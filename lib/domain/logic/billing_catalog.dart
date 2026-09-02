/// The identifiers the RevenueCat dashboard, Google Play Console and App Store
/// Connect were configured with (docs/08, "RevenueCat naming sheet"). They are
/// permanent on both stores — a product id can never be reused, even after
/// deletion — so this file changes by addition only.
///
/// Mirrors `functions/src/domain/plans.ts` name-for-name; the parity is pinned
/// by `test/domain/billing_catalog_test.dart` and `functions/test/plans.test.ts`
/// with the same fixtures. If a product is added on the stores, it lands in
/// both files and both tests, or the server files the purchase under the
/// wrong plan while the app shows the right one.
library;

import '../models/billing.dart';

abstract final class BillingCatalog {
  /// The single RevenueCat entitlement every plan unlocks. The dashboard's
  /// identifier (created Aug 30 2026); the user-facing word is "Premium".
  static const String entitlementId = 'cirrus_pro';

  /// The offering the paywall reads. Always the dashboard's *current* one, so
  /// an A/B variant can be swapped in without a release.
  static const String offeringId = 'default';

  /// RevenueCat's reserved package ids, one per period.
  static const String annualPackage = r'$rc_annual';
  static const String monthlyPackage = r'$rc_monthly';
  static const String weeklyPackage = r'$rc_weekly';

  /// Play models one *subscription* with a base plan per duration; the App
  /// Store models one *product* per duration inside a group. RevenueCat reports
  /// the Play shape as `subscription:basePlan`.
  static const String playSubscriptionId = 'cirrus_premium';

  /// The last path segment of every store product id on sale, by period.
  /// App Store ids use underscores; Play base-plan ids may only use hyphens.
  ///
  /// `yearly-399` is the yearly base plan's id AS CREATED in Play Console
  /// (Sep 2 2026) — base-plan ids cannot be changed once activated, so the
  /// catalogue carries the id that exists rather than the one the sheet
  /// intended. Both spellings are kept so a later corrected plan maps too.
  static const Map<String, PlanPeriod> _periodBySku = {
    'yearly_3999': PlanPeriod.yearly,
    'monthly_799': PlanPeriod.monthly,
    'weekly_299': PlanPeriod.weekly,
    'yearly-399': PlanPeriod.yearly,
    'yearly-3999': PlanPeriod.yearly,
    'monthly-799': PlanPeriod.monthly,
    'weekly-299': PlanPeriod.weekly,
    // RevenueCat's Test Store products (debug builds only, see
    // `BillingOptions.usesTestStore`), so a simulated purchase still names
    // its plan everywhere a real one does.
    'yearly': PlanPeriod.yearly,
    'monthly': PlanPeriod.monthly,
    'weekly': PlanPeriod.weekly,
  };

  /// Docs/02 §4's $3.99 founding month. Off until the store offer exists and
  /// is tagged so it cannot leak into the main paywall (tracker S4-7).
  static const bool foundingOfferEnabled = false;

  static String packageOf(PlanPeriod period) => switch (period) {
    PlanPeriod.yearly => annualPackage,
    PlanPeriod.monthly => monthlyPackage,
    PlanPeriod.weekly => weeklyPackage,
  };

  /// The inverse of [packageOf]; null for a package this build does not sell.
  static PlanPeriod? periodOfPackage(String packageId) => switch (packageId) {
    annualPackage => PlanPeriod.yearly,
    monthlyPackage => PlanPeriod.monthly,
    weeklyPackage => PlanPeriod.weekly,
    _ => null,
  };

  /// The plan a store product id belongs to, or null for anything not in the
  /// catalogue — a promotional grant, a future product this build predates.
  ///
  /// Accepts every shape the backends produce: `yearly_3999`,
  /// `cirrus_premium:yearly-3999`, and a bare base-plan id `yearly-3999`
  /// (the Android SDK reports product and base plan as separate fields).
  static PlanPeriod? periodOf(String? productId) {
    if (productId == null || productId.isEmpty) return null;
    final sku = productId.substring(productId.lastIndexOf(':') + 1);
    return _periodBySku[sku];
  }
}
