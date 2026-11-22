import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/firebase/reminder_scheduler.dart';
import 'package:last_puff/data/stores/reminder_coordinator.dart';
import 'package:last_puff/data/stores/settings_store.dart';
import 'package:last_puff/domain/logic/reminder_planner.dart';
import 'package:last_puff/domain/logic/reminder_tap.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/data/seed/seed_data.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart' show journeyOnDay;

/// Records what it was asked to schedule, so the coordinator's decisions can
/// be asserted without touching the platform.
class _FakeSink implements ReminderSink {
  @override
  Stream<ReminderTap> get opened => const Stream.empty();

  final List<List<ReminderSlot>> applied = [];
  final List<OneShotReminder> scheduledOnce = [];

  /// The whole payload of each one-shot, parallel to [scheduledOnce]: the
  /// kind, and for a check-in the slot and plan day a tap will report.
  final List<ReminderTap> taps = [];
  final List<ReminderKind> kinds = [];
  final List<String> bodies = [];
  final List<int> cancelled = [];
  int cancels = 0;

  /// Whether the device accepts one-shots. False stands in for a plugin that
  /// is not ready or a permission that was revoked — the real scheduler
  /// swallows those and answers false.
  bool arms = true;

  @override
  Future<void> apply(
    List<ReminderSlot> slots, {
    required String title,
    required String body,
  }) async => applied.add(slots);

  @override
  Future<bool> scheduleOnce(
    OneShotReminder reminder, {
    required ReminderTap tap,
    required String title,
    required String body,
  }) async {
    if (!arms) return false;
    scheduledOnce.add(reminder);
    // The payload is the only thing that tells a tap where to land, so which
    // kind went through this door is worth recording.
    taps.add(tap);
    kinds.add(tap.kind);
    bodies.add(body);
    return true;
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
        onMilestoneScheduled: (armed, covers, at) {
          marked.add(armed);
          covered.addAll(covers);
          expect(at, sink.scheduledOnce.single.at, reason: 'the due time travels with it');
        },
        now: () => DateTime(2026, 8, 20, 14),
      );

