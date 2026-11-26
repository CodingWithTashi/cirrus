import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/exercise_runs.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/exercises/exercise.dart';
import 'package:last_puff/domain/models/coach_ui.dart';

import '../helpers.dart';

/// What a coach turn carries beyond its words (K3/K4), and the one place a
/// finished exercise is handed from the screen that ran it to the chat that
/// offered it (K5).
void main() {
  final now = DateTime(2026, 11, 25, 21, 30);

  const run = ExerciseRun(
    id: ExerciseId.orbs,
    source: ExerciseSource.coach,
    seconds: 61,
    completed: true,
    passed: false,
  );

  group('what a turn tells the server', () {
    test('nothing set is nothing sent', () {
      // An empty map spreads into the request as no keys at all, which is
      // what an older build sends: no `ui` means no cards.
      expect(const CoachTurnExtras().toJson(), <String, Object?>{});
    });

    test('what this build can draw', () {
      expect(
        const CoachTurnExtras(
          ui: CoachUiCaps(exercises: ['orbs'], craving: true),
        ).toJson(),
        {
          'ui': {
            'v': 1,
            'exercises': ['orbs'],
            'craving': true,
          },
        },
      );
    });

    test('what they just did', () {
      // The id, how long, and the two facts the app knows. No score and no
      // source: a block and a report both carry ids and nothing drawn.
      expect(const CoachTurnExtras(justDid: run).toJson(), {
        'justDid': {
          'exercise': 'orbs',
          'seconds': 61,
          'completed': true,
          'passed': false,
        },
      });
    });
  });

  group('the run store', () {
    ({ProviderContainer c, RecordingAnalytics a, void Function(DateTime) at})
    open() {
      var clock = now;
      final a = RecordingAnalytics();
      final c = ProviderContainer(
        overrides: fastBackendOverrides(
          analytics: a,
          extra: [nowProvider.overrideWithValue(() => clock)],
        ),
      );
      addTearDown(c.dispose);
      return (c: c, a: a, at: (t) => clock = t);
    }

    test('a run is handed over once', () {
      final (:c, :a, :at) = open();
      final runs = c.read(exerciseRunsProvider.notifier);
      runs.report(run);
      expect(c.read(exerciseRunsProvider), same(run));

      final later = now.add(const Duration(minutes: 5));
      expect(
        runs.peekRecent(source: ExerciseSource.coach, now: later),
        same(run),
      );
      expect(
        runs.peekRecent(source: ExerciseSource.coach, now: later),
        same(run),
      );
      expect(
        runs.takeRecent(source: ExerciseSource.coach, now: later),
        same(run),
      );
      expect(runs.takeRecent(source: ExerciseSource.coach, now: later), isNull);
      expect(c.read(exerciseRunsProvider), isNull);
    });

    test('a run from somewhere else, or an old one, is not handed over', () {
      final (:c, :a, :at) = open();
      final runs = c.read(exerciseRunsProvider.notifier);

      // The panic flow's run is not the chat's to report.
      runs.report(
        const ExerciseRun(
          id: ExerciseId.orbs,
          source: ExerciseSource.panic,
          seconds: 61,
          completed: true,
          passed: true,
        ),
      );
      expect(runs.peekRecent(source: ExerciseSource.coach, now: now), isNull);
      expect(runs.takeRecent(source: ExerciseSource.coach, now: now), isNull);

      // And a craving that is over is not "just before this message".
      runs.report(run);
      final late = now.add(const Duration(minutes: 20));
      expect(runs.peekRecent(source: ExerciseSource.coach, now: late), isNull);
      expect(runs.takeRecent(source: ExerciseSource.coach, now: late), isNull);
    });

    test('the window is measured from when the run was reported', () {
      // The stamp is the store's own clock at `report`, never the caller's
      // `now`: a run filed at 21:40 is still recent at 21:55.
      final (:c, :a, :at) = open();
      final runs = c.read(exerciseRunsProvider.notifier);
      at(now.add(const Duration(minutes: 10)));
      runs.report(run);
      expect(
        runs.peekRecent(
          source: ExerciseSource.coach,
          now: now.add(const Duration(minutes: 25)),
        ),
        same(run),
      );
    });

    test('reporting a run fires exercise_finished', () {
      // One place files a run and one place reports it: a screen that
      // called `report` and forgot the event would be an exercise nobody
      // can see was used.
      final (:c, :a, :at) = open();
      c.read(exerciseRunsProvider.notifier).report(run);
      expect(a.propsOfAll('exercise_finished'), [
        {
          'exercise': 'orbs',
          'source': 'coach',
          'completed': 'true',
          'passed': 'false',
          'seconds': 61,
        },
      ]);
    });

    test('a run does not outlive the session it was filed in', () {
      // The shared-phone rule: a run is in memory and account-shaped, and
      // what it becomes is a line telling Ember what "they" just did.
      final (:c, :a, :at) = open();
      c
          .read(quitStoreProvider.notifier)
          .replaceForTest(journeyOnDay(10, now: now));
      c.read(exerciseRunsProvider.notifier).report(run);

      c.read(quitStoreProvider.notifier).signOut();
      c
          .read(quitStoreProvider.notifier)
          .replaceForTest(journeyOnDay(1, now: now));

      expect(c.read(exerciseRunsProvider), isNull);
      expect(
        c
            .read(exerciseRunsProvider.notifier)
            .takeRecent(source: ExerciseSource.coach, now: now),
        isNull,
      );
    });
  });
}
