import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/core/utils/lp_format.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/journey_factory.dart';
import 'package:last_puff/domain/logic/money_engine.dart';
import 'package:last_puff/domain/logic/taper_engine.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// `TodaySnapshot` — the one object Home, the coach header, the widget mirror
/// and the memories facts all read their numbers from — pinned day by day.
///
/// PARITY SUITE: the first case is the Sep 5 2026 screenshot journey, and its
/// twin lives in `functions/test/memoryCard.test.ts` ("the day and the money,
/// exactly as Home shows them"). Change one, change both.
void main() {
  final sep5 = DateTime(2026, 9, 5, 14, 12);

  /// Sat Sep 5 2026, 14:12: day 2 of a 30-day taper from 100 puffs/day at $30
  /// a week, 36 puffs logged on day 1, nothing yet today.
  JourneyState screenshot() => journeyOnDay(
    2,
    now: sep5,
    puffsByDay: {1: 36},
    lastPuffAt: DateTime(2026, 9, 4, 20, 10),
  );

  test('the fixture is on the engine curve', () {
    final plan = screenshot().plan;
    expect(TaperEngine.limitFor(plan, 1), 95);
    expect(TaperEngine.limitFor(plan, 2), 90);
  });

  test('the Sep 5 screenshot: Day 2 of 30, 0 of 90, 1-day streak, \$3', () {
    final snap = TodaySnapshot.of(screenshot(), sep5);
    expect(snap.dayNumber, 2);
    expect(snap.totalDays, 30);
    expect(snap.limit, 90);
    expect(snap.puffs, 0);
    expect(snap.puffsLeft, 90);
    expect(snap.isOverLimit, isFalse);
    // Day 1 held under its line; today is unconfirmed so the walk anchors on
    // yesterday. "🔥 1 day" beside "Day 2 of 30" is correct, not a mismatch.
    expect(snap.streak, 1);
    expect(snap.flame, FlameState.spark);
    // 64 puffs under a 100 baseline at $30/week = $2.742857…
    expect(snap.savedLifetime, closeTo(64 * 30 / 700, 1e-9));
    expect(LpFormat.money(snap.savedLifetime, 'en'), r'$3');
    expect(snap.puffsNotTaken, 64);
    expect(snap.savedRunRatePerDay, closeTo(64 * 30 / 700, 1e-9));
    expect(snap.vsDay1Percent, 0, reason: 'one completed day is not a trend');
    expect(snap.dangerWindow, isNull);
    expect(snap.daysToFreedom, 28);
    expect(snap.isFreedomDay, isFalse);
    expect(snap.isMaintenance, isFalse);
  });

  test('rounds money the way the coach card does', () {
    // 100 puffs/day at $35/week is 5¢ a puff; a 50-puff day keeps exactly
    // $2.50 and rounds half away from zero to $3 on both sides of the seam.
    final half = journeyOnDay(2, now: sep5, weeklySpend: 35, puffsByDay: {1: 50});
    expect(TodaySnapshot.of(half, sep5).savedLifetime, closeTo(2.5, 1e-9));
    expect(LpFormat.money(TodaySnapshot.of(half, sep5).savedLifetime, 'en'), r'$3');
    // 56 under at 3/70 a puff = 2.4 → $2.
    final under = journeyOnDay(2, now: sep5, puffsByDay: {1: 44});
    expect(LpFormat.money(TodaySnapshot.of(under, sep5).savedLifetime, 'en'), r'$2');
  });

  test('day 1 with the factory log: nothing saved, nothing not taken', () {
    // `InitialJourney` mints today as a 0-puff unconfirmed log. It used to
    // read "$4 saved so far · 100 puffs not taken" on Home before the first
    // tap — a projection dressed as a result.
    final sep4 = DateTime(2026, 9, 4, 15);
    final fresh = InitialJourney.build(
      profile: const UserProfile(alias: '@newfox', avatarEmoji: '🦊'),
      plan: screenshot().plan,
      now: sep4,
    );
    final snap = TodaySnapshot.of(fresh, sep4);
    expect(snap.dayNumber, 1);
    expect(snap.limit, 95);
    expect(snap.puffs, 0);
    expect(snap.streak, 0);
    expect(snap.savedLifetime, 0);
    expect(snap.puffsNotTaken, 0);
    expect(snap.savedRunRatePerDay, 0);
    expect(snap.isOverLimit, isFalse);
  });

  test('an unconfirmed zero day in history saves nothing', () {
    final s = journeyOnDay(3, now: DateTime(2026, 9, 6, 9), puffsByDay: {1: 36});
    final day2 = LpDate.addDays(s.plan.startDate, 1);
    final unknown = s.copyWith(
      days: {...s.days, day2: s.days[day2]!.copyWith(puffs: 0)},
    );
    expect(unknown.days[day2]!.isConfirmed, isFalse);
    final snap = TodaySnapshot.of(unknown, DateTime(2026, 9, 6, 9));
    expect(snap.savedLifetime, closeTo(64 * 30 / 700, 1e-9));
    expect(snap.savedRunRatePerDay, closeTo(64 * 30 / 700, 1e-9));
    expect(snap.streak, 0, reason: 'the unknown day broke the chain');
  });

  test('a future-dated log is excluded from money', () {
    // A clock that was wrong when a puff was filed. Money already "saved" on
    // a day that has not happened is the invented number in its purest form.
    final s = screenshot();
    final future = LpDate.addDays(LpDate.dayStart(sep5), 1);
    final withFuture = s.copyWith(
      days: {
        ...s.days,
        future: DayLog(
          date: future,
          puffs: 0,
          limit: 85,
          vapeFreeConfirmed: true,
        ),
      },
    );
    final snap = TodaySnapshot.of(withFuture, sep5);
    expect(snap.savedLifetime, closeTo(64 * 30 / 700, 1e-9));
    expect(snap.puffsNotTaken, 64);
    expect(snap.dayNumber, 2);
  });

  test('day 30 is Freedom Day, with a zero line', () {
    final now = DateTime(2026, 10, 3, 9);
    final snap = TodaySnapshot.of(journeyOnDay(30, now: now), now);
    expect(snap.dayNumber, 30);
    expect(snap.isFreedomDay, isTrue);
    expect(snap.isMaintenance, isFalse);
    expect(snap.limit, 0);
    expect(snap.daysPastPlan, 0);
    expect(snap.daysToFreedom, 0);
    expect(snap.streak, 29, reason: 'every day before it held its line');
  });

  test('day 31 is maintenance, never "Day 31 of 30"', () {
    final now = DateTime(2026, 10, 4, 9);
    final snap = TodaySnapshot.of(journeyOnDay(31, now: now), now);
    expect(snap.dayNumber, 31);
    expect(snap.isMaintenance, isTrue);
    expect(snap.isFreedomDay, isFalse);
    expect(snap.daysPastPlan, 1);
    expect(snap.limit, 0);
    expect(snap.daysToFreedom, 0, reason: 'clamped, never negative');
    expect(snap.streak, 30);
  });

  test('the run rate is over the last seven completed days', () {
    final now = DateTime(2026, 9, 12, 9);
    final s = journeyOnDay(9, now: now);
    final snap = TodaySnapshot.of(s, now);
    final completed = s.days.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    // Days 2–8, not day 1.
    final lastSeven = completed.sublist(completed.length - 7);
    expect(lastSeven.first.date, LpDate.addDays(s.plan.startDate, 1));
    expect(
      snap.savedRunRatePerDay,
      closeTo(MoneyEngine.dailyRunRate(s.plan, lastSeven), 1e-9),
    );
  });

  test('vs day 1 compares the latest completed day to the first', () {
    final now = DateTime(2026, 9, 8, 9);
    final s = journeyOnDay(5, now: now, puffsByDay: {1: 100, 4: 60});
    expect(TodaySnapshot.of(s, now).vsDay1Percent, -40);
    final up = journeyOnDay(5, now: now, puffsByDay: {1: 50, 4: 60});
    expect(TodaySnapshot.of(up, now).vsDay1Percent, 20);
    // A day 1 with nothing logged has no baseline to compare against.
    final zero = journeyOnDay(5, now: now, puffsByDay: {1: 0, 4: 60});
    expect(TodaySnapshot.of(zero, now).vsDay1Percent, 0);
  });
}