      expect(marked, ['spark']);
      expect(covered, {'spark'});
    });

    test('a celebration the device refused to arm is not settled, and is retried', () async {
      // `ReminderScheduler.scheduleOnce` swallows every failure — plugin not
      // initialised, POST_NOTIFICATIONS revoked — so without a signal back
      // the badge was marked celebrated for a notification that never
      // existed, and the planner answered null for it for ever.
      final sink = _FakeSink()..arms = false;
      final marked = <String>[];
      final coordinator = ReminderCoordinator(sink);
      Future<void> attempt() => coordinator.sync(
        journey: earned({'spark'}),
        settings: const SettingsState(milestonesAdopted: true),
        title: title,
        body: body,
        milestoneTitle: 'Come see your flame',
        milestoneBody: (badgeId) => 'you earned $badgeId',
        onMilestoneScheduled: (armed, covers, at) => marked.add(armed),
        now: () => DateTime(2026, 8, 20, 14),
      );

      await attempt();
      expect(sink.scheduledOnce, isEmpty);
      expect(marked, isEmpty, reason: 'nothing armed, nothing settled');

      sink.arms = true;
      await attempt();
      expect(sink.scheduledOnce, hasLength(1), reason: 'the next sync tries again');
      expect(marked, ['spark']);
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
        onMilestoneScheduled: (armed, covers, _) {
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
        onMilestonesWithdrawn: (_) => withdrawn++,
      );

      expect(withdrawn, 1);
    });

    test('nothing runs before the stored settings have been read', () async {
      // Cold start: `restoreSession` can land the journey before
      // SharedPreferences answers, and the store shows its defaults until
      // then. Acting on them adopted the ledger (committing every default
      // over the user's stored settings) and cleared the device against a
      // ledger that did not know a celebration was armed.
      final sink = _FakeSink();
      var withdrawn = 0;
      final adopted = <String>{};
      final marked = <String>[];
      Future<void> syncWith(SettingsState settings, {JourneyState? journey}) =>
          ReminderCoordinator(sink).sync(
            journey: journey,
            settings: settings,
            title: title,
            body: body,
            milestoneTitle: 'Come see your flame',
            milestoneBody: (badgeId) => 'you earned $badgeId',
            onMilestoneScheduled: (armed, covers, _) => marked.add(armed),
            onMilestonesWithdrawn: (_) => withdrawn++,
            onMilestonesAdopted: adopted.addAll,
            now: () => DateTime(2026, 8, 20, 14),
          );

      // Unhydrated, no journey yet: the cold-start clear must wait.
      await syncWith(const SettingsState(hydrated: false));
      expect(sink.cancels, 0);
      expect(withdrawn, 0);
      // Unhydrated, journey in hand: neither adoption nor a celebration.
      await syncWith(const SettingsState(hydrated: false), journey: earned({'spark'}));
      expect(adopted, isEmpty);
      expect(marked, isEmpty);
      expect(sink.applied, isEmpty);
      // Hydrated: the same inputs act.
      await syncWith(const SettingsState(), journey: earned({'spark'}));
      expect(adopted, {'spark'});
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
  // The evening check-in (docs/10 §51): seven one-shots on their own ids, so
  // nothing else's schedule is touched by re-arming them.
  group('the evening check-in', () {
    ({String title, String body}) copy(CheckinReminder c) =>
        (title: 'Day ${c.planDay} check-in', body: 'limit ${c.limit}');
    final morning = DateTime(2026, 8, 20, 9);

    /// The fixture with today unlogged — a confirmed today has no check-in,
    /// and these cases are about the whole week.
    JourneyState unloggedToday() {
      final journey = journeyWith({10: 30});
      return journey.copyWith(
        days: {...journey.days}..remove(JourneyState.dateKey(morning)),
      );
    }

    Future<void> sync(
      ReminderCoordinator coordinator, {
      JourneyState? journey,
      SettingsState settings = const SettingsState(),
      DateTime? now,
    }) => coordinator.sync(
      journey: journey ?? unloggedToday(),
      settings: settings,
      title: title,
      body: body,
      checkinCopy: copy,
      now: () => now ?? morning,
    );

    test('arms a week of evenings, through its own ids only', () async {
      final sink = _FakeSink();
      await sync(ReminderCoordinator(sink));

      final checkins = [
        for (final (i, kind) in sink.kinds.indexed)
          if (kind == ReminderKind.checkin) sink.scheduledOnce[i],
      ];
      expect(checkins, hasLength(CheckinReminderPlanner.window));
      expect(checkins.map((r) => r.id), CheckinReminderPlanner.ids);
      expect(checkins.every((r) => r.at.hour == 20), isTrue);
      // Re-armed over its own seven ids — never `cancelAll`, which would take
      // the trial reminder and an armed milestone down with it.
      expect(sink.cancelled, containsAll(CheckinReminderPlanner.ids));
      expect(sink.cancels, 0);
    });

    test('an unchanged week is not re-armed on the next puff', () async {
      final sink = _FakeSink();
      final coordinator = ReminderCoordinator(sink);
      await sync(coordinator);
      final armed = sink.scheduledOnce.length;
      await sync(coordinator);
      expect(sink.scheduledOnce.length, armed);
    });

    test('switched off, it withdraws its own week and nothing else', () async {
      final sink = _FakeSink();
      final coordinator = ReminderCoordinator(sink);
      await sync(coordinator);
      sink.cancelled.clear();
      final armed = sink.scheduledOnce.length;

      await sync(
        coordinator,
        settings: const SettingsState(checkinReminderOn: false),
      );
      // Its evening slots, the program's three mornings and the plain
      // mornings: all are this schedule's, and all go when it does.
      expect(sink.cancelled, [
        ...CheckinReminderPlanner.ids,
        ...CheckinReminderPlanner.morningIds,
        ...CheckinReminderPlanner.planMorningIds,
      ]);
      expect(sink.scheduledOnce.length, armed);
      expect(sink.cancels, 0);
    });

    test('a refused schedule is tried again on the next sync', () async {
      final sink = _FakeSink()..arms = false;
      final coordinator = ReminderCoordinator(sink);
      await sync(coordinator);
      expect(sink.scheduledOnce, isEmpty);

      sink.arms = true;
      await sync(coordinator);
      expect(sink.kinds.where((k) => k == ReminderKind.checkin), isNotEmpty);
    });

    test('an evening danger hour does not silence it', () async {
      // The first cut skipped any day a danger nudge used the same hour. The
      // most common evening danger hour, 21:00, is nudged at 20:50 — so the
      // check-in never fired for those people while Settings read "20:00".
      final sink = _FakeSink();
      final journey = journeyWith({21: 30});
      await ReminderCoordinator(sink).sync(
        journey: journey.copyWith(
          days: {...journey.days}..remove(JourneyState.dateKey(morning)),
        ),
        settings: const SettingsState(),
        title: title,
        body: body,
        checkinCopy: copy,
        now: () => morning,
      );
      expect(sink.applied.single.single.hour, 20); // the 20:50 nudge
      expect(
        sink.kinds.where((k) => k == ReminderKind.checkin),
        hasLength(CheckinReminderPlanner.window),
      );
    });

    // docs/15 QP-B5: the daily program rides this schedule. Same switch, same
    // seven-day window, same ids for the evening — plus three mornings.
    group('carrying the daily program', () {
      ({String title, String body}) programCopy(CheckinReminder c) =>
          (title: 'Day ${c.planDay}', body: 'program ${c.message!.name}');
      final dawn = DateTime(2026, 8, 20, 7);

      /// The fixture on its quit day: cold turkey, day one today, today
      /// unlogged.
      JourneyState quitDay() {
        final j = unloggedToday();
        return j.copyWith(
          plan: j.plan.copyWith(
            method: QuitMethod.coldTurkey,
            startDate: DateTime(2026, 8, 20),
          ),
        );
      }

      Future<void> syncProgram(
        ReminderCoordinator coordinator, {
        JourneyState? journey,
        SettingsState settings = const SettingsState(),
        DateTime? now,
        bool withProgramCopy = true,
      }) => coordinator.sync(
        journey: journey ?? quitDay(),
        settings: settings,
        title: title,
        body: body,
        checkinCopy: copy,
        programCopy: withProgramCopy ? programCopy : null,
        now: () => now ?? dawn,
      );

      test('arms program messages, with the program kind and its own words', () async {
        final sink = _FakeSink();
        await syncProgram(ReminderCoordinator(sink));

        final program = [
          for (final (i, kind) in sink.kinds.indexed)
            if (kind == ReminderKind.program) i,
        ];
        // Seven evenings and the three mornings.
        expect(program, hasLength(10));
        expect(sink.bodies[program.first], startsWith('program '));
        final ids = [for (final i in program) sink.scheduledOnce[i].id];
        expect(ids, containsAll(CheckinReminderPlanner.morningIds));
        expect(ids, containsAll(CheckinReminderPlanner.ids));
        expect(
          sink.kinds.where((k) => k == ReminderKind.checkin),
          isEmpty,
          reason: 'every day in this window has a message',
        );
      });

      test('a day without a message is still the plain check-in', () async {
        final sink = _FakeSink();
        final j = quitDay();
        // Program day 14 onward: messages on 14, 16, 18 only.
        final later = j.copyWith(
          plan: j.plan.copyWith(startDate: DateTime(2026, 8, 6)),
        );
        await syncProgram(ReminderCoordinator(sink), journey: later);

        final plain = [
          for (final (i, kind) in sink.kinds.indexed)
            if (kind == ReminderKind.checkin) sink.bodies[i],
        ];
        expect(plain, isNotEmpty);
        expect(plain.every((b) => b.startsWith('limit ')), isTrue);
        expect(
          sink.kinds.where((k) => k == ReminderKind.program),
          isNotEmpty,
        );
      });

      test('a re-arm withdraws the mornings along with the evenings', () async {
        final sink = _FakeSink();
        await syncProgram(ReminderCoordinator(sink));
        expect(
          sink.cancelled,
          containsAll([
            ...CheckinReminderPlanner.ids,
            ...CheckinReminderPlanner.morningIds,
          ]),
        );
        expect(sink.cancels, 0, reason: 'never cancelAll');
      });

      test('a moved date re-arms with the new words even when nothing else '
          'about the day changed', () async {
        // Baseline 0 keeps every limit at zero, so a stretch changes the
        // MESSAGE for each instant and nothing else the fingerprint carries.
        final sink = _FakeSink();
        final coordinator = ReminderCoordinator(sink);
        final base = journeyWith({10: 30});
        final at = DateTime(2026, 8, 20, 7);
        final taper = base.copyWith(
          days: {...base.days}..remove(JourneyState.dateKey(at)),
          plan: base.plan.copyWith(
            method: QuitMethod.taper,
            baselinePuffsPerDay: 0,
            startDate: DateTime(2026, 7, 28), // day 24 of 30 on Aug 20
          ),
        );
        await syncProgram(coordinator, journey: taper, now: at);
        final first = [...sink.bodies];
        final armed = sink.scheduledOnce.length;
        expect(first.any((b) => b == 'program pre6'), isTrue);

        await syncProgram(
          coordinator,
          journey: taper.copyWith(plan: taper.plan.copyWith(stretchDays: 1)),
          now: at,
        );
        expect(
          sink.scheduledOnce.length,
          greaterThan(armed),
          reason: 'the same instants, different messages: it must re-arm',
        );
        expect(sink.bodies.skip(armed).any((b) => b == 'program pre7'), isTrue);
      });

      test('an unchanged program window is not re-armed on the next puff', () async {
        final sink = _FakeSink();
        final coordinator = ReminderCoordinator(sink);
        await syncProgram(coordinator);
        final armed = sink.scheduledOnce.length;
        await syncProgram(coordinator);
        expect(sink.scheduledOnce.length, armed);
      });

      test('a refused program schedule is tried again', () async {
        final sink = _FakeSink()..arms = false;
        final coordinator = ReminderCoordinator(sink);
        await syncProgram(coordinator);
        expect(sink.scheduledOnce, isEmpty);
        sink.arms = true;
        await syncProgram(coordinator);
        expect(
          sink.kinds.where((k) => k == ReminderKind.program),
          isNotEmpty,
        );
      });

      test('without program copy a program slot is left unarmed rather than '
          'fired with the wrong words', () async {
        final sink = _FakeSink();
        await syncProgram(ReminderCoordinator(sink), withProgramCopy: false);
        expect(sink.kinds.where((k) => k == ReminderKind.program), isEmpty);
        expect(sink.scheduledOnce, isEmpty, reason: 'every day here is a program day');
      });

      test('the one switch turns it all off, mornings included', () async {
        final sink = _FakeSink();
        final coordinator = ReminderCoordinator(sink);
        await syncProgram(coordinator);
        sink.cancelled.clear();
        final armed = sink.scheduledOnce.length;

        await syncProgram(
          coordinator,
          settings: const SettingsState(checkinReminderOn: false),
        );
        expect(sink.cancelled, containsAll(CheckinReminderPlanner.morningIds));
        expect(sink.scheduledOnce.length, armed);
      });
    });

    test('nothing before the stored settings have been read', () async {
      final sink = _FakeSink();
      await sync(
        ReminderCoordinator(sink),
        settings: const SettingsState(hydrated: false),
      );
      expect(sink.scheduledOnce, isEmpty);
      expect(sink.cancelled, isEmpty);
    });
  });

  // The plain morning on plan days 2 and 3 (docs/15): armed with the
  // evenings, on its own ids, and out of the way of anything else this phone
  // already says around nine.
  group('the day-2 morning', () {
    ({String title, String body}) copy(CheckinReminder c) =>
        (title: 'Day ${c.planDay}', body: 'limit ${c.limit}');

    // Plan day 1 is Sep 14 2026, so the mornings are Sep 15 and Sep 16.
    final eve = DateTime(2026, 9, 14, 19);

    Future<void> sync(
      ReminderCoordinator coordinator, {
      JourneyState? journey,
      SettingsState settings = const SettingsState(hydrated: true),
      void Function()? onDay2MorningArmed,
    }) => coordinator.sync(
      journey: journey ?? journeyOnDay(1, now: eve),
      settings: settings,
      title: title,
      body: body,
      checkinCopy: copy,
      onDay2MorningArmed: onDay2MorningArmed,
      now: () => eve,
    );

    /// The encoded tap of each armed one-shot, by id.
    Map<int, String> tapsById(_FakeSink sink) => {
      for (final (i, r) in sink.scheduledOnce.indexed)
        r.id: sink.taps[i].encode(),
    };

    Set<int> morningIds(_FakeSink sink) => {
      for (final r in sink.scheduledOnce)
        if (CheckinReminderPlanner.planMorningIds.contains(r.id)) r.id,
    };

    test('a day-1 taper is armed 5102 and 5103 with morning taps', () async {
      final sink = _FakeSink();
      await sync(ReminderCoordinator(sink));

      final taps = tapsById(sink);
      expect(taps[5102], 'checkin|morning|2|');
      expect(taps[5103], 'checkin|morning|3|');
      // And the evenings say which half of the day they are, too.
      expect(taps[4000], 'checkin|evening|1|');
      expect(sink.scheduledOnce.singleWhere((r) => r.id == 5102).at,
          DateTime(2026, 9, 15, 9));
    });

    test('every sync cancels the plain-morning ids too', () async {
      final sink = _FakeSink();
      final coordinator = ReminderCoordinator(sink);
      await sync(coordinator);
      sink.cancelled.clear();

      // A different limit changes every reminder's words, so it re-arms.
      await sync(coordinator, journey: journeyOnDay(1, now: eve, baseline: 80));

      expect(sink.cancelled, containsAll([5102, 5103]));
      expect(sink.cancels, 0, reason: 'never cancelAll');
    });

    test('the 08:50 first-puff fallback drops the plain morning', () async {
      final sink = _FakeSink();
      final journey = journeyOnDay(1, now: eve);
      await sync(
        ReminderCoordinator(sink),
        journey: journey.copyWith(
          // `copyWith` cannot set the first-puff answer: build the profile.
          profile: UserProfile(
            alias: journey.profile.alias,
            avatarEmoji: journey.profile.avatarEmoji,
            smoking: SmokingHistory.never,
            firstPuff: FirstPuffWindow.hourPlus,
          ),
        ),
      );

      final slot = sink.applied.single.single;
      expect((slot.hour, slot.minute), (8, 50));
      expect(
        morningIds(sink),
        isEmpty,
        reason: '08:50 is ten minutes from 09:00',
      );
    });

    test('a celebration armed for 09:00 drops that morning', () async {
      final sink = _FakeSink();
      await sync(
        ReminderCoordinator(sink),
        settings: SettingsState(
          hydrated: true,
          armedMilestoneAt: DateTime(2026, 9, 15, 9),
        ),
      );

      expect(morningIds(sink), {5103});
    });

    test('a celebration armed in this very sync drops that morning', () async {
      // `armedMilestoneAt` is only written once the coordinator reports the
      // badge, so the instant armed in THIS sync has to come back to the
      // check-in plan by hand — and stay dropped when the settings hold it.
      final sink = _FakeSink();
      final coordinator = ReminderCoordinator(sink);
      final journey = journeyOnDay(
        1,
        now: eve,
      ).copyWith(earnedBadges: {'spark'});
      DateTime? armedAt;
      Future<void> run(SettingsState settings) => coordinator.sync(
        journey: journey,
        settings: settings,
        title: title,
        body: body,
        milestoneTitle: 'Come see your flame',
        milestoneBody: (badgeId) => 'you earned $badgeId',
        onMilestoneScheduled: (_, _, at) => armedAt = at,
        checkinCopy: copy,
        now: () => eve,
      );

      await run(const SettingsState(hydrated: true, milestonesAdopted: true));
      expect(armedAt, DateTime(2026, 9, 15, 8));
      expect(
        morningIds(sink),
        {5103},
        reason: '08:00 is within an hour of 09:00',
      );

      // The next sync: the milestone is unchanged and returns nothing, and the
      // settings now carry the instant. The morning must not come back.
      final before = sink.scheduledOnce.length;
      await run(
        SettingsState(
          hydrated: true,
          milestonesAdopted: true,
          armedMilestoneAt: armedAt,
        ),
      );
      expect(sink.scheduledOnce.length, before);
    });

    test('a plan started again with morning history drops the plain morning',
        () async {
      // Three confirmed days of puffs at 09:00 before this plan's day one:
      // the detected danger hour is 9, nudged at 08:50, daily.
      final sink = _FakeSink();
      final base = journeyOnDay(1, now: eve);
      final earlier = {
        for (final d in [11, 12, 13])
          DateTime(2026, 9, d): DayLog(
            date: DateTime(2026, 9, d),
            puffs: 20,
            limit: 100,
            hourBuckets: const {9: 20},
          ),
      };
      await sync(
        ReminderCoordinator(sink),
        journey: base.copyWith(
          plan: base.plan.copyWith(planNumber: 2),
          days: {...base.days, ...earlier},
        ),
      );

      final slot = sink.applied.single.single;
      expect((slot.hour, slot.minute), (8, 50));
      expect(morningIds(sink), isEmpty);
    });

    group('reports itself', () {
      test('day2 armed is reported once per sync that arms it', () async {
        final sink = _FakeSink();
        final coordinator = ReminderCoordinator(sink);
        var armed = 0;

        await sync(coordinator, onDay2MorningArmed: () => armed++);
        expect(armed, 1);

        // Nothing changed, nothing re-armed, nothing reported.
        await sync(coordinator, onDay2MorningArmed: () => armed++);
        expect(armed, 1);
      });

      test('not when the device refused it, and once it accepts', () async {
        final sink = _FakeSink()..arms = false;
        final coordinator = ReminderCoordinator(sink);
        var armed = 0;

        await sync(coordinator, onDay2MorningArmed: () => armed++);
        expect(armed, 0);

        sink.arms = true;
        await sync(coordinator, onDay2MorningArmed: () => armed++);
        expect(armed, 1);
      });

      test('a program morning on plan day 2 counts too', () async {
        // Cold turkey on plan day 1: program day one's morning (5001) is the
        // next day's, which is plan day 2, so it reports the same property.
        // The condition is the slot and the plan day, not the plain morning.
        final base = journeyOnDay(1, now: eve);
        final cold = base.copyWith(
          plan: base.plan.copyWith(method: QuitMethod.coldTurkey),
        );
        final sink = _FakeSink();
        var armed = 0;
        await ReminderCoordinator(sink).sync(
          journey: cold,
          settings: const SettingsState(hydrated: true),
          title: title,
          body: body,
          checkinCopy: copy,
          programCopy: (c) => (title: 'Day', body: 'program ${c.message!.name}'),
          onDay2MorningArmed: () => armed++,
          now: () => eve,
        );
        expect(tapsById(sink)[5001], startsWith('program|morning|2|'));
        expect(morningIds(sink), isEmpty, reason: 'no plain morning here');
        expect(armed, 1);
      });

      test('not for the day-3 morning alone', () async {
        // Day 2's morning is already past: Sep 15 09:00 is behind it.
        final sink = _FakeSink();
        var armed = 0;
        await ReminderCoordinator(sink).sync(
          journey: journeyOnDay(1, now: eve),
          settings: const SettingsState(hydrated: true),
          title: title,
          body: body,
          checkinCopy: copy,
          onDay2MorningArmed: () => armed++,
          now: () => DateTime(2026, 9, 15, 10),
        );
        expect(morningIds(sink), {5103});
        expect(armed, 0);
      });
    });
  });
}
