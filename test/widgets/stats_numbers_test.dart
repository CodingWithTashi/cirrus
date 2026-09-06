import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/utils/lp_format.dart';
import 'package:last_puff/core/widgets/lp_charts.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/dependence_engine.dart';
import 'package:last_puff/domain/logic/puff_gaps.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// Stats, number by number. `stats_window_test` pins WHICH days the bars are;
/// this pins what they say: heights, the "vs last" percentage, the hard-day
/// caption, the danger window, the nicotine figure and the records row — the
/// row whose "longest gap" was a fabricated 8–16h until Sep 5 2026, and whose
/// "best day" read 0 for every account on its second day.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  /// Mon Sep 14 2026, 10:15 — day 14 of a plan that started Tue Sep 1.
  final now = DateTime(2026, 9, 14, 10, 15);
  final start = DateTime(2026, 9, 1);

  /// Week one (days 1–7) at 100 a day, week two (days 8–13) at 80: this
  /// week averages 20% under last week.
  JourneyState journey() => journeyOnDay(
    14,
    now: now,
    puffsByDay: {
      for (var d = 1; d <= 7; d++) d: 100,
      for (var d = 8; d <= 13; d++) d: 80,
    },
    lastPuffAt: DateTime(2026, 9, 13, 10, 40),
  );

  Future<ProviderContainer> pumpStats(
    WidgetTester tester, {
    JourneyState? state,
    bool premium = true,
  }) async {
    ignoreFontWidthOverflow();
    final container = ProviderContainer(
      overrides: fastBackendOverrides(now: now, premium: premium),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).replaceForTest(state ?? journey());
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    container.read(routerProvider).go(Routes.stats);
    await tester.pumpAndSettle();
    return container;
  }

  Finder bar(DateTime date) => find.byKey(ValueKey(date));
  double heightOf(WidgetTester tester, DateTime date) =>
      tester.widget<FractionallySizedBox>(bar(date)).heightFactor!;

  testWidgets('the week bars are the puffs of each calendar day', (
    tester,
  ) async {
    await pumpStats(tester);
    expect(find.text(l10n.statsPuffsThisWeek), findsOneWidget);
    // Tue Sep 8 → Mon Sep 14. Six 80-puff days at full height, today's
    // empty bar at the 4% sliver.
    for (var i = 0; i < 6; i++) {
      final date = LpDate.addDays(DateTime(2026, 9, 8), i);
      expect(heightOf(tester, date), 1.0, reason: '$date is 80 of max 80');
    }
    expect(heightOf(tester, DateTime(2026, 9, 14)), 0.04);
    expect(bar(DateTime(2026, 9, 7)), findsNothing, reason: 'last week');
  });

  testWidgets('"vs last" compares confirmed days of the two windows', (
    tester,
  ) async {
    await pumpStats(tester);
    // Last week averaged 100; this week's six confirmed days 80. Today is
    // unconfirmed and left out — an unlogged day is unknown, not zero.
    expect(find.text(l10n.statsVsLast(LpFormat.signedPercent(-20))), findsOneWidget);
  });

  testWidgets('the hard-day caption names the first day at the maximum', (
    tester,
  ) async {
    await pumpStats(tester);
    expect(
      find.text(l10n.statsHardDayCaptionPlain(LpFormat.weekday(DateTime(2026, 9, 8), 'en'))),
      findsOneWidget,
    );
  });

  testWidgets('the danger window is the engine\'s, in the user\'s hours', (
    tester,
  ) async {
    // Every logged day put its puffs at 10 AM.
    await pumpStats(tester);
    expect(
      find.text(l10n.statsDangerWindow('${LpFormat.hour(10, 'en')}–${LpFormat.hour(11, 'en')}')),
      findsOneWidget,
    );
  });

  testWidgets('the nicotine figure is the latest FULL day through the engine', (
    tester,
  ) async {
    await pumpStats(tester);
    final journey = journey_();
    final mg = DependenceEngine.nicotineMg(80, journey.plan.strength).round();
    expect(find.text('≈ ${l10n.statsNicotineValue(mg)}'), findsOneWidget);
  });

  testWidgets('the records row: best confirmed day, real longest gap, cravings', (
    tester,
  ) async {
    final container = await pumpStats(tester);
    final state = container.read(quitStoreProvider)!;
    expect(find.text('80'), findsOneWidget, reason: 'best day (puffs)');
    final gap = PuffGaps.longestGapHours(state, now)!;
    // 10 AM puffs every day: 11 PM–9 AM... the walk finds the 23-hour stretch
    // between one day's 10 AM bucket and the next — and today, unlogged, is
    // covered by the live stretch since yesterday's last puff.
    expect(gap, 23);
    expect(find.text('${gap}h'), findsOneWidget);
    expect(find.text(l10n.statsLongestGap), findsOneWidget);
    expect(find.text('0'), findsWidgets, reason: 'cravings beaten');
  });

  testWidgets('with nothing confirmed the records say so, not zero', (
    tester,
  ) async {
    // Two days on the books, neither confirmed — the logs a mood check-in
    // mints. "best day 0" and "8h" were the old answers.
    final unknown = JourneyState(
      profile: const UserProfile(alias: '@quietfox', avatarEmoji: '🦊'),
      plan: QuitPlan(
        method: QuitMethod.taper,
        paceDays: 30,
        startDate: DateTime(2026, 9, 12),
        baselinePuffsPerDay: 100,
        weeklySpend: 30,
        strength: NicStrength.mg50,
      ),
      days: {
        DateTime(2026, 9, 12): DayLog(date: DateTime(2026, 9, 12), puffs: 0, limit: 95),
        DateTime(2026, 9, 13): DayLog(date: DateTime(2026, 9, 13), puffs: 0, limit: 90),
      },
      cravingsSurvivedTotal: 0,
      repairTokens: 0,
      longestStreak: 0,
      goals: const [],
      earnedBadges: const {},
    );
    await pumpStats(tester, state: unknown);
    expect(find.text('—'), findsNWidgets(2), reason: 'best day and longest gap');
    expect(find.text(l10n.statsWindowNoPuffs), findsOneWidget);
  });

  testWidgets('the Day view buckets add up to today', (tester) async {
    final container = await pumpStats(tester);
    container.read(quitStoreProvider.notifier).adjustToday(5);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.statsRangeDay));
    await tester.pumpAndSettle();
    final chart = tester.widget<BarChart>(find.byType(BarChart).first);
    expect(chart.values.fold<num>(0, (a, b) => a + b), 5);
  });

  testWidgets('Month shows every day since the plan began, for Premium', (
    tester,
  ) async {
    await pumpStats(tester);
    await tester.tap(find.text(l10n.statsRangeMonth));
    await tester.pumpAndSettle();
    expect(find.text(l10n.statsPuffsThisMonth), findsOneWidget);
    for (var i = 0; i < 14; i++) {
      expect(bar(LpDate.addDays(start, i)), findsOneWidget);
    }
    expect(bar(LpDate.addDays(start, -1)), findsNothing);
  });
}

/// The fixture again, for assertions that need the plan.
JourneyState journey_() => journeyOnDay(
  14,
  now: DateTime(2026, 9, 14, 10, 15),
  puffsByDay: {
    for (var d = 1; d <= 7; d++) d: 100,
    for (var d = 8; d <= 13; d++) d: 80,
  },
);
