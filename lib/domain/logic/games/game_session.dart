import 'dart:math' as math;

import 'game_id.dart';
import 'panic_game.dart';

/// Sixty seconds are up; the session stops driving the engine until
/// [GameSession.nextRound].
class RoundFinished extends GameEvent {
  const RoundFinished(this.round);

  final int round;
}

/// What a session says about itself, for the panel and analytics.
class GameRunSummary {
  const GameRunSummary({
    required this.id,
    required this.rounds,
    required this.roundScore,
    required this.totalScore,
    required this.bestCombo,
    required this.misses,
    required this.roundMisses,
    required this.seconds,
  });

  final GameId id;
  final int rounds;
  final int roundScore;
  final int totalScore;
  final int bestCombo;
  final int misses;
  final int roundMisses;
  final double seconds;
}

/// The clock every panic game runs on: 60-second rounds chained to five,
/// each ending on the person's own word (docs/08 §7 row 18). Three rounds
/// is the dose the Tetris studies used, and the arena's ring fills toward it.
///
/// Engines know nothing of rounds: the session clamps every step, cuts the
/// last one at the boundary, and freezes/thaws the engine around the check-in.
class GameSession {
  /// [freshGame] builds the next round's engine for a game whose
  /// [PanicGame.freshEachRound] is true; other games resume in place.
  GameSession(PanicGame game, {PanicGame Function()? freshGame})
    : _game = game,
      _freshGame = freshGame {
    _markRoundStart();
    _game.roundStarted(1);
  }

  static const int roundSeconds = 60;
  static const int maxRounds = 5;

  /// Rounds that make up the studied three-minute dose.
  static const int targetRounds = 3;

  /// The most game time one [advance] may cover: a backgrounded app hands
  /// over the whole gap on resume, and without the clamp a tile would be lost.
  static const double maxStep = 0.1;

  /// 60 fps steps land a hair either side of a whole second.
  static const double _epsilon = 1e-6;

  PanicGame _game;
  final PanicGame Function()? _freshGame;
  int _round = 1;
  double _roundElapsed = 0;
  double _sessionSeconds = 0;
  bool _roundOver = false;
  bool _paused = false;
  int _scoreAtRoundStart = 0;
  int _missesAtRoundStart = 0;

  /// The engine in play; a fresh-each-round game swaps it at [nextRound].
  PanicGame get game => _game;
  GameId get id => _game.id;

  /// 1-based.
  int get round => _round;
  bool get roundOver => _roundOver;
  bool get paused => _paused;
  bool get canContinue => _round < maxRounds;

  /// Rounds played to the end so far.
  int get roundsDone => _roundOver ? _round : _round - 1;

  /// The countdown the header shows: 60 at the start, 0 when over.
  int get secondsLeft =>
      (roundSeconds - _roundElapsed - _epsilon).ceil().clamp(0, roundSeconds);

  double get roundElapsed => _roundElapsed;

  /// Game seconds played across every round.
  double get sessionSeconds => _sessionSeconds;

  /// A third per round, full from the third round on.
  double get doseProgress => (roundsDone / targetRounds).clamp(0.0, 1.0);

  /// Score gained this round — the engine's total for a fresh-each-round
  /// game, the difference for one that keeps counting.
  int get roundScore => _game.score - _scoreAtRoundStart;
  int get roundMisses => _game.misses - _missesAtRoundStart;

  /// Steps the round by [dt] (clamped, cut at the line) and hands back the
  /// engine's events, with [RoundFinished] last when this step ended it.
  List<GameEvent> advance(double dt) {
    if (_roundOver || _paused || dt.isNaN || dt <= 0) return const [];
    final step = math.min(math.min(dt, maxStep), roundSeconds - _roundElapsed);
    final events = <GameEvent>[..._game.advance(step)];
    _roundElapsed += step;
    _sessionSeconds += step;
    if (_roundElapsed + _epsilon >= roundSeconds) {
      _roundOver = true;
      _game.roundEnded(_round);
      events.add(RoundFinished(_round));
    }
    return events;
  }

  /// "Still craving — 60 more seconds": resume the engine where it froze,
  /// or build a fresh one for a game that wants a new board each round.
  void nextRound() {
    if (!_roundOver) throw StateError('the round is still running');
    if (!canContinue) throw StateError('$maxRounds rounds is the cap');
    if (_game.freshEachRound) {
      final fresh = _freshGame;
      if (fresh == null) {
        throw StateError('${_game.id.name} wants a fresh engine each round');
      }
      _game = fresh();
    }
    _round++;
    _roundElapsed = 0;
    _roundOver = false;
    _paused = false;
    _markRoundStart();
    _game.roundStarted(_round);
  }

  /// The app went to the background: nothing moves until [resume].
  void pause() {
    if (!_roundOver) _paused = true;
  }

  void resume() => _paused = false;

  GameRunSummary summarize() => GameRunSummary(
    id: _game.id,
    rounds: roundsDone,
    roundScore: roundScore,
    totalScore: _game.score,
    bestCombo: _game.bestCombo,
    misses: _game.misses,
    roundMisses: roundMisses,
    seconds: _sessionSeconds,
  );

  void _markRoundStart() {
    _scoreAtRoundStart = _game.score;
    _missesAtRoundStart = _game.misses;
  }
}
