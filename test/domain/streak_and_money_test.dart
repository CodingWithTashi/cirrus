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

    group('repairTokens — the wallet is derived from history', () {
      // QA H2 (Aug 31 2026 30-day sim): over-limit days 15, 20, 21 and 22
      // ALL absorbed "Repair token used". The wallet was re-derived as
      // `streak ~/ 7` on every mutation, so a spent token was re-minted the
      // moment the next commit ran. Spec (docs/03 §5): 1 token per 7
      // consecutive streak-days, wallet cap 2, one over-limit day per token.
      //
      // Parity cases with functions/test/streakEngine.test.ts.
      //
      // Chains end YESTERDAY: a token is earned by finishing a day, so the
      // wallet on `today` is a function of the completed days before it.
      Map<DateTime, DayLog> chain(
        int length, {
        DateTime? endingAt,
        Map<int, ({int puffs, bool token})> overrides = const {},
        Set<int> unlogged = const {},
      }) {
        final end = endingAt ?? day(1);
        final days = <DateTime, DayLog>{};
        for (var i = 1; i <= length; i++) {
          if (unlogged.contains(i)) continue;
          final d = LpDate.addDays(end, i - length);
          final o = overrides[i];
          days[d] = log(
            d,
            puffs: o?.puffs ?? 10,
            limit: 100,
            token: o?.token ?? false,
          );
        }
        return days;
      }

      test('mints one token per seven holding days, capped at two', () {
        expect(StreakEngine.repairTokens(chain(6), today), 0);
        expect(StreakEngine.repairTokens(chain(7), today), 1);
        expect(StreakEngine.repairTokens(chain(13), today), 1);
        expect(StreakEngine.repairTokens(chain(14), today), 2);
        expect(StreakEngine.repairTokens(chain(21), today), 2, reason: 'cap');
        expect(StreakEngine.repairTokens(chain(28), today), 2, reason: 'cap');
      });

      test('a spent token stays spent', () {
        // Seven clean days mint one; day 8 burns it. Day 8 still holds (the
        // flame dims, it does not die) — but the wallet is empty now.
        final days = chain(8, overrides: {8: (puffs: 130, token: true)});
        expect(StreakEngine.currentStreak(days, today), 8);
        expect(StreakEngine.repairTokens(days, today), 0);
      });

      test('today can spend a token but never mint one', () {
        // Six completed days plus today: the seventh day is not finished, so
        // nothing is earned yet — today over the line has nothing to spend.
        final seventh = chain(7, endingAt: today);
        expect(StreakEngine.repairTokens(seventh, today), 0);
        // Seven completed days and today used the token they earned.
        final spentToday = {
          ...chain(7),
          today: log(today, puffs: 130, limit: 100, token: true),
        };
        expect(StreakEngine.currentStreak(spentToday, today), 8);
        expect(StreakEngine.repairTokens(spentToday, today), 0);
      });

      test('the QA 22-day scenario funds exactly two absorbs', () {
        // Days 1–14 clean → two tokens. Day 15 over + token → one left.
        // Day 20 over + token → none left. Day 21 over: NOTHING left to
        // absorb it with — the chain breaks there, honestly. (Minting on
        // day 21 itself would have funded a third — see the test above.)
        final days = chain(
          22,
          endingAt: today,
          overrides: {
            15: (puffs: 130, token: true),
            20: (puffs: 130, token: true),
            21: (puffs: 130, token: false),
            22: (puffs: 130, token: false),
          },
        );
        DateTime planDay(int d) => LpDate.addDays(today, d - 22);
        Map<DateTime, DayLog> upTo(int d) => Map.fromEntries(
          days.entries.where((e) => !e.key.isAfter(planDay(d))),
        );
        expect(StreakEngine.repairTokens(upTo(15), planDay(15)), 1);
        expect(StreakEngine.repairTokens(upTo(20), planDay(20)), 0);
        expect(
          StreakEngine.repairTokens(upTo(21), planDay(21)),
          0,
          reason: 'nothing funds a third absorb on day 21',
        );
        expect(StreakEngine.repairTokens(days, today), 0);
        expect(StreakEngine.currentStreak(days, today), 0);
      });

      test('an unspent wallet survives a break in the chain', () {
        // Seven clean days mint one; day 8 goes unlogged (the chain breaks);
        // day 9 is clean again. The token was earned and never spent — it is
        // still there for the new chain.
        final days = chain(9, unlogged: {8});
        expect(StreakEngine.currentStreak(days, today), 1);
        expect(StreakEngine.repairTokens(days, today), 1);
      });

      test('a new chain after a break mints on its own seventh day', () {
        // 7 clean (mint) + 1 unlogged + 7 clean (mint again) → 2.
        final days = chain(15, unlogged: {8});
        expect(StreakEngine.repairTokens(days, today), 2);
      });

      test('a token used with no history to fund it counts as zero', () {
        // Journeys written under the old leak carry `repairTokenUsed` days
        // the wallet could never have funded. The day still holds — nobody
        // loses a streak over our bug — but the wallet does not go negative.
        final days = {day(0): log(day(0), puffs: 130, limit: 100, token: true)};
        expect(StreakEngine.currentStreak(days, today), 1);
        expect(StreakEngine.repairTokens(days, today), 0);
      });
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
