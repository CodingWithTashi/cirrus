/// Billing entities — what a store subscription looks like once the billing
/// backend (RevenueCat in production, `FakeServer` everywhere else) has told
/// us about it. Pure Dart, no vendor types: `purchases_flutter` is imported by
/// exactly one file in `lib/data`, and everything above that speaks these.
library;

import 'enums.dart';

/// The three durations on sale (docs/01 §11). Order is the paywall's order.
enum PlanPeriod { yearly, monthly, weekly }

/// Where the entitlement was bought. `promotional` is a RevenueCat grant with
/// no store behind it — the beta cohort's free lifetime, a support credit.
enum BillingStore { appStore, playStore, promotional, other }

/// One purchasable plan from the current offering, priced by the store in the
/// user's own currency.
final class BillingPlan {
  const BillingPlan({
    required this.id,
    required this.period,
    required this.productId,
    required this.price,
    required this.priceAmount,
    required this.currencyCode,
    this.pricePerWeek,
    this.trialDays,
  });

  /// RevenueCat package id (`$rc_annual`, …) — what [BillingRepository.purchase]
  /// takes. Stable across stores, unlike [productId].
  final String id;
  final PlanPeriod period;

  /// The store's product id: `yearly_3999` on the App Store,
  /// `cirrus_premium:yearly-3999` on Play. Diagnostic; never shown.
  final String productId;

  /// The store-formatted price ("$39.99", "39,99 €"). **The only price a card
  /// may show** — the store sheet charges exactly this, in this currency.
  final String price;
  final double priceAmount;
  final String currencyCode;

  /// The store-formatted per-week price when the store supplies one
  /// (RevenueCat does for every period). Null → compute from [priceAmount].
  final String? pricePerWeek;

  /// Free-trial length offered to THIS user, or null when the store offers
  /// none (already used an intro offer, or the offer is not configured).
  /// Copy must never assume a number: the length is store config and the
  /// A/B roadmap changes it.
  final int? trialDays;
}

/// The plans on sale right now. Empty is a legitimate answer (nothing
/// configured yet); null from the repository means "could not load".
final class BillingOffering {
  const BillingOffering({required this.plans});

  final List<BillingPlan> plans;

  bool get isEmpty => plans.isEmpty;

  BillingPlan? operator [](PlanPeriod period) {
    for (final plan in plans) {
      if (plan.period == period) return plan;
    }
    return null;
  }
}

/// What this account is entitled to, as last reported by the billing backend.
///
/// The client's view only. The server keeps its own mirror in
/// `users/{uid}.entitlement`, written by the RevenueCat webhook, and trusts
/// nothing the app says about tier — so a wrong value here can mis-render a
/// screen but can never buy anything.
final class Entitlement {
  const Entitlement({
    required this.tier,
    this.productId,
    this.period,
    this.expiresAt,
    this.willRenew = false,
    this.store,
    this.managementUrl,
    this.isSandbox = false,
  });

  /// Nothing active. The state before any backend has answered, after
  /// sign-out, and for every account that never bought.
  const Entitlement.none() : this(tier: SubscriptionTier.free);

  final SubscriptionTier tier;
  final String? productId;
  final PlanPeriod? period;

  /// When access ends unless renewed. Null for `free`, for lifetime grants,
  /// and when the store did not say.
  final DateTime? expiresAt;

  /// False once the user cancelled (access continues to [expiresAt]) or a
  /// billing retry is running. Drives "Premium · ends {date}" in Settings.
  final bool willRenew;
  final BillingStore? store;

  /// The store's own "manage subscription" page for this purchase. Null when
  /// the store did not provide one (a family-shared or promotional grant).
  final Uri? managementUrl;
  final bool isSandbox;

  bool get isActive => tier != SubscriptionTier.free;
  bool get isTrial => tier == SubscriptionTier.trial;

  @override
  bool operator ==(Object other) =>
      other is Entitlement &&
      other.tier == tier &&
      other.productId == productId &&
      other.period == period &&
      other.expiresAt == expiresAt &&
      other.willRenew == willRenew &&
      other.store == store &&
      other.managementUrl == managementUrl &&
      other.isSandbox == isSandbox;

  @override
  int get hashCode => Object.hash(
    tier,
    productId,
    period,
    expiresAt,
    willRenew,
    store,
    managementUrl,
    isSandbox,
  );

  @override
  String toString() =>
      'Entitlement(${tier.name}, $productId, ends $expiresAt, '
      'renews $willRenew)';
}

/// How a purchase attempt ended. Failures are exceptions ([BillingException],
/// [NoConnectionException]); these are the non-failure endings, each of which
/// the paywall handles differently and none of which is "success" until the
/// entitlement is actually active.
sealed class PurchaseOutcome {
  const PurchaseOutcome();
}

/// The store took the payment AND the entitlement is active. Constructed only
/// from a customer record that carries the active entitlement — never from
/// "the sheet closed without an error".
final class PurchaseCompleted extends PurchaseOutcome {
  const PurchaseCompleted(this.entitlement);

  final Entitlement entitlement;
}

/// The user dismissed the store sheet. Not a failure: the screen stays put,
/// nothing is said.
final class PurchaseCancelled extends PurchaseOutcome {
  const PurchaseCancelled();
}

/// The store accepted the order but has not settled it (Play's deferred
/// payment methods, Apple's Ask to Buy). Access arrives later through
/// [BillingRepository.changes]; the screen must not claim it now.
final class PurchasePending extends PurchaseOutcome {
  const PurchasePending();
}
