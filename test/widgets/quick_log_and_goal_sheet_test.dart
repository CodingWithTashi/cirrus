import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/widgets/progress_ring.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/features/home/widgets/log_feedback.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// Two field-reported defects around the daily log, driven through the real
/// router:
///  1. The money goal sheet crashed the whole screen on back navigation —
///     its controllers were disposed in `whenComplete`, which fires while
///     the sheet is still animating out, so the next rebuild mid-exit threw
///     and cascaded into a full-screen `_dependents.isEmpty` crash.
///  2. The "Logged 1 puff" snack sat on top of the LOG PUFF button, so the
///     confirmation of a tap blocked the next tap for five seconds.
void main() {
  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    final container = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    return container;
  }

  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('money goal sheet', () {
    testWidgets('survives back during its own exit animation', (tester) async {
      final container = await pumpApp(tester);
      final router = container.read(routerProvider);

      unawaited(router.push(Routes.money));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.moneySetGoal));
      await tester.pumpAndSettle();

      // System back pops the sheet; a second back lands mid sheet-exit and
      // rebuilds the tree while the sheet's fields are still on screen —
      // the frame that used to find them wired to disposed controllers.
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.homeLogPuff), findsOneWidget);
    });

    testWidgets('creating a goal then leaving immediately is safe', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      final router = container.read(routerProvider);
      final goalsBefore = container.read(quitStoreProvider)!.goals.length;

      unawaited(router.push(Routes.money));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.moneySetGoal));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Bike');
      await tester.enterText(find.byType(TextField).last, '500');
      await tester.tap(find.text(l10n.moneyGoalCreate));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        container.read(quitStoreProvider)!.goals.length,
        goalsBefore + 1,
      );
    });
  });

  group('quick-log burst', () {
    testWidgets(
      'the snack never blocks the button and undo takes back the burst',
      (tester) async {
        final container = await pumpApp(tester);
        final before = container.read(todayProvider)!.puffs;

        // Taps two and three land while the previous tap's snack is up —
        // with the old bottom-edge snack they would hit the snack instead
        // of the button and log nothing.
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text(l10n.homeLogPuff));
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle();

        expect(container.read(todayProvider)!.puffs, before + 3);
        expect(find.text(l10n.homeLoggedSnackCount(3)), findsOneWidget);

        // One Undo reverses the whole burst, not just the last tap.
        await tester.tap(find.text(l10n.commonUndo));
        await tester.pumpAndSettle();
        expect(container.read(todayProvider)!.puffs, before);

        // Let the snack's force-close fallback timer expire.
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('holding LOG PUFF auto-repeats and snacks once on release', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      final before = container.read(todayProvider)!.puffs;

      final gesture = await tester.startGesture(
        tester.getCenter(find.text(l10n.homeLogPuff)),
      );
      // Past the long-press threshold: the first tick fires (+1)…
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
      // …then three more on the repeat clock (+1, +1, +2).
      await tester.pump(HoldToLog.interval * 3);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(container.read(todayProvider)!.puffs, before + 5);
      expect(find.text(l10n.homeLoggedSnackCount(5)), findsOneWidget);

      await tester.tap(find.text(l10n.commonUndo));
      await tester.pumpAndSettle();
      expect(container.read(todayProvider)!.puffs, before);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  });

  group('adjust today', () {
    testWidgets('the ring card opens the day editor and minus un-logs', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      // Guarantee something to take back, whatever the seed holds today.
      container.read(quitStoreProvider.notifier).logPuff(count: 2);
      await tester.pumpAndSettle();
      final before = container.read(todayProvider)!.puffs;

      await tester.tap(find.byType(ProgressRing));
      await tester.pumpAndSettle();
      expect(find.text(l10n.statsEditDayNote), findsOneWidget);

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      await tester.tap(find.text(l10n.commonSave));
      await tester.pumpAndSettle();

      expect(container.read(todayProvider)!.puffs, before - 2);
    });
  });
}
