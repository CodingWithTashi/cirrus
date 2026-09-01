import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/home/widgets/log_feedback.dart';

import '../helpers.dart';

/// The quick-log burst: `logPuff(count:)` bursts, their undo, and the burst
/// grouping itself. The transition rules (repair token, slip arming) must
/// behave exactly as if the burst had been that many single taps — and a
/// tap is always exactly one puff (QA H1, Aug 31 2026: the old accelerating
/// ramp turned 18 rapid taps into 68 puffs).
void main() {
  // The store keys "today" off the real clock, so these fixtures do too.
  final now = DateTime.now();
  final key = JourneyState.dateKey(now);
  late ProviderContainer c;

  setUp(() {
    c = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(c.dispose);
  });

  /// Seeded journey with the day map replaced by a known today plus exactly
  /// the completed history that funds [tokens]: the wallet is derived from
  /// the day map (docs/03 §5, one token per seven holding days), so a
  /// fixture that wants a token has to have earned it.
  void seedToday({
    required int puffs,
    required int limit,
    int tokens = 0,
    Map<int, int> hourBuckets = const {},
  }) {
    final store = c.read(quitStoreProvider.notifier);
    store.seedDemoJourney();
    final history = <DateTime, DayLog>{};
    for (var back = tokens * 7; back >= 1; back--) {
      final d = LpDate.addDays(key, -back);
      history[d] = DayLog(date: d, puffs: 10, limit: 100);
    }
    store.replaceForTest(
      c.read(quitStoreProvider)!.copyWith(
        days: {
          ...history,
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

    test('re-crossing after an undo on an absorbed day is the same slip', () {
      // Cross with a token (absorbed), undo back under the line, cross
      // again: the day already spent its token and still holds, so the
      // second crossing must not arm recovery.
      seedToday(puffs: 100, limit: 100, tokens: 1);
      final store = c.read(quitStoreProvider.notifier);
      store.logPuff(at: now);
      expect(today().repairTokenUsed, isTrue);
      store.undoPuffs(1);
      expect(today().puffs, 100);

      store.logPuff(at: now);

      expect(today().puffs, 101);
      expect(today().repairTokenUsed, isTrue);
      expect(c.read(quitStoreProvider)!.pendingSlipCleanDays, isNull);
      expect(c.read(quitStoreProvider)!.repairTokens, 0);
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

    test('every tap in a burst logs exactly one puff — no ramp', () {
      // The ramp used to answer 1,1,1,2,2,3,3,5,5 here (23 puffs for nine
      // taps). N taps are N puffs; the burst only groups them for Undo.
      final burst = c.read(puffBurstProvider.notifier);
      final increments = [
        for (var i = 0; i < 9; i++)
          burst.tap(at: t0.add(Duration(milliseconds: 300 * i))),
      ];

      expect(increments, List.filled(9, 1));
      expect(c.read(puffBurstProvider), 9, reason: 'state is the burst total');
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
