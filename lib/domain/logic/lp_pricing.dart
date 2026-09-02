/// The founder-locked launch prices (docs/01 §11, docs/08 §1) — the ONE place
/// a price literal exists in the app.
///
/// On a device these are the fallback the paywall shows when the store's own
/// offering cannot be loaded; the store-formatted price on the offering is
/// what every card renders otherwise, and what the sheet charges. On the fake
/// backend they ARE the store. USD by design: store SDKs own currency
/// localization.
abstract final class LpPricing {
  static const String yearly = r'$39.99';
  static const String monthly = r'$7.99';
  static const String weekly = r'$2.99';
  static const String foundingMonth = r'$3.99';

  static const double yearlyUsd = 39.99;

  /// Numeric monthly price for localized sentences (the win-back note).
  static const double monthlyUsd = 7.99;
  static const double weeklyUsd = 2.99;

  /// Free-trial length on every plan (7 days since Sep 1 2026, docs/08 §7
  /// #14). The fake store's value; on a device the offering carries the
  /// store's own, which is what the paywall must say.
  static const int trialDays = 7;
}
