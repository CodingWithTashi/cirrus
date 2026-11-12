import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// The store's side of starting a new plan: one commit, one event.
///
/// The rules themselves are `PlanRestart`'s and are tested there; this is
/// that the command applies them, saves like every other mutation, and says
/// what happened — so "people start again instead of signing out" can be
/// read off the dashboard rather than inferred from screens.
void main() {
  final now = DateTime(2026, 11, 12, 15, 30);
  final today = LpDate.dayStart(now);

  (ProviderContainer, RecordingAnalytics) boot(JourneyState journey) {
    final analytics = RecordingAnalytics();
    final c = ProviderContainer(
      overrides: fastBackendOverrides(now: now, analytics: analytics),
    );
    addTearDown(c.dispose);
    c.read(quitStoreProvider.notifier).replaceForTest(journey);
    return (c, analytics);
  }

  test('starts day one today, from the level given, as plan two', () {
    final (c, _) = boot(journeyOnDay(36, now: now, baseline: 200));

    c
        .read(quitStoreProvider.notifier)
        .startNewPlan(method: QuitMethod.taper, paceDays: 21, level: 82);

    final plan = c.read(quitStoreProvider)!.plan;
    expect(plan.startDate, today);
    expect(plan.paceDays, 21);
    expect(plan.taperFrom, 82);
    expect(plan.planNumber, 2);
    expect(c.read(todayProvider)!.dayNumber, 1);
    expect(c.read(todayProvider)!.limit, 76);
  });

  test('says where the person was and what they chose', () {
    final (c, analytics) = boot(journeyOnDay(36, now: now, baseline: 200));

    c
        .read(quitStoreProvider.notifier)
        .startNewPlan(method: QuitMethod.coldTurkey, paceDays: 30, level: 60);

    expect(analytics.propsOfAll('plan_restarted'), [
      {
        'from_day': 36,
        'past_freedom': 'true',
        'method': 'coldTurkey',
        'pace': 30,
        'plan_number': 2,
      },
    ]);
  });

  test('mid-plan is reported as mid-plan', () {
    final (c, analytics) = boot(journeyOnDay(12, now: now, baseline: 200));

    c
        .read(quitStoreProvider.notifier)
        .startNewPlan(method: QuitMethod.taper, paceDays: 60, level: 150);

    expect(analytics.propsOf('plan_restarted'), containsPair('from_day', 12));
    expect(
      analytics.propsOf('plan_restarted'),
      containsPair('past_freedom', 'false'),
    );
  });

  test('advice worked out for the plan just left is not applied to the new '
      'one', () {
    // The nightly verdict is computed at 01:00 for the plan as it was then,
    // and re-read on every resume. A restart clears the accepted copy — so
    // the next resume read the old plan's number again and applied it: a
    // limit of 0 on day one of a new taper, and a stretched runway.
    final (c, _) = boot(journeyOnDay(36, now: now, baseline: 200));
    final store = c.read(quitStoreProvider.notifier)
      ..startNewPlan(method: QuitMethod.taper, paceDays: 21, level: 82);

    store.applyPlanAdvice(
      PlanAdvice(
        forDay: today,
        limit: 0,
        adherence: PlanAdherence.struggling,
        stretchDelta: 1,
      ),
    );

    final journey = c.read(quitStoreProvider)!;
    expect(journey.planAdvice, isNull);
    expect(journey.plan.totalDays, 21, reason: 'not stretched');
    expect(c.read(todayProvider)!.limit, 76);
  });

  test('a first day one takes no advice either — there is none to give', () {
    final (c, _) = boot(journeyOnDay(1, now: now, baseline: 200));
    c
        .read(quitStoreProvider.notifier)
        .applyPlanAdvice(
          PlanAdvice(
            forDay: today,
            limit: 5,
            adherence: PlanAdherence.crushing,
            stretchDelta: 0,
          ),
        );

    expect(c.read(quitStoreProvider)!.planAdvice, isNull);
  });

  test('advice for a later day of the plan still lands', () {
    final (c, _) = boot(journeyOnDay(5, now: now, baseline: 200));
    c
        .read(quitStoreProvider.notifier)
        .applyPlanAdvice(
          PlanAdvice(
            forDay: today,
            limit: 150,
            adherence: PlanAdherence.onTrack,
            stretchDelta: 0,
          ),
        );

    expect(c.read(todayProvider)!.limit, 150);
  });

  group('the first check-in is a Day-1 task only while Day 1 is in play', () {
    JourneyState coldTurkey(int day) {
      final j = journeyOnDay(day, now: now);
      return j.copyWith(
        plan: j.plan.copyWith(method: QuitMethod.coldTurkey),
        days: {
          for (final e in j.days.entries)
            e.key: DayLog(
              date: e.key,
              puffs: 0,
              limit: 0,
              vapeFreeConfirmed: true,
            ),
        },
        day1TasksDone: const {},
      );
    }

    test('on day one it ticks the task and says so', () {
      final (c, analytics) = boot(coldTurkey(1));
      c.read(quitStoreProvider.notifier).confirmVapeFreeDay();

      expect(c.read(quitStoreProvider)!.day1TasksDone, {0});
      expect(analytics.propsOfAll('day1_task_done'), [
        {'task': 'first_checkin'},
      ]);
    });

    test('an account weeks in does not start reporting Day-1 tasks', () {
      // Every cold-turkey account made before this shipped has task zero
      // undone — nothing to log. Their next confirmation must not land in
      // the Day-1 funnel as though they had just arrived.
      final (c, analytics) = boot(coldTurkey(9));
      c.read(quitStoreProvider.notifier).confirmVapeFreeDay();

      expect(analytics.names, isNot(contains('day1_task_done')));
      expect(analytics.names, isNot(contains('day1_completed')));
      expect(c.read(quitStoreProvider)!.day1TasksDone, isEmpty);
    });

    test('and it follows the line Home is showing, not a stale stored one', () {
      // Day one minted as a taper (stored limit 97), switched to cold turkey
      // the same afternoon: Home shows the zero-day button, so the tap on it
      // has to be the first move.
      final j = journeyOnDay(1, now: now);
      final switched = j.copyWith(
        plan: j.plan.copyWith(method: QuitMethod.coldTurkey),
        days: {today: DayLog(date: today, puffs: 0, limit: 97)},
        day1TasksDone: const {},
      );
      final (c, analytics) = boot(switched);
      c.read(quitStoreProvider.notifier).confirmVapeFreeDay();

      expect(c.read(quitStoreProvider)!.day1TasksDone, {0});
      expect(analytics.propsOfAll('day_confirmed'), [
        {'day': 'today', 'zero_day': 'true'},
      ]);
    });
  });

  test('reaches the backend like every other mutation', () async {
    final (c, _) = boot(journeyOnDay(36, now: now, baseline: 200));
    c
        .read(quitStoreProvider.notifier)
        .startNewPlan(method: QuitMethod.taper, paceDays: 21, level: 82);
    await Future<void>.delayed(const Duration(milliseconds: 5));

    // The write-behind save put it on the fake backend (a guest session:
    // `putJourney` binds one, so the read below sees the same account).
    final stored = c.read(fakeServerProvider).journeyJsonForCurrentSession();
    expect((stored!['plan'] as Map<String, dynamic>)['taperFrom'], 82);
    expect((stored['plan'] as Map<String, dynamic>)['planNumber'], 2);
  });
}
