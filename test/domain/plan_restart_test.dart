import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/day_window.dart';
import 'package:last_puff/domain/logic/money_engine.dart';
import 'package:last_puff/domain/logic/plan_restart.dart';
import 'package:last_puff/domain/logic/streak_engine.dart';
import 'package:last_puff/domain/logic/taper_engine.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// Starting a new plan keeps everything that happened and changes only what
/// happens next.
///
/// Until Nov 2026 a plan that had ended, or stopped fitting, had no next
/// step. Seven people signed out and five of them made a new account to get
/// one — losing their streak, their history, and in one case a paid
/// subscription. "Adjust my plan" was no way out either: past Freedom Day it
/// re-drew the curve from the ORIGINAL baseline over the old runway, so
/// somebody now vaping 80 a day on a finished 200-a-day plan was handed a
/// line of 28.
void main() {
  final now = DateTime(2026, 11, 12, 15, 30);
  final today = LpDate.dayStart(now);

  /// A finished 30-day, 200-a-day taper, five days past its end, still
  /// logging about 80 a day.
  JourneyState finished() {
    final j = journeyOnDay(36, now: now, baseline: 200, weeklySpend: 60);
    final days = {...j.days};
    // The seven days before today, newest first. One of them was clean; the
    // six with puffs average 82.
    const lately = [78, 80, 82, 84, 86, 0, 82];
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
    return j.copyWith(
      days: days,
      cravingsSurvivedTotal: 14,
      earnedBadges: const {'spark', 'weekFlame'},
      pendingSlipCleanDays: () => 0,
    );
  }

  JourneyState restart(
    JourneyState s, {
    QuitMethod method = QuitMethod.taper,
    int paceDays = 21,
    int level = 82,
  }) => PlanRestart.apply(
    s,
    now: now,
    method: method,
    paceDays: paceDays,
    level: level,
  );

  group('the suggested starting level', () {
    test('is the average of the days with puffs among the last seven', () {
      expect(PlanRestart.suggestedLevel(finished(), now), 82);
    });

    test('a clean day in the window is not a level to taper from', () {
      // Six days with puffs and one clean: (78+80+82+84+86+82)/6 = 82. With
      // the clean day counted as a zero it would be 70 — a number the
      // person is not vaping on any day they vape.
      final j = finished();
      expect(j.days[LpDate.addDays(today, -6)]!.puffs, 0, reason: 'fixture');
      expect(PlanRestart.suggestedLevel(j, now), 82);
    });

    test('is null with fewer than three logged days: nothing is guessed', () {
      final j = journeyOnDay(36, now: now, baseline: 200);
      expect(PlanRestart.suggestedLevel(j, now), isNull);
    });

    test('never includes today, which is not over', () {
      final j = finished();
      final withToday = j.copyWith(
        days: {
          ...j.days,
          today: DayLog(date: today, puffs: 400, limit: 0),
        },
      );
      expect(PlanRestart.suggestedLevel(withToday, now), 82);
    });
  });

  group('what the new plan is', () {
    test('day one is today, on the chosen runway, and it is plan two', () {
      final next = restart(finished());

      expect(next.plan.startDate, today);
      expect(next.plan.dayNumber(now), 1);
      expect(next.plan.paceDays, 21);
      expect(next.plan.stretchDays, 0);
      expect(next.plan.totalDays, 21);
      expect(next.plan.planNumber, 2);
      expect(next.plan.freedomDate, LpDate.addDays(today, 20));
    });

    test('the curve starts from where the person is now', () {
      final next = restart(finished());

      expect(next.plan.taperFrom, 82);
      // Day one sits just under the starting level, as it does on a first
      // plan, and the curve still lands on zero.
      expect(TaperEngine.limitFor(next.plan, 1), inInclusiveRange(70, 82));
      expect(TaperEngine.limitFor(next.plan, 21), 0);
      expect(next.limitOn(now), TaperEngine.limitFor(next.plan, 1));
    });

    test('cold turkey is zero from today', () {
      final next = restart(finished(), method: QuitMethod.coldTurkey);

      expect(next.plan.method, QuitMethod.coldTurkey);
      expect(next.limitOn(now), 0);
    });

    test('a first plan is untouched by any of this', () {
      final j = journeyOnDay(5, now: now, baseline: 200);
      expect(j.plan.planNumber, 1);
      expect(j.plan.taperFrom, isNull);
      expect(TaperEngine.limitFor(j.plan, 1), 190); // round(200 × (29/30)^1.5)
    });
  });

  group('what it keeps', () {
    test('every day already lived, exactly as it was', () {
      final before = finished();
      final next = restart(before);

      for (final e in before.days.entries) {
        if (e.key == today) continue;
        expect(next.days[e.key]!.puffs, e.value.puffs);
        expect(next.days[e.key]!.limit, e.value.limit);
        expect(next.days[e.key]!.vapeFreeConfirmed, e.value.vapeFreeConfirmed);
      }
    });

    test('money saved, to the cent — the old habit is still the yardstick', () {
      final before = finished();
      final next = restart(before);

      expect(next.plan.baselinePuffsPerDay, 200);
      expect(next.plan.weeklySpend, 60);
      expect(
        MoneyEngine.lifetimeSaved(next.plan, next.days.values),
        MoneyEngine.lifetimeSaved(before.plan, before.days.values),
      );
      expect(
        MoneyEngine.lifetimeSaved(next.plan, next.days.values),
        greaterThan(0),
        reason: 'fixture: there is something to keep',
      );
    });

    test('the streak, the badges and the cravings beaten', () {
      final before = finished();
      final next = restart(before);

      expect(
        StreakEngine.currentStreak(next.days, now),
        StreakEngine.currentStreak(before.days, now),
      );
      expect(next.earnedBadges, containsAll(before.earnedBadges));
      expect(next.cravingsSurvivedTotal, 14);
      expect(next.lastPuffAt, before.lastPuffAt);
    });

    test('the history Stats draws, back past the new day one', () {
      final next = restart(finished());

      final week = DayWindow.trailing(next, now, 7);
      expect(week, hasLength(7), reason: 'not clamped to the new start');
      expect(week[5].puffs, 78, reason: 'yesterday is still yesterday');
      expect(next.historyStart, isNot(today));
    });
  });

  group('what it clears', () {
    test('the slip waiting to be worked through, and last night\'s advice', () {
      final next = restart(finished());

      expect(next.pendingSlipCleanDays, isNull);
      expect(next.planAdvice, isNull);
    });
  });

  group('today, the day the plan starts on', () {
    test('a morning already over the new line is not born a slip', () {
      // 120 logged before deciding; the new day-one line would be ~76.
      final j = finished();
      final withToday = j.copyWith(
        days: {
          ...j.days,
          today: DayLog(date: today, puffs: 120, limit: 0),
        },
      );
      final next = restart(withToday);

      expect(next.days[today]!.puffs, 120);
      expect(next.days[today]!.limit, 120, reason: 'the line holds here');
      expect(next.days[today]!.isOverLimit, isFalse);
    });

    test('and that held line is the one Home, the widget and the streak all '
        'read', () {
      // Written only onto the day log, it reached the streak engine and
      // nothing else: Home opened day one of a fresh plan on a red ring and
      // "over today's line" while the streak counted the day as held.
      final j = finished();
      final withToday = j.copyWith(
        days: {
          ...j.days,
          today: DayLog(date: today, puffs: 120, limit: 0),
        },
      );
      final next = restart(withToday);

      expect(next.limitOn(now), 120);
      final snap = TodaySnapshot.of(next, now);
      expect(snap.limit, 120);
      expect(snap.isOverLimit, isFalse);
      // Only today. Tomorrow is the curve's own second day.
      final tomorrow = LpDate.addDays(today, 1);
      expect(next.limitOn(tomorrow), TaperEngine.limitFor(next.plan, 2));
    });

    test('cold turkey with puffs already logged holds there too', () {
      final j = finished();
      final withToday = j.copyWith(
        days: {
          ...j.days,
          today: DayLog(date: today, puffs: 20, limit: 0),
        },
      );
      final next = restart(withToday, method: QuitMethod.coldTurkey);

      expect(next.limitOn(now), 20);
      expect(TodaySnapshot.of(next, now).isOverLimit, isFalse);
      expect(next.limitOn(LpDate.addDays(today, 1)), 0);
    });

    test('a first plan\'s day one is its curve, whatever the log says', () {
      // The rule is for a plan started again. A first day one whose stored
      // limit disagrees with the curve (an Adjust the same afternoon) keeps
      // reading the live curve, as it always has.
      final j = journeyOnDay(1, now: now, baseline: 200);
      final odd = j.copyWith(
        days: {today: DayLog(date: today, puffs: 0, limit: 999)},
      );
      expect(odd.limitOn(now), TaperEngine.limitFor(odd.plan, 1));
    });

    test('an unlogged day before the new plan is not handed its line', () {
      // Back-filling a day that came before the restart used to read the
      // new plan's day-one limit — 76 for a day the old plan held at zero —
      // and 50 puffs entered there "held" a streak nobody lived.
      final next = restart(finished());

      expect(next.limitOn(LpDate.addDays(today, -10)), 0);
    });

    test('and one under it gets the new day-one line', () {
      final j = finished();
      final withToday = j.copyWith(
        days: {
          ...j.days,
          today: DayLog(date: today, puffs: 10, limit: 0),
        },
      );
      final next = restart(withToday);

      expect(next.days[today]!.limit, TaperEngine.limitFor(next.plan, 1));
    });
  });
}
