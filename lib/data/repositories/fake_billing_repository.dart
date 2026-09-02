import 'dart:async';

import '../../domain/logic/billing_catalog.dart';
import '../../domain/logic/lp_pricing.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../api/fake/fake_server.dart';
import '../dto/entitlement_codec.dart';

/// [BillingRepository] over [FakeServer] — the demo backend's store.
///
/// Every mutation happens inside `respond()`, so it inherits the fake's
/// latency, its sync-apply invariant and its offline behaviour (airplane mode
/// → [NoConnectionException], nothing applied). The store sheet itself is
/// scripted through [FakeServer.nextPurchase], which is how a widget test
/// exercises a cancelled sheet or a deferred payment without a store.
///
/// A substantive fake rather than a `Noop*`: the paywall, Settings and the
/// premium gates all have to be walkable on desktop and in tests.
class FakeBillingRepository implements BillingRepository {
  FakeBillingRepository(this._server, {required DateTime Function() now})
    : _now = now;

  final FakeServer _server;
  final DateTime Function() _now;
  final StreamController<Entitlement> _changes =
      StreamController<Entitlement>.broadcast();
  Entitlement? _cached;

  /// The catalogue the store would serve, priced from the founder-locked
  /// figures. `pricePerWeek` is left null on purpose so the paywall's own
  /// derivation path runs here every day, not only on a device.
  static BillingOffering offering() => const BillingOffering(
    plans: [
      BillingPlan(
        id: BillingCatalog.annualPackage,
        period: PlanPeriod.yearly,
        productId: 'yearly_3999',
        price: LpPricing.yearly,
        priceAmount: LpPricing.yearlyUsd,
        currencyCode: 'USD',
        trialDays: LpPricing.trialDays,
      ),
      BillingPlan(
        id: BillingCatalog.monthlyPackage,
        period: PlanPeriod.monthly,
        productId: 'monthly_799',
        price: LpPricing.monthly,
        priceAmount: LpPricing.monthlyUsd,
        currencyCode: 'USD',
        trialDays: LpPricing.trialDays,
      ),
      BillingPlan(
        id: BillingCatalog.weeklyPackage,
        period: PlanPeriod.weekly,
        productId: 'weekly_299',
        price: LpPricing.weekly,
        priceAmount: LpPricing.weeklyUsd,
        currencyCode: 'USD',
        trialDays: LpPricing.trialDays,
      ),
    ],
  );

  @override
  Future<BillingOffering?> offerings() => _server.respond(
    () => BillingOffering(
      plans: [
        for (final plan in offering().plans)
          if (_server.offeringPeriods.contains(plan.period))
            BillingPlan(
              id: plan.id,
              period: plan.period,
              productId: plan.productId,
              price: plan.price,
              priceAmount: plan.priceAmount,
              currencyCode: plan.currencyCode,
              pricePerWeek: plan.pricePerWeek,
              trialDays: _server.offeringTrialDays,
            ),
      ],
    ),
  );

  @override
  Entitlement? get cached => _cached;

  @override
  Stream<Entitlement> changes() async* {
    final known = _cached;
    if (known != null) yield known;
    yield* _changes.stream;
  }

  @override
  Future<Entitlement> identify(String? uid) async {
    final e = await _server.respond(_read);
    _set(e);
    return e;
  }

  @override
  Future<void> reset() async => _set(const Entitlement.none());

  @override
  Future<PurchaseOutcome> purchase(String planId) async {
    BillingPlan? found;
    for (final candidate in offering().plans) {
      if (candidate.id == planId) found = candidate;
    }
    if (found == null) throw const StoreUnavailableException();
    final plan = found;
    final script = await _server.respond(() {
      final script = _server.nextPurchase;
      _server.nextPurchase = FakePurchaseScript.completed;
      if (script == FakePurchaseScript.completed) {
        // A trial only for an account that has never held a row: a lapsed
        // subscriber re-buying pays from day one, as the stores rule.
        final firstEver = _server.entitlementForSession() == null;
        final now = _now();
        _server.putEntitlement(
          EntitlementCodec.encode(
            Entitlement(
              tier: firstEver
                  ? SubscriptionTier.trial
                  : SubscriptionTier.premium,
              productId: plan.productId,
              period: plan.period,
              expiresAt: firstEver
                  ? now.add(Duration(days: plan.trialDays ?? 0))
                  : _renewalAfter(now, plan.period),
              willRenew: true,
              store: BillingStore.other,
              isSandbox: true,
            ),
          ),
        );
      }
      return script;
    });
    switch (script) {
      case FakePurchaseScript.completed:
        final e = _read();
        _set(e);
        return PurchaseCompleted(e);
      case FakePurchaseScript.cancelled:
        return const PurchaseCancelled();
      case FakePurchaseScript.pending:
        return const PurchasePending();
      case FakePurchaseScript.alreadyOwned:
        // What the real repository does with `productAlreadyPurchased`: the
        // store says it is owned, so the answer is a restore.
        final e = _read();
        if (!e.isActive) throw const StoreUnavailableException();
        _set(e);
        return PurchaseCompleted(e);
      case FakePurchaseScript.notAllowed:
        throw const PurchaseNotAllowedException();
    }
  }

  @override
  Future<Entitlement> restore() async {
    final e = await _server.respond(_read);
    _set(e);
    return e;
  }

  Entitlement _read() {
    final json = _server.entitlementForSession();
    return json == null ? const Entitlement.none() : EntitlementCodec.decode(json);
  }

  void _set(Entitlement e) {
    if (e == _cached) return;
    _cached = e;
    _changes.add(e);
  }

  static DateTime _renewalAfter(DateTime now, PlanPeriod period) =>
      switch (period) {
        PlanPeriod.yearly => DateTime(now.year + 1, now.month, now.day),
        PlanPeriod.monthly => DateTime(now.year, now.month + 1, now.day),
        PlanPeriod.weekly => now.add(const Duration(days: 7)),
      };
}
