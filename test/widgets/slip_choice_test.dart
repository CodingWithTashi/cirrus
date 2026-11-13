import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/utils/lp_format.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// docs/15 QP-A10. A slip used to stretch the plan whichever button was
/// pressed, and drew the stretched curve and the later date before any choice
/// was made. Each week of delay to a quit date raised the chance of lapsing by
/// 19% (Hughes 2010), so the date now stays unless the person moves it.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final now = DateTime(2026, 11, 12, 10, 15);

  /// A day-10 plan with a slip waiting to be resolved.
  JourneyState slipping({
    int stretch = 0,
    QuitMethod method = QuitMethod.taper,
    SmokingHistory? smoking = SmokingHistory.never,
  }) {
    final base = journeyOnDay(10, now: now);
    return base.copyWith(
      plan: base.plan.copyWith(stretchDays: stretch, method: method),
      profile: UserProfile(
        alias: base.profile.alias,
        avatarEmoji: base.profile.avatarEmoji,
        smoking: smoking,
      ),
      pendingSlipCleanDays: () => 3,
    );
  }

  String date(DateTime d) => LpFormat.shortDate(d, 'en');

  /// Past the settle of a tap: `PressScale` schedules a 120ms delay.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
  }

  Future<(ProviderContainer, RecordingAnalytics)> openAdjustment(
    WidgetTester tester,
    JourneyState journey,
  ) async {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
    // A tall phone: the step scrolls, and a button under the fold cannot be
    // tapped by `tester.tap`. (Whether the primary button is reachable without
    // scrolling on a real screen is a device check, not this test's.)
    tester.view.physicalSize = const Size(393, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
    container.read(quitStoreProvider.notifier).replaceForTest(journey);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    unawaited(container.read(routerProvider).push(Routes.slip));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.slipTriggerStress));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.text(l10n.slipAdjustCta));
    await settle(tester);
    return (container, analytics);
  }

  JourneyState journeyOf(ProviderContainer c) => c.read(quitStoreProvider)!;
  String pathOf(ProviderContainer c) =>
      c.read(routerProvider).state.uri.path;

  group('the choice', () {
    testWidgets('offers both: keep the date, or add days', (tester) async {
      final (container, _) = await openAdjustment(tester, slipping());
      final plan = journeyOf(container).plan;

      expect(find.text(l10n.slipKeepDate), findsOneWidget);
      expect(find.text(l10n.slipAddDays(2)), findsOneWidget);
      // The date as it stands now is the headline, not the later one.
      expect(
        find.text(l10n.slipDateStays(date(plan.freedomDate))),
        findsOneWidget,
      );
    });

    testWidgets('the later date is only ever the consequence of Add', (
      tester,
    ) async {
      final (container, _) = await openAdjustment(tester, slipping());
      final plan = journeyOf(container).plan;
      final later = LpDate.addDays(plan.freedomDate, 2);

      expect(find.text(l10n.slipNewFreedom(date(later), 2)), findsOneWidget);
      expect(
        find.text(l10n.slipNewFreedom(date(plan.freedomDate), 0)),
        findsNothing,
      );
    });

    testWidgets('Keep my date changes nothing about the plan', (tester) async {
      final (container, analytics) = await openAdjustment(tester, slipping());
      final before = journeyOf(container).plan;

      await tester.tap(find.text(l10n.slipKeepDate));
      await settle(tester);

      final after = journeyOf(container);
      expect(after.plan.stretchDays, before.stretchDays);
      expect(after.plan.freedomDate, before.freedomDate);
      expect(after.pendingSlipCleanDays, isNull, reason: 'the card is cleared');
      expect(pathOf(container), Routes.home);
      expect(analytics.propsOfAll('slip_resolved'), [
        {'kept_date': 'true'},
      ]);
    });

    testWidgets('Add moves Freedom Day by the days it says, and no more', (
      tester,
    ) async {
      final (container, analytics) = await openAdjustment(tester, slipping());
      final before = journeyOf(container).plan;

      await tester.tap(find.text(l10n.slipAddDays(2)));
      await settle(tester);

      final after = journeyOf(container);
      expect(after.plan.stretchDays, before.stretchDays + 2);
      expect(
        after.plan.freedomDate,
        LpDate.addDays(before.freedomDate, 2),
      );
      expect(after.pendingSlipCleanDays, isNull);
      expect(pathOf(container), Routes.home);
      expect(analytics.propsOfAll('slip_resolved'), [
        {'kept_date': 'false'},
      ]);
    });

    testWidgets('Add offers only the room that is left', (tester) async {
      // Six of seven days already given: one more is all a slip can add, and
      // the button must say 1, not 2.
      final (container, _) = await openAdjustment(tester, slipping(stretch: 6));
      expect(find.text(l10n.slipAddDays(1)), findsOneWidget);
      expect(find.text(l10n.slipAddDays(2)), findsNothing);

      // The caption under it names the same single day, grammatically. Before
      // the stretch ceiling a slip always added two, so "(+{days} days)" had no
      // singular and read "+1 days" the first time one day was all that was left.
      final plan = journeyOf(container).plan;
      final oneLater = LpDate.addDays(plan.freedomDate, 1);
      expect(
        find.text(l10n.slipNewFreedom(date(oneLater), 1)),
        findsOneWidget,
      );
      expect(l10n.slipNewFreedom('x', 1), contains('+1 day'));
      expect(l10n.slipNewFreedom('x', 1), isNot(contains('1 days')));

      await tester.tap(find.text(l10n.slipAddDays(1)));
      await settle(tester);
      expect(journeyOf(container).plan.stretchDays, 7);
    });

    testWidgets('Add is gone once the stretch is used up', (tester) async {
      final (_, _) = await openAdjustment(tester, slipping(stretch: 7));
      expect(find.text(l10n.slipKeepDate), findsOneWidget);
      expect(find.textContaining('Add '), findsNothing);
    });

    testWidgets('a stretch given under the old rule counts as used up', (
      tester,
    ) async {
      final (_, _) = await openAdjustment(tester, slipping(stretch: 10));
      expect(find.text(l10n.slipKeepDate), findsOneWidget);
      expect(find.textContaining('Add '), findsNothing);
    });

    testWidgets('cold turkey has no runway to add to', (tester) async {
      final (_, _) = await openAdjustment(
        tester,
        slipping(method: QuitMethod.coldTurkey),
      );
      expect(find.text(l10n.slipKeepDate), findsOneWidget);
      expect(find.textContaining('Add '), findsNothing);
    });

    testWidgets('Talk it through opens the coach and stretches nothing', (
      tester,
    ) async {
      final (container, analytics) = await openAdjustment(tester, slipping());
      final before = journeyOf(container);

      await tester.tap(find.text(l10n.slipTalkFirst));
      await settle(tester);

      expect(pathOf(container), Routes.coach);
      final after = journeyOf(container);
      expect(after.plan.stretchDays, before.plan.stretchDays);
      // Undecided is not resolved: the slip card stays until they choose.
      expect(after.pendingSlipCleanDays, isNotNull);
      expect(analytics.propsOfAll('slip_resolved'), isEmpty);
    });
  });

  group('the one rule and More help', () {
    testWidgets('a former smoker sees the rule here', (tester) async {
      await openAdjustment(tester, slipping(smoking: SmokingHistory.former));
      expect(find.text(l10n.smokingRuleBody), findsOneWidget);
    });

    testWidgets('someone who still smokes sees both lines', (tester) async {
      await openAdjustment(tester, slipping(smoking: SmokingHistory.current));
      expect(find.text(l10n.smokingRuleBody), findsOneWidget);
      expect(find.text(l10n.smokingRuleCurrent), findsOneWidget);
    });

    testWidgets('never, and not asked, see no rule', (tester) async {
      for (final smoking in [SmokingHistory.never, null]) {
        await openAdjustment(tester, slipping(smoking: smoking));
        expect(
          find.text(l10n.smokingRuleBody),
          findsNothing,
          reason: '$smoking',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('everyone gets a way to More help, tagged slip', (tester) async {
      final (_, analytics) = await openAdjustment(tester, slipping());

      await tester.tap(find.text(l10n.helpTitle));
      await settle(tester);

      expect(analytics.propsOfAll('help_viewed'), [
        {'source': 'slip'},
      ]);
    });
  });
}
