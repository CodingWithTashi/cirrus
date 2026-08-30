import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// Things that would have shipped wrong.
void main() {
  group('the Comeback badge', () {
    // It was in the grid, awarded by nothing, and counted in the "N/17
    // earned" denominator — so the one badge about recovering from a bad day
    // was itself a permanent small reproach.
    late ProviderContainer c;

    setUp(() {
      c = ProviderContainer(overrides: fastBackendOverrides());
      addTearDown(c.dispose);
    });

    /// The seeded journey with its day map replaced, so this file does not
    /// re-derive a plan the engines already own.
    JourneyState journeyWith(List<({int day, int puffs, int limit})> days) {
      final start = DateTime(2026, 8, 1);
      c.read(quitStoreProvider.notifier).seedDemoJourney();
      final seeded = c.read(quitStoreProvider)!;
      return seeded.copyWith(
        days: {
          for (final d in days)
            JourneyState.dateKey(start.add(Duration(days: d.day))): DayLog(
              date: JourneyState.dateKey(start.add(Duration(days: d.day))),
              puffs: d.puffs,
              limit: d.limit,
            ),
        },
      );
    }

    test('is earned by going straight back under the line', () async {
      final store = c.read(quitStoreProvider.notifier);
      store.replaceForTest(
        journeyWith([
          (day: 0, puffs: 120, limit: 100), // over
          (day: 1, puffs: 80, limit: 100), // and straight back under
        ]),
      );
      // A no-op mutation re-runs the badge pass.
      store.logPuff(at: DateTime(2026, 8, 1));

      expect(c.read(quitStoreProvider)!.earnedBadges, contains('comeback'));
    });

    test('is not earned by a bad day followed by another one', () async {
      final store = c.read(quitStoreProvider.notifier);
      store.replaceForTest(
        journeyWith([
          (day: 0, puffs: 120, limit: 100),
          (day: 1, puffs: 130, limit: 100),
        ]),
      );
      store.logPuff(at: DateTime(2026, 8, 1));

      expect(
        c.read(quitStoreProvider)!.earnedBadges,
        isNot(contains('comeback')),
        reason: 'two bad days in a row is not a comeback',
      );
    });

    test('is not earned by recovering a week later', () async {
      // The promise is that a slip costs one day, not the attempt. A rule that
      // let you claim it a week later would be describing something else.
      final store = c.read(quitStoreProvider.notifier);
      store.replaceForTest(
        journeyWith([
          (day: 0, puffs: 120, limit: 100),
          (day: 7, puffs: 40, limit: 100),
        ]),
      );
      store.logPuff(at: DateTime(2026, 8, 1));

      expect(
        c.read(quitStoreProvider)!.earnedBadges,
        isNot(contains('comeback')),
      );
    });
  });
}
