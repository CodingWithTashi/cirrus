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
  @override
  Stream<ReminderKind> get opened => const Stream.empty();

  final List<List<ReminderSlot>> applied = [];
  final List<OneShotReminder> scheduledOnce = [];
  final List<ReminderKind> kinds = [];
  final List<String> bodies = [];
  final List<int> cancelled = [];
  int cancels = 0;

  @override
  Future<void> apply(
    List<ReminderSlot> slots, {
    required String title,
    required String body,
  }) async => applied.add(slots);

  @override
  Future<void> scheduleOnce(
    OneShotReminder reminder, {
    required ReminderKind kind,
    required String title,
    required String body,
  }) async {
    scheduledOnce.add(reminder);
    // The payload is the only thing that tells a tap where to land, so which
    // kind went through this door is worth recording.
    kinds.add(kind);
    bodies.add(body);
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

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
  group('the trial-ending reminder', () {
    final now = DateTime(2026, 8, 20, 12);
    final trial = Entitlement(
      tier: SubscriptionTier.trial,
      period: PlanPeriod.yearly,
      expiresAt: DateTime(2026, 8, 27, 15),
      willRenew: true,
    );
    const paid = Entitlement(tier: SubscriptionTier.premium);

    Future<void> syncWith(
      ReminderCoordinator c, {
      JourneyState? journey,
      Entitlement entitlement = const Entitlement.none(),
      SettingsState settings = const SettingsState(),
    }) => c.sync(
      journey: journey ?? journeyWith({21: 30}),
      settings: settings,
      title: title,
      body: body,
      entitlement: entitlement,
      trialTitle: 'Your trial ends tomorrow',
      trialBody: 'as promised',
      now: () => now,
    );

    test('is scheduled once, a day before the trial ends', () async {
      final sink = _FakeSink();
      final c = ReminderCoordinator(sink);
      await syncWith(c, entitlement: trial);
      expect(sink.scheduledOnce.single.id, 2000);
      expect(sink.scheduledOnce.single.at, DateTime(2026, 8, 26, 15));

      // Nothing changed: the OS is not touched again.
      await syncWith(c, entitlement: trial);
      expect(sink.scheduledOnce, hasLength(1));
      expect(sink.cancelled, isEmpty);
    });

    test('a danger-hour resync never touches it', () async {
      // The bug this guards: `apply()` used to cancel everything, so the next
      // puff tap after a trial started silently deleted its reminder.
      final sink = _FakeSink();
      final c = ReminderCoordinator(sink);
      await syncWith(c, entitlement: trial);
      await syncWith(c, journey: journeyWith({9: 30}), entitlement: trial);
      expect(sink.applied, hasLength(2), reason: 'the danger plan changed');
      expect(sink.scheduledOnce, hasLength(1));
      expect(sink.cancelled, isEmpty);
      expect(sink.cancels, 0);
    });

    test('is withdrawn when the trial converts or the toggle goes off', () async {
      final sink = _FakeSink();
      final c = ReminderCoordinator(sink);
      await syncWith(c, entitlement: trial);
      await syncWith(c, entitlement: paid);
      expect(sink.cancelled, [2000]);

      final off = _FakeSink();
      final c2 = ReminderCoordinator(off);
      await syncWith(
        c2,
        entitlement: trial,
        settings: const SettingsState(trialReminderOn: false),
      );
      expect(off.scheduledOnce, isEmpty);
    });

    test('is never scheduled for a paid or free account', () async {
      final sink = _FakeSink();
      await syncWith(ReminderCoordinator(sink), entitlement: paid);
      await syncWith(ReminderCoordinator(sink));
      expect(sink.scheduledOnce, isEmpty);
    });

    test('signing out clears both schedules together', () async {
      final sink = _FakeSink();
      final c = ReminderCoordinator(sink);
      await syncWith(c, entitlement: trial);
      await c.sync(
        journey: null,
        settings: const SettingsState(),
        title: title,
        body: body,
      );
      expect(sink.cancels, 1);
    });
  });

  group('the milestone celebration', () {
    JourneyState earned(Set<String> badges) =>
        journeyWith({21: 30}).copyWith(earnedBadges: badges);

    Future<void> sync(
      _FakeSink sink,
      JourneyState journey, {
      Set<String> celebrated = const {},
      ReminderCoordinator? on,
      // Every case below is about an account this device has already watched.
      // The adoption path — a ledger that has never been initialised — has its
      // own tests at the end of this group.
      bool adopted = true,
    }) => (on ?? ReminderCoordinator(sink)).sync(
      journey: journey,
      settings: SettingsState(
        celebratedMilestones: celebrated,
        milestonesAdopted: adopted,
      ),
      title: title,
      body: body,
      milestoneTitle: 'Come see your flame',
      milestoneBody: (badgeId) => 'you earned $badgeId',
      now: () => DateTime(2026, 8, 20, 14),
    );

    test('is scheduled once, with its own kind and id', () async {
      final sink = _FakeSink();

      await sync(sink, earned({'weekFlame'}));

      expect(sink.scheduledOnce, hasLength(1));
      expect(sink.scheduledOnce.single.id, 3001);
      expect(sink.kinds.single, ReminderKind.milestone);
      expect(sink.bodies.single, 'you earned weekFlame');
    });

    test('a second sync with the same inputs touches nothing', () async {
      // This runs on every puff tap. The important behaviour is the one that
      // does nothing.
      final sink = _FakeSink();
      final coordinator = ReminderCoordinator(sink);

      await sync(sink, earned({'weekFlame'}), on: coordinator);
      await sync(sink, earned({'weekFlame'}), on: coordinator);

      expect(sink.scheduledOnce, hasLength(1));
    });

    test('is never withdrawn once armed', () async {
      // Unlike the trial reminder, whose reason can evaporate, an earned badge
      // stays earned — and the moment it is marked celebrated the planner
      // answers null. A cancel-on-null branch would delete the very
      // notification the previous sync had just armed.
      final sink = _FakeSink();
      final coordinator = ReminderCoordinator(sink);

      await sync(sink, earned({'weekFlame'}), on: coordinator);
      await sync(
        sink,
        earned({'weekFlame'}),
        celebrated: {'weekFlame'},
        on: coordinator,
      );

      // Scoped to its own id: 2000 IS cancelled here, correctly, because the
      // fixture has no trial to remind anyone about.
      expect(sink.cancelled, isNot(contains(3001)));
      expect(sink.scheduledOnce, hasLength(1));
    });

    test('nothing earned schedules nothing', () async {
      final sink = _FakeSink();

      await sync(sink, earned(const {}));

      expect(sink.scheduledOnce, isEmpty);
    });

    test('a danger-hour resync never touches it', () async {
      final sink = _FakeSink();
      final coordinator = ReminderCoordinator(sink);
      await sync(sink, earned({'weekFlame'}), on: coordinator);

      // The hour moved: the danger schedule reapplies, the celebration must not.
      await coordinator.sync(
        journey: journeyWith({14: 30}).copyWith(earnedBadges: {'weekFlame'}),
        settings: const SettingsState(milestonesAdopted: true),
        title: title,
        body: body,
        milestoneTitle: 'Come see your flame',
        milestoneBody: (badgeId) => 'you earned $badgeId',
        now: () => DateTime(2026, 8, 20, 14),
      );

      expect(sink.scheduledOnce, hasLength(1));
      expect(sink.cancelled, isNot(contains(3001)));
    });

    test('reports the badge so it is never promised twice', () async {
      final sink = _FakeSink();
      final marked = <String>[];
      final covered = <String>{};

      await ReminderCoordinator(sink).sync(
        journey: earned({'spark'}),
        settings: const SettingsState(milestonesAdopted: true),
        title: title,
        body: body,
        milestoneTitle: 'Come see your flame',
        milestoneBody: (badgeId) => 'you earned $badgeId',
        onMilestoneScheduled: (armed, covers) {
          marked.add(armed);
          covered.addAll(covers);
        },
        now: () => DateTime(2026, 8, 20, 14),
      );

      expect(marked, ['spark']);
      expect(covered, {'spark'});
    });

    test('a restored journey settles the whole backlog in one go', () async {
      // `earnedBadges` comes back from the server while the record of what has
      // been celebrated is device-local, so a reinstall finds several owed at
      // once. Only the strongest is announced; the rest are settled silently,
      // or the user wakes to four separate 08:00 notifications about
      // milestones from weeks ago.
      final sink = _FakeSink();
      final marked = <String>[];
      final covered = <String>{};

      await ReminderCoordinator(sink).sync(
        journey: earned({'spark', 'weekFlame', 'twoWeekFlame', 'inferno'}),
        settings: const SettingsState(milestonesAdopted: true),
        title: title,
        body: body,
        milestoneTitle: 'Come see your flame',
        milestoneBody: (badgeId) => 'you earned $badgeId',
        onMilestoneScheduled: (armed, covers) {
          marked.add(armed);
          covered.addAll(covers);
        },
        now: () => DateTime(2026, 8, 20, 14),
      );

      expect(sink.scheduledOnce, hasLength(1));
      expect(marked, ['inferno'], reason: 'only the strongest is announced');
      expect(covered, {'spark', 'weekFlame', 'twoWeekFlame', 'inferno'});
    });

    test('switching notifications off hands the armed badge back', () async {
      // `cancelAll` takes ids 3000-3004 with it. The badge is marked settled at
      // scheduling time, so without a withdraw the celebration is not paused —
      // it is destroyed, and switching notifications back on finds nothing owed.
      final sink = _FakeSink();
      var withdrawn = 0;

      await ReminderCoordinator(sink).sync(
        journey: earned({'weekFlame'}),
        settings: const SettingsState(notificationsOn: false),
        title: title,
        body: body,
        milestoneTitle: 'Come see your flame',
        milestoneBody: (badgeId) => 'you earned $badgeId',
        onMilestonesWithdrawn: () => withdrawn++,
      );

      expect(withdrawn, 1);
    });

    test('notifications off still clears everything', () async {
      final sink = _FakeSink();

      await ReminderCoordinator(sink).sync(
        journey: earned({'weekFlame'}),
        settings: const SettingsState(notificationsOn: false),
        title: title,
        body: body,
        milestoneTitle: 'Come see your flame',
        milestoneBody: (badgeId) => 'you earned $badgeId',
      );

      expect(sink.scheduledOnce, isEmpty);
      expect(sink.cancels, 1);
    });

    group('a ledger this device has never initialised', () {
      test('adopts what is already earned instead of celebrating it late',
          () async {
        // The case that bites every existing install the day it updates, and
        // every account that signs in on a phone someone else used: badges
        // earned before this device was watching must not wake the user at
        // 08:00 with "Two weeks. TWO WEEKS." about a milestone from a month
        // ago.
        final sink = _FakeSink();
        final adopted = <String>{};

        await ReminderCoordinator(sink).sync(
          journey: earned({'spark', 'weekFlame', 'twoWeekFlame'}),
          settings: const SettingsState(),
          title: title,
          body: body,
          milestoneTitle: 'Come see your flame',
          milestoneBody: (badgeId) => 'you earned $badgeId',
          onMilestonesAdopted: adopted.addAll,
          now: () => DateTime(2026, 8, 20, 14),
        );

        expect(adopted, {'spark', 'weekFlame', 'twoWeekFlame'});
        expect(
          sink.scheduledOnce,
          isEmpty,
          reason: 'adoption settles the backlog, it does not announce it',
        );
      });

      test('a fresh account adopts nothing and stays able to celebrate',
          () async {
        // The bug in the other direction: an empty ledger is ALSO the honest
        // state of someone about to earn their first badge, which is why
        // adoption is a flag rather than "is the ledger empty".
        final sink = _FakeSink();
        final adopted = <String>{};

        await ReminderCoordinator(sink).sync(
          journey: earned(const {}),
          settings: const SettingsState(),
          title: title,
          body: body,
          milestoneTitle: 'Come see your flame',
          milestoneBody: (badgeId) => 'you earned $badgeId',
          onMilestonesAdopted: adopted.addAll,
          now: () => DateTime(2026, 8, 20, 14),
        );
        expect(adopted, isEmpty);

        // Day 3 arrives on an adopted ledger: the celebration lands.
        await sync(sink, earned({'spark'}));
        expect(sink.scheduledOnce, hasLength(1));
      });

      test('the danger-hour and trial schedules still run', () async {
        // Adoption returns early out of the MILESTONE sync only. A first
        // launch must still arm the nudges it was always going to arm.
        final sink = _FakeSink();

        await ReminderCoordinator(sink).sync(
          journey: earned({'weekFlame'}),
          settings: const SettingsState(),
          title: title,
          body: body,
          milestoneTitle: 'Come see your flame',
          milestoneBody: (badgeId) => 'you earned $badgeId',
          now: () => DateTime(2026, 8, 20, 14),
        );

        expect(sink.applied, hasLength(1));
      });
    });
  });
}
