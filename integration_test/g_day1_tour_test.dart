/// The Day-1 walkthrough, on a real device.
///
/// This suite exists because a widget test structurally cannot prove the thing
/// that matters here. The gate is made of four separate mechanisms — the
/// showcase barrier, an `IgnorePointer` over the rest of Home, `enabled: false`
/// on the shell's tabs, and a `PopScope` for the system back gesture — and
/// only a real tree with a real router and a real back gesture exercises all
/// four at once. Three of them look fine in isolation and let the user
/// straight past in combination.
///
///   flutter test integration_test/g_day1_tour_test.dart -d DEVICE_ID \
///     --dart-define=LP_BACKEND=fake
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/day1_tour_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// A seeded session rewound to a real day one: nothing done, nothing
  /// skipped, sitting on the checklist.
  Future<E2E> openDay1(WidgetTester tester) async {
    final e2e = await E2E.boot(tester);
    await e2e.waitFor(const Duration(seconds: 2));
    final store = e2e.container.read(quitStoreProvider.notifier)
      ..seedDemoJourney();
    store.replaceForTest(
      e2e.container
          .read(quitStoreProvider)!
          .copyWith(day1TasksDone: const {}, day1TourSkipped: false),
    );
    e2e.container.read(routerProvider).go(Routes.day1);
    await e2e.settle();
    return e2e;
  }

  testWidgets('step one holds Home closed until a puff is really logged', (
    tester,
  ) async {
    final e2e = await openDay1(tester);
    await e2e.tapText(e2e.l10n.day1Task1);
    await e2e.settle();

    expect(
      e2e.container.read(day1TourStepProvider),
      Day1TourStep.logPuff,
      reason: 'on screen: ${e2e.texts()}',
    );

    // Everything else on Home is behind the barrier. Tapping the panic
    // button — the most reachable control on the screen and the one most
    // likely to be hit by accident — must not open the panic flow. (The tap
    // may legitimately land on the tooltip's "Maybe later", which sits low on
    // the screen too and pauses the tour to the checklist — that is a chosen
    // exit, not a leak.)
    await e2e.tapText(e2e.l10n.homeSos);
    await e2e.settle();
    expect(
      e2e.showing(e2e.l10n.panicBreatheNote),
      isFalse,
      reason: 'the panic flow opened through the walkthrough barrier',
    );
    // Recover to the step regardless of where that tap landed.
    if (!e2e.showing(e2e.l10n.homeLogPuff)) {
      await e2e.tapText(e2e.l10n.day1Task1);
      await e2e.settle();
    }

    // The real move.
    await e2e.tapText(e2e.l10n.homeLogPuff);
    await e2e.settle();
    expect(e2e.container.read(quitStoreProvider)!.day1TasksDone, contains(0));
    expect(e2e.container.read(day1TourStepProvider), Day1TourStep.meetCoach);
  });

  testWidgets('the tab bar is shut while a step is live', (tester) async {
    // The tab bar lives OUTSIDE whichever branch screen owns the showcase, so
    // no overlay barrier reaches it. It is the hole the whole gate would have
    // had, and the reason `AppShell` knows about the walkthrough at all.
    final e2e = await openDay1(tester);
    await e2e.tapText(e2e.l10n.day1Task1);
    await e2e.settle();

    await e2e.tapText(e2e.l10n.navCommunity);
    await e2e.settle();

    expect(
      e2e.showing(e2e.l10n.homeLogPuff),
      isTrue,
      reason: 'a tab switch escaped the walkthrough: ${e2e.texts()}',
    );
  });

  testWidgets('skipping setup opens the app and ticks nothing', (tester) async {
    final e2e = await openDay1(tester);

    await e2e.tapText(e2e.l10n.day1Skip);
    await e2e.settle();

    final journey = e2e.container.read(quitStoreProvider)!;
    expect(journey.day1TasksDone, isEmpty);
    expect(journey.day1TourSkipped, isTrue);
    expect(e2e.container.read(day1TourLockedProvider), isFalse);
    // And the tabs are usable again.
    await e2e.tapText(e2e.l10n.navCommunity);
    await e2e.settle();
    expect(e2e.showing(e2e.l10n.homeLogPuff), isFalse);
  });

  testWidgets('a row tapped out of order spotlights that row\'s screen', (
    tester,
  ) async {
    // The rows are tappable in any order. Deriving "first undone" while
    // navigating by the tapped row once sent someone to the coach with the
    // HOME spotlight active — a locked screen with no tooltip anywhere.
    final e2e = await openDay1(tester);
    await e2e.tapText(e2e.l10n.day1Task2);
    await e2e.settle();

    expect(
      e2e.container.read(day1TourStepProvider),
      Day1TourStep.meetCoach,
      reason: 'the chosen row must win over the first undone task',
    );
    expect(e2e.showing(e2e.l10n.coachInputHint), isTrue);
  });

  testWidgets('the back gesture leaves a step for the checklist, ticking '
      'nothing', (tester) async {
    final e2e = await openDay1(tester);
    await e2e.tapText(e2e.l10n.day1Task1);
    await e2e.settle();

    // The system back gesture. Swallowing it outright made an unfinishable
    // step (a coach with no network) a hostage situation.
    await tester.binding.handlePopRoute();
    await e2e.settle();

    expect(e2e.showing(e2e.l10n.day1Title), isTrue, reason: e2e.texts().join());
    expect(e2e.container.read(quitStoreProvider)!.day1TasksDone, isEmpty);
    expect(e2e.container.read(day1TourLockedProvider), isFalse);
  });

  testWidgets('step one returns to the checklist with the box ticked', (
    tester,
  ) async {
    // Nothing used to route back after the puff was logged: the step flipped
    // to meetCoach while the user was still on a fully locked Home, and the
    // only way out was killing the app.
    final e2e = await openDay1(tester);
    await e2e.tapText(e2e.l10n.day1Task1);
    await e2e.settle();

    await e2e.tapText(e2e.l10n.homeLogPuff);
    await e2e.settle();

    expect(e2e.showing(e2e.l10n.day1Title), isTrue, reason: e2e.texts().join());
    expect(e2e.container.read(quitStoreProvider)!.day1TasksDone, contains(0));
  });

  testWidgets('step three exists on a REAL day one and saving ticks the box', (
    tester,
  ) async {
    // The demo seed carries twelve days of logs; a genuine day-1 account has
    // one. The Stats screen used to swap the trigger-hours card — the only
    // spotlight target for this step — for its empty state below two logs,
    // which left the step with no target, no tooltip, and no way to finish.
    final e2e = await openDay1(tester);
    final journey = e2e.container.read(quitStoreProvider)!;
    final today = JourneyState.dateKey(DateTime.now());
    e2e.container.read(quitStoreProvider.notifier).replaceForTest(
      journey.copyWith(
        days: {today: journey.days[today] ?? journey.days.values.last},
        day1TasksDone: const {0, 1},
      ),
    );
    e2e.container.read(routerProvider).go(Routes.day1);
    await e2e.settle();

    await e2e.tapText(e2e.l10n.day1Task3);
    await e2e.settle();
    expect(
      e2e.showing(e2e.l10n.statsTriggerHours),
      isTrue,
      reason: 'no spotlight target on a one-log journey: ${e2e.texts()}',
    );

    await e2e.tapText(e2e.l10n.statsTriggerHours);
    await e2e.settle();
    await e2e.tapText(e2e.l10n.commonSave);
    await e2e.settle();

    expect(e2e.container.read(quitStoreProvider)!.day1TasksDone, contains(2));
    expect(e2e.showing(e2e.l10n.day1Title), isTrue, reason: e2e.texts().join());
    expect(e2e.container.read(day1TourLockedProvider), isFalse);
  });

  testWidgets('a real coach reply is what finishes step two', (tester) async {
    final e2e = await openDay1(tester);
    e2e.container.read(quitStoreProvider.notifier).completeDay1Task(0);
    await e2e.tapText(e2e.l10n.day1Task2);
    await e2e.settle();

    expect(e2e.container.read(day1TourStepProvider), Day1TourStep.meetCoach);
    expect(
      e2e.container.read(quitStoreProvider)!.day1TasksDone,
      isNot(contains(1)),
      reason: 'arriving at the coach is not meeting the coach',
    );

    // The composer is a raw TextField with a hint, not an LpField —
    // `enterField` walks label siblings and cannot see it.
    final composer = find.byWidgetPredicate(
      (w) =>
          w is TextField && w.decoration?.hintText == e2e.l10n.coachInputHint,
    );
    expect(composer, findsOneWidget, reason: 'no composer: ${e2e.texts()}');
    await tester.enterText(composer.first, 'hi');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    // The fake backend "thinks" for up to 1.4s, and the tour then holds the
    // screen another 2.5s so the reply is actually seen before the checklist
    // takes over.
    await e2e.waitFor(const Duration(seconds: 6));

    expect(
      e2e.container.read(quitStoreProvider)!.day1TasksDone,
      contains(1),
      reason: 'a reply arrived and the box did not tick: ${e2e.texts()}',
    );
    expect(
      e2e.showing(e2e.l10n.day1Title),
      isTrue,
      reason: 'the walkthrough should land back on the checklist',
    );
  });
}
