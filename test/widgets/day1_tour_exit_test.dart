import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/network/connectivity.dart';
import 'package:last_puff/data/stores/day1_tour_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// iPhone 15, TestFlight, Sep 2 2026 — the P1: "the AI chat failed and I am
/// stuck on this screen from the walkthrough."
///
/// Step two holds the app closed until Ember answers. When the reply failed,
/// an Android user had the system back gesture (which pauses the tour and
/// returns to the checklist). An iPhone has no back at all, the tooltip's own
/// "Maybe later" had come down the moment the composer was focused, and the
/// four tabs were dimmed and dead — a locked screen with nothing on it that
/// said why or offered a way out.
///
/// Two things now: the tab bar shows the exit while a lesson has the app
/// locked, and the dropped reply carries a retry. Both drive the real app
/// through the real router, offline from the first frame so the fake
/// backend refuses the reply the way a dead wire would.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// Step two of the walkthrough, entered from the checklist, with a reply
  /// that has just failed.
  Future<ProviderContainer> failOnStepTwo(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: fastBackendOverrides(online: false),
    );
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
    final store = container.read(quitStoreProvider.notifier);
    store.replaceForTest(
      container.read(quitStoreProvider)!.copyWith(day1TasksDone: const {0}),
    );
    container.read(routerProvider).go(Routes.day1);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.day1Task2).first);
    await tester.pumpAndSettle();
    expect(container.read(day1TourStepProvider), Day1TourStep.meetCoach);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hi ember');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    return container;
  }

  void goOnline(ProviderContainer c) =>
      (c.read(connectivityProvider.notifier) as ToggleConnectivity).set(true);

  testWidgets('the locked tab bar is the way out, and it ticks nothing', (
    tester,
  ) async {
    final container = await failOnStepTwo(tester);

    // Still locked, still on step two — a failed reply is not an answer.
    expect(container.read(day1TourStepProvider), Day1TourStep.meetCoach);
    expect(container.read(quitStoreProvider)!.day1TasksDone, {0});
    // The dead tabs are gone; the exit stands where they were.
    expect(find.text(l10n.navCoach), findsNothing);
    expect(find.text(l10n.day1TourBack), findsOneWidget);

    await tester.tap(find.text(l10n.day1TourBack));
    await tester.pumpAndSettle();

    expect(find.text(l10n.day1Title), findsOneWidget);
    expect(container.read(day1TourLockedProvider), isFalse);
    final journey = container.read(quitStoreProvider)!;
    expect(journey.day1TasksDone, {0}, reason: 'leaving is not meeting');
    expect(journey.day1TourSkipped, isFalse, reason: 'leaving is not skipping');

    // And the app is open again: the tabs are back.
    container.read(routerProvider).go(Routes.day1);
    await tester.pumpAndSettle();
    expect(find.text(l10n.day1Task2), findsWidgets);
  });

  testWidgets('a retry that lands completes the step like a first answer', (
    tester,
  ) async {
    final container = await failOnStepTwo(tester);
    expect(find.text(l10n.errorRetry), findsOneWidget);

    goOnline(container);
    await tester.tap(find.text(l10n.errorRetry));
    await tester.pumpAndSettle();
    // The reply, then the beat that lets the user see it before the
    // checklist takes over.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(container.read(quitStoreProvider)!.day1TasksDone, contains(1));
    expect(
      find.text(l10n.day1Title),
      findsOneWidget,
      reason: 'the walkthrough should land back on the checklist',
    );
  });

  testWidgets('the exit is not on screen once the app is open', (
    tester,
  ) async {
    final container = await failOnStepTwo(tester);
    await tester.tap(find.text(l10n.day1TourBack));
    await tester.pumpAndSettle();
    container.read(day1TourProvider.notifier).skip();
    container.read(routerProvider).go(Routes.home);
    await tester.pumpAndSettle();

    expect(find.text(l10n.day1TourBack), findsNothing);
    expect(find.text(l10n.navCoach), findsWidgets);
  });
}
