import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// QA L5 (Aug 31 2026 sim): after a streak reset the Milestones card read
/// "Next: 30-day inferno · day 0 of 1 · two more sunrises" — three numbers
/// that contradicted each other. The "next" flame was computed from a state
/// (Spark, 1 day) that has no badge, fell through a `switch` default to
/// "inferno", and the trailing "two more sunrises" was a fixed string
/// whatever the distance actually was.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<void> pumpMilestones(
    WidgetTester tester, {
    required int streak,
  }) async {
    final now = DateTime(2026, 9, 24, 10);
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
    final plan = QuitPlan(
      method: QuitMethod.taper,
      paceDays: 30,
      startDate: DateTime(2026, 9, 1),
      baselinePuffsPerDay: 20,
      weeklySpend: 14,
      strength: NicStrength.mg50,
    );
    // `streak` clean days ending yesterday; today unlogged.
    final days = <DateTime, DayLog>{};
    for (var back = 1; back <= streak; back++) {
      final d = LpDate.addDays(DateTime(2026, 9, 24), -back);
      days[d] = DayLog(date: d, puffs: 1, limit: 20);
    }
    container
        .read(quitStoreProvider.notifier)
        .replaceForTest(
          JourneyState(
            profile: const UserProfile(
              alias: '@simfox',
              avatarEmoji: '🦊',
            ),
            plan: plan,
            days: days,
            cravingsSurvivedTotal: 0,
            repairTokens: 0,
            longestStreak: 21,
            goals: const [],
            earnedBadges: const {},
            day1TasksDone: const {0, 1, 2},
          ),
        );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    container.read(routerProvider).go(Routes.milestones);
    await tester.pumpAndSettle();
    expect(container.read(todayProvider)!.streak, streak);
  }

  testWidgets('at streak 0 the next badge is Spark, three sunrises away', (
    tester,
  ) async {
    await pumpMilestones(tester, streak: 0);

    expect(find.text(l10n.milestonesNext(l10n.mSpark)), findsOneWidget);
    expect(find.text(l10n.milestonesNextProgress(0, 3, 3)), findsOneWidget);
    // The grid below still lists the inferno badge; the NEXT line must not.
    expect(find.text(l10n.milestonesNext(l10n.mInferno)), findsNothing);
  });

  testWidgets('at streak 5 the next badge is the week flame, two away', (
    tester,
  ) async {
    await pumpMilestones(tester, streak: 5);

    expect(find.text(l10n.milestonesNext(l10n.mWeekFlame)), findsOneWidget);
    expect(find.text(l10n.milestonesNextProgress(5, 7, 2)), findsOneWidget);
  });

  testWidgets('at streak 29 the inferno is one sunrise away', (tester) async {
    await pumpMilestones(tester, streak: 29);

    expect(find.text(l10n.milestonesNext(l10n.mInferno)), findsOneWidget);
    expect(find.text(l10n.milestonesNextProgress(29, 30, 1)), findsOneWidget);
  });
}
