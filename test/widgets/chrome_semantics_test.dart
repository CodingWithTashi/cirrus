import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/widgets/lp_misc.dart';
import 'package:last_puff/data/network/connectivity.dart';
import 'package:last_puff/data/stores/providers.dart';

import '../helpers.dart';

/// Chrome that a screen reader must be able to name.
///
/// Found on Sep 8 2026 by reading the app's accessibility tree from outside
/// (Maestro on the iPhone simulator, `.maestro/README.md`): the back chevron
/// on every pushed screen, the composer FAB and every post's `…` menu were
/// bare icons — present for a sighted thumb and absent for VoiceOver. The
/// last one matters most: Report, Mute and Block live behind it, and those
/// are the controls App Store 1.2 asks for on user content. The coach's send
/// arrow joined the list the same evening. The offline pill
/// had the opposite problem: hidden by a slide, it stayed readable on every
/// screen while online.
void main() {
  /// `flutter test` substitutes a square-glyph fallback font; overflow here
  /// says nothing about the device (see `screen_layout_test`).
  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    bool online = true,
  }) async {
    ignoreFontWidthOverflow();
    final container = ProviderContainer(
      overrides: fastBackendOverrides(online: online),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(seconds: 2)); // splash beat
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('the back chevron is a labelled button', (tester) async {
    // Disposed at the end of the body, not in a tearDown: flutter_test checks
    // for live handles BEFORE tearDowns run.
    final handle = tester.ensureSemantics();
    final container = await pumpApp(tester);
    container.read(routerProvider).go(Routes.settings);
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byType(BackChevron)),
      matchesSemantics(label: 'Back', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('the composer FAB and every post menu are labelled buttons', (
    tester,
  ) async {
    // Disposed at the end of the body, not in a tearDown: flutter_test checks
    // for live handles BEFORE tearDowns run.
    final handle = tester.ensureSemantics();
    final container = await pumpApp(tester);
    container.read(routerProvider).go(Routes.community);
    await tester.pumpAndSettle();

    final fab = find.bySemanticsLabel('New post');
    expect(fab, findsOneWidget);
    expect(
      tester.getSemantics(fab),
      matchesSemantics(label: 'New post', isButton: true, hasTapAction: true),
    );

    // One per post that is not mine; the seeded feed has several.
    final menus = find.bySemanticsLabel('Post options');
    expect(menus, findsWidgets);
    expect(
      tester.getSemantics(menus.first),
      matchesSemantics(
        label: 'Post options',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('the coach send button is a labelled button', (tester) async {
    final handle = tester.ensureSemantics();
    final container = await pumpApp(tester);
    container.read(routerProvider).go(Routes.coach);
    await tester.pumpAndSettle();

    final send = find.bySemanticsLabel('Send');
    expect(send, findsOneWidget);
    expect(
      tester.getSemantics(send),
      matchesSemantics(label: 'Send', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('the offline pill is readable only while it shows', (
    tester,
  ) async {
    // Disposed at the end of the body, not in a tearDown: flutter_test checks
    // for live handles BEFORE tearDowns run.
    final handle = tester.ensureSemantics();
    final container = await pumpApp(tester, online: false);
    final pill = find.bySemanticsLabel(RegExp('^offline —'));
    expect(pill, findsOneWidget);

    (container.read(connectivityProvider.notifier) as ToggleConnectivity).set(
      true,
    );
    await tester.pumpAndSettle();
    expect(pill, findsNothing);
    handle.dispose();
  });
}
