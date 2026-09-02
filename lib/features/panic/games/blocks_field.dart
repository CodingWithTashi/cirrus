import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../domain/logic/games/games.dart';
import 'game_catalog.dart';
import 'ghost_combo.dart';

/// The playfield of Blocks: an 8×14 board of rounded pebbles, the falling
/// piece under a glow, rows flashing and collapsing on a clear, the bottom
/// rows dissolving on a relief, and the ghost combo behind it all.
///
/// One thumb, one action per gesture: a drag slides the piece column by
/// column and sticks to the finger, a tap turns it, a downward drag pulls it
/// a row per cell, a flick slams it. The axis is fixed once a drag leaves the
/// slop, so a drag's lift is never also a tap.
class BlocksField extends StatefulWidget {
  const BlocksField({super.key, required this.scope});

  final GameFieldScope scope;

  /// The live engine. Public so tests can read the board.
  BlocksGame get game => scope.game as BlocksGame;

  /// A downward flick at least this fast, over a cell, is a hard drop.
  static const double flickVelocity = 900;

  @override
  State<BlocksField> createState() => _BlocksFieldState();
}

enum _Axis { horizontal, vertical }

class _BlocksFieldState extends State<BlocksField> {
  Offset? _downAt;
  _Axis? _axis;
  int _colAtDown = 0;
  int _softDropped = 0;
  double _cell = 1;

  BlocksGame get _game => widget.game;

  void _rotate() {
    if (!widget.scope.accepting) return;
    if (_game.rotate() == RotateOutcome.turned) {
      widget.scope.report(GameFeedback.none);
    }
  }

  void _panStart(DragStartDetails d) {
    _downAt = d.localPosition;
    _axis = null;
    _colAtDown = _game.active.col;
    _softDropped = 0;
  }

  void _panUpdate(DragUpdateDetails d) {
    final origin = _downAt;
    if (origin == null || !widget.scope.accepting) return;
    final total = d.localPosition - origin;
    _axis ??= total.dx.abs() >= total.dy.abs()
        ? _Axis.horizontal
        : _Axis.vertical;
    switch (_axis!) {
      case _Axis.horizontal:
        final target = _colAtDown + (total.dx / _cell).round();
        if (_game.moveTo(target) > 0) widget.scope.report(GameFeedback.none);
      case _Axis.vertical:
        // Only downward travel counts, a row per cell.
        final rows = (total.dy / _cell).floor();
        while (_softDropped < rows) {
          _softDropped++;
          if (_game.softDrop(1) == 0) break;
        }
    }
  }

