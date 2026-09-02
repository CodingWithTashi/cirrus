import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/core/utils/lp_review.dart';

/// Where "Rate Cirrus" goes, decided without a plugin in the loop.
///
/// The Sep 1 field test tapped the button on a sideloaded build and nothing
/// happened: Play's in-app review is silent for any install that did not
/// come from Play, and the availability check cannot tell (docs/09 issue 3).
/// The route is now decided by the installer the OS reports, and these cases
/// pin that decision so the silent button cannot come back.
void main() {
  group('LpReview.routeFor', () {
    test('no sheet possible means no control, on every platform', () {
      for (final platform in TargetPlatform.values) {
        expect(
          LpReview.routeFor(
            platform: platform,
            sheetAvailable: false,
            installerStore: LpReview.playStore,
          ),
          ReviewRoute.none,
          reason: platform.name,
        );
      }
    });

    test('a Play install gets the real sheet', () {
      expect(
        LpReview.routeFor(
          platform: TargetPlatform.android,
          sheetAvailable: true,
          installerStore: LpReview.playStore,
        ),
        ReviewRoute.sheet,
      );
    });

    test('any other Android install opens the listing instead', () {
      // adb reports nothing; the system installer, a browser download and a
      // third-party store each report themselves. None of them can show
      // Play's sheet, and all of them can open Play.
      for (final installer in [
        null,
        '',
        'com.google.android.packageinstaller',
        'com.android.packageinstaller',
        'com.sec.android.app.samsungapps',
      ]) {
        expect(
          LpReview.routeFor(
            platform: TargetPlatform.android,
            sheetAvailable: true,
            installerStore: installer,
          ),
          ReviewRoute.listing,
          reason: 'installer: $installer',
        );
      }
    });

    test('iOS and macOS show their sheet whatever installed the app', () {
      // StoreKit prompts in development builds too, so there is nothing to
      // fall back from — and no listing id to fall back to yet.
      for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
        for (final installer in [null, 'com.apple', 'com.apple.testflight']) {
          expect(
            LpReview.routeFor(
              platform: platform,
              sheetAvailable: true,
              installerStore: installer,
            ),
            ReviewRoute.sheet,
            reason: '${platform.name} / $installer',
          );
        }
      }
    });
  });
}
