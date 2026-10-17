import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/reminder_planner.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// The evening check-in (docs/10 §51): the one reminder that reaches somebody
/// who has not opened the app today. Two in three people who finished
/// onboarding before Oct 16 2026 never came back a second day, and nothing in
/// the app could reach them.
void main() {
  List<CheckinReminder> plan(
    JourneyState journey, {
    required DateTime now,
    int hour = 20,
    int quietStart = 23,
    int quietEnd = 8,
    bool enabled = true,
  }) => CheckinReminderPlanner.plan(
    journey: journey,
    now: now,
    hour: hour,
    quietStartHour: quietStart,
    quietEndHour: quietEnd,
    enabled: enabled,
  );

  final morning = DateTime(2026, 9, 14, 9, 30);

  test('seven evenings from today, each naming the number Home will show', () {
    final journey = journeyOnDay(4, now: morning);
    final checkins = plan(journey, now: morning);

    expect(checkins, hasLength(CheckinReminderPlanner.window));
    for (final (i, c) in checkins.indexed) {
      expect(c.reminder.id, CheckinReminderPlanner.firstId + i);
      expect(c.reminder.at, DateTime(2026, 9, 14 + i, 20));
      expect(c.planDay, 4 + i);
      expect(c.totalDays, 30);
      // Never re-derived here: the limit is the journey's own answer.
      expect(c.limit, journey.limitOn(c.reminder.at));
    }
  });

  test('after the hour, the window starts tomorrow', () {
    final late = DateTime(2026, 9, 14, 21, 5);
    final checkins = plan(journeyOnDay(4, now: late), now: late);

    expect(checkins.first.reminder.at, DateTime(2026, 9, 15, 20));
    expect(checkins.length, CheckinReminderPlanner.window - 1);
  });

  test('not today once today is confirmed — they have been here', () {
    final journey = journeyOnDay(4, now: morning);
    final today = JourneyState.dateKey(morning);
    final logged = journey.copyWith(
      days: {
        ...journey.days,
        today: DayLog(date: today, puffs: 2, limit: journey.limitOn(morning)),
      },
    );

    final checkins = plan(logged, now: morning);
    expect(checkins.first.reminder.at, DateTime(2026, 9, 15, 20));
  });

  test('nothing when switched off or inside quiet hours', () {
    final journey = journeyOnDay(4, now: morning);

    expect(plan(journey, now: morning, enabled: false), isEmpty);
    expect(plan(journey, now: morning, quietStart: 19, quietEnd: 7), isEmpty);
  });

  test(
    'every evening is 20:00 on its own calendar day, across a DST change',
    () {
      // North America leaves DST on Nov 1 2026 and Europe on Oct 25. Whatever
      // zone the suite runs in, `Duration(days: 1)` steps would land on 19:00
      // or 21:00 after the change; calendar arithmetic never does.
      final before = DateTime(2026, 10, 22, 9);
      final checkins = plan(journeyOnDay(4, now: before), now: before);
      for (final (i, c) in checkins.indexed) {
        expect(c.reminder.at.hour, 20);
        expect(
          LpDate.dayKey(c.reminder.at),
          LpDate.dayKey(LpDate.addDays(before, i)),
        );
      }
    },
  );

  test('past Freedom Day the day keeps counting and the limit is zero', () {
    final journey = journeyOnDay(30, now: morning, totalDays: 30);
    final checkins = plan(journey, now: morning);

    expect(checkins.first.planDay, 30);
    expect(checkins.first.limit, 0);
    expect(checkins[1].planDay, greaterThan(checkins[1].totalDays));
    expect(checkins[1].limit, 0);
  });

  test('its ids stay clear of every other schedule', () {
    final ids = CheckinReminderPlanner.ids;
    expect(ids, hasLength(CheckinReminderPlanner.window));
    expect(ids.every((id) => id >= 4000 && id < 4100), isTrue);
    expect(ids.contains(TrialReminderPlanner.id), isFalse);
  });
}
