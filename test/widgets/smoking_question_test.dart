import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/data/stores/day1_tour_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/home/home_screen.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// docs/15 QP-A3: accounts made before the question existed are asked it once,
/// on Home, until they answer. New accounts answer it in onboarding, so for
/// them the card never appears.
///
/// 10:15 on purpose: after 18:00 Home's evening mood prompt takes the one-card
/// slot, and a test about a different card must not depend on the hour the
/// suite happens to run at.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final now = DateTime(2026, 11, 12, 10, 15);

  /// A day-3 journey that predates the question (smoking null), with setup
  /// finished so neither the checklist card nor the tour is in the way.
  JourneyState unasked({
    SmokingHistory? answer,
    Set<int> setup = const {0, 1, 2},
  }) {
    final base = journeyOnDay(3, now: now);
    return base.copyWith(
      profile: UserProfile(
        alias: base.profile.alias,
        avatarEmoji: base.profile.avatarEmoji,
        smoking: answer,
      ),
      day1TasksDone: setup,
    );
  }

  Future<ProviderContainer> pumpHome(
    WidgetTester tester,
    JourneyState journey,
  ) async {
    final container = ProviderContainer(
      overrides: fastBackendOverrides(now: now),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).replaceForTest(journey);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    return container;
  }

  testWidgets('asks an account that has never been asked', (tester) async {
    await pumpHome(tester, unasked());

    expect(find.text(l10n.obSmokingTitle), findsOneWidget);
    expect(find.text(l10n.obSmokingNever), findsOneWidget);
    expect(find.text(l10n.obSmokingFormer), findsOneWidget);
    expect(find.text(l10n.obSmokingCurrent), findsOneWidget);
  });

  testWidgets('does not ask an account that answered, whatever it said', (
    tester,
  ) async {
    for (final answer in SmokingHistory.values) {
      await pumpHome(tester, unasked(answer: answer));
      expect(
        find.text(l10n.obSmokingTitle),
        findsNothing,
        reason: 'answered ${answer.name}',
      );
      // A fresh tree per answer, so the previous Home is not reused.
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('one tap answers it, saves it and the card is gone', (
    tester,
  ) async {
    final container = await pumpHome(tester, unasked());

    await tester.tap(find.text(l10n.obSmokingFormer));
    // Optimistic and synchronous: the journey already says so, before any
    // frame or any wire round trip.
    expect(
      container.read(quitStoreProvider)!.profile.smoking,
      SmokingHistory.former,
    );

    await tester.pumpAndSettle();
    expect(find.text(l10n.obSmokingTitle), findsNothing);
    expect(find.text(l10n.obSmokingFormer), findsNothing);
  });

  testWidgets('each of the three answers is stored as itself', (tester) async {
    for (final (label, answer) in [
      (l10n.obSmokingNever, SmokingHistory.never),
      (l10n.obSmokingFormer, SmokingHistory.former),
      (l10n.obSmokingCurrent, SmokingHistory.current),
    ]) {
      final container = await pumpHome(tester, unasked());
      await tester.tap(find.text(label));
      expect(container.read(quitStoreProvider)!.profile.smoking, answer);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('stays out of the way while the Day-1 tour is running', (
    tester,
  ) async {
    final container = await pumpHome(tester, unasked(setup: const {}));
    // Setup is unfinished and the tour has not started, so it shows.
    expect(find.text(l10n.obSmokingTitle), findsOneWidget);

    container.read(day1TourProvider.notifier).start(Day1TourStep.logPuff);
    await tester.pumpAndSettle();
    expect(find.text(l10n.obSmokingTitle), findsNothing);
  });

  testWidgets('does not hide, and is not hidden by, a pending slip', (
    tester,
  ) async {
    // The one-card chain (slip → mood → nudge) is for things that cannot wait;
    // this question can, so it must never take the slip card's place or lose
    // its own to it.
    final slipping = unasked().copyWith(pendingSlipCleanDays: () => 1);
    await pumpHome(tester, slipping);
    expect(find.text(l10n.obSmokingTitle), findsOneWidget);
    expect(find.text(l10n.slipTitle), findsOneWidget);
  });

  group('the one rule (QP-A4)', () {
    testWidgets('a former smoker is shown it once, right after answering', (
      tester,
    ) async {
      await pumpHome(tester, unasked());
      await tester.tap(find.text(l10n.obSmokingFormer));
      await tester.pumpAndSettle();

      // The question is gone and the rule has taken its place.
      expect(find.text(l10n.obSmokingTitle), findsNothing);
      expect(find.text(l10n.smokingRuleBody), findsOneWidget);
      expect(find.text(l10n.smokingRuleCurrent), findsNothing);
    });

    testWidgets('someone who still smokes also gets the stop-smoking line', (
      tester,
    ) async {
      await pumpHome(tester, unasked());
      await tester.tap(find.text(l10n.obSmokingCurrent));
      await tester.pumpAndSettle();

      expect(find.text(l10n.smokingRuleBody), findsOneWidget);
      expect(find.text(l10n.smokingRuleCurrent), findsOneWidget);
    });

    testWidgets('never gets no rule at all', (tester) async {
      await pumpHome(tester, unasked());
      await tester.tap(find.text(l10n.obSmokingNever));
      await tester.pumpAndSettle();

      expect(find.text(l10n.smokingRuleBody), findsNothing);
    });

    testWidgets('Done puts it away for good', (tester) async {
      await pumpHome(tester, unasked());
      await tester.tap(find.text(l10n.obSmokingFormer));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.commonDone));
      await tester.pumpAndSettle();
      expect(find.text(l10n.smokingRuleBody), findsNothing);
    });

    testWidgets('an account that answered long ago is not shown it again', (
      tester,
    ) async {
      // "Once" means once: the card lives only for the visit on which the
      // answer was given, and nothing about it is stored.
      await pumpHome(tester, unasked(answer: SmokingHistory.former));
      expect(find.text(l10n.smokingRuleBody), findsNothing);
    });

    testWidgets('More help opens the page, tagged with where it came from', (
      tester,
    ) async {
      final analytics = RecordingAnalytics();
      final container = ProviderContainer(
        overrides: fastBackendOverrides(now: now, analytics: analytics),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LastPuffApp(),
        ),
      );
      container.read(quitStoreProvider.notifier).replaceForTest(unasked());
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.obSmokingFormer));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.helpTitle));
      await tester.pumpAndSettle();

      expect(analytics.propsOfAll('help_viewed'), [
        {'source': 'home'},
      ]);
    });
  });

  test('answering with no journey does nothing and does not throw', () {
    final container = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(container.dispose);
    expect(container.read(quitStoreProvider), isNull);
    container
        .read(quitStoreProvider.notifier)
        .setSmokingHistory(SmokingHistory.never);
    expect(container.read(quitStoreProvider), isNull);
  });
}
