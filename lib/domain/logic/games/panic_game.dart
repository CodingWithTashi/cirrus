import 'game_id.dart';

/// What an event means to the arena's haptics and sparks, so the arena
/// never switches on a game's own event types.
enum GameFeedback {
  none,
  attention,
  hit,
  miss,
  clear,
  bigClear,
  comboMilestone,
}

/// Something the engine's clock caused. Inputs report their own outcome
/// synchronously and never appear here.
abstract class GameEvent {
  const GameEvent();

  GameFeedback get feedback => GameFeedback.none;

  /// Field-normalized (0..1) position for particles; null when nowhere.
  ({double x, double y})? get at => null;
}

/// A panic game's engine: pure Dart, seeded, stepped by [advance], and
/// ignorant of rounds — `GameSession` owns the clock and freezes/thaws it.
///
/// Every engine keeps docs/09 §8's rules: no game-over, one input is one
/// action, difficulty follows the player, and [score] is a countable thing.
abstract interface class PanicGame {
  GameId get id;

  /// The countable score — what the personal best records.
  int get score;
  int get combo;
  int get bestCombo;
  int get misses;

  /// Whether "keep playing" hands the session a fresh engine (Tiles) rather
  /// than resuming this one where it froze.
  bool get freshEachRound;

  /// Engine seconds: the sum of the steps it was given.
  double get elapsed;

  /// Moves the clock on by [dt] seconds (already clamped by the session).
  List<GameEvent> advance(double dt);

  /// A round is starting: thaw, and reset what a long pause made unfair.
  void roundStarted(int round);

  /// Sixty seconds are up: freeze until the next [roundStarted].
  void roundEnded(int round);
}
