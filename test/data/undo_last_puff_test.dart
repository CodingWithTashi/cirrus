import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// "Last puff" follows the puffs that are actually logged (docs/10 §41).
///
/// `lastPuffAt` only ever moved forward, so an accidental tap and its Undo
/// restarted the whole health timeline from the tap: the puff was gone and its
/// clock stayed. Seen on a Pixel 8, where a test puff logged at 8:01 PM and
/// taken back left "last puff" at 8:01 PM. Past-day corrections never moved it
/// at all, in either direction.
void main() {
  final now = DateTime(2026, 9, 13, 20, 1);
  final realLastPuff = DateTime(2026, 9, 13, 19, 40);

  ProviderContainer withJourney(JourneyState journey) {
    final c = ProviderContainer(overrides: fastBackendOverrides(now: now));
    addTearDown(c.dispose);
    c.read(quitStoreProvider.notifier).replaceForTest(journey);
    return c;
  }

  /// Day two with 21 puffs logged today, the last at 19:40.
  JourneyState dayTwo() {
    final j = journeyOnDay(2, now: now, lastPuffAt: realLastPuff);
    final today = JourneyState.dateKey(now);
    return j.copyWith(
      days: {
        ...j.days,
        today: DayLog(
          date: today,
          puffs: 21,
          limit: 180,
          hourBuckets: const {18: 10, 19: 11},
        ),
      },
    );
  }

  DateTime? lastPuff(ProviderContainer c) =>
      c.read(quitStoreProvider)!.lastPuffAt;

  group('Undo', () {
    test('puts "last puff" back where it was', () {
      final c = withJourney(dayTwo());
      final store = c.read(quitStoreProvider.notifier);

      store.logPuff();
      expect(lastPuff(c), now);
      store.undoLastPuff();

      expect(lastPuff(c), realLastPuff);
      expect(c.read(todayProvider)!.puffs, 21);
    });

    test('of part of a burst keeps the burst time; all of it restores', () {
      final c = withJourney(dayTwo());
      final store = c.read(quitStoreProvider.notifier);

      store.logPuff(count: 3);
      store.undoPuffs(1);
      expect(lastPuff(c), now, reason: 'two of the burst are still logged');
      store.undoPuffs(2);
      expect(lastPuff(c), realLastPuff);
    });

    test('through the day editor restores it too', () {
      final c = withJourney(dayTwo());
      final store = c.read(quitStoreProvider.notifier);

      store.adjustToday(22);
      store.adjustToday(21);

      expect(lastPuff(c), realLastPuff);
    });

    test('with no trail still never leaves it in an hour with no puff', () {
      // Logged at 20:01 in an earlier session and taken back after a restart:
      // nothing remembers 19:40, so it moves to the end of the latest hour
      // that still holds a puff — never earlier than the truth could be.
      final j = dayTwo();
      final today = JourneyState.dateKey(now);
      final c = withJourney(
        j.copyWith(
          lastPuffAt: () => now,
          days: {
            ...j.days,
            today: j.days[today]!.copyWith(
              puffs: 22,
              hourBuckets: const {18: 10, 19: 11, 20: 1},
            ),
          },
        ),
      );

      c.read(quitStoreProvider.notifier).undoLastPuff();

      expect(lastPuff(c), DateTime(2026, 9, 13, 19, 59, 59));
    });

    test('after signing out and back in does not follow the old trail', () {
      final c = withJourney(dayTwo());
      final store = c.read(quitStoreProvider.notifier);
      store.logPuff();

      store.signOut();
      final returning = dayTwo();
      final today = JourneyState.dateKey(now);
      store.replaceForTest(
        returning.copyWith(
          lastPuffAt: () => now,
          days: {
            ...returning.days,
            today: returning.days[today]!.copyWith(
              puffs: 22,
              hourBuckets: const {18: 10, 19: 11, 20: 1},
            ),
          },
        ),
      );
      store.undoLastPuff();

      // Settled from the day's own hours, not restored to 19:40 from a trail
      // that belonged to the session before.
      expect(lastPuff(c), DateTime(2026, 9, 13, 19, 59, 59));
    });
  });

  group('A past-day correction', () {
    test('to zero takes "last puff" off the day', () {
      final c = withJourney(
        journeyOnDay(
          2,
          now: now,
          puffsByDay: {1: 40},
          lastPuffAt: DateTime(2026, 9, 12, 10, 30),
        ),
      );

      c.read(quitStoreProvider.notifier).editPastDay(DateTime(2026, 9, 12), 0);

      final journey = c.read(quitStoreProvider)!;
      expect(journey.lastPuffAt, isNull, reason: 'no logged puff is left');
      expect(journey.days[DateTime(2026, 9, 12)]!.hourBuckets, isEmpty);
    });

    test('onto a later day moves "last puff" to the end of that day', () {
      // The morning-after "I vaped": yesterday was never logged, and the
      // health timeline was still counting from the day before.
      final c = withJourney(
        journeyOnDay(
          3,
          now: now,
          puffsByDay: {1: 40, 2: 0},
          lastPuffAt: DateTime(2026, 9, 11, 10, 30),
        ),
      );

      c.read(quitStoreProvider.notifier).editPastDay(DateTime(2026, 9, 12), 5);

      expect(lastPuff(c), DateTime(2026, 9, 12, 23, 59, 59));
    });

    test('adding puffs to its own day moves it to the end of that day', () {
      final c = withJourney(
        journeyOnDay(
          3,
          now: now,
          puffsByDay: {1: 40, 2: 30},
          lastPuffAt: DateTime(2026, 9, 12, 10, 30),
        ),
      );

      c.read(quitStoreProvider.notifier).editPastDay(DateTime(2026, 9, 12), 35);

      expect(lastPuff(c), DateTime(2026, 9, 12, 23, 59, 59));
    });

    test('taking puffs off its own day leaves it where it was', () {
      final c = withJourney(
        journeyOnDay(
          3,
          now: now,
          puffsByDay: {1: 40, 2: 30},
          lastPuffAt: DateTime(2026, 9, 12, 10, 30),
        ),
      );

      c.read(quitStoreProvider.notifier).editPastDay(DateTime(2026, 9, 12), 25);

      expect(lastPuff(c), DateTime(2026, 9, 12, 10, 30));
    });

    test('to an earlier day leaves it alone', () {
      final c = withJourney(
        journeyOnDay(
          3,
          now: now,
          puffsByDay: {1: 40, 2: 30},
          lastPuffAt: DateTime(2026, 9, 12, 10, 30),
        ),
      );

      c.read(quitStoreProvider.notifier).editPastDay(DateTime(2026, 9, 11), 50);

      expect(lastPuff(c), DateTime(2026, 9, 12, 10, 30));
    });
  });
}
