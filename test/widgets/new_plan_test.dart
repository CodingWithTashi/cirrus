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
import 'package:last_puff/features/home/home_screen.dart';
import 'package:last_puff/features/plan/new_plan_screen.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// "Start a new plan": one page, reached from where people were getting
/// stuck, that changes the line from today and nothing behind it.
///
/// The doors are the places the people who signed out and started over had
/// been standing (Nov 11 2026): the Plan screen, Home after the plan had
/// ended while they were still logging puffs, and the sign-out dialog itself.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final now = DateTime(2026, 11, 12, 15, 30);
  final today = LpDate.dayStart(now);

  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  /// A finished 30-day, 200-a-day taper, five days past its end. [lately] is
  /// the puffs on the days before today, newest first.
  JourneyState finished({List<int> lately = const [78, 80, 82, 84, 86, 0, 82]}) {
    final j = journeyOnDay(36, now: now, baseline: 200, weeklySpend: 60);
    final days = {...j.days};
    for (var back = 1; back <= lately.length; back++) {
      final date = LpDate.addDays(today, -back);
      final puffs = lately[back - 1];
      days[date] = DayLog(
        date: date,
        puffs: puffs,
        limit: 0,
        hourBuckets: puffs == 0 ? const {} : {21: puffs},
        vapeFreeConfirmed: puffs == 0,
      );
    }
    return j.copyWith(days: days);
  }

  Future<(ProviderContainer, RecordingAnalytics)> open(
    WidgetTester tester,
    JourneyState journey, {
    String route = Routes.home,
  }) async {
    ignoreFontWidthOverflow();
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
    container.read(routerProvider).go(Routes.home);
    await tester.pumpAndSettle();
    if (route != Routes.home) {
      unawaited(container.read(routerProvider).push(route));
      await tester.pumpAndSettle();
    }
    return (container, analytics);
  }

  String path(ProviderContainer c) => c.read(routerProvider).state.uri.path;

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('the page', () {
    testWidgets('opens on the level they have really been at', (tester) async {
      await open(tester, finished(), route: Routes.planNew);

      expect(find.byType(NewPlanScreen), findsOneWidget);
      expect(find.text(l10n.newPlanLead), findsOneWidget);
      expect(find.widgetWithText(TextField, '82'), findsOneWidget);
      expect(find.text(l10n.newPlanLevelHint(82)), findsOneWidget);
    });

    testWidgets('asks, and guesses nothing, when there is nothing to go on', (
      tester,
    ) async {
      await open(tester, finished(lately: const []), route: Routes.planNew);

      expect(find.text(l10n.newPlanLevelNoHint), findsOneWidget);
      expect(find.textContaining('averaged'), findsNothing);
      // Nothing typed, nothing to start a taper from.
      await tapVisible(tester, find.text(l10n.newPlanCta));
      expect(find.byType(NewPlanScreen), findsOneWidget);
    });

    testWidgets('shows the line and the date the choices lead to, live', (
      tester,
    ) async {
      await open(tester, finished(), route: Routes.planNew);

      // The default runway is the one the old plan used: 30 days from 82.
      expect(find.text(l10n.newPlanToday(78)), findsOneWidget);
      expect(
        find.text(
          l10n.newPlanFreedom(
            LpFormat.shortDate(LpDate.addDays(today, 29), 'en'),
          ),
        ),
        findsOneWidget,
      );

      await tapVisible(tester, find.text('21'));
      expect(find.text(l10n.newPlanToday(76)), findsOneWidget);
      expect(
        find.text(
          l10n.newPlanFreedom(
            LpFormat.shortDate(LpDate.addDays(today, 20), 'en'),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('starting it lands on Home on day one, with nothing lost', (
      tester,
    ) async {
      final (c, analytics) = await open(
        tester,
        finished(),
        route: Routes.planNew,
      );
      final before = c.read(todayProvider)!;

      await tapVisible(tester, find.text('21'));
      await tapVisible(tester, find.text(l10n.newPlanCta));

      expect(path(c), Routes.home);
      expect(find.byType(HomeScreen), findsOneWidget);
      final after = c.read(todayProvider)!;
      expect(after.dayNumber, 1);
      expect(after.totalDays, 21);
      expect(after.limit, 76);
      expect(after.streak, before.streak);
      expect(after.savedLifetime, before.savedLifetime);
      expect(after.cravingsSurvivedTotal, before.cravingsSurvivedTotal);
      expect(
        find.text(
          l10n.homeGreetingDate(LpFormat.weekdayDate(now, 'en'), 1, 21),
        ),
        findsOneWidget,
      );
      expect(analytics.names, contains('plan_restarted'));
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('a new day one is not sent back to the setup checklist', (
      tester,
    ) async {
      // Somebody who skipped setup on their first plan. Day one of plan two
      // must not be read as the first day of the app.
      final (c, _) = await open(
        tester,
        finished().copyWith(day1TasksDone: const {}, day1TourSkipped: false),
        route: Routes.planNew,
      );

      await tapVisible(tester, find.text(l10n.newPlanCta));

      expect(path(c), Routes.home);
      expect(find.textContaining('Finish setup'), findsNothing);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  });

  group('after a new plan has started', () {
    /// Restarted today, on top of [before].
    Future<ProviderContainer> restarted(
      WidgetTester tester,
      JourneyState before, {
      String route = Routes.home,
    }) async {
      final (c, _) = await open(tester, before);
      c
          .read(quitStoreProvider.notifier)
          .startNewPlan(method: QuitMethod.taper, paceDays: 21, level: 82);
      await tester.pumpAndSettle();
      if (route != Routes.home) {
        unawaited(c.read(routerProvider).push(route));
        await tester.pumpAndSettle();
      }
      return c;
    }

    testWidgets('an unanswered yesterday is still asked about', (
      tester,
    ) async {
      // Yesterday has no log at all. It came before the new plan's day one,
      // and the card was bounded by the plan — so it vanished and the chain
      // stayed broken with nothing to say why.
      final j = finished();
      final yesterday = LpDate.addDays(today, -1);
      final c = await restarted(
        tester,
        j.copyWith(days: {...j.days}..remove(yesterday)),
      );
      expect(c.read(quitStoreProvider)!.days[yesterday], isNull);

      expect(
        find.text(l10n.homeYesterdayTitle, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('Money and Profile still date things from the beginning', (
      tester,
    ) async {
      final before = finished();
      final began = LpFormat.shortDate(before.historyStart, 'en');
      final restartDay = LpFormat.shortDate(today, 'en');
      expect(began, isNot(restartDay), reason: 'fixture');

      await restarted(tester, before, route: Routes.money);
      expect(find.textContaining('saved since $began'), findsOneWidget);
      expect(find.textContaining('saved since $restartDay'), findsNothing);
    });

    testWidgets('Profile says how long they have really been at it', (
      tester,
    ) async {
      final before = finished();
      final began = LpFormat.shortDate(before.historyStart, 'en');

      await restarted(tester, before, route: Routes.profile);
      expect(find.textContaining('quitting since $began'), findsOneWidget);
    });
  });

  group('the doors', () {
    testWidgets('Home, once the plan has ended and puffs are still being '
        'logged', (tester) async {
      final (c, _) = await open(tester, finished());

      await tapVisible(
        tester,
        find.text(l10n.homePlanEndedTitle, skipOffstage: false),
      );

      expect(path(c), Routes.planNew);
    });

    testWidgets('but not for somebody who has stopped', (tester) async {
      // Past Freedom Day with clean days behind them: they are done, and
      // suggesting another plan would be telling them they are not.
      await open(tester, finished(lately: const [0, 0, 0]));

      expect(
        find.text(l10n.homePlanEndedTitle, skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('nor in the middle of a plan', (tester) async {
      await open(tester, journeyOnDay(12, now: now));

      expect(
        find.text(l10n.homePlanEndedTitle, skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('the Plan screen, where a finished plan offers the next one '
        'in place of an adjustment', (tester) async {
      final (c, _) = await open(tester, finished(), route: Routes.plan);

      expect(find.text(l10n.planAdjustCta), findsNothing);
      await tapVisible(tester, find.text(l10n.planNewCta));

      expect(path(c), Routes.planNew);
    });

    testWidgets('and a running one offers both', (tester) async {
      await open(tester, journeyOnDay(12, now: now), route: Routes.plan);

      expect(find.text(l10n.planAdjustCta), findsOneWidget);
      expect(find.text(l10n.planNewCta), findsOneWidget);
    });

    testWidgets('the sign-out dialog, which is where they were giving up', (
      tester,
    ) async {
      final (c, _) = await open(tester, finished(), route: Routes.settings);
      final signOut = find.text(l10n.settingsSignOut, skipOffstage: false);
      await tester.scrollUntilVisible(
        signOut,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(signOut);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.settingsSignOutNewPlan));
      await tester.pumpAndSettle();

      expect(path(c), Routes.planNew);
      expect(c.read(quitStoreProvider), isNotNull, reason: 'still signed in');
    });
  });
}
