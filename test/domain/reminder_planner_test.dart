import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/reminder_planner.dart';
import 'package:last_puff/domain/models/models.dart';

DayLog log(DateTime date, Map<int, int> buckets) => DayLog(
  date: date,
  puffs: buckets.values.fold(0, (a, b) => a + b),
  limit: 100,
  hourBuckets: buckets,
);

/// docs/03 §8. These rules decide whether the app reads as a helpful friend or
/// as spam, so they are worth pinning precisely.
void main() {
  final base = DateTime(2026, 8, 20);
  List<DayLog> days(Map<int, int> buckets, {int count = 5}) => [
    for (var i = 0; i < count; i++) log(base.subtract(Duration(days: i)), buckets),
  ];

  group('riskiestHours', () {

    test('stays silent until there are enough days to know anything', () {
      // Two days is a hunch, not a pattern.
      final thin = days({21: 30}, count: 2);
      expect(ReminderPlanner.riskiestHours(thin), isEmpty);
    });

    test('picks the top two hour buckets', () {
      final logs = days({9: 5, 14: 2, 21: 30, 22: 18});
      expect(ReminderPlanner.riskiestHours(logs), [21, 22]);
    });

    test('breaks ties on the earlier hour so the plan is stable', () {
      final logs = days({20: 10, 8: 10});
      expect(ReminderPlanner.riskiestHours(logs), [8, 20]);
    });

    test('ignores hours with no puffs at all', () {
      final logs = days({21: 12, 3: 0});
      expect(ReminderPlanner.riskiestHours(logs), [21]);
    });
  });

  group('plan', () {
    test('fires ten minutes before the risky hour, not during it', () {
      final slots = ReminderPlanner.plan(
        logs: days({21: 30}),
        quietStartHour: 23,
        quietEndHour: 8,
        notificationsOn: true,
      );

      expect(slots, hasLength(1));
      expect(slots.single.hour, 20);
      expect(slots.single.minute, 50);
    });

    test('never schedules anything when notifications are off', () {
      final slots = ReminderPlanner.plan(
        logs: days({21: 30}),
        quietStartHour: 23,
        quietEndHour: 8,
        notificationsOn: false,
      );
      expect(slots, isEmpty);
    });

    // Shifting a 2am nudge to 8am would fire it nine hours after the craving
    // it was meant to precede. Dropping it is the kinder failure.
    test('drops a reminder that lands inside quiet hours', () {
      final slots = ReminderPlanner.plan(
        logs: days({2: 40}),
        quietStartHour: 23,
        quietEndHour: 8,
        notificationsOn: true,
      );
      expect(slots, isEmpty);
    });

    test('keeps a reminder just outside the quiet window', () {
      // 23:00 risk → fires 22:50, which is still before quiet hours begin.
      final slots = ReminderPlanner.plan(
        logs: days({23: 40}),
        quietStartHour: 23,
        quietEndHour: 8,
        notificationsOn: true,
      );
      expect(slots.single.hour, 22);
      expect(slots.single.minute, 50);
    });

    test('wraps backwards past midnight', () {
      final slots = ReminderPlanner.plan(
        logs: days({0: 40}),
        quietStartHour: 3,
        quietEndHour: 4,
        notificationsOn: true,
      );
      expect(slots.single.hour, 23);
      expect(slots.single.minute, 50);
    });

    test('falls back to the onboarding answer before data exists', () {
      final slots = ReminderPlanner.plan(
        logs: days({21: 30}, count: 1),
        quietStartHour: 23,
        quietEndHour: 8,
        notificationsOn: true,
        fallbackHour: 9,
      );
      expect(slots.single.hour, 8);
      expect(slots.single.minute, 50);
    });

    test('gives each hour a stable id so a reschedule replaces, not stacks', () {
      final first = ReminderPlanner.plan(
        logs: days({21: 30, 14: 10}),
        quietStartHour: 23,
        quietEndHour: 8,
        notificationsOn: true,
      );
      final again = ReminderPlanner.plan(
        logs: days({21: 31, 14: 11}),
        quietStartHour: 23,
        quietEndHour: 8,
        notificationsOn: true,
      );

      expect(
        first.map((s) => s.id).toList(),
        again.map((s) => s.id).toList(),
      );
    });

    test('never exceeds the daily cap', () {
      final slots = ReminderPlanner.plan(
        logs: days({9: 40, 13: 38, 17: 36, 20: 34}),
        quietStartHour: 23,
        quietEndHour: 8,
        notificationsOn: true,
      );
      expect(slots.length, lessThanOrEqualTo(ReminderPlanner.maxPerDay));
    });
  });

  group('the Settings sheet promises only what will fire', () {
    // Sep 1 field test (docs/09 issue 5): the old editor let you save a
    // midnight start whose nudge quiet hours then dropped, and printed a
    // "max 3 pushes" note that belonged to the detected mode. The sheet now
    // draws its choices and its exact time from these two helpers, so it
    // cannot drift from the scheduler.
    test('fires ten minutes before the hour, wrapping past midnight', () {
      expect(ReminderPlanner.fireTimeFor(21), (20, 50));
      expect(ReminderPlanner.fireTimeFor(9), (8, 50));
      expect(ReminderPlanner.fireTimeFor(0), (23, 50));
    });

    test('offers 9am through 11pm under the default quiet hours', () {
      final hours = ReminderPlanner.eligibleStartHours(
        quietStartHour: 23,
        quietEndHour: 8,
      );
      expect(hours, [for (var h = 9; h <= 23; h++) h]);
      // 8am is out because its nudge (7:50am) is still inside quiet hours;
      // midnight is out because 11:50pm is.
      expect(hours, isNot(contains(8)));
      expect(hours, isNot(contains(0)));
    });

    test('every offered hour really schedules, and no other hour does', () {
      const quietStart = 23;
      const quietEnd = 8;
      final offered = ReminderPlanner.eligibleStartHours(
        quietStartHour: quietStart,
        quietEndHour: quietEnd,
      );
      for (var hour = 0; hour < 24; hour++) {
        final slots = ReminderPlanner.plan(
          logs: const [],
          quietStartHour: quietStart,
          quietEndHour: quietEnd,
          notificationsOn: true,
          overrideHours: [hour],
        );
        expect(
          slots.isNotEmpty,
          offered.contains(hour),
          reason: 'hour $hour: offered=${offered.contains(hour)}, slots=$slots',
        );
      }
    });

    test('no quiet hours at all offers the whole day', () {
      expect(
        ReminderPlanner.eligibleStartHours(quietStartHour: 0, quietEndHour: 0),
        hasLength(24),
      );
    });
  });
}
