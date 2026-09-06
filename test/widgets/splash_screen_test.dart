import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/features/auth/splash_screen.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// Frame 25: the launcher tile, the wordmark and the tagline, stacked and
/// centred on the screen.
///
/// The geometry is asserted because it was wrong once without any test
/// noticing: the splash was a `Stack(alignment: center)` straight in the
/// Scaffold body. The body hands its child LOOSE constraints, and a Stack
/// under loose constraints sizes itself to its largest non-positioned child —
/// so the whole group lived in a 340dp square in the top-left corner, centred
/// only within that square. Every other assertion in the suite is about what
/// the splash shows and where it routes, none about where it draws.
void main() {
  testWidgets('tile, wordmark and tagline are stacked on the screen centre', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: fastBackendOverrides(),
        child: const LastPuffApp(),
      ),
    );
    // Let the 400ms fade-up finish so the geometry is final, but stay well
    // under the 1.5s auto-advance.
    await tester.pump(const Duration(milliseconds: 500));

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final splash = find.byType(SplashScreen);
    expect(splash, findsOneWidget);

    final tile = find.descendant(
      of: splash,
      matching: find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == SplashScreen.iconAsset,
      ),
    );
    final name = find.descendant(of: splash, matching: find.text(l10n.appName));
    final tagline = find.descendant(
      of: splash,
      matching: find.text(l10n.appTagline),
    );
    expect(tile, findsOneWidget);
    expect(name, findsOneWidget);
    expect(tagline, findsOneWidget);

    final screen = tester.getSize(splash);
    for (final part in [tile, name, tagline]) {
      expect(
        tester.getCenter(part).dx,
        moreOrLessEquals(screen.width / 2, epsilon: 1),
        reason: 'horizontally centred',
      );
    }
    // Tile above name above tagline, none overlapping.
    expect(
      tester.getBottomLeft(tile).dy,
      lessThanOrEqualTo(tester.getTopLeft(name).dy),
    );
    expect(
      tester.getBottomLeft(name).dy,
      lessThanOrEqualTo(tester.getTopLeft(tagline).dy),
    );
    // The group as a whole sits around the vertical middle, not in a corner.
    final groupMid =
        (tester.getTopLeft(tile).dy + tester.getBottomLeft(tagline).dy) / 2;
    expect(groupMid, closeTo(screen.height / 2, screen.height * 0.15));

    // Drain the auto-advance and the navigation it ends in.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(splash, findsNothing);
  });
}
