import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/money_engine.dart';
import 'package:last_puff/domain/logic/streak_engine.dart';
import 'package:last_puff/domain/models/models.dart';

DayLog log(
  DateTime date, {
  required int puffs,
  required int limit,
  bool token = false,
  bool vapeFree = false,
}) => DayLog(
  date: date,
  puffs: puffs,
  limit: limit,
  repairTokenUsed: token,
  vapeFreeConfirmed: vapeFree,
);

void main() {
  final today = DateTime(2026, 8, 16);
  DateTime day(int offset) => today.subtract(Duration(days: offset));

  group('StreakEngine', () {
    test('counts consecutive confirmed under-limit days', () {
      final days = {
        day(2): log(day(2), puffs: 80, limit: 100),
        day(1): log(day(1), puffs: 90, limit: 100),
        day(0): log(day(0), puffs: 10, limit: 100),
      };
      expect(StreakEngine.currentStreak(days, today), 3);
    });

    test('a repair token keeps an over-limit day alive', () {
      final days = {
        day(2): log(day(2), puffs: 80, limit: 100),
        day(1): log(day(1), puffs: 130, limit: 100, token: true),
        day(0): log(day(0), puffs: 10, limit: 100),
      };
      expect(StreakEngine.currentStreak(days, today), 3);
    });

    test('over limit without a token breaks the streak', () {
      final days = {
        day(2): log(day(2), puffs: 80, limit: 100),
        day(1): log(day(1), puffs: 130, limit: 100),
        day(0): log(day(0), puffs: 10, limit: 100),
      };
      expect(StreakEngine.currentStreak(days, today), 1);
    });

    test('a zero-puff day counts only when confirmed', () {
      final unconfirmed = {day(0): log(day(0), puffs: 0, limit: 100)};
      expect(StreakEngine.currentStreak(unconfirmed, today), 0);
      final confirmed = {
        day(0): log(day(0), puffs: 0, limit: 100, vapeFree: true),
      };
      expect(StreakEngine.currentStreak(confirmed, today), 1);
    });

    test('an unconfirmed in-progress today dims, never zeroes, the flame', () {
      // Day 2 mid-morning: yesterday was clean, today has no puffs and no
      // vape-free confirmation yet — the chain must survive from yesterday.
      final days = {
        day(1): log(day(1), puffs: 1, limit: 76),
        day(0): log(day(0), puffs: 0, limit: 72),
      };
      expect(StreakEngine.currentStreak(days, today), 1);
      // A slip today without a token also anchors to yesterday.
      final slipped = {
        day(1): log(day(1), puffs: 1, limit: 76),
        day(0): log(day(0), puffs: 90, limit: 72),
      };
      expect(StreakEngine.currentStreak(slipped, today), 1);
    });

    test('a streak survives a DST change in both directions', () {
      // Parity case with functions/test/streakEngine.test.ts.
      //
      // The day map is keyed by LOCAL midnight, so the walk backwards has to
      // be calendar arithmetic. `cursor.subtract(const Duration(days: 1))`
      // subtracts 24 ABSOLUTE hours, which on a transition day lands on 23:00
      // or 01:00 of the previous date — not a key — so the lookup returned
      // null and the streak silently reset to 0. It cost every user in a DST
      // zone their Freedom Streak twice a year.
      //
      // EU falls back 2026-10-25 and the US 2026-11-01, ten and seventeen days
      // after the Oct 15 2026 launch, so the first paying cohort walks into it.
      for (final anchor in [
        DateTime(2026, 11, 4), // US fall back, 2026-11-01
        DateTime(2026, 10, 28), // EU fall back, 2026-10-25
        DateTime(2026, 3, 11), // US spring forward, 2026-03-08
        DateTime(2026, 4, 1), // EU spring forward, 2026-03-29
      ]) {
        final days = <DateTime, DayLog>{};
        for (var back = 0; back < 10; back++) {
          final d = LpDate.addDays(anchor, -back);
          days[d] = log(d, puffs: 10, limit: 100);
        }
        expect(
          StreakEngine.currentStreak(days, anchor),
          10,
          reason: 'streak broke across the DST change near $anchor',
        );
      }
    });

    test('flame states follow the docs thresholds', () {
      expect(FlameState.forStreak(1), FlameState.spark);
      expect(FlameState.forStreak(3), FlameState.flicker);
      expect(FlameState.forStreak(7), FlameState.flame);
      expect(FlameState.forStreak(14), FlameState.blaze);
      expect(FlameState.forStreak(30), FlameState.inferno);
    });
  });

  group('MoneyEngine', () {
    final plan = QuitPlan(
      method: QuitMethod.taper,
      paceDays: 30,
      startDate: DateTime(2026, 8, 4),
      baselinePuffsPerDay: 200,
      weeklySpend: 42,
      strength: NicStrength.mg50,
    );

    test('costPerPuff derives from the weekly spend', () {
      expect(plan.costPerPuff, closeTo(42 / 1400, 1e-9));
    });

    test('savedOn is max(0, B − actual) × costPerPuff', () {
      final under = log(day(0), puffs: 100, limit: 120);
      expect(
        MoneyEngine.savedOn(plan, under),
        closeTo(100 * plan.costPerPuff, 1e-9),
      );
      final over = log(day(0), puffs: 260, limit: 120);
      expect(MoneyEngine.savedOn(plan, over), 0);
    });

    test('puffsNotTaken ignores over-baseline days', () {
      final logs = [
        log(day(1), puffs: 150, limit: 160),
        log(day(0), puffs: 250, limit: 160),
      ];
      expect(MoneyEngine.puffsNotTaken(plan, logs), 50);
    });
  });

  group('DependenceLevel', () {
    test('badge thresholds match docs/02 B2', () {
      expect(DependenceLevel.forPuffs(50), DependenceLevel.light);
      expect(DependenceLevel.forPuffs(51), DependenceLevel.moderate);
      expect(DependenceLevel.forPuffs(150), DependenceLevel.moderate);
      expect(DependenceLevel.forPuffs(151), DependenceLevel.heavy);
      expect(DependenceLevel.forPuffs(300), DependenceLevel.heavy);
      expect(DependenceLevel.forPuffs(301), DependenceLevel.severe);
    });
  });
}
