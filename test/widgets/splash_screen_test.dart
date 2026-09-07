import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/features/auth/splash_screen.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// Frame 25: the mark, the wordmark and the tagline, stacked and centred on
/// the screen.
///
/// The geometry is asserted because it was wrong once without any test
/// noticing: the splash was a `Stack(alignment: center)` straight in the
/// Scaffold body. The body hands its child LOOSE constraints, and a Stack
/// under loose constraints sizes itself to its largest non-positioned child —
/// so the whole group lived in a 340dp square in the top-left corner, centred
/// only within that square. Every other assertion in the suite is about what
/// the splash shows and where it routes, none about where it draws.
void main() {
  testWidgets('mark, wordmark and tagline are stacked on the screen centre', (
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

    final mark = find.descendant(
      of: splash,
      matching: find.byKey(SplashScreen.markKey),
    );
    final name = find.descendant(of: splash, matching: find.text(l10n.appName));
    final tagline = find.descendant(
      of: splash,
      matching: find.text(l10n.appTagline),
    );
    expect(mark, findsOneWidget);
    expect(name, findsOneWidget);
    expect(tagline, findsOneWidget);

    final screen = tester.getSize(splash);
    for (final part in [mark, name, tagline]) {
      expect(
        tester.getCenter(part).dx,
        moreOrLessEquals(screen.width / 2, epsilon: 1),
        reason: 'horizontally centred',
      );
    }
    // Mark above name above tagline, none overlapping.
    expect(
      tester.getBottomLeft(mark).dy,
      lessThanOrEqualTo(tester.getTopLeft(name).dy),
    );
    expect(
      tester.getBottomLeft(name).dy,
      lessThanOrEqualTo(tester.getTopLeft(tagline).dy),
    );
    // The group as a whole sits around the vertical middle, not in a corner.
    final groupMid =
        (tester.getTopLeft(mark).dy + tester.getBottomLeft(tagline).dy) / 2;
    expect(groupMid, closeTo(screen.height / 2, screen.height * 0.15));

    // Drain the auto-advance and the navigation it ends in.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(splash, findsNothing);
  });

  // The mark once disappeared OUTRIGHT on the frame it sealed — glow and all,
  // with every earlier frame correct — because Skia's `addArc` takes
  // `sweep mod 360` unless the start angle is near a multiple of 90°, so a
  // sweep of exactly one turn appends an empty path. A sealed ring therefore
  // stops a thousandth of a turn short; the round caps cover the rest.
  test('the mark seals without ever asking for a full turn', () {
    expect(cirrusMarkArc(1).sweepTurns, lessThan(1.0));
    expect(cirrusMarkArc(1).sweepTurns, greaterThan(0.99));
    for (final seal in [0.0, 0.25, 0.5, 0.6, 0.75, 0.9, 1.0]) {
      expect(cirrusMarkArc(seal).sweepTurns, lessThan(1.0), reason: '@$seal');
    }
  });

  // Open at 0.84 of the circumference with the gap at 3 o'clock is what makes
  // it read as a C rather than as a ring somebody forgot to finish, and the
  // two tips must advance by EQUAL amounts or one end visibly chases the
  // other around the ring instead of the gap closing on itself.
  test('the C opens at the design sweep and closes from both tips', () {
    final open = cirrusMarkArc(0);
    expect(open.sweepTurns, closeTo(0.84, 1e-9));
    expect(open.startTurns, closeTo(0.049, 1e-9));
    for (final seal in [0.5, 0.7, 0.9, 1.0]) {
      final arc = cirrusMarkArc(seal);
      expect(
        open.startTurns - arc.startTurns,
        closeTo((arc.sweepTurns - open.sweepTurns) / 2, 1e-9),
        reason: 'each tip advances half the growth @$seal',
      );
    }
  });
}
