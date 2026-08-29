import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/firebase/reminder_scheduler.dart';
import 'package:last_puff/data/stores/reminder_coordinator.dart';
import 'package:last_puff/data/stores/settings_store.dart';
import 'package:last_puff/domain/logic/reminder_planner.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/data/seed/seed_data.dart';
import 'package:last_puff/domain/models/models.dart';

/// Records what it was asked to schedule, so the coordinator's decisions can
/// be asserted without touching the platform.
class _FakeSink implements ReminderSink {
  final List<List<ReminderSlot>> applied = [];
  int cancels = 0;

  @override
  Future<void> apply(
    List<ReminderSlot> slots, {
    required String title,
    required String body,
  }) async => applied.add(slots);

  @override
  Future<void> cancelAll() async => cancels++;
}

DayLog log(DateTime date, Map<int, int> buckets) => DayLog(
  date: date,
  puffs: buckets.values.fold(0, (a, b) => a + b),
  limit: 100,
  hourBuckets: buckets,
);

/// The seeded day-12 journey with its day map replaced, so the coordinator has
/// a real plan to read without this file re-deriving one. The engines are
/// exercised in their own suites.
JourneyState journeyWith(Map<int, int> buckets, {int days = 5}) {
  final today = DateTime(2026, 8, 20);
  return SeedData.journey(today).copyWith(
    days: {
      for (var i = 0; i < days; i++)
        JourneyState.dateKey(today.subtract(Duration(days: i))): log(
          JourneyState.dateKey(today.subtract(Duration(days: i))),
          buckets,
        ),
    },
  );
}

void main() {
  const title = 'Heads up';
  const body = 'Friday nights are your spike.';

  test('schedules the planned slots when notifications are on', () async {
    final sink = _FakeSink();
    await ReminderCoordinator(sink).sync(
      journey: journeyWith({21: 30}),
      settings: const SettingsState(),
      title: title,
      body: body,
    );

    expect(sink.applied, hasLength(1));
    expect(sink.applied.single.single.hour, 20);
    expect(sink.applied.single.single.minute, 50);
  });

  // Turning notifications off must actually clear the device, not merely stop
  // adding new ones — otherwise yesterday's schedule keeps firing.
  test('cancels everything when notifications are switched off', () async {
    final sink = _FakeSink();
    await ReminderCoordinator(sink).sync(
      journey: journeyWith({21: 30}),
      settings: const SettingsState(notificationsOn: false),
      title: title,
      body: body,
    );

    expect(sink.cancels, 1);
    expect(sink.applied, isEmpty);
  });

  test('cancels everything when there is no journey (signed out)', () async {
    final sink = _FakeSink();
    await ReminderCoordinator(sink).sync(
      journey: null,
      settings: const SettingsState(),
      title: title,
      body: body,
    );

    expect(sink.cancels, 1);
    expect(sink.applied, isEmpty);
  });

  // The coordinator runs on every journey mutation — that is once per puff
  // tap. Rescheduling the OS alarm hundreds of times a day would be absurd,
  // so an unchanged plan must be a no-op.
  test('does not touch the device when the plan has not changed', () async {
    final sink = _FakeSink();
    final coordinator = ReminderCoordinator(sink);
    final journey = journeyWith({21: 30});

    await coordinator.sync(
      journey: journey,
      settings: const SettingsState(),
      title: title,
      body: body,
    );
    await coordinator.sync(
      journey: journey,
      settings: const SettingsState(),
      title: title,
      body: body,
    );

    expect(sink.applied, hasLength(1));
  });

  test('reschedules when the danger hour actually moves', () async {
    final sink = _FakeSink();
    final coordinator = ReminderCoordinator(sink);

    await coordinator.sync(
      journey: journeyWith({21: 30}),
      settings: const SettingsState(),
      title: title,
      body: body,
    );
    await coordinator.sync(
      journey: journeyWith({14: 30}),
      settings: const SettingsState(),
      title: title,
      body: body,
    );

    expect(sink.applied, hasLength(2));
    expect(sink.applied.last.single.hour, 13);
  });

  test('reschedules when quiet hours change the outcome', () async {
    final sink = _FakeSink();
    final coordinator = ReminderCoordinator(sink);
    final journey = journeyWith({21: 30});

    await coordinator.sync(
      journey: journey,
      settings: const SettingsState(),
      title: title,
      body: body,
    );
    // Widening quiet hours to swallow 20:50 must clear the slot.
    await coordinator.sync(
      journey: journey,
      settings: const SettingsState(quietStartHour: 20, quietEndHour: 8),
      title: title,
      body: body,
    );

    expect(sink.applied.last, isEmpty);
  });
}