  void _panEnd(DragEndDetails d) {
    final origin = _downAt;
    _downAt = null;
    if (origin == null || !widget.scope.accepting) return;
    if (_axis == _Axis.vertical &&
        d.velocity.pixelsPerSecond.dy >= BlocksField.flickVelocity &&
        d.localPosition.dy - origin.dy >= _cell) {
      for (final event in _game.hardDrop()) {
        widget.scope.report(event.feedback, at: event.at);
      }
    }
    _axis = null;
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return LayoutBuilder(
      builder: (context, constraints) {
        _cell = math.min(
          constraints.maxWidth / BlocksGame.cols,
          constraints.maxHeight / BlocksGame.visibleRows,
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Measure from the finger's landing, not a slop later — otherwise
          // the first column is twenty pixels further than the rest.
          dragStartBehavior: DragStartBehavior.down,
          onTapUp: (_) => _rotate(),
          onPanStart: _panStart,
          onPanUpdate: _panUpdate,
          onPanEnd: _panEnd,
          onPanCancel: () => _downAt = null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: GhostCombo(
                  combo: widget.scope.combo,
                  threshold: widget.scope.ghostFrom,
                ),
              ),
              RepaintBoundary(
                child: CustomPaint(
                  painter: BlocksPainter(
                    game: _game,
                    repaint: widget.scope.frame,
                    // The stronger member of each family: plain volt and
                    // oxygen wash out on the pale daylight ground.
                    volt: lp.voltStrong,
                    oxygen: lp.isDark ? lp.oxygen : lp.oxygenText,
                    stone: lp.textSecondary,
                    ember: lp.ember,
                    board: lp.surfaceInset,
                    border: lp.border,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Paints one frame off the engine; everything animated is read from its
/// records (a settle, a trail, a clear's flash and collapse, a relief's
/// dissolve and drop) — the board itself is final the instant a piece locks.
class BlocksPainter extends CustomPainter {
  BlocksPainter({
    required this.game,
    required Listenable repaint,
    required this.volt,
    required this.oxygen,
    required this.stone,
    required this.ember,
    required this.board,
    required this.border,
  }) : super(repaint: repaint);

  final BlocksGame game;
  final Color volt;
  final Color oxygen;
  final Color stone;
  final Color ember;
  final Color board;
  final Color border;

  static const double settleFor = 0.09;
  static const double flashFor = 0.12;
  static const double collapseFor = 0.12;

  static double _easeOut(double p) => 1 - math.pow(1 - p, 3).toDouble();

  Color _tone(BlockTone tone) => switch (tone) {
    BlockTone.volt => volt,
    BlockTone.oxygen => oxygen,
    BlockTone.stone => stone,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final cell = math.min(
      size.width / BlocksGame.cols,
      size.height / BlocksGame.visibleRows,
    );
    final boardW = cell * BlocksGame.cols;
    final boardH = cell * BlocksGame.visibleRows;
    final origin = Offset(
      (size.width - boardW) / 2,
      (size.height - boardH) / 2,
    );
    final now = game.elapsed;
    final inset = math.max(1.0, cell * 0.04);
    final radius = Radius.circular(cell * 0.32);

    Rect cellRect(double col, double row) => Rect.fromLTWH(
      origin.dx + col * cell + inset,
      origin.dy + row * cell + inset,
      cell - 2 * inset,
      cell - 2 * inset,
    );

    // The board: a quiet well with a hairline edge.
    final boardRect = Rect.fromLTWH(origin.dx, origin.dy, boardW, boardH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, Radius.circular(cell * 0.4)),
      Paint()..color = board,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, Radius.circular(cell * 0.4)),
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.save();
    canvas.clipRect(boardRect);

    // How far the stack is still drawn above where it now sits: rows above
    // a clear ease down into it, the whole stack drops after a relief.
    var reliefShift = 0.0;
    for (final r in game.reliefs) {
      final p = ((now - r.at) / BlocksGame.reliefRecordFor).clamp(0.0, 1.0);
      reliefShift = math.max(
        reliefShift,
        BlocksGame.reliefRows * (1 - _easeOut(p)),
      );
    }
    double clearShiftFor(int row) {
      var shift = 0.0;
      for (final c in game.clears) {
        final age = now - c.at;
        if (row >= c.rows.reduce(math.max)) continue;
        final count = c.rows.length.toDouble();
        if (age < flashFor) {
          shift += count;
        } else {
          shift +=
              count *
              (1 - _easeOut(((age - flashFor) / collapseFor).clamp(0.0, 1.0)));
        }
      }
      return shift;
    }

    // Locked cells as pebbles; only the cells of one piece bridge, so two
    // neighbours of one tone never melt into a blob.
    for (var row = 0; row < BlocksGame.visibleRows; row++) {
      final lift = clearShiftFor(row) + reliefShift;
      for (var col = 0; col < BlocksGame.cols; col++) {
        final tone = game.cellAt(col, row);
        if (tone == null) continue;
        final piece = game.pieceAt(col, row);
        final y = row - lift;
        final right =
            col + 1 < BlocksGame.cols && game.pieceAt(col + 1, row) == piece;
        final down =
            row + 1 < BlocksGame.visibleRows &&
            game.pieceAt(col, row + 1) == piece;
        final corner = right && down && game.pieceAt(col + 1, row + 1) == piece;
        _joinedPebble(
          canvas,
          cellRect(col.toDouble(), y),
          radius,
          _tone(tone),
          pitch: cell,
          right: right,
          down: down,
          corner: corner,
        );
      }
    }

    // Just-locked pieces settle with a breath of vertical squash.
    for (final l in game.locks) {
      final age = now - l.at;
      if (age >= settleFor) continue;
      final p = _easeOut((age / settleFor).clamp(0.0, 1.0));
      final squash = 0.92 + 0.08 * p;
      for (final (c, r) in l.cells) {
        if (r < 0) continue;
        final rect = cellRect(c.toDouble(), r.toDouble());
        canvas
          ..save()
          ..translate(rect.center.dx, rect.bottom)
          ..scale(1, squash)
          ..translate(-rect.center.dx, -rect.bottom);
        _pebble(canvas, rect, radius, _tone(l.tone));
        canvas.restore();
      }
      // A hard drop leaves a fading trail from where it fell.
      if (l.hardDrop && l.toRow > l.fromRow) {
        final cols = l.cells.map((c) => c.$1);
        final left = cols.reduce(math.min).toDouble();
        final right = cols.reduce(math.max) + 1.0;
        final top = cellRect(left, (l.fromRow - 1).toDouble()).top;
        final bottom = cellRect(left, l.toRow.toDouble()).top;
        canvas.drawRect(
          Rect.fromLTRB(
            cellRect(left, 0).left,
            top,
            cellRect(right - 1, 0).right,
            bottom,
          ),
          Paint()
            ..color = _tone(
              l.tone,
            ).withValues(alpha: 0.35 * (1 - age / BlocksGame.lockRecordFor)),
        );
      }
    }

    // Cleared rows flash oxygen where they were.
    for (final c in game.clears) {
      final age = now - c.at;
      if (age >= flashFor) continue;
      for (final row in c.rows) {
        if (row < 0) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(origin.dx, origin.dy + row * cell, boardW, cell),
            radius,
          ),
          Paint()..color = oxygen.withValues(alpha: 0.9 * (1 - age / flashFor)),
        );
      }
    }

    // Relieved cells dissolve ember where they sat.
    for (final r in game.reliefs) {
      final p = ((now - r.at) / BlocksGame.reliefRecordFor).clamp(0.0, 1.0);
      final color = ember.withValues(alpha: 0.85 * (1 - p));
      for (final cellRecord in r.cells) {
        _pebble(
          canvas,
          cellRect(cellRecord.col.toDouble(), cellRecord.row.toDouble()),
          radius,
          color,
        );
      }
    }

    // The falling piece, where it really is, under a soft glow.
    final piece = game.active;
    final color = _tone(piece.kind.tone);
    final glow = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.45);
    final cells = [
      for (final (dx, dy) in piece.kind.shape(piece.state))
        (piece.col + dx, piece.y + dy),
    ];
    for (final (c, y) in cells) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(cellRect(c.toDouble(), y).inflate(3), radius),
        glow,
      );
    }
    bool has(int c, double y) =>
        cells.any((cell) => cell.$1 == c && (cell.$2 - y).abs() < 1e-9);
    for (final (c, y) in cells) {
      _joinedPebble(
        canvas,
        cellRect(c.toDouble(), y),
        radius,
        color,
        pitch: cell,
        right: has(c + 1, y),
        down: has(c, y + 1),
        corner: has(c + 1, y) && has(c, y + 1) && has(c + 1, y + 1),
      );
    }
    canvas.restore();
  }

  void _pebble(Canvas canvas, Rect rect, Radius radius, Color color) => canvas
      .drawRRect(RRect.fromRectAndRadius(rect, radius), Paint()..color = color);

  /// One cell of a pebble plus the seams to its neighbours right and below,
  /// and the centre of a 2×2 block (four rounded corners leave a pinhole).
  void _joinedPebble(
    Canvas canvas,
    Rect rect,
    Radius radius,
    Color color, {
    required double pitch,
    required bool right,
    required bool down,
    required bool corner,
  }) {
    final paint = Paint()..color = color;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    if (right) {
      canvas.drawRect(
        Rect.fromLTRB(cx, rect.top, cx + pitch, rect.bottom),
        paint,
      );
    }
    if (down) {
      canvas.drawRect(
        Rect.fromLTRB(rect.left, cy, rect.right, cy + pitch),
        paint,
      );
    }
    if (corner) {
      canvas.drawRect(Rect.fromLTRB(cx, cy, cx + pitch, cy + pitch), paint);
    }
  }

  @override
  bool shouldRepaint(BlocksPainter old) =>
      old.game != game ||
      old.volt != volt ||
      old.oxygen != oxygen ||
      old.stone != stone ||
      old.ember != ember ||
      old.board != board ||
      old.border != border;
}
