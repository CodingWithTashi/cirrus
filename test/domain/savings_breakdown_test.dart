import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/savings_breakdown.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// The numbers behind the savings (i) (docs/10 §40).
///
/// Every figure here is one the Home and Money screens already show, taken
/// from the same engine — the sheet explains a number, it never computes a
/// second one. The plan is the helper's: 100 puffs a day at $30 a week, so a
/// usual day costs $4.29 and a puff about 4.3¢.
void main() {
  final now = DateTime(2026, 9, 13, 10, 0);
  final todayKey = JourneyState.dateKey(now);

  SavingsBreakdown of(JourneyState journey) =>
      SavingsBreakdown.of(journey, TodaySnapshot.of(journey, now));

  JourneyState dayOneWith({int puffs = 0, bool vapeFree = false}) {
    final j = journeyOnDay(1, now: now);
    return j.copyWith(
      days: {
        ...j.days,
        todayKey: DayLog(
          date: todayKey,
          puffs: puffs,
          limit: 95,
          vapeFreeConfirmed: vapeFree,
        ),
      },
    );
  }

  test('day one before any log: today is not counted, nothing is saved', () {
    final b = of(journeyOnDay(1, now: now));
    expect(b.today, TodaySavings.notCounted);
    expect(b.total, 0);
    expect(b.todaySaved, 0);
    expect(b.todayNotTaken, 0);
    expect(b.usualPuffs, 100);
    expect(b.usualDaySpend, closeTo(30 / 7, 1e-9));
  });

  test(
    'the unconfirmed zero-puff log onboarding mints is still not counted',
    () {
      final b = of(dayOneWith());
      expect(b.today, TodaySavings.notCounted);
      expect(b.total, 0);
    },
  );

  test('the first puff counts the day: puffs not taken are money kept', () {
    final b = of(dayOneWith(puffs: 12));
    expect(b.today, TodaySavings.kept);
    expect(b.todayPuffs, 12);
    expect(b.todayNotTaken, 88);
    expect(b.todaySaved, closeTo(88 * 30 / 700, 1e-9));
    expect(
      b.total,
      closeTo(b.todaySaved, 1e-9),
      reason: 'day one is the total',
    );
  });

  test('at or over the usual day, today keeps nothing', () {
    for (final puffs in [100, 120]) {
      final b = of(dayOneWith(puffs: puffs));
      expect(b.today, TodaySavings.nothingKept, reason: '$puffs puffs');
      expect(b.todaySaved, 0);
      expect(b.todayNotTaken, 0);
    }
  });

  test('a confirmed vape-free day keeps the whole usual day', () {
    final b = of(dayOneWith(vapeFree: true));
    expect(b.today, TodaySavings.kept);
    expect(b.todayNotTaken, 100);
    expect(b.todaySaved, closeTo(30 / 7, 1e-9));
  });

  test('the total is the figure Home shows, completed days included', () {
    final j = journeyOnDay(3, now: now, puffsByDay: {1: 40, 2: 60});
    final b = of(j);
    expect(b.today, TodaySavings.notCounted);
    expect(b.total, closeTo((60 + 40) * 30 / 700, 1e-9));
    expect(b.total, TodaySnapshot.of(j, now).savedLifetime);
  });

  test('a plan with no weekly spend has nothing to price', () {
    expect(
      of(journeyOnDay(1, now: now, weeklySpend: 0)).today,
      TodaySavings.unpriced,
    );
  });
}
