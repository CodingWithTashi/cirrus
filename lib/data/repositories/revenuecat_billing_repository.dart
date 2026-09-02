import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../domain/logic/billing_catalog.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../billing_options.dart';

/// [BillingRepository] over RevenueCat — **the only file in the app that
/// imports `purchases_flutter`**, the way `AmplitudeAnalytics` is the only one
/// importing Amplitude. Everything above it speaks the domain's billing
/// types, so a vendor change is one new class behind `billingRepositoryProvider`.
///
/// Two rules this class exists to enforce:
///
/// 1. A purchase is "completed" only when the returned customer record
///    carries the active `premium` entitlement. A sheet that closed without
///    an error but without the entitlement is [PurchasePending], never a
///    success — Play's deferred payment methods and Apple's Ask to Buy both
///    produce exactly that shape.
/// 2. The client's tier is whatever RevenueCat last said, no more. The server
///    keeps its own mirror and trusts nothing the app reports, so a wrong
///    value here mis-renders a screen and buys nothing.
class RevenueCatBillingRepository implements BillingRepository {
  RevenueCatBillingRepository() {
    if (_configured) {
      // Replays the last received customer record immediately when the SDK
      // has one, so a returning subscriber is Premium on the first frame.
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
    }
  }

  static bool _configured = false;

  /// True once [configure] succeeded. Read by nothing but this class and its
  /// own diagnostics; the app asks the repository, never the SDK.
  static bool get isConfigured => _configured;

