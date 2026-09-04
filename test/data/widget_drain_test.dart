import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/widget_store.dart';
import 'package:last_puff/data/network/connectivity.dart';
import 'package:last_puff/data/repositories/api_journey_repository.dart';
import 'package:last_puff/data/stores/journey_store.dart';
import 'package:last_puff/data/stores/pending_puffs.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/data/stores/widget_coordinator.dart';
import 'package:last_puff/data/stores/widget_mirror.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';

import '../helpers.dart';

/// Draining the home-screen widget's outbox.
///
/// This is the most safety-critical path in the feature: it is the one place a
/// puff can be counted twice or lost, and both are the worst class of bug this
/// app can have. Every case here is a failure that would reach the user's own
/// record.
void main() {
  final now = DateTime(2026, 9, 4, 9, 15);
  final today = JourneyState.dateKey(now);
  final yesterday = LpDate.addDays(today, -1);

  late ProviderContainer c;
  late MemoryWidgetStore store;
  late WidgetCoordinator coordinator;
  late _CountingJourneys journeys;

  setUp(() {
    store = MemoryWidgetStore();
    coordinator = WidgetCoordinator(store);
    c = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(now: now),
        journeyRepositoryProvider.overrideWith((ref) {
          journeys = _CountingJourneys(ApiJourneyRepository(
            ref.watch(journeyApiProvider),
          ));
          return journeys;
        }),
      ],
    );
    addTearDown(c.dispose);
  });

  JourneyStore seed({Map<DateTime, DayLog>? days}) {
    final s = c.read(quitStoreProvider.notifier);
    s.seedDemoJourney();
    s.replaceForTest(
      c.read(quitStoreProvider)!.copyWith(
        days:
            days ??
            {today: DayLog(date: today, puffs: 2, limit: 48, hourBuckets: {8: 2})},
        pendingSlipCleanDays: () => null,
      ),
    );
    journeys.saves = 0;
    return s;
  }

  void queue(List<PendingPuff> events) =>
      store.values[PendingPuffs.outboxKey] = PendingPuffs.encode(events);

  PendingPuff puff(int seq, {int delta = 1, DateTime? at}) => PendingPuff(
    id: 'e$seq',
    seq: seq,
    at: at ?? DateTime(2026, 9, 4, 8, 30),
    delta: delta,
  );

  int puffsOn(DateTime day) => c.read(quitStoreProvider)!.days[day]?.puffs ?? 0;

  String? cursor() => store.values[PendingPuffs.cursorKey];

  group('applying the queue', () {
    test('lands every event and moves the cursor to the last one', () async {
      final s = seed();
      queue([puff(1), puff(2), puff(3)]);

      expect(await coordinator.drain(s, now: now), 3);

      expect(puffsOn(today), 5, reason: '2 seeded + 3 from the widget');
      expect(cursor(), '3');
    });

    test('files each puff on the day and hour it actually happened', () async {
      final s = seed();
      queue([
        puff(1, at: DateTime(2026, 9, 3, 23, 58)),
        puff(2, at: DateTime(2026, 9, 4, 8, 5)),
      ]);

      await coordinator.drain(s, now: now);

      final journey = c.read(quitStoreProvider)!;
      expect(journey.days[yesterday]!.puffs, 1);
      expect(journey.days[yesterday]!.hourBuckets, {23: 1});
      expect(journey.days[today]!.hourBuckets, {8: 3});
    });

    test('a − takes one off, and one off the right day', () async {
      final s = seed(
        days: {
          yesterday: DayLog(
            date: yesterday,
            puffs: 2,
            limit: 50,
            hourBuckets: {22: 2},
          ),
          today: DayLog(date: today, puffs: 2, limit: 48, hourBuckets: {8: 2}),
        },
      );
      queue([puff(1, delta: -1, at: DateTime(2026, 9, 3, 23, 59))]);

      await coordinator.drain(s, now: now);

      expect(puffsOn(yesterday), 1);
      expect(puffsOn(today), 2, reason: 'today is not where that − was tapped');
    });

    test('is ONE document write, however many events', () async {
      // Twelve events would otherwise be twelve unordered fire-and-forget
      // whole-document set()s of strictly superseded states.
      final s = seed();
      queue([for (var i = 1; i <= 12; i++) puff(i)]);

      await coordinator.drain(s, now: now);

      expect(puffsOn(today), 14);
      expect(journeys.saves, 1);
    });
  });

  group('idempotency — the double-count guard', () {
    test('a second drain over the same queue applies nothing', () async {
      final s = seed();
      queue([puff(1), puff(2)]);

      await coordinator.drain(s, now: now);
      final after = puffsOn(today);
      expect(await coordinator.drain(s, now: now), 0);

      expect(puffsOn(today), after);
    });

    test('a fresh coordinator over the same store also applies nothing', () async {
      // The next launch: a new process, the cursor read back off the device.
      final s = seed();
      queue([puff(1), puff(2)]);
      await coordinator.drain(s, now: now);

      await WidgetCoordinator(store).drain(s, now: now);

      expect(puffsOn(today), 4);
    });

    test('only the events above the cursor are applied', () async {
      final s = seed();
      store.values[PendingPuffs.cursorKey] = '2';
      queue([puff(1), puff(2), puff(3)]);

      expect(await coordinator.drain(s, now: now), 1);

      expect(puffsOn(today), 3);
    });

    test('two drains racing apply the events once', () async {
      // A resume and a foreground widget tap can fire together; both would
      // read the cursor before either had written it.
      final s = seed();
      queue([puff(1), puff(2), puff(3)]);

      await Future.wait([
        coordinator.drain(s, now: now),
        coordinator.drain(s, now: now),
      ]);

      expect(puffsOn(today), 5);
    });

    test('a queue appended to mid-session still drains on the next pass', () async {
      final s = seed();
      queue([puff(1)]);
      await coordinator.drain(s, now: now);

      // The widget kept appending while the app was open.
      queue([puff(1), puff(2), puff(3)]);
      expect(await coordinator.drain(s, now: now), 2);

      expect(puffsOn(today), 5);
    });
  });

  group('refusing to act', () {
    test('no journey means nothing is applied and the cursor holds', () async {
      final s = c.read(quitStoreProvider.notifier);
      queue([puff(1)]);

      expect(await coordinator.drain(s, now: now), 0);

      expect(cursor(), isNull, reason: 'the puff is early, not lost');
    });

    test('an empty queue is not a write', () async {
      final s = seed();

      expect(await coordinator.drain(s, now: now), 0);
      expect(journeys.saves, 0);
    });

    test('a corrupt queue is skipped, not applied', () async {
      final s = seed();
      store.values[PendingPuffs.outboxKey] = '{"v":1,"e":[ truncated';

      expect(await coordinator.drain(s, now: now), 0);
      expect(puffsOn(today), 2);
    });
  });

  group('signing out', () {
    test('abandons the queue rather than handing it to the next account', () async {
      // A shared phone: whatever the widget queued belonged to whoever was
      // signed in when they tapped it.
      final s = seed();
      queue([puff(1), puff(2), puff(3)]);

      await coordinator.discardQueued();
      await coordinator.drain(s, now: now);

      expect(puffsOn(today), 2, reason: 'nothing from the old account applied');
      expect(cursor(), '3');
    });
  });

  group('the mirror', () {
    test('pushes once and then stays quiet until something changes', () async {
      await coordinator.push({'v': 1, 'puffs': 2}, now: now);
      expect(store.refreshes, 1);

      await coordinator.push({'v': 1, 'puffs': 2}, now: now);
      expect(store.refreshes, 1, reason: 'nothing the widget shows has changed');

      await coordinator.push({'v': 1, 'puffs': 3}, now: now);
      expect(store.refreshes, 2);
    });

    test('arms a repaint at each of the next local midnights', () async {
      // Without these the day number only turns over on the 30-minute
      // updatePeriodMillis floor, so a phone left alone overnight shows
      // yesterday's day and yesterday's count until the system gets to it.
      await coordinator.push({'v': 1, 'dayKey': '2026-09-04'}, now: now);

      expect(store.scheduled, hasLength(kMirrorRepaintDays));
      expect(store.scheduled.first, DateTime(2026, 9, 5, 0, 0, 5));
      expect(store.scheduled.last, DateTime(2026, 9, 11, 0, 0, 5));
      // Local midnight by calendar arithmetic, so a DST night is still one day.
      for (final at in store.scheduled) {
        expect(at.hour, 0);
      }
    });

    test('re-arms when the day turns, and not on every puff', () async {
      await coordinator.push({'v': 1, 'dayKey': '2026-09-04', 'p': 1}, now: now);
      store.scheduled = const [];

      // Same day, different count: nothing to re-arm.
      await coordinator.push({'v': 1, 'dayKey': '2026-09-04', 'p': 2}, now: now);
      expect(store.scheduled, isEmpty);

      // The day turned.
      await coordinator.push(
        {'v': 1, 'dayKey': '2026-09-05', 'p': 0},
        now: DateTime(2026, 9, 5, 9),
      );
      expect(store.scheduled, hasLength(kMirrorRepaintDays));
      expect(store.scheduled.first, DateTime(2026, 9, 6, 0, 0, 5));
    });
  });
  group('reconciliation — it always converges', () {
    test('the widget and the app agree once a drain has run', () async {
      // The property that matters: whatever the widget was showing
      // optimistically, after a drain it equals the journey exactly.
      final s = seed();
      queue([puff(1), puff(2), puff(3), puff(4, delta: -1)]);

      await coordinator.drain(s, now: now);

      final journeyCount = puffsOn(today);
      final cursor = int.parse(store.values[PendingPuffs.cursorKey]!);
      final stillPending = PendingPuffs.pending(
        PendingPuffs.decode(store.values[PendingPuffs.outboxKey]),
        cursor,
      ).fold(0, (sum, e) => sum + e.delta);

      // What the widget draws is mirror.puffs + whatever is still pending.
      expect(journeyCount + stillPending, journeyCount);
      expect(stillPending, 0, reason: 'nothing may be left double-counted');
      expect(journeyCount, 4, reason: '2 seeded + 3 added - 1 removed');
    });

    test('the widget is repainted AFTER the cursor lands', () async {
      // Caught on device: applying the events commits the journey, which
      // triggers the app's own mirror push — and that push renders while the
      // cursor is still at its old value, so the widget shows
      // `newCount + theSameEventsStillPending`, one too high. Moving the
      // cursor then makes that number wrong, and the fingerprint skips every
      // later push because the mirror content has not changed since. The
      // widget read 2 against a journey of 1, indefinitely.
      final s = seed();
      queue([puff(1)]);
      final before = store.refreshes;

      await coordinator.drain(s, now: now);

      expect(
        store.refreshes,
        greaterThan(before),
        reason: 'a drain must always end in a repaint',
      );
      // And the repaint sees a cursor that already covers the events, so the
      // widget computes exactly what the journey holds.
      final cursor = int.parse(store.values[PendingPuffs.cursorKey]!);
      final pending = PendingPuffs.pending(
        PendingPuffs.decode(store.values[PendingPuffs.outboxKey]),
        cursor,
      );
      expect(pending, isEmpty);
      expect(puffsOn(today), 3);
    });

    test('a drain forces a repaint even when the mirror looks unchanged', () async {
      // The cursor moving IS a change the fingerprint cannot see: it stops the
      // drained events counting as pending. Without a forced push the widget
      // would show the pre-drain number with the pending ones no longer added
      // on — an undercount that sits there until something else moves.
      final s = seed();
      await coordinator.push({'v': 1, 'dayKey': '2026-09-04', 'puffs': 2}, now: now);
      final before = store.refreshes;
      queue([puff(1)]);

      await coordinator.drain(s, now: now);
      await coordinator.push({'v': 1, 'dayKey': '2026-09-04', 'puffs': 2}, now: now);

      expect(
        store.refreshes,
        greaterThan(before),
        reason: 'the identical mirror must still reach the device after a drain',
      );
    });

    test('a foreground re-push heals a repaint that never landed', () async {
      await coordinator.push({'v': 1, 'puffs': 2}, now: now);
      final before = store.refreshes;

      // Same content: normally skipped, which is what stops a heavy logging
      // day spamming the OS — and also what would strand a failed repaint.
      await coordinator.push({'v': 1, 'puffs': 2}, now: now);
      expect(store.refreshes, before);

      coordinator.invalidate();
      await coordinator.push({'v': 1, 'puffs': 2}, now: now);
      expect(store.refreshes, before + 1);
    });

    test('a stamp from a wrong clock cannot mint a future day', () async {
      // An NTP correction, or a timezone the device has since left. Clamped to
      // now, because a future day log would sit in the map as a confirmed day
      // and could hand out a streak nobody lived.
      final s = seed();
      queue([puff(1, at: DateTime(2026, 9, 20, 12))]);

      await coordinator.drain(s, now: now);

      expect(puffsOn(today), 3);
      expect(
        c.read(quitStoreProvider)!.days[LpDate.addDays(today, 16)],
        isNull,
        reason: 'no day may be created ahead of the clock',
      );
    });
  });

  group('reconciliation — a refused write loses nothing', () {
    setUp(() {
      store = MemoryWidgetStore();
      coordinator = WidgetCoordinator(store);
      c = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(now: now, online: false),
          journeyRepositoryProvider.overrideWith((ref) {
            journeys = _CountingJourneys(
              ApiJourneyRepository(ref.watch(journeyApiProvider)),
            );
            return journeys;
          }),
        ],
      );
      addTearDown(c.dispose);
    });

    test('the cursor holds and the journey is left exactly as it was', () async {
      // The fake backend refuses outright when offline. The puffs would exist
      // only in memory, so advancing the cursor would lose them to the next
      // cold start.
      final s = c.read(quitStoreProvider.notifier);
      s.seedDemoJourney();
      s.replaceForTest(
        c.read(quitStoreProvider)!.copyWith(
          days: {
            today: DayLog(date: today, puffs: 2, limit: 48, hourBuckets: {8: 2}),
          },
          pendingSlipCleanDays: () => null,
        ),
      );
      queue([puff(1), puff(2)]);

      await coordinator.drain(s, now: now);

      expect(
        c.read(quitStoreProvider)!.days[today]!.puffs,
        2,
        reason: 'the batch is all-or-nothing — memory must not keep them',
      );
      expect(store.values[PendingPuffs.cursorKey], isNull);
    });

    test('and a later drain applies them exactly once', () async {
      // Memory was rolled back and the cursor held, so the retry is the FIRST
      // time these events land. If either half were wrong this would be 6.
      final s = c.read(quitStoreProvider.notifier);
      s.seedDemoJourney();
      s.replaceForTest(
        c.read(quitStoreProvider)!.copyWith(
          days: {
            today: DayLog(date: today, puffs: 2, limit: 48, hourBuckets: {8: 2}),
          },
          pendingSlipCleanDays: () => null,
        ),
      );
      queue([puff(1), puff(2)]);
      await coordinator.drain(s, now: now);

      (c.read(connectivityProvider.notifier) as ToggleConnectivity)
          .set(true);
      await coordinator.drain(s, now: now);

      expect(c.read(quitStoreProvider)!.days[today]!.puffs, 4);
      expect(store.values[PendingPuffs.cursorKey], '2');
    });
  });
}



/// Counts the write-behind saves so "one drain is one document write" is a
/// test rather than a claim.
class _CountingJourneys implements JourneyRepository {
  _CountingJourneys(this._inner);

  final JourneyRepository _inner;
  int saves = 0;

  @override
  Future<JourneyState> create({
    required UserProfile profile,
    required QuitPlan plan,
  }) => _inner.create(profile: profile, plan: plan);

  @override
  Future<void> save(JourneyState journey) {
    saves++;
    return _inner.save(journey);
  }

  @override
  Future<void> delete() => _inner.delete();
}
