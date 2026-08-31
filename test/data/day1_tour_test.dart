/// The Day-1 walkthrough: what advances it, what does not, and what "skip"
/// is allowed to mean.
///
/// The whole point of this feature is a distinction the old checklist did not
/// make. A row that says "meet your coach" is a description of work. Ticking
/// it when somebody taps the description is a claim that the work happened —
/// the same class of lie as a Restore Purchases button that only shows a
/// success snack. So every assertion here is about one question: did the box
/// tick for the REAL move, and only for the real move?
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/day1_tour_store.dart';
import 'package:last_puff/data/stores/providers.dart';

import '../helpers.dart';

void main() {
  /// A container on a fresh day-1 journey: nothing done, nothing skipped.
  ProviderContainer freshDay1() {
    final container = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(container.dispose);
    final store = container.read(quitStoreProvider.notifier)..seedDemoJourney();
    store.replaceForTest(
      container
          .read(quitStoreProvider)!
          .copyWith(day1TasksDone: const {}, day1TourSkipped: false),
    );
    return container;
  }

  Day1TourStep? stepOf(ProviderContainer c) => c.read(day1TourStepProvider);

  group('starting', () {
    test('nothing is spotlighted until the walkthrough is started', () {
      final c = freshDay1();
      expect(stepOf(c), isNull);
      expect(c.read(day1TourLockedProvider), isFalse);
    });

    test('starting opens on the chosen move and closes the app around it', () {
      final c = freshDay1();
      c.read(day1TourProvider.notifier).start(Day1TourStep.logPuff);

      expect(stepOf(c), Day1TourStep.logPuff);
      expect(c.read(day1TourLockedProvider), isTrue);
    });

    test('the chosen step wins even when an earlier one is undone', () {
      // The checklist rows are tappable in any order, and the spotlight has
      // to light up on the screen the user chose to visit. Deriving "first
      // undone" here once sent someone to the coach with the HOME spotlight
      // active — a locked screen with no tooltip anywhere on it.
      final c = freshDay1();
      c.read(day1TourProvider.notifier).start(Day1TourStep.meetCoach);

      expect(stepOf(c), Day1TourStep.meetCoach);
    });

    test('a row tap still teaches after a skip', () {
      // "Skip setup" means "don't force me", not "never teach me". The
      // automatic entry (the day-1 redirect) respects the flag; an explicit
      // tap on a checklist row is intent and runs the single step — without
      // this, tasks 1 and 2 could never tick again after a skip.
      final c = freshDay1();
      c.read(day1TourProvider.notifier)
        ..skip()
        ..start(Day1TourStep.meetCoach);

      expect(stepOf(c), Day1TourStep.meetCoach);
    });

    test('it does not start for someone who already did all three', () {
      final c = freshDay1();
      c.read(quitStoreProvider.notifier)
        ..completeDay1Task(0)
        ..completeDay1Task(1)
        ..completeDay1Task(2);

      c.read(day1TourProvider.notifier).start(Day1TourStep.logPuff);

      expect(stepOf(c), isNull);
      expect(c.read(day1TourLockedProvider), isFalse);
    });

    test('it does not start when there is no journey at all', () {
      final c = ProviderContainer(overrides: fastBackendOverrides());
      addTearDown(c.dispose);
      c.read(day1TourProvider.notifier).start(Day1TourStep.logPuff);
      expect(stepOf(c), isNull);
    });
  });

  group('advancing', () {
    test('the steps run in order, each one on the real move', () {
      final c = freshDay1();
      final tour = c.read(day1TourProvider.notifier)
        ..start(Day1TourStep.logPuff);

      // Step one is the only move the journey store ticks by itself: logging
      // a puff anywhere sets task 0, which is exactly right — the lesson IS
      // the log, wherever it was made.
      c.read(quitStoreProvider.notifier).logPuff();
      expect(stepOf(c), Day1TourStep.meetCoach);

      tour.complete(Day1TourStep.meetCoach);
      expect(stepOf(c), Day1TourStep.dangerHours);

      tour.complete(Day1TourStep.dangerHours);
      expect(stepOf(c), isNull);
      expect(c.read(day1TourLockedProvider), isFalse);
      expect(
        c.read(quitStoreProvider)!.day1TasksDone,
        {0, 1, 2},
        reason: 'the checklist should show all three ticked',
      );
    });

    test('completing the chosen step falls back to the first undone', () {
      final c = freshDay1();
      final tour = c.read(day1TourProvider.notifier)
        ..start(Day1TourStep.dangerHours);
      expect(stepOf(c), Day1TourStep.dangerHours);

      tour.complete(Day1TourStep.dangerHours);

      // The request is spent; the derivation takes over in order.
      expect(stepOf(c), Day1TourStep.logPuff);
    });

    test('a step that never ran cannot complete anything', () {
      // `complete` is called from the screens, and a screen can be rebuilt for
      // reasons that have nothing to do with the walkthrough.
      final c = freshDay1();
      c.read(day1TourProvider.notifier).complete(Day1TourStep.meetCoach);

      expect(c.read(quitStoreProvider)!.day1TasksDone, isEmpty);
    });

    test('the walkthrough resumes where the user left off', () {
      // `day1TasksDone` lives on the journey and syncs, so a step is derived
      // rather than counted — which is why killing the app mid-tour cannot
      // put someone back on a lesson they already finished.
      final c = freshDay1();
      c.read(quitStoreProvider.notifier).completeDay1Task(0);
      c.read(day1TourProvider.notifier).start(Day1TourStep.meetCoach);

      expect(stepOf(c), Day1TourStep.meetCoach);
    });
  });

  group('pausing', () {
    test('pause unlocks the app and ticks nothing', () {
      // The escape hatch behind the back gesture and the tooltip's "maybe
      // later": leaves the step, keeps the tasks undone, records no skip —
      // so the checklist offers the same step again.
      final c = freshDay1();
      c.read(day1TourProvider.notifier)
        ..start(Day1TourStep.meetCoach)
        ..pause();

      expect(stepOf(c), isNull);
      expect(c.read(day1TourLockedProvider), isFalse);
      expect(c.read(quitStoreProvider)!.day1TasksDone, isEmpty);
      expect(c.read(quitStoreProvider)!.day1TourSkipped, isFalse);
    });

    test('pausing an idle tour is a no-op', () {
      final c = freshDay1();
      c.read(day1TourProvider.notifier).pause();
      expect(stepOf(c), isNull);
    });
  });

  group('skipping', () {
    test('skip ticks nothing', () {
      // The one thing this must never do. A skip that marked the tasks done
      // would put back the exact claim the whole change removes: three
      // checkmarks for work nobody did.
      final c = freshDay1();
      c.read(day1TourProvider.notifier)
        ..start(Day1TourStep.logPuff)
        ..skip();

      expect(c.read(quitStoreProvider)!.day1TasksDone, isEmpty);
      expect(c.read(quitStoreProvider)!.day1TourSkipped, isTrue);
    });

    test('skip opens the app back up', () {
      final c = freshDay1();
      c.read(day1TourProvider.notifier)
        ..start(Day1TourStep.logPuff)
        ..skip();

      expect(stepOf(c), isNull);
      expect(c.read(day1TourLockedProvider), isFalse);
    });

    test('the three moves are still there to be made afterwards', () {
      final c = freshDay1();
      c.read(day1TourProvider.notifier)
        ..start(Day1TourStep.logPuff)
        ..skip();

      c.read(quitStoreProvider.notifier).logPuff();

      expect(c.read(quitStoreProvider)!.day1TasksDone, contains(0));
    });
  });
}