  /// One-time SDK setup, called from `main()` inside the Firebase-mode block
  /// after App Check. Never throws and never blocks launch: a billing SDK
  /// that cannot start leaves a paywall that shows fixed prices and answers
  /// every purchase with "store unavailable", which is the honest state.
  ///
  /// No `appUserID` here on purpose: at cold start Firebase Auth may not have
  /// rehydrated the session, and `identify` binds the uid the moment a
  /// session is established anyway.
  static Future<void> configure() async {
    final key = BillingOptions.apiKeyFor(defaultTargetPlatform);
    if (key.isEmpty) {
      debugPrint(
        'billing: NO REVENUECAT KEY for ${defaultTargetPlatform.name}. The '
        'paywall will show fixed prices and every purchase will answer '
        '"store unavailable". Fill lib/data/billing_options.dart.',
      );
      return;
    }
    try {
      if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(key));
      _configured = true;
    } on Object catch (error) {
      debugPrint('billing: RevenueCat configure failed — $error');
    }
  }

  final StreamController<Entitlement> _changes =
      StreamController<Entitlement>.broadcast();
  Entitlement? _cached;

  @override
  Entitlement? get cached => _cached;

  @override
  Stream<Entitlement> changes() async* {
    final known = _cached;
    if (known != null) yield known;
    yield* _changes.stream;
  }

  @override
  Future<BillingOffering?> offerings() async {
    if (!_configured) return null;
    try {
      final current = await _currentOffering();
      if (current == null) return null;
      final plans = <BillingPlan>[];
      for (final package in current.availablePackages) {
        final period = _periodOf(package);
        if (period == null) continue;
        final product = package.storeProduct;
        plans.add(
          BillingPlan(
            id: package.identifier,
            period: period,
            productId: product.identifier,
            price: product.priceString,
            priceAmount: product.price,
            currencyCode: product.currencyCode,
            pricePerWeek: product.pricePerWeekString,
            trialDays: _trialDays(product),
          ),
        );
      }
      return plans.isEmpty ? null : BillingOffering(plans: plans);
    } on PlatformException catch (error) {
      debugPrint(
        'billing: offerings unavailable — '
        '${PurchasesErrorHelper.getErrorCode(error).name}',
      );
      return null;
    }
  }

  @override
  Future<Entitlement> identify(String? uid) async {
    // Unconfigured (no key for this platform yet, or `configure` threw) is
    // "the store is unavailable", never "known free": a settled free answer
    // is what shows a paying user the launch paywall.
    if (!_configured) throw const StoreUnavailableException();
    try {
      final info = uid == null
          ? await Purchases.getCustomerInfo()
          : (await Purchases.logIn(uid)).customerInfo;
      return _publish(info);
    } on PlatformException catch (error) {
      throw _wireFailure(error);
    }
  }

  @override
  Future<void> reset() async {
    // Forget first: a sign-in that lands while `logOut` is still on the wire
    // must not be overwritten by this call's completion.
    _set(const Entitlement.none());
    if (!_configured) return;
    try {
      await Purchases.logOut();
    } on PlatformException {
      // Already anonymous (`logOutWithAnonymousUserError`) or offline — either
      // way there is nothing bound to this phone any more.
    }
  }

  @override
  Future<PurchaseOutcome> purchase(String planId) async {
    if (!_configured) throw const StoreUnavailableException();
    final Package package;
    try {
      final found = await _findPackage(planId);
      if (found == null) throw const StoreUnavailableException();
      package = found;
    } on PlatformException catch (error) {
      throw _wireFailure(error);
    }
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      final entitlement = _publish(result.customerInfo);
      return entitlement.isActive
          ? PurchaseCompleted(entitlement)
          : const PurchasePending();
    } on PlatformException catch (error) {
      switch (PurchasesErrorHelper.getErrorCode(error)) {
        case PurchasesErrorCode.purchaseCancelledError:
          return const PurchaseCancelled();
        case PurchasesErrorCode.paymentPendingError:
          return const PurchasePending();
        case PurchasesErrorCode.productAlreadyPurchasedError:
          // The store says this account already owns it: the answer is a
          // restore, not a second charge.
          final restored = await restore();
          if (restored.isActive) return PurchaseCompleted(restored);
          throw const StoreUnavailableException();
        default:
          throw _wireFailure(error);
      }
    }
  }

  @override
  Future<Entitlement> restore() async {
    if (!_configured) throw const StoreUnavailableException();
    try {
      return _publish(await Purchases.restorePurchases());
    } on PlatformException catch (error) {
      throw _wireFailure(error);
    }
  }

  // ---- SDK → domain ---------------------------------------------------------

  void _onCustomerInfo(CustomerInfo info) => _publish(info);

  Entitlement _publish(CustomerInfo info) {
    final entitlement = _toEntitlement(info);
    _set(entitlement);
    return entitlement;
  }

  void _set(Entitlement entitlement) {
    if (entitlement == _cached) return;
    _cached = entitlement;
    _changes.add(entitlement);
  }

  static Entitlement _toEntitlement(CustomerInfo info) {
    final e = info.entitlements.active[BillingCatalog.entitlementId];
    if (e == null || !e.isActive) return const Entitlement.none();
    // Play reports the base plan separately; the catalogue and the server
    // both key on `subscription:basePlan`.
    final basePlan = e.productPlanIdentifier;
    final productId = basePlan == null || basePlan.isEmpty
        ? e.productIdentifier
        : '${e.productIdentifier}:$basePlan';
    final management = info.managementURL;
    final expires = e.expirationDate;
    return Entitlement(
      tier: e.periodType == PeriodType.trial
          ? SubscriptionTier.trial
          : SubscriptionTier.premium,
      productId: productId,
      period: BillingCatalog.periodOf(productId),
      expiresAt: expires == null ? null : DateTime.tryParse(expires)?.toLocal(),
      willRenew: e.willRenew,
      store: switch (e.store) {
        Store.appStore || Store.macAppStore => BillingStore.appStore,
        Store.playStore => BillingStore.playStore,
        Store.promotional => BillingStore.promotional,
        _ => BillingStore.other,
      },
      managementUrl: management == null ? null : Uri.tryParse(management),
      isSandbox: e.isSandbox,
    );
  }

  static Future<Offering?> _currentOffering() async {
    final offerings = await Purchases.getOfferings();
    return offerings.current ?? offerings.all[BillingCatalog.offeringId];
  }

  static Future<Package?> _findPackage(String planId) async {
    final current = await _currentOffering();
    if (current == null) return null;
    for (final package in current.availablePackages) {
      if (package.identifier == planId) return package;
    }
    return null;
  }

  /// The package's period: RevenueCat's reserved package type first, then
  /// the catalogue's reading of the store product id.
  static PlanPeriod? _periodOf(Package package) => switch (package.packageType) {
    PackageType.annual => PlanPeriod.yearly,
    PackageType.monthly => PlanPeriod.monthly,
    PackageType.weekly => PlanPeriod.weekly,
    _ => BillingCatalog.periodOf(package.storeProduct.identifier),
  };

  /// Free-trial length the store offers THIS user for the product, or null.
  /// Apple exposes it as an introductory price of zero; Play as the free
  /// phase of the default subscription option. Either way it is store data,
  /// never a constant — the length is dashboard config and an A/B lever.
  static int? _trialDays(StoreProduct product) {
    final intro = product.introductoryPrice;
    if (intro != null && intro.price == 0) {
      return _days(intro.periodUnit, intro.periodNumberOfUnits);
    }
    final free = product.defaultOption?.freePhase?.billingPeriod;
    if (free != null) return _days(free.unit, free.value);
    return null;
  }

  static int? _days(PeriodUnit unit, int count) => switch (unit) {
    PeriodUnit.day => count,
    PeriodUnit.week => count * 7,
    PeriodUnit.month => count * 30,
    PeriodUnit.year => count * 365,
    PeriodUnit.unknown => null,
  };

  /// Every SDK failure that is not a purchase-flow outcome, mapped onto the
  /// domain taxonomy so `lpErrorCopy` can say the right thing.
  static Exception _wireFailure(PlatformException error) {
    final code = PurchasesErrorHelper.getErrorCode(error);
    debugPrint('billing: ${code.name} — ${error.message}');
    return switch (code) {
      PurchasesErrorCode.networkError ||
      PurchasesErrorCode.offlineConnectionError => const NoConnectionException(),
      PurchasesErrorCode.purchaseNotAllowedError ||
      PurchasesErrorCode.insufficientPermissionsError =>
        const PurchaseNotAllowedException(),
      PurchasesErrorCode.receiptAlreadyInUseError ||
      PurchasesErrorCode.receiptInUseByOtherSubscriberError =>
        const ReceiptOwnedElsewhereException(),
      _ => const StoreUnavailableException(),
    };
  }
}
