import '../../domain/logic/billing_catalog.dart';
import '../../domain/models/models.dart';
import 'codec_helpers.dart';

/// JSON ↔ [Entitlement].
///
/// One shape for both backends: the fake's stored row and the server-owned
/// mirror `users/{uid}.entitlement` written by the RevenueCat webhook (field
/// names match `functions/src/lib/firestore.ts` `Entitlement`). Dates travel
/// as ISO-8601 strings; the Firestore reader normalizes its `Timestamp`s to
/// that before calling [decode], the way `planAdvice` already does.
abstract final class EntitlementCodec {
  static Map<String, dynamic> encode(Entitlement e) => {
    'tier': e.tier.name,
    'productId': e.productId,
    'plan': e.period?.name,
    'expiresAt': e.expiresAt?.toUtc().toIso8601String(),
    'willRenew': e.willRenew,
    'store': e.store?.name,
    'managementUrl': e.managementUrl?.toString(),
    'isSandbox': e.isSandbox,
  };

  /// Tolerant on purpose: an unknown tier is `free`, an unknown plan is
  /// re-derived from the product id, and a missing field is its default.
  /// A mirror written by a newer server must never crash an older app.
  static Entitlement decode(Map<String, dynamic> json) {
    final productId = json['productId'] as String?;
    final expires = json['expiresAt'];
    final url = json['managementUrl'] as String?;
    return Entitlement(
      tier: enumByName(
        SubscriptionTier.values,
        json['tier'],
        SubscriptionTier.free,
      ),
      productId: productId,
      period:
          enumByNameOrNull(PlanPeriod.values, json['plan']) ??
          BillingCatalog.periodOf(productId),
      expiresAt: expires is String
          ? DateTime.tryParse(expires)?.toLocal()
          : null,
      willRenew: json['willRenew'] == true,
      store: enumByNameOrNull(BillingStore.values, json['store']),
      managementUrl: url == null ? null : Uri.tryParse(url),
      isSandbox: json['isSandbox'] == true,
    );
  }
}
