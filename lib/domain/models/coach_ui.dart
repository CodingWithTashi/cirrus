/// Coach cards: what a reply may carry beyond its words, and what a turn tells
/// the server beyond its text. Pure Dart — no Flutter imports.
///
/// The wire is a short list of TYPED BLOCKS, each carrying an id and nothing
/// else. Never a route, a URL, a number, a label or a colour: everything
/// drawn is the app's own (ARB, `context.lp`, the exercise catalog), so the
/// server can only ever choose among things this build already knows how to
/// draw.
library;

import '../logic/exercises/exercise.dart';

/// One card under an Ember reply. Sealed, so a new block type is a new
/// subclass and every `switch` over blocks fails to compile until it is
/// handled.
sealed class CoachBlock {
  const CoachBlock();
}

/// "Open this exercise." The whole payload is the id.
final class CoachLauncherBlock extends CoachBlock {
  const CoachLauncherBlock(this.exercise);

  final ExerciseId exercise;

  @override
  bool operator ==(Object other) =>
      other is CoachLauncherBlock && other.exercise == exercise;

  @override
  int get hashCode => exercise.hashCode;

  @override
  String toString() => 'CoachLauncherBlock(${exercise.name})';
}

/// What this build can draw, sent with every turn that may show cards.
///
/// Capability negotiation is a list: the server intersects [exercises] with
/// its own registry and its own read of the tier. A turn that sends no caps
/// at all (an older build, the Day-1 walkthrough's coach step) gets no cards.
class CoachUiCaps {
  const CoachUiCaps({required this.exercises, this.craving = false});

  /// The `v` both directions of the card wire carry.
  static const int version = 1;

  /// Every exercise id this build knows, by wire name.
  final List<String> exercises;

  /// Whether this message is sent from inside a craving: one next step, never
  /// a menu.
  final bool craving;

  Map<String, Object?> toJson() => {
    'v': version,
    'exercises': exercises,
    'craving': craving,
  };
}

/// Everything a coach turn carries beyond its text, chip and panic strength.
/// Each field is optional, and an unset one is not sent at all, so a turn
/// with no extras is byte-for-byte the request an older build makes.
class CoachTurnExtras {
  const CoachTurnExtras({this.ui, this.justDid});

  final CoachUiCaps? ui;

  /// The exercise they finished just before this message, reported once.
  final ExerciseRun? justDid;

  /// Only the keys that are set.
  Map<String, Object?> toJson() {
    final ui = this.ui;
    final justDid = this.justDid;
    return {
      if (ui != null) 'ui': ui.toJson(),
      if (justDid != null)
        'justDid': {
          'exercise': justDid.id.name,
          'seconds': justDid.seconds,
          'completed': justDid.completed,
          'passed': justDid.passed,
        },
    };
  }
}
