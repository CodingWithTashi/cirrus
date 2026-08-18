/// Product pricing shown in the demo paywalls — the single source StoreKit /
/// Play Billing products replace later. Display strings are USD by design;
/// store SDKs take over currency localization in the billing phase.
abstract final class LpPricing {
  static const String yearly = r'$39.99';
  static const String monthly = r'$7.99';
  static const String weekly = r'$2.99';
  static const String foundingMonth = r'$3.99';

  /// Numeric monthly price for localized sentences (the win-back note).
  static const double monthlyUsd = 7.99;
}

/// Product links — never translated, never duplicated into ARB files.
abstract final class LpLinks {
  static String invite(String alias) =>
      'lastpuff.app/j/${alias.replaceAll('@', '')}';

  static String inviteUrl(String alias) => 'https://${invite(alias)}';
}
