import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/features/auth/auth_screens.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The sign-in screen on a screen the keyboard has taken most of.
///
/// It is mounted UNDER the register and log-in forms, so when one of them
/// opens the keyboard the sign-in screen underneath is laid out in what is
/// left. On an iPhone 16e that is 422 points, and its bare `Column` needed 99
/// more — a `RenderFlex overflowed` that fails every device suite at the first
/// sign-in (the first iOS run of `p_safety_and_date`, Nov 13 2026), and clips
/// the screen for real on a short phone or at a large text size. The three
/// forms beside it already scroll under a minimum height (`_AuthScrollView`);
/// this screen was the one that did not.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// Layout errors seen so far in this test. Widget tests run on a fixed-width
  /// fallback font, so a few sub-pixel HORIZONTAL overflows (the footer links)
  /// appear here that the real font does not have; the bug under test is the
  /// vertical one, so only that is judged.
  final errors = <String>[];

  bool overflowedAtTheBottom() => errors.any(
    (e) => e.contains('overflowed by') && e.contains('on the bottom'),
  );

  Future<void> pumpSignIn(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(container.dispose);
    // The screen alone, as `screen_layout_test` mounts it: the app's own
    // harness (`parkOnSignIn`) settles a signed-out app, which is not what is
    // under test and was what made this suite hang.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SignInScreen(),
        ),
      ),
    );
    // Bounded, never `pumpAndSettle`.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Both Apple's and Google's buttons are on screen on some platform, so the
  /// tallest layout is the Apple one. Layout errors are collected for the
  /// duration, and BOTH overrides are undone here, inside the test body: the
  /// binding asserts they are back before the test ends, and a red test that
  /// restored them in a tear-down never finished at all.
  Future<void> onIOS(Future<void> Function() body) async {
    errors.clear();
    final prior = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exceptionAsString());
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
      FlutterError.onError = prior;
    }
  }

  testWidgets('does not overflow with the keyboard up (422 points left)',
      (tester) async {
    await onIOS(() async {
      await pumpSignIn(tester, const Size(390, 422));

      expect(overflowedAtTheBottom(), isFalse, reason: errors.join('\n'));
      expect(find.text(l10n.authSignInWithApple), findsOneWidget);
    });
  });

  testWidgets('can be scrolled to its footer when the screen is that short',
      (tester) async {
    await onIOS(() async {
      await pumpSignIn(tester, const Size(390, 422));

      // Everything is reachable, not clipped: the legal links at the bottom.
      await tester.scrollUntilVisible(
        find.text(l10n.authTerms),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.authTerms), findsOneWidget);
      expect(overflowedAtTheBottom(), isFalse, reason: errors.join('\n'));
    });
  });

  testWidgets('keeps the footer pinned to the bottom when there is room',
      (tester) async {
    await onIOS(() async {
      await pumpSignIn(tester, const Size(390, 844));

      expect(overflowedAtTheBottom(), isFalse, reason: errors.join('\n'));
      // The Spacer-pinned footer still sits low on a full-height screen: the
      // scroll wrapper must not have collapsed it up against the card.
      final terms = tester.getTopLeft(find.text(l10n.authTerms)).dy;
      expect(terms, greaterThan(844 * 0.7));
    });
  });
}
