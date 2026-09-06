import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
import 'package:last_puff/core/widgets/lp_charts.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/day_window.dart';
import 'package:last_puff/features/insight/insight_screen.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The Sunday AI report reaching the screen (`weeklyInsight`, docs/04 §5).
///
/// Same class of bug as B11: the cron generated a report every week and the
/// screen rendered authored placeholder copy over hardcoded bars, so the
/// model's words were produced, paid for, and never seen. These tests pin the
/// two halves — the report renders when there is one, and the authored cards
/// stand in when there isn't.
void main() {
  const report = WeeklyInsight(
    weekId: '2026-08-30',
    headline: 'Thursday is your hard day',
    pattern: 'Three of your four over-limit days this month were Thursdays.',
    win: 'You survived nine cravings, up from four last week.',
    watchout: 'Your 9pm window is creeping back toward baseline.',
    move: 'Put your kit in another room before 8:30pm on Thursday.',
  );

  ProviderContainer containerWith(WeeklyInsight? insight) {
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        serverStateRepositoryProvider.overrideWithValue(
          _StubServerState(insight),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    return container;
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const InsightScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("the model's report replaces the authored cards", (tester) async {
    final container = containerWith(report);
    await pumpScreen(tester, container);

    expect(find.text(report.headline), findsOneWidget);
    expect(find.text(report.pattern), findsOneWidget);
    // The pending state must be gone once a real report exists — showing both
    // would be two contradictory claims about the same week.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.insightPendingTitle), findsNothing);
  });

  testWidgets("the report's next move rides the last card", (tester) async {
    final container = containerWith(report);
    await pumpScreen(tester, container);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(report.win), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(report.watchout), findsOneWidget);
    expect(find.text(report.move), findsOneWidget);
  });

  testWidgets("the charts cover the report's own week, whenever it is read", (
    tester,
  ) async {
    // The bars used to be the last seven LOGGED days from now, so after a
    // quiet stretch they reached back into a week the report never saw, they
    // drew today's half-day beside six finished ones, and a Sunday report
    // opened on Thursday showed a different week from its prose. The server
    // windows the seven days before the report's own `weekId`
    // (`trailingDays`); `DayWindow.logged` is that window on this side.
    const sundayReport = WeeklyInsight(
      weekId: '2026-09-13',
      headline: 'Thursday is your hard day',
      pattern: 'Three of your four over-limit days this month were Thursdays.',
      win: 'You survived nine cravings, up from four last week.',
      watchout: 'Your 9pm window is creeping back toward baseline.',
      move: 'Put your kit in another room before 8:30pm on Thursday.',
    );
    // Opened the following Thursday.
    final now = DateTime(2026, 9, 17, 10, 15);
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(now: now),
        serverStateRepositoryProvider.overrideWithValue(
          const _StubServerState(sundayReport),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Day 17: days 1–16 logged, day 10 skipped, 5 puffs already today.
    final journey = journeyOnDay(
      17,
      now: now,
      puffsByDay: {for (var d = 1; d <= 16; d++) d: 40 + d},
    );
    final day10 = LpDate.addDays(journey.plan.startDate, 9);
    final withGap = journey.copyWith(
      days: {for (final e in journey.days.entries) if (e.key != day10) e.key: e.value},
    );
    container.read(quitStoreProvider.notifier).replaceForTest(withGap);
    container.read(quitStoreProvider.notifier).adjustToday(5);
    await pumpScreen(tester, container);

    final chart = tester.widget<BarChart>(find.byType(BarChart).first);
    // Sep 6 → Sep 12 (days 6–12) minus the missing day 10: six bars. Neither
    // today's 5 nor the four days since the report (days 13–16) appear.
    expect(chart.values, [46, 47, 48, 49, 51, 52]);
    expect(
      chart.values,
      [for (final d in DayWindow.logged(withGap, DateTime(2026, 9, 13), 7)) d.puffs],
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      find.text(l10n.insightTitle(2, 'Sep 6–Sep 12')),
      findsOneWidget,
      reason: "the header names the report's week, not the reader's",
    );
  });

  testWidgets('no report says so — it never invents one', (tester) async {
    // The old fallback rendered four authored cards that read as findings
    // about the reader ("You vape 3x more after 10 p.m. on weekends"), the
    // same for everybody. An honest empty state is the whole point.
    final container = containerWith(null);
    await pumpScreen(tester, container);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.insightPendingTitle), findsOneWidget);
    expect(find.text(report.headline), findsNothing);
    // No charts either: a bar chart with no data behind it is a made-up
    // number in a different costume.
    expect(find.byType(BarChart), findsNothing);
  });
}

class _StubServerState implements ServerStateRepository {
  const _StubServerState(this._insight);

  final WeeklyInsight? _insight;

  @override
  Future<PlanAdvice?> planAdvice() async => null;

  @override
  Future<WeeklyInsight?> latestInsight() async => _insight;

  @override
  Future<bool> refreshEntitlement() async => false;
}
