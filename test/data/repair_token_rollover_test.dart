import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// QA H2 (Aug 31 2026, 30-day emulator sim): the repair-token wallet never
/// depleted across day rollovers. Over-limit days 15, 20, 21 and 22 ALL
/// absorbed "Repair token used — your streak survives", the streak climbed
/// 9 → 16, and slip recovery was unreachable for anyone past a 7-day streak.
///
/// The existing token tests never crossed a rollover — every fixture parked
/// today on the line and tapped once. This one replays the sim through the
/// real store with the clock advanced a day at a time, and pins the spec:
/// 1 token per 7 streak-days, wallet cap 2, so at most TWO absorbs are
/// fundable and the third over-limit day breaks the chain and arms recovery.
void main() {
  final start = DateTime(2026, 9, 1);
  var now = DateTime(2026, 9, 1, 10, 15);
  late ProviderContainer c;

  setUp(() {
    now = DateTime(2026, 9, 1, 10, 15);
    c = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        nowProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(c.dispose);
  });

  JourneyState journey() => c.read(quitStoreProvider)!;

  /// Day-1 journey: B=20/day, 30-day taper — the sim's fixture.
  void seedDay1() {
    c
        .read(quitStoreProvider.notifier)
        .replaceForTest(
          JourneyState(
            profile: const UserProfile(
              alias: '@simfox',
              avatarEmoji: '🦊',
            ),
            plan: QuitPlan(
              method: QuitMethod.taper,
              paceDays: 30,
              startDate: start,
              baselinePuffsPerDay: 20,
              weeklySpend: 14,
              strength: NicStrength.mg50,
            ),
            days: const {},
            cravingsSurvivedTotal: 0,
            repairTokens: 0,
            longestStreak: 0,
            goals: const [],
            earnedBadges: const {},
          ),
        );
  }

  /// Advances the clock to 10:15 on plan day [d] and logs [puffs] there.
  void logOnDay(int d, {required int puffs}) {
    now = LpDate.addDays(
      start,
      d - 1,
    ).add(const Duration(hours: 10, minutes: 15));
    c.read(dayClockProvider.notifier).refresh();
    c.read(quitStoreProvider.notifier).logPuff(count: puffs);
  }

  int limitOn(int d) => journey().limitOn(LpDate.addDays(start, d - 1));

  DayLog logOf(int d) => journey().days[LpDate.addDays(start, d - 1)]!;

  test('the wallet funds exactly two absorbs, then the chain breaks', () {
    seedDay1();

    // Days 1–14: on the line every day. Token #1 is earned by finishing
    // day 7, #2 by finishing day 14 — so on day 14 itself the wallet still
    // reads 1; the second token is there from day 15.
    for (var d = 1; d <= 14; d++) {
      logOnDay(d, puffs: limitOn(d));
    }
    expect(journey().repairTokens, 1, reason: 'day 14 is not finished yet');
    expect(c.read(todayProvider)!.streak, 14);

    // Day 15: two tokens funded; over the line → token #1 absorbs it.
    // Wallet: 1.
    logOnDay(15, puffs: limitOn(15) + 2);
    expect(logOf(15).repairTokenUsed, isTrue, reason: 'day 15 absorbed');
    expect(journey().repairTokens, 1, reason: 'one token left after day 15');
    expect(journey().pendingSlipCleanDays, isNull);

    // Days 16–19 clean. Not seven days since the last mint — nothing earned.
    for (var d = 16; d <= 19; d++) {
      logOnDay(d, puffs: limitOn(d));
    }
    expect(journey().repairTokens, 1, reason: 'no re-mint on days 16–19');

    // Day 20: over the line → token #2 absorbs it. Wallet: 0.
    logOnDay(20, puffs: limitOn(20) + 2);
    expect(logOf(20).repairTokenUsed, isTrue, reason: 'day 20 absorbed');
    expect(journey().repairTokens, 0, reason: 'wallet empty after day 20');
    expect(c.read(todayProvider)!.streak, 20, reason: 'streak still alive');

    // Day 21: over the line with NOTHING to absorb it. This is the day the
    // sim watched get "absorbed" for the third time. It must not be: the
    // flame breaks honestly and slip recovery arms.
    logOnDay(21, puffs: limitOn(21) + 2);
    expect(logOf(21).repairTokenUsed, isFalse, reason: 'day 21 not absorbed');
    expect(journey().repairTokens, 0);
    expect(
      journey().pendingSlipCleanDays,
      20,
      reason: 'recovery arms with the 20 clean days before the slip',
    );

    // Day 22: still nothing in the wallet — and the streak is gone.
    logOnDay(22, puffs: limitOn(22) + 2);
    expect(logOf(22).repairTokenUsed, isFalse, reason: 'day 22 not absorbed');
    expect(journey().repairTokens, 0);
    expect(c.read(todayProvider)!.streak, 0);
  });

  test(
    'a token is earned by finishing the seventh day, not by starting it',
    () {
      // Six clean days; the seventh goes over the line. The day that would
      // mint the token cannot be the day it absorbs — the chain breaks and
      // recovery arms, exactly as docs/03 §5 reads.
      seedDay1();
      for (var d = 1; d <= 6; d++) {
        logOnDay(d, puffs: limitOn(d));
      }
      expect(journey().repairTokens, 0);
      logOnDay(7, puffs: limitOn(7) + 1);
      expect(logOf(7).repairTokenUsed, isFalse);
      expect(journey().pendingSlipCleanDays, 6);
      expect(journey().repairTokens, 0);
    },
  );

  test('the eighth day can spend the token the seventh day earned', () {
    seedDay1();
    for (var d = 1; d <= 7; d++) {
      logOnDay(d, puffs: limitOn(d));
    }
    expect(journey().repairTokens, 0, reason: 'day 7 is not finished yet');
    logOnDay(8, puffs: limitOn(8) + 1);
    expect(logOf(8).repairTokenUsed, isTrue);
    expect(journey().repairTokens, 0);
    expect(
      c.read(todayProvider)!.streak,
      8,
      reason: 'the flame dimmed, not out',
    );
  });

  test('the wallet is re-derived from history on every commit', () {
    // A stale stored value (a journey written under the old leak, or a
    // fixture) is corrected by the first mutation, never trusted.
    seedDay1();
    for (var d = 1; d <= 3; d++) {
      logOnDay(d, puffs: limitOn(d));
    }
    c
        .read(quitStoreProvider.notifier)
        .replaceForTest(journey().copyWith(repairTokens: 2));
    logOnDay(4, puffs: limitOn(4));
    expect(journey().repairTokens, 0, reason: 'three days fund nothing');
  });
}
