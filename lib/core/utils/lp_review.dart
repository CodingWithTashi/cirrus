import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Where a tap on "Rate Cirrus" goes.
enum ReviewRoute {
  /// The OS review sheet — Play In-App Review, or StoreKit's.
  sheet,

  /// The app's own store listing, opened in the store app.
  listing,

  /// Nothing would visibly happen, so the CTA must not be offered.
  none,
}

/// The native store review sheet, wrapped the way [LpHaptics] wraps haptics:
/// one place, never throws, and honest about what it cannot know.
///
/// ## Three things about this API that shape every caller
///
/// **Play's sheet is silent for any install that did not come from Play.**
/// `isAvailable()` only answers "is the Play Store on this phone", which is
/// yes on every phone — and then `requestReview()` on a sideloaded build (every
/// `./tool/device.ps1` install, every internal APK) shows nothing at all. That
/// was the Sep 1 field test's "Rate Cirrus does nothing" (docs/09 issue 3): a
/// live button, silent by design of the Play API. So the route is decided by
/// how the app was installed, which the OS does report ([PackageInfo.installerStore]):
/// a Play install gets the sheet, anything else opens the listing instead —
/// an action the user can see happen. The listing is the app's own package
/// name, so there is no URL to remember to replace once the store page exists.
///
/// **Neither platform reports whether the sheet appeared, or what the user
/// did with it.** Play's In-App Review has an undocumented per-user quota and
/// simply shows nothing when it is spent; iOS caps at three prompts a year.
/// So nothing downstream may render a "Thanks for rating!" or log a
/// `rating_completed` — a control that only shows a success snack is worse
/// than a missing one, and here we would not even know if we were lying.
///
/// **Review gating is prohibited.** Apple Guideline 1.1.7 forbids asking for a
/// rating ahead of the system prompt or routing by sentiment, and Google Play
/// forbids asking the user's opinion at all before presenting the rating card
/// — including a star picker that routes every value identically. So there is
/// no way to pass a rating into this, and there must not be.
abstract final class LpReview {
  /// The installer id Play stamps on everything it installs.
  static const String playStore = 'com.android.vending';

  /// The decision on its own, so it can be pinned without a plugin in the
  /// loop. [sheetAvailable] is the platform's own answer (Play Store present
  /// and Android 5+, or iOS 10.3+); [installerStore] is what the OS says
  /// installed the app, null when it does not know (adb, most sideloads).
  ///
  /// Only Android distinguishes the two routes: StoreKit shows its sheet in
  /// development builds too, so there is nothing to fall back from there.
  static ReviewRoute routeFor({
    required TargetPlatform platform,
    required bool sheetAvailable,
    required String? installerStore,
  }) {
    if (!sheetAvailable) return ReviewRoute.none;
    if (platform != TargetPlatform.android) return ReviewRoute.sheet;
    return installerStore == playStore ? ReviewRoute.sheet : ReviewRoute.listing;
  }

  /// Where a tap would go on this device, right now.
  ///
  /// [ReviewRoute.none] on desktop, in `flutter test`, and on a phone without
  /// the Play Store — so the CTA can be hidden rather than shipped as a button
  /// that does nothing.
  static Future<ReviewRoute> route() async {
    final bool sheetAvailable;
    try {
      sheetAvailable = await InAppReview.instance.isAvailable();
    } on Object {
      // A missing plugin is not worth failing a funnel step over.
      return ReviewRoute.none;
    }
    if (!sheetAvailable) return ReviewRoute.none;
    String? installer;
    try {
      installer = (await PackageInfo.fromPlatform()).installerStore;
    } on Object {
      // Unknown installer reads as "not Play", which is the safe direction:
      // the listing always opens, the sheet only sometimes does.
      installer = null;
    }
    return routeFor(
      platform: defaultTargetPlatform,
      sheetAvailable: true,
      installerStore: installer,
    );
  }

  /// Whether the CTA has somewhere to go.
  static Future<bool> isAvailable() async =>
      await route() != ReviewRoute.none;

  /// Does the one thing this device can do: asks the OS for its sheet, or
  /// opens the listing. Silence from the sheet is a normal outcome.
  static Future<void> request() async {
    try {
      switch (await route()) {
        case ReviewRoute.sheet:
          await InAppReview.instance.requestReview();
        case ReviewRoute.listing:
          await InAppReview.instance.openStoreListing();
        case ReviewRoute.none:
          break;
      }
    } on Object {
      // Nothing to tell the user: we could not have confirmed success either.
    }
  }
}
