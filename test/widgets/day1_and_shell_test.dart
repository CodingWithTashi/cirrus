import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// `Day1Screen` and `AppShell` — the two features with no coverage of any
/// kind, not even the layout sweep.
///
/// They are an odd pair to have missed, because between them they carry the
/// first five minutes of the product: the shell is every navigation the user
/// makes, and Day 1 is the checklist that decides whether they ever reach a
/// second session. Both are driven here through the real router, since the
/// interesting behaviour in both is navigation.
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
    // Past the splash, into a seeded session.
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    return container;
  }

  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('Day 1 checklist', () {
    Future<ProviderContainer> openDay1(WidgetTester tester) async {
      final container = await pumpApp(tester);
      // The seeded demo journey is day 12 with all three tasks already done,
      // which is the right fixture for every other screen and the wrong one
      // for this: clear them so the checklist starts where a real day 1 does.
      final store = container.read(quitStoreProvider.notifier);
      store.replaceForTest(
        container.read(quitStoreProvider)!.copyWith(day1TasksDone: const {}),
      );
      container.read(routerProvider).go(Routes.day1);
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('opens with nothing done and all three moves offered', (
      tester,
    ) async {
      final container = await openDay1(tester);

      expect(find.text(l10n.day1Title), findsOneWidget);
      expect(find.text('0/3'), findsOneWidget);
      // `findsWidgets`, not `findsOneWidget`: the bottom CTA always names the
      // next unchecked task, so the first title legitimately renders twice.
      expect(find.text(l10n.day1Task1), findsWidgets);
      expect(find.text(l10n.day1Task2), findsWidgets);
      expect(find.text(l10n.day1Task3), findsWidgets);
      expect(container.read(quitStoreProvider)!.day1TasksDone, isEmpty);
    });

    testWidgets('the first task logs a real puff, not just a checkmark', (
      tester,
    ) async {
      // The whole point of task one is that the user has logged something —
      // ticking it without a log would leave the taper with no baseline and
      // the streak engine with nothing to anchor to.
      final container = await openDay1(tester);
      final before = container.read(todayProvider)!.puffs;

      await tester.tap(find.text(l10n.day1Task1).first);
      await tester.pumpAndSettle();

      expect(container.read(quitStoreProvider)!.day1TasksDone, contains(0));
      expect(container.read(todayProvider)!.puffs, before + 1);
      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('a completed task stops being tappable', (tester) async {
      // Tapping task one twice would log a second puff the user never took.
      final container = await openDay1(tester);
      await tester.tap(find.text(l10n.day1Task1).first);
      await tester.pumpAndSettle();
      final after = container.read(todayProvider)!.puffs;

      await tester.tap(find.text(l10n.day1Task1).first);
      await tester.pumpAndSettle();

      expect(container.read(todayProvider)!.puffs, after);
      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('the second task takes you to Ember', (tester) async {
      final container = await openDay1(tester);
      await tester.tap(find.text(l10n.day1Task2).first);
      await tester.pumpAndSettle();

      expect(container.read(quitStoreProvider)!.day1TasksDone, contains(1));
      expect(find.text(l10n.coachName), findsOneWidget);
    });

    testWidgets('progress survives leaving and coming back', (tester) async {
      final container = await openDay1(tester);
      await tester.tap(find.text(l10n.day1Task1).first);
      await tester.pumpAndSettle();

      container.read(routerProvider).go(Routes.home);
      await tester.pumpAndSettle();
      container.read(routerProvider).go(Routes.day1);
      await tester.pumpAndSettle();

      expect(find.text('1/3'), findsOneWidget);
    });
  });

  group('the tab shell', () {
    testWidgets('lands on Home with all four tabs', (tester) async {
      await pumpApp(tester);
      for (final label in [
        l10n.navHome,
        l10n.navStats,
        l10n.navCommunity,
        l10n.navCoach,
      ]) {
        expect(find.text(label), findsWidgets, reason: 'missing tab $label');
      }
    });

    testWidgets('each tab opens its own screen', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text(l10n.navStats).last);
      await tester.pumpAndSettle();
      expect(find.text(l10n.statsTitle), findsWidgets);

      await tester.tap(find.text(l10n.navCoach).last);
      await tester.pumpAndSettle();
      expect(find.text(l10n.coachName), findsOneWidget);
    });

    testWidgets('the centre button logs a puff from anywhere', (tester) async {
      // One tap from every tab is the core habit loop; making the user open
      // Home first would put a navigation in front of the only action the
      // whole product depends on being frictionless.
      final container = await pumpApp(tester);
      await tester.tap(find.text(l10n.navStats).last);
      await tester.pumpAndSettle();

      final before = container.read(todayProvider)!.puffs;
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(container.read(todayProvider)!.puffs, before + 1);

      // Logging raises the undo snack, whose force-close fallback timer
      // outlives the test otherwise — `showLpSnack` sets it deliberately
      // (the framework skips its own timeout for action snacks under
      // accessible navigation).
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('that log can be undone from the snack', (tester) async {
      final container = await pumpApp(tester);
      final before = container.read(todayProvider)!.puffs;

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(container.read(todayProvider)!.puffs, before + 1);

      await tester.tap(find.text(l10n.commonUndo));
      await tester.pumpAndSettle();
      expect(container.read(todayProvider)!.puffs, before);

      // Let the snack's force-close fallback timer expire.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('switching away and back keeps each tab where it was', (
      tester,
    ) async {
      final container = await pumpApp(tester);

      await tester.tap(find.text(l10n.navCoach).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.navHome).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.navCoach).last);
      await tester.pumpAndSettle();

      expect(find.text(l10n.coachName), findsOneWidget);
      expect(container.read(routerProvider), isNotNull);
    });
  });
}
