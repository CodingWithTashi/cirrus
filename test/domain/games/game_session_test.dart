import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/games/games.dart';

/// The clock every panic game runs on, pinned against a scripted engine and
/// once against the real tile board.
void main() {
  /// Advances in 60 fps frames, the way the ticker does.
  List<GameEvent> run(GameSession session, double seconds) {
    final events = <GameEvent>[];
    var t = 0.0;
    while (t < seconds - 1e-9) {
      final step = math.min(1 / 60, seconds - t);
      events.addAll(session.advance(step));
      t += step;
    }
    return events;
  }

  test('opens at round one with sixty seconds, and the engine is told', () {
    final game = _ScriptedGame();
    final session = GameSession(game);
    expect(session.round, 1);
    expect(session.secondsLeft, 60);
    expect(session.roundsDone, 0);
    expect(session.doseProgress, 0);
    expect(session.roundOver, isFalse);
    expect(session.canContinue, isTrue);
    expect(session.sessionSeconds, 0);
    expect(game.started, [1]);
  });

  test('the countdown reads 60 at the start and moves with the clock', () {
    final session = GameSession(_ScriptedGame());
    run(session, 0.5);
    expect(session.secondsLeft, 60);
    run(session, 0.5);
    expect(session.secondsLeft, 59);
    run(session, 58.5);
    expect(session.secondsLeft, 1);
    run(session, 0.5);
    expect(session.secondsLeft, 0);
  });

  test('a long pause is one clamped step', () {
    // The ticker hands over the whole background gap in one call; without
    // the clamp a tile would be lost the moment the app came back.
    final game = _ScriptedGame();
    final session = GameSession(game);
    session.advance(30);
    expect(game.steps, [GameSession.maxStep]);
    expect(session.sessionSeconds, GameSession.maxStep);
  });

  test('NaN and non-positive steps are nothing', () {
    final game = _ScriptedGame();
    final session = GameSession(game);
    expect(session.advance(double.nan), isEmpty);
    expect(session.advance(0), isEmpty);
    expect(session.advance(-1), isEmpty);
    expect(game.steps, isEmpty);
  });

  test('sixty seconds end the round exactly once, cut at the line, and nothing '
      'moves afterwards', () {
    final game = _ScriptedGame();
    final session = GameSession(game);
    final events = run(session, 60);
    expect(events.whereType<RoundFinished>().single.round, 1);
    expect(session.roundOver, isTrue);
    expect(session.secondsLeft, 0);
    expect(session.roundsDone, 1);
    expect(session.doseProgress, closeTo(1 / 3, 1e-9));
    // The last frame is cut so the engine saw exactly sixty seconds.
    expect(game.steps.fold(0.0, (a, b) => a + b), closeTo(60, 1e-9));
    expect(game.ended, [1]);

    final steps = game.steps.length;
    expect(session.advance(1), isEmpty);
    expect(game.steps, hasLength(steps));
    expect(session.sessionSeconds, closeTo(60, 1e-9));
  });

  test("engine events come through, the round's end last", () {
    final game = _ScriptedGame();
    final session = GameSession(game);
    run(session, 59.99);
    game.pending.add(const _Ping());
    final events = session.advance(1);
    expect(events, hasLength(2));
    expect(events.first, isA<_Ping>());
    expect(events.last, isA<RoundFinished>());
  });

  test('keep playing resumes the same engine into round two', () {
    final game = _ScriptedGame();
    final session = GameSession(game);
    run(session, 60);
    game.score = 5;
    game.misses = 2;

    session.nextRound();

    expect(session.round, 2);
    expect(session.secondsLeft, 60);
    expect(session.roundOver, isFalse);
    expect(session.roundsDone, 1);
    expect(session.sessionSeconds, closeTo(60, 1e-9));
    expect(identical(session.game, game), isTrue);
    expect(game.started, [1, 2]);
    // The round's score is what was gained since it started.
    expect(session.roundScore, 0);
    game.score = 8;
    game.misses = 3;
    expect(session.roundScore, 3);
    expect(session.roundMisses, 1);
    expect(session.summarize().totalScore, 8);
  });

  test('keep playing hands a fresh engine to a game that wants one', () {
    final first = _ScriptedGame(fresh: true);
    final second = _ScriptedGame(fresh: true);
    final session = GameSession(first, freshGame: () => second);
    run(session, 60);
    first.score = 4;

    session.nextRound();

    expect(identical(session.game, second), isTrue);
    expect(second.started, [2]);
    expect(session.roundScore, 0, reason: 'a fresh board starts at nothing');

    final orphan = GameSession(_ScriptedGame(fresh: true));
    run(orphan, 60);
    expect(orphan.nextRound, throwsStateError);
  });

  test('nextRound before the round is over throws; five rounds is the cap', () {
    final session = GameSession(_ScriptedGame());
    expect(session.nextRound, throwsStateError);
    for (var round = 1; round < GameSession.maxRounds; round++) {
      run(session, 60);
      expect(session.canContinue, isTrue, reason: 'round $round');
      session.nextRound();
    }
    expect(session.round, GameSession.maxRounds);
    run(session, 60);
    expect(session.roundOver, isTrue);
    expect(session.canContinue, isFalse);
    expect(session.nextRound, throwsStateError);
    expect(session.roundsDone, GameSession.maxRounds);
    expect(session.sessionSeconds, closeTo(300, 1e-6));
  });

  test('the three-minute dose is the target', () {
    final session = GameSession(_ScriptedGame());
    final seen = <double>[];
    for (var round = 1; round <= 4; round++) {
      run(session, 60);
      seen.add(session.doseProgress);
      session.nextRound();
    }
    expect(seen[0], closeTo(1 / 3, 1e-9));
    expect(seen[1], closeTo(2 / 3, 1e-9));
    expect(seen[2], 1);
    expect(seen[3], 1, reason: 'full from the third round on');
  });

  test('pause stops the clock and the engine; resume continues', () {
    final game = _ScriptedGame();
    final session = GameSession(game);
    run(session, 1);
    session.pause();
    expect(session.paused, isTrue);
    expect(session.advance(0.05), isEmpty);
    expect(game.steps, hasLength(60));
    expect(session.secondsLeft, 59);
    session.resume();
    run(session, 1);
    expect(session.secondsLeft, 58);
    expect(game.steps, hasLength(120));
  });

  test('summarize reports the run', () {
    final game = _ScriptedGame();
    final session = GameSession(game);
    run(session, 60);
    game.score = 7;
    game.bestCombo = 4;
    game.misses = 1;
    final summary = session.summarize();
    expect(summary.id, GameId.tiles);
    expect(summary.rounds, 1);
    expect(summary.roundScore, 7);
    expect(summary.totalScore, 7);
    expect(summary.bestCombo, 4);
    expect(summary.misses, 1);
    expect(summary.roundMisses, 1);
    expect(summary.seconds, closeTo(60, 1e-9));
  });

  test('a real board: a steady player never loses a tile in a round', () {
    // Two hits a second, all minute long: the window is 0.75 s and the tap
    // always comes at 0.5 s. Sixty seconds, a hundred and twenty tiles.
    final session = GameSession(TileGame(random: math.Random(9)));
    final game = session.game as TileGame;
    while (!session.roundOver) {
      expect(
        game.tap(game.targetLane),
        TapOutcome.hit,
        reason: game.score.toString(),
      );
      run(session, 0.5);
    }
    expect(game.misses, 0);
    expect(game.score, 120);
    expect(game.combo, 120);
    expect(session.roundScore, 120);
    // Frozen at the check-in: the board holds and a tap is not a hit.
    expect(game.tap(game.targetLane), TapOutcome.ignored);
  });
}

/// Records what the session tells it; emits whatever the test queues.
class _ScriptedGame implements PanicGame {
  _ScriptedGame({this.fresh = false});

  final bool fresh;
  final List<double> steps = [];
  final List<int> started = [];
  final List<int> ended = [];
  final List<GameEvent> pending = [];

  @override
  int score = 0;
  @override
  int combo = 0;
  @override
  int bestCombo = 0;
  @override
  int misses = 0;
  @override
  double elapsed = 0;

  @override
  GameId get id => GameId.tiles;

  @override
  bool get freshEachRound => fresh;

  @override
  List<GameEvent> advance(double dt) {
    steps.add(dt);
    elapsed += dt;
    final out = List<GameEvent>.of(pending);
    pending.clear();
    return out;
  }

  @override
  void roundStarted(int round) => started.add(round);

  @override
  void roundEnded(int round) => ended.add(round);
}

class _Ping extends GameEvent {
  const _Ping();
}
