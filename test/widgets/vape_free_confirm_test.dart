import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/core/utils/lp_format.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/stats/edit_day_sheet.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// QA H4 (Aug 31 2026 sim): a zero-puff day whose evening never saw an app
/// open silently zeroed a 21-day streak — on the plan's own 0-limit tail
/// days, where zero puffs IS the goal. The "Confirm vape-free day" card was
/// evening-only (hour >= 20), and the next morning there was no notice and
/// no way back.
///
/// Two rules now: on a 0-limit day the confirm card is there all day, and
/// the morning after an unconfirmed day Home ASKS "was yesterday vape-free?"
/// — it never assumes. Either answer is the user's own word.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final start = DateTime(2026, 9, 1);

  /// B=20/30-day plan (the sim's fixture) with [cleanDays] completed clean
  /// days from day 1, viewed at [now].
  JourneyState journeyAt(DateTime now, {required int cleanDays}) {
    final plan = QuitPlan(
      method: QuitMethod.taper,
      paceDays: 30,
      startDate: start,
      baselinePuffsPerDay: 20,
      weeklySpend: 14,
      strength: NicStrength.mg50,
    );
    final days = <DateTime, DayLog>{};
    for (var d = 1; d <= cleanDays; d++) {
      final date = LpDate.addDays(start, d - 1);
      final limit = JourneyState(
        profile: const UserProfile(
          alias: '@x',
          avatarEmoji: '🦊',
          tier: SubscriptionTier.free,
        ),
        plan: plan,
        days: const {},
        cravingsSurvivedTotal: 0,
        repairTokens: 0,
        longestStreak: 0,
        goals: const [],
        earnedBadges: const {},
      ).limitOn(date);
      days[date] = DayLog(
        date: date,
        puffs: limit > 0 ? limit : 0,
        limit: limit,
        vapeFreeConfirmed: limit == 0,
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

  Future<ProviderContainer> pumpHome(
    WidgetTester tester, {
    required DateTime now,
    required JourneyState journey,
  }) async {
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
    expect(find.text(l10n.homeLogPuff), findsOneWidget);
    return container;
  }

  group('the confirm card on a 0-limit day', () {
    // Day 29 of 30 at B=20: the curve is 0 (verified by hand in the sim).
    final day29 = DateTime(2026, 9, 29, 10, 15);

    testWidgets('is there in the morning, not only in the evening', (
      tester,
    ) async {
      final container = await pumpHome(
        tester,
        now: day29,
        journey: journeyAt(day29, cleanDays: 28),
      );
      expect(container.read(todayProvider)!.limit, 0, reason: 'fixture');

      expect(find.text(l10n.homeVapeFreeTitle), findsOneWidget);

      await tester.tap(find.text(l10n.homeVapeFreeCta));
      await tester.pump();
      final today = container.read(quitStoreProvider)!.logFor(day29);
      expect(today?.vapeFreeConfirmed, isTrue);
      expect(container.read(todayProvider)!.streak, 29);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a non-zero day keeps the evening rule', (tester) async {
      // Day 5 at 10:15: the line is 15, the day is wide open — confirming
      // "no puffs today" at breakfast would be a guess about the evening.
      final day5 = DateTime(2026, 9, 5, 10, 15);
      final container = await pumpHome(
        tester,
        now: day5,
        journey: journeyAt(day5, cleanDays: 4),
      );
      expect(container.read(todayProvider)!.limit, greaterThan(0));

      expect(find.text(l10n.homeVapeFreeTitle), findsNothing);
    });
  });

  group('the morning after an unconfirmed day', () {
    // Day 28 had no log at all (a perfect zero day nobody confirmed);
    // day 29 at 09:00.
    final day29 = DateTime(2026, 9, 29, 9);
    final day28 = DateTime(2026, 9, 28);

    testWidgets('asks, and "vape-free" confirms yesterday', (tester) async {
      final container = await pumpHome(
        tester,
        now: day29,
        journey: journeyAt(day29, cleanDays: 27),
      );
      expect(container.read(quitStoreProvider)!.days[day28], isNull);
      // Without an answer the chain is broken at day 28.
      expect(container.read(todayProvider)!.streak, 0);

      expect(find.text(l10n.homeYesterdayTitle), findsOneWidget);
      expect(
        find.text(l10n.homeYesterdayBody(LpFormat.mediumDate(day28, 'en'))),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.homeYesterdayYes));
      await tester.pump();

      final yesterday = container.read(quitStoreProvider)!.days[day28];
      expect(yesterday?.vapeFreeConfirmed, isTrue);
      expect(yesterday?.puffs, 0);
      expect(
        container.read(todayProvider)!.streak,
        28,
        reason: 'the 27 clean days plus yesterday, anchored from yesterday',
      );
      expect(find.text(l10n.homeYesterdayTitle), findsNothing);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('"I vaped" opens the editor for yesterday and keeps its word', (
      tester,
    ) async {
      final container = await pumpHome(
        tester,
        now: day29,
        journey: journeyAt(day29, cleanDays: 27),
      );

      await tester.tap(find.text(l10n.homeYesterdayNo));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.statsEditDayTitle(LpFormat.mediumDate(day28, 'en'))),
        findsOneWidget,
      );
      // Three puffs on a 0-limit day: over the line, honestly.
      final plus = find.widgetWithIcon(PressScaleIcon, Icons.add_rounded);
      await tester.tap(plus);
      await tester.tap(plus);
      await tester.tap(plus);
      await tester.pump();
      await tester.tap(find.text(l10n.commonSave));
      await tester.pumpAndSettle();

      final yesterday = container.read(quitStoreProvider)!.days[day28];
      expect(yesterday?.puffs, 3);
      expect(yesterday?.isConfirmed, isTrue);
      expect(find.text(l10n.homeYesterdayTitle), findsNothing);
    });

    testWidgets('does not ask about a day before the plan started', (
      tester,
    ) async {
      // Day 1 at 09:00: there is no "yesterday" on this plan.
      final day1 = DateTime(2026, 9, 1, 9);
      await pumpHome(tester, now: day1, journey: journeyAt(day1, cleanDays: 0));

      expect(find.text(l10n.homeYesterdayTitle), findsNothing);
    });
  });
}
