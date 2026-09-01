import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/utils/lp_format.dart';
import 'package:last_puff/core/widgets/lp_charts.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// QA M1 + L7 (Aug 31 2026 sim): on Tue Sep 29 the Stats "PUFFS THIS WEEK"
/// bars were Sep 21–27 — long-pressing the "M" bar opened "Edit Sep 21" —
/// and the Day view showed a tall 10 AM bar on a 0-puff day.
///
/// The window was "the last seven LOGGED days", so any day with no log fell
/// out of it and the whole chart slid into the past; the Day view rendered
/// the last logged day's hours rather than today's. Both windows are calendar
/// days now: today's bar is always in the rendered week, an unlogged day is
/// an empty bar you can long-press to fix, and the Day view is today.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final start = DateTime(2026, 9, 1);
  final tueSep29 = DateTime(2026, 9, 29, 10, 15);

  /// The sim's journey on Sep 29: every day logged through Sep 27, with
  /// hour buckets around 10 AM, and NOTHING for Sep 28 or Sep 29.
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
    for (var d = 1; d <= 27; d++) {
      final date = LpDate.addDays(start, d - 1);
      final puffs = (20 - d).clamp(1, 20);
      days[date] = DayLog(
        date: date,
        puffs: puffs,
        limit: 20,
        hourBuckets: puffs == 0 ? const {} : {10: puffs},
        vapeFreeConfirmed: puffs == 0,
      );
    }
    return JourneyState(
      profile: const UserProfile(
        alias: '@simfox',
        avatarEmoji: '🦊',
        tier: SubscriptionTier.premium,
      ),
      plan: plan,
      days: days,
      cravingsSurvivedTotal: 0,
      repairTokens: 0,
      longestStreak: 0,
      goals: const [],
      earnedBadges: const {},
      day1TasksDone: const {0, 1, 2},
    );
  }

  Future<ProviderContainer> pumpStats(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: fastBackendOverrides(now: tueSep29),
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
    container.read(routerProvider).go(Routes.stats);
    await tester.pumpAndSettle();
    expect(find.text(l10n.statsPuffsThisWeek), findsOneWidget);
    return container;
  }

  /// The week bars are the row of `GestureDetector`s with long-press inside
  /// the puffs card; the last one is the newest day.
  Finder weekBars() => find.byWidgetPredicate(
    (w) => w is GestureDetector && w.onLongPress != null,
  );

  testWidgets("today's bar is always in the rendered week", (tester) async {
    await pumpStats(tester);

    final bars = weekBars();
    expect(bars, findsNWidgets(7), reason: 'Tue Sep 23 → Tue Sep 29');

    await tester.longPress(bars.last);
    await tester.pumpAndSettle();

    // Long-pressing the last bar edits TODAY — not Sep 27, and not Sep 21.
    expect(
      find.text(l10n.statsEditDayTitle(LpFormat.mediumDate(tueSep29, 'en'))),
      findsOneWidget,
    );
  });

  testWidgets('an unlogged day is an empty bar that can be fixed', (
    tester,
  ) async {
    // Sep 28 had no log. It is the second-to-last bar, and saving a count
    // for it creates the day — QA H4's broken repair path.
    final container = await pumpStats(tester);
    final sep28 = DateTime(2026, 9, 28);
    expect(container.read(quitStoreProvider)!.days[sep28], isNull);

    final bars = weekBars();
    await tester.longPress(bars.at(5));
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.statsEditDayTitle(LpFormat.mediumDate(sep28, 'en'))),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.commonSave));
    await tester.pumpAndSettle();

    final fixed = container.read(quitStoreProvider)!.days[sep28];
    expect(fixed, isNotNull, reason: 'saving must create the missing day');
    expect(fixed!.puffs, 0);
    expect(fixed.vapeFreeConfirmed, isTrue, reason: 'a typed 0 is their word');
  });

  testWidgets('the Day view is today, and today has no phantom bar', (
    tester,
  ) async {
    await pumpStats(tester);
    await tester.tap(find.text(l10n.statsRangeDay));
    await tester.pumpAndSettle();
    expect(find.text(l10n.statsPuffsToday), findsOneWidget);

    // Every hour bar is zero: nothing was logged today. The old code drew
    // Sep 27's 10 AM bucket here.
    final chart = tester.widget<BarChart>(find.byType(BarChart).first);
    expect(
      chart.values.every((v) => v == 0),
      isTrue,
      reason: chart.values.toString(),
    );
  });

  testWidgets('long-pressing the Day view fixes today, as the caption says', (
    tester,
  ) async {
    await pumpStats(tester);
    await tester.tap(find.text(l10n.statsRangeDay));
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(BarChart).first);
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.statsEditDayTitle(LpFormat.mediumDate(tueSep29, 'en'))),
      findsOneWidget,
    );
  });
}
