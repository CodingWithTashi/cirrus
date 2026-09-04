import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/firebase/reminder_scheduler.dart';
import 'package:last_puff/data/stores/reminder_coordinator.dart';
import 'package:last_puff/data/stores/settings_store.dart';
import 'package:last_puff/domain/logic/reminder_planner.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/data/seed/seed_data.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The danger-hour reminder has to arrive at the danger hour.
///
/// That sentence was false for the whole life of the feature. The planner was
/// correct and unit-tested, the coordinator fingerprinted `id@hour:minute` so
/// it believed it was tracking times — and then the scheduler called
/// `periodicallyShow`, which repeats every 24h *from the moment it is called*
/// and ignores hour and minute entirely. Whatever moment the app last synced
/// became the daily notification time, forever.
///
/// So the tests below assert on the wall-clock time, which is the only thing a
/// user experiences and the one thing nothing checked.
void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    // A zone with DST, deliberately: a fixed-offset zone would hide the bug
    // these reminders are anchored in a real location to avoid.
    tz.setLocalLocation(tz.getLocation('America/Toronto'));
  });

  ReminderSlot slotAt(int hour, int minute) =>
      ReminderSlot(hour: hour, minute: minute, id: 1000 + hour);

  group('when the reminder actually fires', () {
    test('later today, when the time has not passed yet', () {
      final now = tz.TZDateTime(tz.local, 2026, 9, 15, 10, 0);
      final next = ReminderScheduler.nextOccurrence(slotAt(20, 50), now);

      expect(next.hour, 20);
      expect(next.minute, 50);
      expect(next.day, 15);
    });

    test('tomorrow, when the time has already passed', () {
      final now = tz.TZDateTime(tz.local, 2026, 9, 15, 21, 30);
      final next = ReminderScheduler.nextOccurrence(slotAt(20, 50), now);

      expect(next.hour, 20);
      expect(next.minute, 50);
      expect(next.day, 16);
    });

    test('never in the past — zonedSchedule rejects that outright', () {
      final now = tz.TZDateTime(tz.local, 2026, 9, 15, 20, 50);
      // Exactly now counts as passed: scheduling for this instant races the
      // call itself.
      final next = ReminderScheduler.nextOccurrence(slotAt(20, 50), now);
      expect(next.isAfter(now), isTrue);
    });

    test('survives the day rolling over', () {
      final now = tz.TZDateTime(tz.local, 2026, 9, 30, 23, 55);
      final next = ReminderScheduler.nextOccurrence(slotAt(7, 50), now);

      expect(next.month, 10);
      expect(next.day, 1);
      expect(next.hour, 7);
    });

    test('keeps the wall-clock hour across a DST boundary', () {
      // Toronto ends DST on 2026-11-01. A reminder is a promise about a time
      // of day, not about an elapsed duration — 9pm must stay 9pm.
      final before = tz.TZDateTime(tz.local, 2026, 10, 31, 22, 0);
      final after = tz.TZDateTime(tz.local, 2026, 11, 1, 10, 0);

      expect(ReminderScheduler.nextOccurrence(slotAt(20, 50), before).hour, 20);
      expect(ReminderScheduler.nextOccurrence(slotAt(20, 50), after).hour, 20);
    });
  });

  group('the Settings window', () {
    // Days that all point at 14:00, so a detected plan and an overridden one
    // are impossible to confuse.
    const buckets = {14: 30, 15: 5};
    final today = DateTime(2026, 8, 20);
    final journey = SeedData.journey(today).copyWith(
      days: {
        for (var i = 0; i < 5; i++)
          JourneyState.dateKey(today.subtract(Duration(days: i))): DayLog(
            date: JourneyState.dateKey(today.subtract(Duration(days: i))),
            puffs: 35,
            limit: 200,
            hourBuckets: buckets,
          ),
      },
    );
    final logs = journey.days.values;

    test('with no choice made, the detected hours win', () {
      final slots = ReminderPlanner.plan(
        logs: logs,
        quietStartHour: 23,
        quietEndHour: 8,
        notificationsOn: true,
      );

      expect(slots, isNotEmpty);
      expect(slots.first.hour, 13);
      expect(slots.first.minute, 50);
    });

    test('a chosen window overrides what we inferred', () {
      // The editor persisted a window that nothing read, so the control was
      // decoration: a user who knew about their 9pm habit could set it and
      // still be reminded at 2pm.
      final slots = ReminderPlanner.plan(
        logs: logs,
        quietStartHour: 23,
        quietEndHour: 8,
        notificationsOn: true,
        overrideHours: const [21],
      );

      expect(slots, hasLength(1));
      expect(slots.single.hour, 20);
      expect(slots.single.minute, 50);
    });

    test('an overridden window still obeys quiet hours', () {
      // The override is the user naming an hour, not overruling the rails.
      final slots = ReminderPlanner.plan(
        logs: logs,
        quietStartHour: 23,
        quietEndHour: 8,
        notificationsOn: true,
        overrideHours: const [3],
      );

      expect(slots, isEmpty);
    });

    test('the coordinator passes the window through only once chosen', () async {
      final sink = _RecordingSink();
      final coordinator = ReminderCoordinator(sink);

      await coordinator.sync(
        journey: journey,
        settings: const SettingsState(notificationsOn: true),
        title: 't',
        body: 'b',
      );
      // Two detected hours (14:00 and 15:00) become two slots.
      expect(sink.last, hasLength(2));
      expect(sink.last.first.hour, 13, reason: 'detected hour expected');

      await coordinator.sync(
        journey: journey,
        settings: const SettingsState(
          notificationsOn: true,
          dangerStartHour: 21,
          dangerEndHour: 24,
          dangerHoursCustom: true,
        ),
        title: 't',
        body: 'b',
      );
      expect(sink.last.single.hour, 20, reason: 'chosen window expected');
    });
  });
}

class _RecordingSink implements ReminderSink {
  @override
  Stream<ReminderKind> get opened => const Stream.empty();

  List<ReminderSlot> last = const [];

  @override
  Future<void> apply(
    List<ReminderSlot> slots, {
    required String title,
    required String body,
  }) async => last = slots;

  @override
  Future<void> scheduleOnce(
    OneShotReminder reminder, {
    required ReminderKind kind,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async => last = const [];
}
