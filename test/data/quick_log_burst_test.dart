import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/home/widgets/log_feedback.dart';

import '../helpers.dart';

/// The accelerating quick-log: `logPuff(count:)` bursts, their undo, and the
/// tap-ramp itself. The transition rules (repair token, slip arming) must
/// behave exactly as if the burst had been that many single taps.
void main() {
  // The store keys "today" off the real clock, so these fixtures do too.
  final now = DateTime.now();
  final key = JourneyState.dateKey(now);
  late ProviderContainer c;

  setUp(() {
    c = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(c.dispose);
  });

  /// Seeded journey with the day map replaced by a single known today —
  /// no history, so the badge pass can't re-accrue streak tokens under the
  /// assertions.
  void seedToday({
    required int puffs,
    required int limit,
    int tokens = 0,
    Map<int, int> hourBuckets = const {},
  }) {
    final store = c.read(quitStoreProvider.notifier);
    store.seedDemoJourney();
    store.replaceForTest(
      c.read(quitStoreProvider)!.copyWith(
        days: {
          key: DayLog(
            date: key,
            puffs: puffs,
            limit: limit,
            hourBuckets: hourBuckets,
          ),
        },
        repairTokens: tokens,
        pendingSlipCleanDays: () => null,
      ),
    );
  }

  DayLog today() => c.read(quitStoreProvider)!.days[key]!;

  group('logPuff(count:)', () {
    test('adds the whole burst in one commit, buckets included', () {
      seedToday(puffs: 10, limit: 100);
      c.read(quitStoreProvider.notifier).logPuff(at: now, count: 5);

      expect(today().puffs, 15);
      expect(today().hourBuckets[now.hour], 5);
    });

    test('a burst crossing the line burns the token on the crossing puff', () {
      seedToday(puffs: 98, limit: 100, tokens: 1);
      c.read(quitStoreProvider.notifier).logPuff(at: now, count: 5);

      expect(today().puffs, 103);
      expect(today().repairTokenUsed, isTrue);
      expect(c.read(quitStoreProvider)!.repairTokens, 0);
      expect(
        c.read(quitStoreProvider)!.pendingSlipCleanDays,
        isNull,
        reason: 'the token absorbed the slip, exactly as five single taps do',
      );
    });

    test('a crossing burst with no token arms the slip flow', () {
      seedToday(puffs: 98, limit: 100);
      c.read(quitStoreProvider.notifier).logPuff(at: now, count: 5);

      expect(today().repairTokenUsed, isFalse);
      expect(c.read(quitStoreProvider)!.pendingSlipCleanDays, isNotNull);
    });
  });

  group('undoPuffs', () {
    test('drains the newest hours first and clamps to what today holds', () {
      seedToday(puffs: 10, limit: 100, hourBuckets: const {14: 4, 15: 6});
      final store = c.read(quitStoreProvider.notifier);

      store.undoPuffs(8);
      expect(today().puffs, 2);
      expect(today().hourBuckets, {14: 2});

      store.undoPuffs(99);
      expect(today().puffs, 0);
      expect(today().hourBuckets, isEmpty);
    });
  });

  group('adjustToday', () {
    test('downward goes through undoPuffs so buckets drain honestly', () {
      seedToday(puffs: 10, limit: 100, hourBuckets: const {14: 4, 15: 6});
      c.read(quitStoreProvider.notifier).adjustToday(6);

      expect(today().puffs, 6);
      expect(today().hourBuckets, {14: 4, 15: 2});
    });

    test('upward goes through logPuff, over-limit rules included', () {
      seedToday(puffs: 98, limit: 100, tokens: 1);
      c.read(quitStoreProvider.notifier).adjustToday(103);

      expect(today().puffs, 103);
      expect(today().repairTokenUsed, isTrue);
      expect(c.read(quitStoreProvider)!.repairTokens, 0);
    });

    test('same value and negative targets are no-ops', () {
      seedToday(puffs: 10, limit: 100);
      final store = c.read(quitStoreProvider.notifier);
      store.adjustToday(10);
      store.adjustToday(-3);

      expect(today().puffs, 10);
    });
  });

  group('PuffBurst', () {
    final t0 = DateTime(2026, 8, 20, 15);

    test('ramps 1,1,1,2,2,3,3,5 within one burst', () {
      final burst = c.read(puffBurstProvider.notifier);
      final increments = [
        for (var i = 0; i < 9; i++)
          burst.tap(at: t0.add(Duration(milliseconds: 300 * i))),
      ];

      expect(increments, [1, 1, 1, 2, 2, 3, 3, 5, 5]);
      expect(c.read(puffBurstProvider), 23, reason: 'state is the burst total');
    });

    test('a pause longer than the window starts a fresh burst at +1', () {
      final burst = c.read(puffBurstProvider.notifier);
      for (var i = 0; i < 5; i++) {
        burst.tap(at: t0.add(Duration(milliseconds: 300 * i)));
      }

      expect(burst.tap(at: t0.add(const Duration(seconds: 10))), 1);
      expect(c.read(puffBurstProvider), 1);
    });

    test('reset clears the running total so undo cannot double-count', () {
      final burst = c.read(puffBurstProvider.notifier);
      burst.tap(at: t0);
      burst.tap(at: t0.add(const Duration(milliseconds: 100)));
      burst.reset();

      expect(c.read(puffBurstProvider), 0);
      expect(
        burst.tap(at: t0.add(const Duration(milliseconds: 200))),
        1,
        reason: 'the tap after a reset is a fresh burst',
      );
    });
  });
}
