/// The billing seam on the fake backend: what the paywall, Settings and the
/// premium gates can rely on without a store. The RevenueCat implementation
/// is exercised on a device; this is everything around it.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/fake/fake_server.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/billing_catalog.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
import 'package:last_puff/data/api/fake/fake_fixtures.dart';
import 'package:last_puff/data/network/connectivity.dart';

import '../helpers.dart';

void main() {
  late RecordingAnalytics analytics;

  ProviderContainer make({bool online = true}) {
    analytics = RecordingAnalytics();
    final container = ProviderContainer(
      // A fresh install: no subscription row anywhere until one is bought.
      overrides: fastBackendOverrides(
        online: online,
        analytics: analytics,
        premium: false,
      ),
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Zero-latency acks still land on the microtask queue.
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('a fresh account', () {
    test('is free, and the offering carries the three locked plans', () async {
      final c = make();
      expect(c.read(entitlementProvider).isActive, isFalse);
      expect(c.read(isPremiumProvider), isFalse);

      final offering = await c.read(billingRepositoryProvider).offerings();
      expect(offering, isNotNull);
      expect(
        offering!.plans.map((p) => p.period),
        [PlanPeriod.yearly, PlanPeriod.monthly, PlanPeriod.weekly],
      );
      expect(offering[PlanPeriod.yearly]!.price, r'$39.99');
      expect(offering[PlanPeriod.monthly]!.price, r'$7.99');
      expect(offering[PlanPeriod.weekly]!.price, r'$2.99');
      expect(offering[PlanPeriod.yearly]!.trialDays, 7);
    });

    test('starts a trial on its first purchase, and the gate flips', () async {
      final c = make();
      final outcome = await c
          .read(entitlementProvider.notifier)
          .purchase(BillingCatalog.annualPackage);

      expect(outcome, isA<PurchaseCompleted>());
      final e = c.read(entitlementProvider);
      expect(e.tier, SubscriptionTier.trial);
      expect(e.period, PlanPeriod.yearly);
      expect(e.willRenew, isTrue);
      expect(c.read(isPremiumProvider), isTrue);
      expect(analytics.propsOf('purchase_completed'), {
        'plan': 'yearly',
        'trial': 'true',
      });
    });
  });

  group('the sheet', () {
    test('cancelled: nothing changes and nothing is claimed', () async {
      final c = make();
      c.read(fakeServerProvider).nextPurchase = FakePurchaseScript.cancelled;
      final outcome = await c
          .read(entitlementProvider.notifier)
          .purchase(BillingCatalog.monthlyPackage);

      expect(outcome, isA<PurchaseCancelled>());
      expect(c.read(entitlementProvider).isActive, isFalse);
      expect(analytics.propsOf('purchase_cancelled'), {'plan': 'monthly'});
      expect(analytics.names, isNot(contains('purchase_completed')));
      // The script is consumed: the next sheet completes.
      expect(
        c.read(fakeServerProvider).nextPurchase,
        FakePurchaseScript.completed,
      );
    });

    test('pending: the store has not settled, so we do not claim it', () async {
      final c = make();
      c.read(fakeServerProvider).nextPurchase = FakePurchaseScript.pending;
      final outcome = await c
          .read(entitlementProvider.notifier)
          .purchase(BillingCatalog.weeklyPackage);
      expect(outcome, isA<PurchasePending>());
      expect(c.read(entitlementProvider).isActive, isFalse);
    });

    test('refused by the device: the taxonomy names it', () async {
      final c = make();
      c.read(fakeServerProvider).nextPurchase = FakePurchaseScript.notAllowed;
      await expectLater(
        c.read(entitlementProvider.notifier).purchase(BillingCatalog.weeklyPackage),
        throwsA(isA<PurchaseNotAllowedException>()),
      );
      expect(c.read(entitlementProvider).isActive, isFalse);
      expect(analytics.propsOf('purchase_failed'), {'code': 'not_allowed'});
    });

    test('offline: NoConnectionException, nothing applied', () async {
      final c = make(online: false);
      await expectLater(
        c.read(entitlementProvider.notifier).purchase(BillingCatalog.annualPackage),
        throwsA(isA<NoConnectionException>()),
      );
      expect(c.read(entitlementProvider).isActive, isFalse);
      expect(analytics.propsOf('purchase_failed'), {'code': 'offline'});
    });

    test('never opens for an account that is already active', () async {
      final c = make();
      final store = c.read(entitlementProvider.notifier);
      await store.purchase(BillingCatalog.annualPackage);
      final before = c.read(entitlementProvider);

      // Were the sheet opened, this script would throw.
      c.read(fakeServerProvider).nextPurchase = FakePurchaseScript.notAllowed;
      final again = await store.purchase(BillingCatalog.weeklyPackage);
      expect(again, isA<PurchaseCompleted>());
      expect(c.read(entitlementProvider), before);
      expect(
        c.read(fakeServerProvider).nextPurchase,
        FakePurchaseScript.notAllowed,
        reason: 'the script was never consumed — no sheet was opened',
      );
    });
  });

  group('restore', () {
    test('finds nothing on an empty account, and says so', () async {
      final c = make();
      final e = await c.read(entitlementProvider.notifier).restore();
      expect(e.isActive, isFalse);
      expect(analytics.propsOf('restore_completed'), {'found': 'false'});
    });

    test('brings a purchase back after the identity was unbound', () async {
      final c = make();
      final store = c.read(entitlementProvider.notifier);
      await store.purchase(BillingCatalog.monthlyPackage);
      await store.unbind();
      expect(c.read(entitlementProvider).isActive, isFalse);

      final e = await store.restore();
      expect(e.isActive, isTrue);
      expect(e.period, PlanPeriod.monthly);
      expect(c.read(isPremiumProvider), isTrue);
      expect(analytics.propsOf('restore_completed'), {'found': 'true'});
    });
  });

  group('one phone, two people', () {
    test('a slow sign-out cannot wipe the next sign-in', () async {
      // A's `logOut` is still on the wire when B signs in and binds premium.
      // When A's reset finally completes it must not overwrite B.
      final billing = _ScriptedBilling();
      final c = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(premium: false),
          billingRepositoryProvider.overrideWithValue(billing),
        ],
      );
      addTearDown(c.dispose);
      final store = c.read(entitlementProvider.notifier);

      billing.answers['A'] = _premium;
      await store.bindSession('A');
      expect(c.read(isPremiumProvider), isTrue);

      billing.resetGate = Completer<void>();
      final signOut = store.unbind();
      // The phone forgot synchronously, before the SDK answered.
      expect(c.read(isPremiumProvider), isFalse);

      // B's bind waits for A's log-out to finish rather than racing it.
      billing.answers['B'] = _premium;
      final bind = store.bindSession('B');
      await settle();
      expect(c.read(isPremiumProvider), isFalse, reason: 'still logging A out');

      billing.resetGate!.complete();
      await signOut;
      await bind;
      await settle();
      expect(c.read(isPremiumProvider), isTrue, reason: 'B survived the reset');
    });

    test('a bind that outlives its session is discarded', () async {
      // A's identify is still in flight when the phone signs out; its answer
      // must not land as the signed-out phone's tier.
      final billing = _ScriptedBilling();
      final c = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(premium: false),
          billingRepositoryProvider.overrideWithValue(billing),
        ],
      );
      addTearDown(c.dispose);
      final store = c.read(entitlementProvider.notifier);

      billing.answers['A'] = _premium;
      billing.identifyGate = Completer<void>();
      final bind = store.bindSession('A');
      await store.unbind();
      billing.identifyGate!.complete();
      await bind;
      await settle();
      expect(c.read(isPremiumProvider), isFalse);
      expect(store.isSettled, isFalse);
    });

    test('a bind that failed offline is retried when the network returns', () async {
      final c = make(online: false);
      final store = c.read(entitlementProvider.notifier);
      c.read(fakeServerProvider).putEntitlement(
        FakeServer.demoEntitlementJson(DateTime.now()),
      );
      await store.bindSession('guest');
      await settle();
      expect(store.isSettled, isFalse, reason: 'offline is not known-free');
      expect(c.read(isPremiumProvider), isFalse);

      c.read(connectivityProvider.notifier as dynamic).set(true);
      await settle();
      expect(store.isSettled, isTrue);
      expect(c.read(isPremiumProvider), isTrue);
    });

    test('a purchase never announces itself as a remote change', () async {
      final c = make();
      await c.read(entitlementProvider.notifier).purchase(
        BillingCatalog.annualPackage,
      );
      await settle();
      expect(analytics.names, contains('purchase_completed'));
      expect(analytics.names, isNot(contains('entitlement_changed')));
    });

    test('an account that onboarded free stays free on its next sign-in', () async {
      // Only the seeded demo journey comes with the demo subscription; an
      // account that already has a journey and no row gets nothing minted.
      final c = make();
      final server = c.read(fakeServerProvider);
      server.register('free@x.test', 'secret1');
      server.putJourney(FakeFixtures.journeyJson(DateTime.now()));
      server.signOut();
      server.signIn('free@x.test');
      expect(server.entitlementForSession(), isNull);
    });
  });

  group('sessions', () {
    test('the demo account signs in premium · yearly', () async {
      final c = make();
      await c
          .read(quitStoreProvider.notifier)
          .logIn(email: FakeServer.demoEmail, password: 'secret1');
      await settle();

      final e = c.read(entitlementProvider);
      expect(e.tier, SubscriptionTier.premium);
      expect(e.period, PlanPeriod.yearly);
      expect(e.willRenew, isTrue);
    });

    test('signing out unbinds, so the next person starts free', () async {
      final c = make();
      final journeys = c.read(quitStoreProvider.notifier);
      await journeys.logIn(email: FakeServer.demoEmail, password: 'secret1');
      await settle();
      expect(c.read(isPremiumProvider), isTrue);

      journeys.signOut();
      await settle();
      expect(c.read(isPremiumProvider), isFalse);
      expect(c.read(entitlementProvider), const Entitlement.none());
    });

    test('a lapsed account that buys again pays from day one', () async {
      final c = make();
      final server = c.read(fakeServerProvider);
      final store = c.read(entitlementProvider.notifier);
      await store.purchase(BillingCatalog.weeklyPackage);
      expect(c.read(entitlementProvider).tier, SubscriptionTier.trial);

      // The store expired it (a webhook would, in production).
      server.putEntitlement({'tier': 'free', 'productId': 'weekly_299'});
      await store.restore();
      expect(c.read(entitlementProvider).isActive, isFalse);

      await store.purchase(BillingCatalog.weeklyPackage);
      expect(c.read(entitlementProvider).tier, SubscriptionTier.premium);
    });
  });
}

