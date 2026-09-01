import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/day_window.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';

/// The calendar window behind Stats and the coach's week card (QA M1): the
/// window is days, not logs, so today is always in it and an unlogged day is
/// an empty bar rather than a hole that slides the chart into last week.
void main() {
  final start = DateTime(2026, 9, 1);

  JourneyState journey(Map<int, int> puffsByDay) {
    final plan = QuitPlan(
      method: QuitMethod.taper,
      paceDays: 30,
      startDate: start,
      baselinePuffsPerDay: 20,
      weeklySpend: 14,
      strength: NicStrength.mg50,
    );
    return JourneyState(
      profile: const UserProfile(
        alias: '@x',
        avatarEmoji: '🦊',
        tier: SubscriptionTier.free,
      ),
      plan: plan,
      days: {
        for (final e in puffsByDay.entries)
          LpDate.addDays(start, e.key - 1): DayLog(
            date: LpDate.addDays(start, e.key - 1),
            puffs: e.value,
            limit: 20,
          ),
      },
      cravingsSurvivedTotal: 0,
      repairTokens: 0,
      longestStreak: 0,
      goals: const [],
      earnedBadges: const {},
    );
  }

  test('the last seven calendar days end on today, logged or not', () {
    // Logs through day 27 only; today is day 29 (Tue Sep 29).
    final s = journey({for (var d = 1; d <= 27; d++) d: 5});
    final week = DayWindow.trailing(s, DateTime(2026, 9, 29, 10), 7);

    expect(week.map((l) => l.date), [
      for (var d = 23; d <= 29; d++) DateTime(2026, 9, d),
    ]);
    expect(week.last.puffs, 0);
    expect(week.last.isConfirmed, isFalse, reason: 'empty, not invented');
    expect(week[5].date, DateTime(2026, 9, 28));
    expect(
      week[5].limit,
      s.limitOn(DateTime(2026, 9, 28)),
      reason: 'an empty day carries the limit the plan set that day',
    );
  });

  test('clamps to the first day of the plan', () {
    final s = journey({1: 5, 2: 5, 3: 5});
    final week = DayWindow.trailing(s, DateTime(2026, 9, 3, 12), 7);
    expect(week.length, 3, reason: 'day 3 shows three bars, not seven');
    expect(week.first.date, start);
  });

  test('a month window is thirty calendar days', () {
    final s = journey({for (var d = 1; d <= 30; d++) d: 5});
    final month = DayWindow.trailing(s, DateTime(2026, 10, 5), 30);
    expect(month.length, 30);
    expect(month.first.date, DateTime(2026, 9, 6));
    expect(month.last.date, DateTime(2026, 10, 5));
  });

  test('the previous window is the seven days before, or nothing', () {
    final s = journey({for (var d = 1; d <= 27; d++) d: 5});
    final prev = DayWindow.previous(s, DateTime(2026, 9, 29), 7);
    expect(prev.first.date, DateTime(2026, 9, 16));
    expect(prev.last.date, DateTime(2026, 9, 22));

    expect(
      DayWindow.previous(s, DateTime(2026, 9, 5), 7),
      isEmpty,
      reason: 'no week before the plan began',
    );
  });

  test('walks calendar days across a DST change', () {
    // US falls back 2026-11-01: a window built on absolute hours would land
    // on 23:00 of the wrong date and miss every key.
    final plan = QuitPlan(
      method: QuitMethod.taper,
      paceDays: 90,
      startDate: DateTime(2026, 10, 1),
      baselinePuffsPerDay: 20,
      weeklySpend: 14,
      strength: NicStrength.mg50,
    );
    final days = <DateTime, DayLog>{};
    for (var back = 0; back < 7; back++) {
      final d = LpDate.addDays(DateTime(2026, 11, 4), -back);
      days[d] = DayLog(date: d, puffs: 3, limit: 20);
    }
    final s = JourneyState(
      profile: const UserProfile(
        alias: '@x',
        avatarEmoji: '🦊',
        tier: SubscriptionTier.free,
      ),
      plan: plan,
      days: days,
      cravingsSurvivedTotal: 0,
      repairTokens: 0,
      longestStreak: 0,
      goals: const [],
      earnedBadges: const {},
    );
    final week = DayWindow.trailing(s, DateTime(2026, 11, 4, 9), 7);
    expect(
      week.every((l) => l.puffs == 3),
      isTrue,
      reason: 'every key must be found on both sides of the change',
    );
  });
}
