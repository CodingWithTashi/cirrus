import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/analytics/lp_events.dart';
import '../../domain/logic/exercises/exercise.dart';
import 'providers.dart';

/// The last exercise somebody finished, held for whoever asks about it next.
///
/// An exercise ends on its own screen (the arena, the exercise scaffold) and
/// the thing that cares is somewhere else: the chat that offered it wants to
/// tell Ember what they just did. This is the one hand-over point, so neither
/// side has to know the other exists.
///
/// In memory only, and deliberately short-lived: a run is news for one
/// craving ([CravingWindow]), and it belongs to the session it was filed in.
class ExerciseRuns extends Notifier<ExerciseRun?> {
  /// When the stored run was reported, on the app's clock.
  DateTime? _reportedAt;

  @override
  ExerciseRun? build() {
    // The shared-phone rule. A run is account-shaped state in memory, and what
    // it becomes is a line telling Ember what "they" just did — so it must
    // not reach the next person to sign in on this phone. Watching whether
    // there is a journey at all rebuilds this on sign-out, on account
    // deletion and on the next sign-in, and a rebuild starts from nothing.
    ref.watch(quitStoreProvider.select((journey) => journey == null));
    // A rebuild runs on the SAME instance, so the field is reset by hand.
    _reportedAt = null;
    return null;
  }

  /// Files a finished run, replacing whatever was stored, and reports it:
  /// this is the one place `exercise_finished` fires, so a screen that files
  /// its run cannot forget the event.
  void report(ExerciseRun run) {
    _reportedAt = ref.read(nowProvider)();
    state = run;
    ref.read(analyticsProvider).exerciseFinished(run);
  }

  /// The stored run when it was opened from [source] and reported inside
  /// [CravingWindow.duration] of [now], handed over ONCE: it is cleared, so
  /// the next message does not report it again.
  ExerciseRun? takeRecent({
    required ExerciseSource source,
    required DateTime now,
  }) {
    final run = peekRecent(source: source, now: now);
    if (run != null) {
      _reportedAt = null;
      state = null;
    }
    return run;
  }

  /// [takeRecent] without clearing — for a view that only asks whether there
  /// is something to follow up on.
  ExerciseRun? peekRecent({
    required ExerciseSource source,
    required DateTime now,
  }) {
    final run = state;
    if (run == null || run.source != source) return null;
    return CravingWindow.covers(_reportedAt, now) ? run : null;
  }
}

final exerciseRunsProvider = NotifierProvider<ExerciseRuns, ExerciseRun?>(
  ExerciseRuns.new,
);