final _premium = Entitlement(
  tier: SubscriptionTier.premium,
  productId: 'yearly_3999',
  period: PlanPeriod.yearly,
  expiresAt: DateTime.now().add(const Duration(days: 300)),
  willRenew: true,
);

/// A billing backend whose identify and reset can be held open, so the
/// store's ordering under a sign-out → sign-in on one phone is assertable.
class _ScriptedBilling implements BillingRepository {
  final Map<String, Entitlement> answers = {};
  Completer<void>? identifyGate;
  Completer<void>? resetGate;
  final _changes = StreamController<Entitlement>.broadcast();

  @override
  Future<BillingOffering?> offerings() async => null;

  @override
  Entitlement? get cached => null;

  @override
  Stream<Entitlement> changes() => _changes.stream;

  @override
  Future<Entitlement> identify(String? uid) async {
    final gate = identifyGate;
    if (gate != null) await gate.future;
    return answers[uid] ?? const Entitlement.none();
  }

  @override
  Future<void> reset() async {
    final gate = resetGate;
    if (gate != null) await gate.future;
    _changes.add(const Entitlement.none());
  }

  @override
  Future<PurchaseOutcome> purchase(String planId) async =>
      const PurchaseCancelled();

  @override
  Future<Entitlement> restore() async => const Entitlement.none();
}
