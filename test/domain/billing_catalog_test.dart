/// Parity suite with `functions/test/plans.test.ts` — same fixtures, same
/// answers. The server files a purchase under the plan this table says; the
/// app shows the plan its own copy says. They must agree.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/billing_catalog.dart';
import 'package:last_puff/domain/models/billing.dart';

void main() {
  group('BillingCatalog.periodOf', () {
    test('App Store product ids', () {
      expect(BillingCatalog.periodOf('yearly_3999'), PlanPeriod.yearly);
      expect(BillingCatalog.periodOf('monthly_799'), PlanPeriod.monthly);
      expect(BillingCatalog.periodOf('weekly_299'), PlanPeriod.weekly);
    });

    test('Play subscription:basePlan ids as RevenueCat reports them', () {
      // The yearly base plan exists in Play Console as `yearly-399`.
      expect(
        BillingCatalog.periodOf('cirrus_premium:yearly-399'),
        PlanPeriod.yearly,
      );
      expect(
        BillingCatalog.periodOf('cirrus_premium:yearly-3999'),
        PlanPeriod.yearly,
      );
      expect(
        BillingCatalog.periodOf('cirrus_premium:monthly-799'),
        PlanPeriod.monthly,
      );
      expect(
        BillingCatalog.periodOf('cirrus_premium:weekly-299'),
        PlanPeriod.weekly,
      );
    });

    test('a bare Play base-plan id, as the Android SDK reports it', () {
      expect(BillingCatalog.periodOf('weekly-299'), PlanPeriod.weekly);
    });

    test("RevenueCat's Test Store products (debug builds)", () {
      expect(BillingCatalog.periodOf('yearly'), PlanPeriod.yearly);
      expect(BillingCatalog.periodOf('monthly'), PlanPeriod.monthly);
    });

    test('anything outside the catalogue is null, never a guess', () {
      expect(BillingCatalog.periodOf(null), isNull);
      expect(BillingCatalog.periodOf(''), isNull);
      expect(BillingCatalog.periodOf('cirrus_premium'), isNull);
      expect(BillingCatalog.periodOf('rc_promo'), isNull);
      expect(BillingCatalog.periodOf('weekly_399'), isNull);
    });
  });

  test('the dashboard identifiers are the ones on the naming sheet', () {
    expect(BillingCatalog.entitlementId, 'cirrus_pro');
    expect(BillingCatalog.offeringId, 'default');
    expect(BillingCatalog.playSubscriptionId, 'cirrus_premium');
    expect(BillingCatalog.packageOf(PlanPeriod.yearly), r'$rc_annual');
    expect(BillingCatalog.packageOf(PlanPeriod.monthly), r'$rc_monthly');
    expect(BillingCatalog.packageOf(PlanPeriod.weekly), r'$rc_weekly');
    for (final period in PlanPeriod.values) {
      expect(
        BillingCatalog.periodOfPackage(BillingCatalog.packageOf(period)),
        period,
      );
    }
    expect(BillingCatalog.periodOfPackage(r'$rc_lifetime'), isNull);
  });

  test('the founding offer stays off until its store offer exists', () {
    expect(BillingCatalog.foundingOfferEnabled, isFalse);
  });
}
