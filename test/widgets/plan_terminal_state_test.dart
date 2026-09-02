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

/// QA M3 (Aug 31 2026 sim): day 30 — the Plan screen's own "🏆 Freedom Day"
/// — rendered as an ordinary 0-limit day, and Oct 1 rendered the literal
/// header "Day 31 of 30". Streak, day keys and money all crossed the plan's
/// end correctly; this is terminal-state presentation only.
///
/// Rule: "day N of P" never shows N > P. The last day of the plan is Freedom
/// Day, and every day after it is maintenance, framed as such.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final start = DateTime(2026, 9, 1);

  JourneyState journey() {
    final plan = QuitPlan(
      method: QuitMethod.taper,
      paceDays: 30,
      startDate: start,
      baselinePuffsPerDay: 20,
      weeklySpend: 14,
      strength: NicStrength.mg50,
    );
    final days = <DateTime, DayLog>{};
    for (var d = 1; d <= 29; d++) {
      final date = LpDate.addDays(start, d - 1);
      days[date] = DayLog(
        date: date,
        puffs: 0,
        limit: 0,
        vapeFreeConfirmed: true,
      );
    }
    return JourneyState(
      profile: const UserProfile(
        alias: '@simfox',
        avatarEmoji: '🦊',
      ),
      plan: plan,
      days: days,
      cravingsSurvivedTotal: 0,
      repairTokens: 0,
      longestStreak: 29,
      goals: const [],
      earnedBadges: const {},
      day1TasksDone: const {0, 1, 2},
    );
  }

  Future<ProviderContainer> pumpAt(WidgetTester tester, DateTime now) async {
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
    container.read(quitStoreProvider.notifier).replaceForTest(journey());
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text(l10n.homeLogPuff), findsOneWidget);
    return container;
  }

  testWidgets('day 30 is Freedom Day, not "Day 30 of 30"', (tester) async {
    final day30 = DateTime(2026, 9, 30, 10);
    await pumpAt(tester, day30);
    final date = LpFormat.weekdayDate(day30, 'en');

    expect(find.text(l10n.homeGreetingFreedomDay(date)), findsOneWidget);
    expect(find.text(l10n.homeGreetingDate(date, 30, 30)), findsNothing);
    // The completion state itself.
    expect(find.text(l10n.homeFreedomDayTitle), findsOneWidget);
  });

  testWidgets('the day after is maintenance — never "Day 31 of 30"', (
    tester,
  ) async {
    final oct1 = DateTime(2026, 10, 1, 10);
    final container = await pumpAt(tester, oct1);
    final date = LpFormat.weekdayDate(oct1, 'en');

    expect(find.text(l10n.homeGreetingDate(date, 31, 30)), findsNothing);
    expect(find.text(l10n.homeGreetingMaintenance(date, 1)), findsOneWidget);
    expect(find.text(l10n.homeFreedomDayTitle), findsNothing);

    // The same rule on the coach's "always knows" facts.
    container.read(routerProvider).go(Routes.memories);
    await tester.pumpAndSettle();
    expect(find.text(l10n.memoriesFactDayValue(31, 30)), findsNothing);
    expect(find.text(l10n.memoriesFactDayMaintenance(1)), findsOneWidget);
  });

  testWidgets('a week past the plan counts the days', (tester) async {
    final oct7 = DateTime(2026, 10, 7, 10);
    await pumpAt(tester, oct7);
    final date = LpFormat.weekdayDate(oct7, 'en');

    expect(find.text(l10n.homeGreetingMaintenance(date, 7)), findsOneWidget);
  });
}
