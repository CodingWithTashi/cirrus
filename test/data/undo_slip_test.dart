import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// Undo takes back the slip the puff caused, not just the puff.
///
/// A tap that crosses the day's line arms the slip-recovery card (or spends a
/// repair token), and Undo used to remove only the puff. So an accidental tap
/// on a zero-limit day — every day, for somebody quitting cold turkey — left
/// "A slip is data, not defeat." on Home with nothing logged, and that card
/// owns Home's one slot: the evening mood prompt and the craving nudge stayed
/// hidden behind it until the person walked through a recovery flow for a
/// slip that never happened (Nov 12 2026).
void main() {
  final now = DateTime(2026, 11, 12, 15, 30);
  final today = JourneyState.dateKey(now);

  ProviderContainer withJourney(JourneyState journey) {
    final c = ProviderContainer(overrides: fastBackendOverrides(now: now));
    addTearDown(c.dispose);
    c.read(quitStoreProvider.notifier).replaceForTest(journey);
    return c;
  }

  /// Day [day] of a cold-turkey plan: the line is zero every day.
  JourneyState coldTurkey(int day, {bool cleanHistory = false}) {
    final j = journeyOnDay(day, now: now);
    return j.copyWith(
      plan: j.plan.copyWith(method: QuitMethod.coldTurkey),
      days: {
        for (final e in j.days.entries)
          e.key: DayLog(
            date: e.key,
            puffs: 0,
            limit: 0,
            vapeFreeConfirmed: cleanHistory,
          ),
      },
    );
  }

  JourneyState state(ProviderContainer c) => c.read(quitStoreProvider)!;

  test('an accidental puff on a zero day, undone, leaves no slip behind', () {
    final c = withJourney(coldTurkey(2));
    final store = c.read(quitStoreProvider.notifier);

    store.logPuff();
    expect(state(c).pendingSlipCleanDays, isNotNull, reason: 'the tap arms it');
    store.undoLastPuff();

    expect(state(c).days[today]!.puffs, 0);
    expect(state(c).pendingSlipCleanDays, isNull);
  });

  test('undoing only part of the way back under the line keeps the slip', () {
    final c = withJourney(coldTurkey(2));
    final store = c.read(quitStoreProvider.notifier);

    store.logPuff(count: 3);
    store.undoPuffs(2);

    expect(state(c).days[today]!.puffs, 1);
    expect(state(c).pendingSlipCleanDays, isNotNull);
  });

  test('a slip from an earlier day is not cleared by today\'s undo', () {
    // Yesterday's slip is still waiting to be worked through. Today's
    // accidental tap on a taper day is under the line and armed nothing, so
    // taking it back must not quietly dismiss what yesterday left.
    final j = journeyOnDay(5, now: now).copyWith(pendingSlipCleanDays: () => 3);
    final c = withJourney(j);
    final store = c.read(quitStoreProvider.notifier);

    store.logPuff();
    store.undoLastPuff();

    expect(state(c).pendingSlipCleanDays, 3);
  });

  test('a repair token spent on an undone puff comes back', () {
    // Eight clean confirmed days fund one token; the ninth day's tap spends
    // it. Taken back, the day never crossed its line, so it is not a token
    // day and the wallet is whole again.
    final c = withJourney(coldTurkey(9, cleanHistory: true));
    final store = c.read(quitStoreProvider.notifier);

    store.logPuff();
    expect(state(c).days[today]!.repairTokenUsed, isTrue);
    expect(state(c).pendingSlipCleanDays, isNull, reason: 'the token took it');
    store.undoLastPuff();

    expect(state(c).days[today]!.repairTokenUsed, isFalse);
  });

  test('a token stays spent while the day is still over its line', () {
    final c = withJourney(coldTurkey(9, cleanHistory: true));
    final store = c.read(quitStoreProvider.notifier);

    store.logPuff(count: 2);
    store.undoPuffs(1);

    expect(state(c).days[today]!.repairTokenUsed, isTrue);
  });
}
