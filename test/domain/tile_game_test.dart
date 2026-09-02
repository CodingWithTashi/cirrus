import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/tile_game.dart';

/// The 60-second panic game's rules (docs/09 §8), pinned without a widget.
///
/// Four of them are the whole reason the game exists in this form: the
/// board goes as fast as the thumbs do and never makes anyone wait, a tile
/// waits a fixed multiple of the player's own pace so difficulty follows
/// the player, a miss costs the combo and nothing else (no game-over
/// mid-craving), and one tap is one hit — the same rule LOG PUFF learned the
/// hard way (QA H1).
void main() {
  /// Advances in 60 fps frames, the way the ticker does.
  List<GameEvent> run(TileGame game, double seconds) {
    final events = <GameEvent>[];
    var t = 0.0;
    while (t < seconds - 1e-9) {
      final step = math.min(1 / 60, seconds - t);
      events.addAll(game.advance(step));
      t += step;
    }
    return events;
  }

  /// A lane the target is not in.
  int wrongLane(TileGame game) => (game.targetLane + 1) % TileGame.lanes;

  group('the board', () {
    test('opens full, target at home, nothing to wait for', () {
      final game = TileGame(random: math.Random(1));
      expect(game.rows, hasLength(TileGame.bufferedRows));
      expect(game.sink, 0);
      expect(game.targetY, TileGame.home);
      expect(game.window, TileGame.windowCeilingStart);
      expect(game.secondsLeft, 60);
      expect(game.score, 0);
      expect(game.lastAdvanceAt, lessThan(0));
    });

    test('a hit brings the next row down at once', () {
      final game = TileGame(random: math.Random(2));
      final before = game.rows;
      expect(game.tap(game.targetLane), TapOutcome.hit);
      expect(game.rows.sublist(0, 4), before.sublist(1, 5));
      expect(game.rows, hasLength(TileGame.bufferedRows));
      expect(game.score, 1);
      expect(game.combo, 1);
      expect(game.sink, 0, reason: 'the new target starts at home');
      expect(game.lastAdvanceAt, 0);
      final gone = game.departed.single;
      expect(gone.hit, isTrue);
      expect(gone.lane, before.first);
      expect(gone.y, TileGame.home);
    });

    test('goes exactly as fast as the thumbs — twenty hits in no time', () {
      // The old spark waited to be tapped and the old waterfall made a fast
      // tapper wait for the next tile. Neither is allowed here.
      final game = TileGame(random: math.Random(3));
      for (var i = 0; i < 20; i++) {
        expect(game.tap(game.targetLane), TapOutcome.hit, reason: 'hit $i');
      }
      expect(game.score, 20);
      expect(game.combo, 20);
      expect(game.elapsed, 0);
      expect(game.misses, 0);
    });

    test('the target sinks and is lost at the end of its window', () {
      final game = TileGame(random: math.Random(4));
      final lane = game.targetLane;
      final next = game.rows[1];
      run(game, TileGame.windowCeilingStart / 2);
      expect(game.sink, closeTo(0.5, 0.02));
      expect(
        game.targetY,
        closeTo((TileGame.home + TileGame.missAt) / 2, 0.02),
      );

      TileMissed? missed;
      while (missed == null) {
        missed = game.advance(1 / 60).whereType<TileMissed>().firstOrNull;
      }
      expect(missed.lane, lane);
      expect(game.elapsed, closeTo(TileGame.windowCeilingStart, 0.02));
      expect(game.misses, 1);
      expect(game.combo, 0);
      expect(game.finished, isFalse);
      // The board moved on: the next row is the target, at home again.
      expect(game.targetLane, next);
      expect(game.sink, closeTo(0, 0.02));
      // The lost tile is kept at the miss line for its shake, then dropped.
      final gone = game.departed.single;
      expect(gone.hit, isFalse);
      expect(gone.y, TileGame.missAt);
      run(game, TileGame.resolvedFor + 1 / 60);
      expect(game.departed, isEmpty);
    });

    test('never deals the same lane three rows running', () {
      for (var seed = 0; seed < 20; seed++) {
        final game = TileGame(random: math.Random(seed));
        final sequence = <int>[...game.rows];
        for (var i = 0; i < 200; i++) {
          game.tap(game.targetLane);
          sequence.add(game.rows.last);
        }
        expect(sequence.length, game.dealt);
        for (var i = 2; i < sequence.length; i++) {
          expect(
            sequence[i] == sequence[i - 1] && sequence[i] == sequence[i - 2],
            isFalse,
            reason: 'seed $seed dealt lane ${sequence[i]} three times at $i',
          );
        }
        // Every lane gets dealt — the game is not secretly two-lane.
        expect(sequence.toSet(), {0, 1, 2, 3}, reason: 'seed $seed');
      }
    });

    test('a long pause resumes where it froze', () {
      // The ticker hands over the whole background gap in one call; without
      // the clamp the target would be lost the moment the app came back.
      final game = TileGame(random: math.Random(5));
      final events = game.advance(30);
      expect(game.elapsed, TileGame.maxStep);
      expect(events.whereType<TileMissed>(), isEmpty);
      expect(game.misses, 0);
    });

    test('sixty seconds end it, and nothing moves afterwards', () {
      final game = TileGame(random: math.Random(6));
      final events = run(game, 60);
      expect(events.whereType<GameFinished>(), hasLength(1));
      expect(game.finished, isTrue);
      expect(game.secondsLeft, 0);

      final rows = game.rows;
      final sink = game.sink;
      expect(game.advance(1), isEmpty);
      expect(game.rows, rows);
      expect(game.sink, sink);
      expect(game.tap(game.targetLane), TapOutcome.ignored);
    });

    test('the countdown reads 60 at the start and moves with the clock', () {
      final game = TileGame(random: math.Random(7));
      run(game, 0.5);
      expect(game.secondsLeft, 60);
      run(game, 0.5);
      expect(game.secondsLeft, 59);
      run(game, 58.5);
      expect(game.secondsLeft, 1);
      run(game, 0.5);
      expect(game.secondsLeft, 0);
    });
  });

  group('the window', () {
    test('is a fixed multiple of the pace, between a floor and a ceiling', () {
      expect(TileGame.windowFor(pace: 0, t: 0), TileGame.windowCeilingStart);
      expect(TileGame.windowFor(pace: 1, t: 0), 1.5);
      expect(TileGame.windowFor(pace: 2, t: 0), 0.75);
      expect(TileGame.windowFor(pace: 4, t: 0), TileGame.windowFloor);
      expect(TileGame.windowFor(pace: 0.2, t: 0), TileGame.windowCeilingStart);
    });

    test('the ceiling tightens gently over the minute', () {
      expect(TileGame.windowCeilingAt(0), 2.4);
      expect(TileGame.windowCeilingAt(60), 1.6);
      expect(TileGame.windowCeilingAt(90), 1.6);
      var previous = TileGame.windowCeilingAt(0);
      for (var t = 0.0; t <= 60; t += 5) {
        final now = TileGame.windowCeilingAt(t);
        expect(now, lessThanOrEqualTo(previous));
        previous = now;
      }
    });

    test(
      'follows the player: tighter as they speed up, wider as they stop',
      () {
        final game = TileGame(random: math.Random(8));
        // Four hits a second for three seconds.
        for (var i = 0; i < 12; i++) {
          run(game, 0.25);
          expect(game.tap(game.targetLane), TapOutcome.hit);
        }
        expect(game.pace, closeTo(4, 0.01));
        expect(game.window, TileGame.windowFloor);

        // Then nothing for three seconds: the pace is gone, and the next tile
        // to land gets the full ceiling. Only the tiles that got away
        // meanwhile paid — the window is fixed per tile, so the one on screen
        // keeps the wait it was given.
        run(game, 3.2);
        expect(game.pace, 0);
        TileMissed? missed;
        while (missed == null) {
          missed = game.advance(1 / 60).whereType<TileMissed>().firstOrNull;
        }
        expect(
          game.window,
          closeTo(TileGame.windowCeilingAt(game.elapsed), 1e-9),
        );
      },
    );

    test('a steady player never loses a tile', () {
      // Two hits a second, all minute long: the window is 0.75 s and the tap
      // always comes at 0.5 s. Sixty seconds, a hundred and twenty tiles.
      final game = TileGame(random: math.Random(9));
      while (!game.finished) {
        expect(
          game.tap(game.targetLane),
          TapOutcome.hit,
          reason: game.score.toString(),
        );
        run(game, 0.5);
      }
      expect(game.misses, 0);
      expect(game.score, 120);
      expect(game.combo, 120);
    });

    test('a hesitation half again as long as the beat loses the tile', () {
      final game = TileGame(random: math.Random(10));
      for (var i = 0; i < 8; i++) {
        run(game, 0.5);
        expect(game.tap(game.targetLane), TapOutcome.hit);
      }
      expect(game.window, closeTo(0.75, 1e-9));
      // Attention drifts for 0.8 s.
      final events = run(game, 0.8);
      expect(events.whereType<TileMissed>(), hasLength(1));
      expect(game.combo, 0);
      expect(game.score, 8, reason: 'a miss never takes a hit back');
    });
  });

  group('a tap', () {
    test('in the wrong lane costs the combo, not the score or the board', () {
      final game = TileGame(random: math.Random(11));
      for (var i = 0; i < 3; i++) {
        expect(game.tap(game.targetLane), TapOutcome.hit);
      }
      final rows = game.rows;
      run(game, 0.2); // past the bounce grace
      expect(game.tap(wrongLane(game)), TapOutcome.miss);
      expect(game.combo, 0);
      expect(game.score, 3);
      expect(game.bestCombo, 3);
      expect(game.misses, 1);
      expect(game.rows, rows, reason: 'the target is still waiting');
    });

    test('is one hit, never more — a bounce after a hit is ignored', () {
      // Find a deal where the row after the target is in another lane, so
      // the second tap in the same lane has nothing legitimate to hit.
      late TileGame game;
      for (var seed = 0; ; seed++) {
        game = TileGame(random: math.Random(seed));
        if (game.rows[0] != game.rows[1]) break;
      }
      final lane = game.targetLane;
      expect(game.tap(lane), TapOutcome.hit);
      run(game, 0.05);
      expect(game.tap(lane), TapOutcome.ignored);
      expect(game.score, 1);
      expect(game.misses, 0);
      // Past the grace it is a decision, and a wrong one.
      run(game, TileGame.bounceGrace);
      expect(game.tap(lane), TapOutcome.miss);
      expect(game.score, 1);
    });

    test('in the same lane twice is two hits when two rows are there', () {
      late TileGame game;
      for (var seed = 0; ; seed++) {
        game = TileGame(random: math.Random(seed));
        if (game.rows[0] == game.rows[1]) break;
      }
      final lane = game.targetLane;
      expect(game.tap(lane), TapOutcome.hit);
      expect(game.tap(lane), TapOutcome.hit);
      expect(game.score, 2);
    });

    test('outside the lanes is ignored', () {
      final game = TileGame(random: math.Random(12));
      expect(game.tap(-1), TapOutcome.ignored);
      expect(game.tap(TileGame.lanes), TapOutcome.ignored);
      expect(game.misses, 0);
    });
  });

  test(
    'beats: zero never sets a best, the first real score does, ties do not',
    () {
      expect(TileGame.beats(0, null), isFalse);
      expect(TileGame.beats(1, null), isTrue);
      expect(TileGame.beats(40, 40), isFalse);
      expect(TileGame.beats(39, 40), isFalse);
      expect(TileGame.beats(41, 40), isTrue);
    },
  );
}
