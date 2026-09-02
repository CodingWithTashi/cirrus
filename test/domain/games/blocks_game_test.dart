import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/games/games.dart';

/// Blocks' rules, pinned without a widget: gravity follows the player's own
/// beat, the board breathes instead of ending, one input is one action.
void main() {
  /// Advances in 60 fps frames, the way the ticker does.
  List<GameEvent> run(BlocksGame game, double seconds) {
    final events = <GameEvent>[];
    var t = 0.0;
    while (t < seconds - 1e-9) {
      final step = math.min(1 / 60, seconds - t);
      events.addAll(game.advance(step));
      t += step;
    }
    return events;
  }

  /// Every cell the active piece occupies — and the row below, when it is
  /// drawn partway into it — is inside the board and empty.
  void expectPictureClean(BlocksGame game, {String? reason}) {
    final p = game.active;
    final rows = p.y > p.row ? [0, 1] : [0];
    for (final (c, r) in p.cells) {
      for (final extra in rows) {
        final row = r + extra;
        expect(c, inInclusiveRange(0, BlocksGame.cols - 1), reason: reason);
        expect(
          row,
          inInclusiveRange(-BlocksGame.hiddenRows, BlocksGame.visibleRows - 1),
          reason: reason,
        );
        expect(game.cellAt(c, row), isNull, reason: reason);
      }
    }
  }

  List<String> rows(int count, String line) => List.filled(count, line);

  group('the board', () {
    test('opens with a fully visible piece at the spawn column', () {
      for (var seed = 0; seed < 20; seed++) {
        final game = BlocksGame(random: math.Random(seed));
        expect(game.id, GameId.blocks);
        expect(game.freshEachRound, isFalse);
        expect(game.active.col, BlocksGame.spawnCol, reason: 'seed $seed');
        for (final (_, r) in game.active.cells) {
          expect(r, inInclusiveRange(0, 1), reason: 'seed $seed');
        }
        expect(game.board.expand((row) => row).every((c) => c == null), isTrue);
        expect(game.score, 0);
        expect(game.stackHeight, 0);
        expect(game.resting, isFalse);
      }
    });

    test('the bag deals every piece and never repeats across the seam', () {
      for (var seed = 0; seed < 20; seed++) {
        final game = BlocksGame(random: math.Random(seed));
        final dealt = <BlockKind>[game.active.kind];
        for (var i = 0; i < 79; i++) {
          run(game, 0.2);
          game.hardDrop();
          dealt.add(game.active.kind);
        }
        for (var start = 0; start + 8 <= dealt.length; start += 8) {
          final bag = dealt.sublist(start, start + 8)..sort(_byIndex);
          expect(
            bag,
            [...BlocksGame.bag]..sort(_byIndex),
            reason: 'seed $seed bag at $start',
          );
          if (start > 0) {
            expect(
              dealt[start],
              isNot(dealt[start - 1]),
              reason: 'seed $seed repeats across the seam at $start',
            );
          }
        }
      }
    });

    test('every rotation state is the clockwise turn of the last', () {
      for (final kind in BlockKind.values) {
        for (var s = 0; s < 4; s++) {
          final turned = [for (final (x, y) in kind.shape(s)) (-y, x)];
          expect(kind.shape(s + 1), turned, reason: '$kind state $s');
        }
        expect(kind.shape(4), kind.shape(0));
        expect(kind.shape(0), hasLength(kind.spawnShape.length));
      }
      expect(BlockKind.t4.shape(1), [(0, -1), (0, 0), (0, 1), (-1, 0)]);
      expect(BlockKind.l4.spawnRow, 1, reason: 'its top cell is a row up');
      expect(BlockKind.i5.spawnRow, 0);
    });

    test('a soft drop moves whole rows and never locks', () {
      final game = BlocksGame.withStack(const [], firstPiece: BlockKind.i3);
      expect(game.softDrop(3), 3);
      expect(game.active.row, 3);
      expect(game.active.y, 3);
      expect(game.resting, isFalse);
      expect(game.softDrop(30), BlocksGame.visibleRows - 1 - 3);
      expect(game.resting, isTrue);
      expect(game.placed, 0);
      expect(run(game, 0.4).whereType<PieceLocked>(), isEmpty);
      expect(run(game, 0.2).whereType<PieceLocked>(), hasLength(1));
      expect(game.placed, 1);
    });
  });

  group('inputs', () {
    test(
      'moveTo sticks to the finger and stops at the first blocked column',
      () {
        final game = BlocksGame.withStack(
          rows(12, 'x.......'),
          firstPiece: BlockKind.i3,
        );
        expect(game.moveTo(BlocksGame.spawnCol + 1), 1);
        expect(game.active.col, BlocksGame.spawnCol + 1);
        expect(game.moveTo(BlocksGame.spawnCol - 2), 3);
        expect(game.active.col, BlocksGame.spawnCol - 2);
        expect(game.moveTo(BlocksGame.spawnCol), 2);

        game.softDrop(4); // into the rows the column-0 tower reaches
        expect(game.moveTo(0), 1, reason: 'one column, then the tower');
        final leftmost = game.active.cells.map((c) => c.$1).reduce(math.min);
        expect(leftmost, 1, reason: 'the tower in column 0 stops it');
        expectPictureClean(game);
      },
    );

    test('a rotation kicks in table order and never downward', () {
      final game = BlocksGame.withStack(const [], firstPiece: BlockKind.i3);
      game.moveTo(1); // horizontal against the left wall
      expect(game.rotate(), RotateOutcome.turned);
      expect(game.active.state, 1);
      run(game, 0.1);
      game.moveTo(0); // vertical in column 0
      expect(game.active.col, 0);
      final rowBefore = game.active.row;
      expect(game.rotate(), RotateOutcome.turned);
      expect(game.active.state, 2);
      expect(game.active.col, 1, reason: 'kicked one column right');
      expect(game.active.row, rowBefore, reason: 'never shoved down');
      expectPictureClean(game);
    });

    test('a rotation with nowhere to go leaves the piece as it was', () {
      // A one-wide well eight rows deep in column 3.
      final game = BlocksGame.withStack(
        rows(8, 'xxx.xxxx'),
        firstPiece: BlockKind.i5,
      );
      expect(game.rotate(), RotateOutcome.turned);
      expect(game.softDrop(30), greaterThan(0));
      expect(game.resting, isTrue);
      final before = game.active;
      run(game, 0.1);
      expect(game.rotate(), RotateOutcome.blocked);
      expect(game.active.state, before.state);
      expect(game.active.col, before.col);
      expect(game.active.row, before.row);
    });

    test('a bounce within rotateGrace is one rotation; past it, two', () {
      final game = BlocksGame(random: math.Random(3));
      expect(game.rotate(), RotateOutcome.turned);
      expect(game.rotate(), RotateOutcome.ignored);
      expect(game.active.state, 1);
      run(game, BlocksGame.rotateGrace);
      expect(game.rotate(), RotateOutcome.turned);
      expect(game.active.state, 2);
    });

    test('a hard drop locks at once and is ignored right after a spawn', () {
      final game = BlocksGame(random: math.Random(4));
      expect(game.hardDrop(), isEmpty, reason: 'the piece must be seen first');
      expect(game.placed, 0);
      run(game, BlocksGame.spawnGrace + 0.05);
      final events = game.hardDrop();
      final locked = events.whereType<PieceLocked>().single;
      expect(locked.hardDrop, isTrue);
      expect(locked.feedback, GameFeedback.hit);
      expect(game.placed, 1);
      expect(game.locks.single.hardDrop, isTrue);
      expect(game.locks.single.fromRow, lessThan(game.locks.single.toRow));
      expect(game.active.col, BlocksGame.spawnCol, reason: 'the next arrived');
      expect(game.resting, isFalse);
      expectPictureClean(game);
    });
  });

  group('gravity', () {
    test('is a fixed multiple of the pace, between a floor and a ceiling', () {
      expect(
        BlocksGame.gravityFor(pace: 0, t: 0, stackHeight: 0),
        BlocksGame.gravityFloorStart,
      );
      expect(
        BlocksGame.gravityFor(pace: 1 / 3, t: 0, stackHeight: 0),
        closeTo(2.222, 0.001),
      );
      expect(
        BlocksGame.gravityFor(pace: 2, t: 0, stackHeight: 0),
        BlocksGame.gravityCeiling,
      );
      expect(BlocksGame.gravityFloorAt(0), 2.0);
      expect(BlocksGame.gravityFloorAt(30), 2.25);
      expect(BlocksGame.gravityFloorAt(60), 2.5);
      expect(BlocksGame.gravityFloorAt(90), 2.5);
      expect(BlocksGame.easeFor(0), 1);
      expect(BlocksGame.easeFor(8), 1);
      expect(BlocksGame.easeFor(10), 0.75);
      expect(BlocksGame.easeFor(12), 0.5);
      expect(BlocksGame.easeFor(14), 0.5);
    });

    test('a steady placer never sees a piece fall faster than their pace', () {
      // Hard-dropping every T seconds all round long: every piece is given
      // at least 1.5× that beat to fall the reference distance — unless
      // the beat is slower than the floor, which is the slowest a piece
      // ever falls.
      for (final beat in [1.5, 2.0, 3.0]) {
        final game = BlocksGame(random: math.Random(5));
        while (game.elapsed < 60) {
          run(game, beat);
          game.hardDrop();
          final slowest = math.max(
            BlocksGame.gravityFloorAt(game.elapsed),
            BlocksGame.fallReference / (BlocksGame.paceFactor * beat),
          );
          expect(
            game.gravity,
            lessThanOrEqualTo(slowest + 1e-9),
            reason: 'beat $beat at ${game.elapsed}',
          );
        }
      }
    });

    test('eases to half at the relief line', () {
      final tall = BlocksGame.withStack(rows(12, 'x.......'));
      expect(tall.stackHeight, 12);
      expect(tall.gravity, BlocksGame.gravityFloorStart * BlocksGame.easeMin);
      final low = BlocksGame.withStack(rows(4, 'x.......'));
      expect(low.stackHeight, 4);
      expect(low.gravity, BlocksGame.gravityFloorStart);
    });

    test('a piece rests, then locks after the lock delay with no input', () {
      final game = BlocksGame(random: math.Random(6));
      while (!game.resting) {
        game.advance(1 / 60);
      }
      final landed = game.elapsed;
      expect(game.active.y, game.active.row.toDouble());
      var locked = false;
      while (!locked) {
        locked = game.advance(1 / 60).any((e) => e is PieceLocked);
      }
      expect(game.elapsed - landed, closeTo(BlocksGame.lockDelay, 0.02));
      expect(game.placed, 1);
      // Gravity did the placing, so it set no beat: the next piece falls at
      // the floor, not faster because the last one "arrived quickly".
      expect(game.pace, 0);
      expect(game.gravity, BlocksGame.gravityFloorAt(game.elapsed));
    });

    test('nudges on the ground restart the lock wait, ten times', () {
      final game = BlocksGame.withStack(const [], firstPiece: BlockKind.i3);
      game.softDrop(30);
      expect(game.resting, isTrue);
      var direction = 1;
      for (var i = 0; i < BlocksGame.lockMoveResets; i++) {
        expect(run(game, 0.4).whereType<PieceLocked>(), isEmpty, reason: '$i');
        expect(game.moveTo(game.active.col + direction), 1);
        direction = -direction;
      }
      // The eleventh nudge no longer buys time.
      expect(run(game, 0.4).whereType<PieceLocked>(), isEmpty);
      expect(game.moveTo(game.active.col + direction), 1);
      expect(run(game, 0.2).whereType<PieceLocked>(), hasLength(1));
    });
  });

  group('lines and relief', () {
    test('a full row clears at lock; score counts lines, combo clears', () {
      final game = BlocksGame.withStack(
        rows(5, 'xxxxxxx.'),
        firstPiece: BlockKind.i5,
      );
      expect(game.rotate(), RotateOutcome.turned);
      expect(game.moveTo(7), 4);
      run(game, 0.2);
      final events = game.hardDrop();
      final cleared = events.whereType<LinesCleared>().single;
      expect(cleared.count, 5);
      expect(cleared.feedback, GameFeedback.bigClear);
      expect(game.score, 5);
      expect(game.combo, 1);
      expect(game.bestCombo, 1);
      expect(game.misses, 0);
      expect(game.stackHeight, 0, reason: 'the whole stack was those rows');
      expect(game.clears.single.rows, hasLength(5));

      // A piece that clears nothing ends the combo and costs nothing.
      run(game, 0.2);
      final quiet = game.hardDrop();
      expect(quiet.whereType<LinesCleared>(), isEmpty);
      expect(game.combo, 0);
      expect(game.bestCombo, 1);
      expect(game.score, 5);
    });

    test('the rows above a cleared line fall onto it', () {
      final game = BlocksGame.withStack(const [
        'x.......',
        'xxxxxxx.',
      ], firstPiece: BlockKind.i3);
      expect(game.rotate(), RotateOutcome.turned);
      expect(game.moveTo(7), 4);
      run(game, 0.2);
      final events = game.hardDrop();
      expect(events.whereType<LinesCleared>().single.count, 1);
      expect(game.score, 1);
      expect(game.cellAt(0, 13), BlockTone.stone, reason: 'fell one row');
      expect(game.cellAt(7, 13), BlockTone.volt);
      expect(game.cellAt(7, 12), BlockTone.volt);
      expect(game.cellAt(7, 11), isNull);
      expect(game.cellAt(1, 13), isNull);
    });

    test(
      'a lock at the ceiling breathes the board and never ends the round',
      () {
        final game = BlocksGame.withStack(
          rows(12, 'xxxxxxx.'),
          firstPiece: BlockKind.i3,
        );
        run(game, 0.2);
        final events = game.hardDrop();
        final relief = events.whereType<BoardRelieved>().single;
        expect(relief.reason, ReliefReason.ceiling);
        expect(relief.rows, BlocksGame.reliefRows);
        expect(relief.feedback, GameFeedback.miss);
        expect(game.misses, 1);
        expect(game.combo, 0);
        expect(game.score, 0, reason: 'dissolved rows are not lines');
        expect(game.frozen, isFalse);
        // The stack dropped four rows, holes and all; the piece rode down.
        for (var r = 0; r < 5; r++) {
          for (var c = 0; c < BlocksGame.cols; c++) {
            expect(game.cellAt(c, r), isNull, reason: 'row $r');
          }
        }
        expect(game.cellAt(2, 5), BlockTone.volt);
        expect(game.cellAt(0, 13), BlockTone.stone);
        expect(game.cellAt(7, 13), isNull, reason: 'the hole is kept');
        expect(game.stackHeight, 9);
        expect(game.reliefs.single.cells, isNotEmpty);
        expectPictureClean(game);
      },
    );

    test('a spawn with no room is the backstop', () {
      final game = BlocksGame.withStack(rows(14, 'xxxxxxx.'));
      expect(game.misses, 1);
      expect(game.stackHeight, 10);
      expectPictureClean(game);
    });

    test('one relief always frees the spawn, and the picture stays clean', () {
      for (var seed = 0; seed < 40; seed++) {
        final random = math.Random(seed);
        final game = BlocksGame(random: math.Random(seed + 100));
        var score = 0;
        while (game.elapsed < 60) {
          switch (random.nextInt(12)) {
            case 0:
              game.rotate();
            case 1:
              game.moveTo(random.nextInt(BlocksGame.cols));
            case 2:
              game.softDrop(1 + random.nextInt(3));
            case 3:
              game.hardDrop();
          }
          final events = game.advance(1 / 60);
          for (final e in events) {
            if (e is BoardRelieved) {
              expectPictureClean(game, reason: 'seed $seed after relief');
            }
          }
          expect(game.score, greaterThanOrEqualTo(score), reason: 'seed $seed');
          score = game.score;
          expectPictureClean(game, reason: 'seed $seed at ${game.elapsed}');
        }
        expect(game.frozen, isFalse);
      }
    });
  });

  test('the same seed and script replay the same board', () {
    BlocksGame play(int seed) {
      final game = BlocksGame(random: math.Random(seed));
      for (var i = 0; i < 30; i++) {
        run(game, 0.3);
        game.moveTo(i % BlocksGame.cols);
        if (i.isEven) game.rotate();
        game.hardDrop();
      }
      return game;
    }

    final a = play(11);
    final b = play(11);
    expect(a.board, b.board);
    expect(a.score, b.score);
    expect(a.misses, b.misses);
    expect(a.active.kind, b.active.kind);
  });

  test('a round end freezes the piece where it is; the next thaws it', () {
    final game = BlocksGame(random: math.Random(7));
    run(game, 1);
    game.roundEnded(1);
    final before = game.active;
    expect(game.advance(1), isEmpty);
    expect(game.moveTo(0), 0);
    expect(game.rotate(), RotateOutcome.ignored);
    expect(game.softDrop(2), 0);
    expect(game.hardDrop(), isEmpty);
    expect(game.active.y, before.y);
    expect(game.active.col, before.col);
    expect(game.elapsed, closeTo(1, 1e-9));

    game.roundStarted(2);
    run(game, 0.5);
    expect(game.active.y, greaterThan(before.y), reason: 'falling again');
  });
}

int _byIndex(BlockKind a, BlockKind b) => a.index.compareTo(b.index);
