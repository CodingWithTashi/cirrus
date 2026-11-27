import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/stores/exercise_runs.dart';
import '../../domain/logic/exercises/exercise.dart';

/// Files a run from a screen that is being torn down.
///
/// An exercise left with back (or by anything else that removes its route)
/// has only its `dispose` to file from, and a provider write inside
/// `dispose` throws. So the write waits for a microtask: the frame that is
/// tearing the screen down finishes first.
///
/// A provider rather than a bare `scheduleMicrotask` on the notifier,
/// because of what can happen in between: the container can be disposed in
/// the very frame that disposes the screen (the app closing, a test that
/// ends with the exercise still up), and a late `report` would then throw
/// "Cannot use the Ref … after it has been disposed" as an uncaught async
/// error. This knows whether anybody is left to tell.
///
/// A screen reads it in `initState` and calls it from `dispose`.
final fileRunLaterProvider = Provider<void Function(ExerciseRun run)>((ref) {
  var alive = true;
  ref.onDispose(() => alive = false);
  return (run) => scheduleMicrotask(() {
    if (alive) ref.read(exerciseRunsProvider.notifier).report(run);
  });
});
