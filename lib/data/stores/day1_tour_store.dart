import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/app_router.dart';
import 'providers.dart';

/// The three moves a new account is walked through, in order.
enum Day1TourStep {
  /// Home, the log button. The one gesture the whole app is built around.
  logPuff,

  /// Coach, the composer. Ember has already read their plan; they have to
  /// find that out by talking to it once.
  meetCoach,

  /// The danger-hours sheet. The reminder that shows up before the hour they
  /// usually cave is worthless until somebody sets the hour.
  dangerHours,
}

/// What the walkthrough itself holds: whether it is running this session, and
/// which step the user *chose* — the checklist rows are tappable in any order,
/// so the row tapped and the first undone task are not the same thing, and
/// navigating to one screen while spotlighting another strands the user on a
/// locked screen with no tooltip anywhere.
typedef Day1TourState = ({bool running, Day1TourStep? requested});

/// Whether the Day-1 walkthrough is running in this session, and on which
/// requested step.
///
/// The tour itself is a teaching device, not a state machine: which step is
/// active is DERIVED from what the user has actually done ([day1TourStepProvider]),
/// so there is no second copy of "have they logged a puff yet" to drift.
/// This holds the two bits that are genuinely separate — whether we are
/// walking them through at all, and which step they picked.
class Day1TourStore extends Notifier<Day1TourState> {
  @override
  Day1TourState build() => (running: false, requested: null);

  /// Begins the walkthrough at [step]. Called from the Day-1 screen, which is
  /// the only production route out of the paywall.
  ///
  /// A row tap is explicit intent, so this runs even after "skip setup" — a
  /// skip means "don't force me", not "never teach me"; only the automatic
  /// entry (the day-1 router redirect) respects the skip flag. It still
  /// refuses once everything is done, and ignores a step already ticked.
  void start(Day1TourStep step) {
    final journey = ref.read(quitStoreProvider);
    if (journey == null) return;
    final done = journey.day1TasksDone;
    if (done.length >= 3) return;
    state = (
      running: true,
      requested: done.contains(step.index) ? null : step,
    );
  }

  /// "Skip setup" — records that they chose not to be walked through, and
  /// **ticks nothing**.
  ///
  /// A skip that marked the tasks done would reintroduce exactly the lie this
  /// whole change removes. The three moves stay undone, stay listed, and stay
  /// available from the checklist.
  void skip() {
    state = (running: false, requested: null);
    ref.read(quitStoreProvider.notifier).skipDay1Tour();
  }

  /// The back gesture (or a tooltip "later"): leaves the step without ticking
  /// anything and without recording a skip, so the checklist can offer the
  /// same step again. The escape hatch that keeps a gated flow from being a
  /// hostage situation when the real move cannot happen — a coach reply needs
  /// a network, and airplane mode is not a reason to trap someone.
  void pause() {
    if (!state.running) return;
    state = (running: false, requested: null);
    ref.read(routerProvider).go(Routes.day1);
  }

  /// The real move happened. Marks the task and returns to the checklist so
  /// the box visibly ticks — the tick is the reward, and it is what keeps a
  /// gated flow from reading as a hostage situation.
  void complete(Day1TourStep step) {
    if (!state.running) return;
    ref.read(quitStoreProvider.notifier).completeDay1Task(step.index);
    final done = ref.read(quitStoreProvider)?.day1TasksDone ?? const <int>{};
    state = (running: done.length < 3, requested: null);
    ref.read(routerProvider).go(Routes.day1);
  }
}

final day1TourProvider = NotifierProvider<Day1TourStore, Day1TourState>(
  Day1TourStore.new,
);

/// The step the user is on, or null when no walkthrough is running.
///
/// The step the user picked wins while it is still undone; otherwise the
/// first undone task, in order. Derived rather than stored: the source of
/// truth is `day1TasksDone`, which already lives on the journey and already
/// syncs, so the tour resumes correctly and cannot claim a step is undone
/// that the user has finished.
final day1TourStepProvider = Provider<Day1TourStep?>((ref) {
  final tour = ref.watch(day1TourProvider);
  if (!tour.running) return null;
  final journey = ref.watch(quitStoreProvider);
  if (journey == null) return null;
  final done = journey.day1TasksDone;
  final requested = tour.requested;
  if (requested != null && !done.contains(requested.index)) return requested;
  for (final step in Day1TourStep.values) {
    if (!done.contains(step.index)) return step;
  }
  return null;
});

/// Whether the rest of the app is held closed right now.
///
/// One question, asked from four places (Home's controls, the shell's tabs,
/// the back gesture, the danger-hours sheet), so it is worth a name.
final day1TourLockedProvider = Provider<bool>(
  (ref) => ref.watch(day1TourStepProvider) != null,
);
