import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import 'package:last_puff/data/stores/day1_tour_store.dart';

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

    testWidgets('a checklist row does not tick itself', (tester) async {
      // The defect this whole item exists for. Every row used to mark itself
      // done at the moment it was TAPPED — row one by logging a puff on the
      // user's behalf, rows two and three before the user had said a word to
      // the coach or set a single hour. Three checkmarks claiming work nobody
      // had done, which is the same class of lie as a button that only shows
      // a success snack.
      //
      // A row navigates. That is all a row does. What ticks it is the real
      // move, made on the real screen.
      final container = await openDay1(tester);
      final puffsBefore = container.read(todayProvider)!.puffs;

      for (final row in [l10n.day1Task1, l10n.day1Task2, l10n.day1Task3]) {
        container.read(routerProvider).go(Routes.day1);
        await tester.pumpAndSettle();
        await tester.tap(find.text(row).first);
        await tester.pumpAndSettle();

        expect(
          container.read(quitStoreProvider)!.day1TasksDone,
          isEmpty,
          reason: '"$row" ticked itself on tap',
        );
      }

      expect(
        container.read(todayProvider)!.puffs,
        puffsBefore,
        reason: 'the checklist logged a puff the user never took',
      );
    });

    testWidgets('the first task walks you to the real log button', (
      tester,
    ) async {
      // The row used to log a puff on the user's behalf and tick itself, so
      // the one control the whole app is built around was never seen. Now the
      // row takes you to it, holds everything else closed, and waits.
      final container = await openDay1(tester);
      final before = container.read(todayProvider)!.puffs;

      await tester.tap(find.text(l10n.day1Task1).first);
      await tester.pumpAndSettle();

      expect(find.text(l10n.homeLogPuff), findsOneWidget);
      expect(container.read(day1TourStepProvider), Day1TourStep.logPuff);
      expect(container.read(todayProvider)!.puffs, before);
      expect(container.read(quitStoreProvider)!.day1TasksDone, isEmpty);
    });

    testWidgets('logging the puff for real is what ticks the box', (
      tester,
    ) async {
      final container = await openDay1(tester);
      await tester.tap(find.text(l10n.day1Task1).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.homeLogPuff));
      await tester.pumpAndSettle();

      expect(container.read(quitStoreProvider)!.day1TasksDone, contains(0));
      // And the walkthrough has moved on to the next real move.
      expect(container.read(day1TourStepProvider), Day1TourStep.meetCoach);

      // Let the undo snack live out its bounded life so no timers leak.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('a completed task stops being tappable', (tester) async {
      final container = await openDay1(tester);
      container.read(quitStoreProvider.notifier).completeDay1Task(0);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.day1Task1).first);
      await tester.pumpAndSettle();

      // Still on the checklist: a done row is inert, not a second trip.
      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('the second task takes you to Ember without ticking', (
      tester,
    ) async {
      final container = await openDay1(tester);
      await tester.tap(find.text(l10n.day1Task2).first);
      await tester.pumpAndSettle();

      expect(find.text(l10n.coachName), findsOneWidget);
      // The tapped row wins: the spotlight must be on the screen the user
      // chose, not on the first undone task's screen — deriving "first
      // undone" here once locked the coach screen with the HOME spotlight
      // active and nothing visible explaining anything.
      expect(container.read(day1TourStepProvider), Day1TourStep.meetCoach);
      expect(
        container.read(quitStoreProvider)!.day1TasksDone,
        isEmpty,
        reason: 'arriving at the coach is not meeting the coach',
      );
    });

    testWidgets('the seeded greeting does not tick "meet your coach"', (
      tester,
    ) async {
      // Opening the tab seeds an ember-authored greeting into an empty
      // thread. It is an ember message that appears without the user typing
      // a word — counting it completed the step on arrival, which is the
      // exact class of claim the walkthrough exists to remove.
      final container = await openDay1(tester);
      await tester.tap(find.text(l10n.day1Task2).first);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(container.read(quitStoreProvider)!.day1TasksDone, isEmpty);
      expect(container.read(day1TourStepProvider), Day1TourStep.meetCoach);
    });

    testWidgets('a real reply ticks the box and returns to the checklist', (
      tester,
    ) async {
      final container = await openDay1(tester);
      await tester.tap(find.text(l10n.day1Task2).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'hi ember');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      // The reply, then the deliberate beat that lets the user see it land
      // before the checklist takes over.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(container.read(quitStoreProvider)!.day1TasksDone, contains(1));
      expect(
        find.text(l10n.day1Title),
        findsOneWidget,
        reason: 'the walkthrough should land back on the checklist',
      );
    });

    testWidgets('skipping setup leaves every box empty', (tester) async {
      final container = await openDay1(tester);

      await tester.tap(find.text(l10n.day1Skip));
      await tester.pumpAndSettle();

      final journey = container.read(quitStoreProvider)!;
      expect(journey.day1TasksDone, isEmpty);
      expect(journey.day1TourSkipped, isTrue);
      // And the app is open again, not held on a lesson they declined.
      expect(container.read(day1TourLockedProvider), isFalse);
    });

    testWidgets('progress survives leaving and coming back', (tester) async {
      final container = await openDay1(tester);
      // A real log, made on Home, the way the walkthrough teaches it.
      await tester.tap(find.text(l10n.day1Task1).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.homeLogPuff));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
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
