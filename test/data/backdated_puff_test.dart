import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/journey_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/journey_factory.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// The contract `logPuff(at:)` and `undoPuffs(at:)` now have to keep.
///
/// Both accepted a timestamp before this, but nothing in `lib/` ever passed
/// one — the home-screen widget is the first production caller, and it passes
/// timestamps that can be many hours old. These are the cases that were never
/// exercised until a puff could be logged while the app was dead.
void main() {
  final now = DateTime(2026, 9, 4, 9, 15);
  final today = JourneyState.dateKey(now);
  final yesterday = LpDate.addDays(today, -1);
  late ProviderContainer c;

  setUp(() {
    c = ProviderContainer(overrides: fastBackendOverrides(now: now));
    addTearDown(c.dispose);
  });

  JourneyStateSeed seed({
    Map<DateTime, DayLog>? days,
    DateTime? lastPuffAt,
  }) {
    final store = c.read(quitStoreProvider.notifier);
    store.seedDemoJourney();
    final seeded = c.read(quitStoreProvider)!;
    // Rebuilt through the factory both backends mint day-1 journeys with,
    // because `copyWith` cannot CLEAR `lastPuffAt` (plain `??`) and the demo
    // persona carries one — so "an account that has never logged a puff" is
    // otherwise unreachable as a fixture.
    store.replaceForTest(
      InitialJourney.build(
        profile: seeded.profile,
        plan: seeded.plan,
        now: now,
      ).copyWith(
        days: days ?? {},
        lastPuffAt: lastPuffAt,
        pendingSlipCleanDays: () => null,
      ),
    );
    return (store: store, read: () => c.read(quitStoreProvider)!);
  }

  group('a puff logged at a past instant', () {
    test('lands on that day and that hour bucket, not on now', () {
      final s = seed();

      s.store.logPuff(at: DateTime(2026, 9, 3, 23, 50));

      final log = s.read().days[yesterday]!;
      expect(log.puffs, 1);
      expect(log.hourBuckets, {23: 1});
      expect(
        s.read().days[today],
        isNull,
        reason: 'today must not be touched by a puff that happened yesterday',
      );
    });

    test('a fresh day log takes that day\'s own limit', () {
      final s = seed();

      s.store.logPuff(at: DateTime(2026, 9, 3, 23, 50));

      expect(
        s.read().days[yesterday]!.limit,
        s.read().limitOn(yesterday),
        reason: 'not today\'s line — the day it actually happened on',
      );
    });

    test('an existing day log keeps the limit it was created with', () {
      // Documents the rule rather than changing it: a day already on record
      // was measured against the line it had at the time, and a later curve
      // adjustment must not retroactively make that day a slip.
      final s = seed(
        days: {
          yesterday: DayLog(date: yesterday, puffs: 2, limit: 999),
        },
      );

      s.store.logPuff(at: DateTime(2026, 9, 3, 20));

      expect(s.read().days[yesterday]!.limit, 999);
    });
  });

  group('the lastPuffAt anchor only ever moves forward', () {
    test('a backdated puff does not rewind it', () {
      // The health timeline counts from this anchor. Moving it back would
      // restart a clock that never stopped and hand the user recovery
      // milestones they had not earned.
      final anchor = DateTime(2026, 9, 4, 8, 30);
      final s = seed(lastPuffAt: anchor);

      s.store.logPuff(at: DateTime(2026, 9, 3, 23, 50));

      expect(s.read().lastPuffAt, anchor);
    });

    test('a later puff does move it', () {
      final s = seed(lastPuffAt: DateTime(2026, 9, 4, 7));

      s.store.logPuff(at: DateTime(2026, 9, 4, 8, 45));

      expect(s.read().lastPuffAt, DateTime(2026, 9, 4, 8, 45));
    });

    test('a first-ever puff sets it', () {
      final s = seed();

      s.store.logPuff(at: DateTime(2026, 9, 3, 23, 50));

      expect(s.read().lastPuffAt, DateTime(2026, 9, 3, 23, 50));
    });

    test('the in-app button is unaffected — it still lands on now', () {
      // The guard has to be a no-op for every caller that omits `at`, which
      // is all four of them in `lib/`.
      final s = seed(lastPuffAt: DateTime(2026, 9, 4, 7));

      s.store.logPuff();

      expect(s.read().lastPuffAt, now);
    });
  });

  group('an undo scoped to its own day', () {
    test('takes the puff off the day it was tapped on', () {
      final s = seed(
        days: {
          yesterday: DayLog(
            date: yesterday,
            puffs: 3,
            limit: 50,
            hourBuckets: {21: 1, 23: 2},
          ),
          today: DayLog(date: today, puffs: 4, limit: 48, hourBuckets: {8: 4}),
        },
      );

      s.store.undoPuffs(1, at: DateTime(2026, 9, 3, 23, 59));

      expect(s.read().days[yesterday]!.puffs, 2);
      expect(s.read().days[yesterday]!.hourBuckets, {21: 1, 23: 1});
      expect(
        s.read().days[today]!.puffs,
        4,
        reason: 'a correction to yesterday must not take a puff off today',
      );
    });

    test('clamps at zero rather than going negative', () {
      // The drift case: the widget shows a stale count, the user presses −
      // twice, the day holds one puff.
      final s = seed(
        days: {
          today: DayLog(date: today, puffs: 1, limit: 48, hourBuckets: {8: 1}),
        },
      );

      s.store.undoPuffs(1);
      s.store.undoPuffs(1);

      expect(s.read().days[today]!.puffs, 0);
    });

    test('a day with no log at all is left alone, not created', () {
      final s = seed();

      s.store.undoPuffs(1, at: DateTime(2026, 9, 3, 23, 59));

      expect(s.read().days, isEmpty);
    });

    test('the in-app undo still means today', () {
      final s = seed(
        days: {
          yesterday: DayLog(date: yesterday, puffs: 2, limit: 50),
          today: DayLog(date: today, puffs: 2, limit: 48, hourBuckets: {8: 2}),
        },
      );

      s.store.undoLastPuff();

      expect(s.read().days[today]!.puffs, 1);
      expect(s.read().days[yesterday]!.puffs, 2);
    });
  });
}

typedef JourneyStateSeed = ({
  JourneyStore store,
  JourneyState Function() read,
});
