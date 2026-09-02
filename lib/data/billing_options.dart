import 'package:flutter/foundation.dart';

/// Billing configuration, in source rather than behind a `--dart-define` —
/// the same reasoning as `analytics_options.dart`.
///
/// RevenueCat's *public* SDK keys are client keys by design: they can start a
/// purchase flow for THIS app's products and read nothing else, and they ship
/// inside the binary either way. A define instead would mean every release
/// build has to remember it, and one that forgot ships a paywall that cannot
/// sell. The secret key (`sk_…`) is a different thing entirely and lives only
/// in Secret Manager for `functions/`.
abstract final class BillingOptions {
  /// "Cirrus (Play Store)" in the RevenueCat project — `goog_…`.
  static const String revenueCatAndroidKey = 'goog_YbVeOXatLVCFndkdKhZrLLEEaWh';

  /// "Cirrus (App Store)" in the RevenueCat project — `appl_…`.
  static const String revenueCatAppleKey = '';

  /// RevenueCat's Test Store — a store RevenueCat simulates itself, with no
  /// Google or Apple behind it. Purchases made against it are sandbox events
  /// that flow through RevenueCat's backend, the webhook and the entitlement
  /// mirror exactly like real ones, which is how the server path is proven on
  /// a device before the store credentials are validated.
  static const String revenueCatTestStoreKey = 'test_ABVbbEgJTEYOnscNEQfbHIdibKb';

  /// `--dart-define=LP_BILLING_STORE=test` selects the Test Store. Honoured
  /// in debug builds only: a release build always talks to the real store,
  /// whatever the define says, so this cannot ship by accident.
  static const String _storeOverride = String.fromEnvironment('LP_BILLING_STORE');

  static bool get usesTestStore => kDebugMode && _storeOverride == 'test';

  static String apiKeyFor(TargetPlatform platform) {
    if (usesTestStore) return revenueCatTestStoreKey;
    return switch (platform) {
      TargetPlatform.android => revenueCatAndroidKey,
      TargetPlatform.iOS || TargetPlatform.macOS => revenueCatAppleKey,
      _ => '',
    };
  }
}
