import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/journey_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/repositories/repositories.dart';

import '../helpers.dart';

/// iPhone 15, TestFlight, Sep 2 2026: the coach-name CTA sat on a spinner
/// for three to four seconds — a cold-started `setCoachName`, behind an App
/// Check attempt that had to fail first.
///
/// The store's policy always said a timeout accepts the name locally. Nothing
/// ever imposed one, so "timeout" meant "however long the wire takes". The
/// wait is now bounded by [JourneyStore.coachNameBudget]; a definite no
/// inside the budget still blocks.
void main() {
  ProviderContainer container(CoachNameRepository guard) {
    final c = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        coachNameRepositoryProvider.overrideWithValue(guard),
      ],
    );
    addTearDown(c.dispose);
    c.read(quitStoreProvider.notifier).seedDemoJourney();
    return c;
  }

  testWidgets('a guard that never answers releases the funnel at the budget', (
    tester,
  ) async {
    final c = container(const _NeverAnswers());
    bool? answer;
    unawaited(
      c
          .read(quitStoreProvider.notifier)
          .reserveCoachName('Pip')
          .then((v) => answer = v),
    );

    await tester.pump(
      JourneyStore.coachNameBudget - const Duration(milliseconds: 100),
    );
    expect(answer, isNull, reason: 'inside the budget we are still waiting');

    await tester.pump(const Duration(milliseconds: 200));
    expect(answer, isTrue, reason: 'past the budget the name is kept');
    expect(c.read(quitStoreProvider)!.profile.coachName, 'Pip');
  });

  testWidgets('a definite no inside the budget still blocks', (tester) async {
    final c = container(const _Refuses());
    // Elapse the seed's write-behind ack (a zero-length timer on the fake
    // server) so the test ends with nothing pending — a bare `pump()` draws
    // a frame without moving the fake clock.
    await tester.pump(const Duration(milliseconds: 1));
    final before = c.read(quitStoreProvider)!.profile.coachName;

    final answer = await c
        .read(quitStoreProvider.notifier)
        .reserveCoachName('Pip');

    expect(answer, isFalse);
    expect(c.read(quitStoreProvider)!.profile.coachName, before);
  });

  test('the budget is a beat, not a cold start', () {
    // Long enough for a warm callable on a slow mobile link; short enough
    // that nobody reads it as a hang. Move it deliberately, with a reason.
    expect(
      JourneyStore.coachNameBudget.inMilliseconds,
      inInclusiveRange(1000, 2000),
    );
  });
}

class _NeverAnswers implements CoachNameRepository {
  const _NeverAnswers();

  @override
  Future<bool> reserve(String name) => Completer<bool>().future;
}

class _Refuses implements CoachNameRepository {
  const _Refuses();

  @override
  Future<bool> reserve(String name) async => false;
}
