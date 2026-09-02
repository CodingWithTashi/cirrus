import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../domain/logic/games/games.dart';
import 'game_catalog.dart';
import 'ghost_combo.dart';

/// The playfield of Tiles (docs/09 §8): four full-bleed lanes, volt tiles
/// with the target in the bottom row, the tapped lane washing oxygen or
/// ember, and the ghost combo behind it all.
///
/// A raw [Listener] hands every pointer-down to the engine as one tap in one
/// lane — no arena to wait on, and one tap is one hit, always.
class TileField extends StatefulWidget {
  const TileField({super.key, required this.scope});

  final GameFieldScope scope;

  /// The live engine. Public so tests can read where the target is.
  TileGame get game => scope.game as TileGame;

  @override
  State<TileField> createState() => _TileFieldState();
}

class _TileFieldState extends State<TileField> {
  /// The taps' washes, pruned off the frame clock; the painter reads the
  /// list by reference, so no rebuild is needed.
  final List<LaneFlash> _flashes = [];

  @override
  void initState() {
    super.initState();
    widget.scope.frame.addListener(_prune);
  }

  @override
  void didUpdateWidget(TileField old) {
    super.didUpdateWidget(old);
    if (old.scope.frame != widget.scope.frame) {
      old.scope.frame.removeListener(_prune);
      widget.scope.frame.addListener(_prune);
    }
    // A fresh board's clock starts over, so old washes would never age out.
    if (old.game != widget.game) _flashes.clear();
  }

  @override
  void dispose() {
    widget.scope.frame.removeListener(_prune);
    super.dispose();
  }

  void _prune() => _flashes.removeWhere(
    (f) => widget.game.elapsed - f.at >= TileFieldPainter.flashFor,
  );

  void _tap(int lane) {
    if (!widget.scope.accepting) return;
    final game = widget.game;
    final at = (x: (lane + 0.5) / TileGame.lanes, y: 0.8);
    switch (game.tap(lane)) {
      case TapOutcome.hit:
        _flashes.add(LaneFlash(lane: lane, at: game.elapsed, hit: true));
        widget.scope.report(GameFeedback.hit, at: at);
      case TapOutcome.miss:
        _flashes.add(LaneFlash(lane: lane, at: game.elapsed, hit: false));
        widget.scope.report(GameFeedback.miss, at: at);
      case TapOutcome.ignored:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return LayoutBuilder(
      builder: (context, constraints) {
        final laneWidth = constraints.maxWidth / TileGame.lanes;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => _tap(
            (event.localPosition.dx / laneWidth).floor().clamp(
              0,
              TileGame.lanes - 1,
            ),
          ),
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
                  painter: TileFieldPainter(
                    game: widget.game,
                    flashes: _flashes,
                    repaint: widget.scope.frame,
                    // `voltStrong`, not `volt`: the same lime in the dark
                    // theme, the stronger green on the pale daylight ground
                    // where plain volt washes out.
                    tile: lp.voltStrong,
                    hit: lp.oxygen,
                    miss: lp.ember,
                    divider: lp.border,
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

/// One tap's wash over its lane: oxygen for a hit, ember for a miss.
class LaneFlash {
  const LaneFlash({required this.lane, required this.at, required this.hit});

  final int lane;

  /// Game second of the tap.
  final double at;
  final bool hit;
}

/// Paints one frame off the engine, repainting off the frame clock. For
/// [slideFor] after an advance the rows ease down a row so a hit reads as
/// scrolling; the engine's positions are already final.
class TileFieldPainter extends CustomPainter {
  TileFieldPainter({
    required this.game,
    required this.flashes,
    required Listenable repaint,
    required this.tile,
    required this.hit,
    required this.miss,
    required this.divider,
  }) : super(repaint: repaint);

  final TileGame game;
  final List<LaneFlash> flashes;

  /// Tile fill (Volt in both themes).
  final Color tile;

  /// The flash a hit tile and its lane wash start from (Oxygen).
  final Color hit;

  /// A lost tile and a wrong-lane wash (Ember).
  final Color miss;

  /// The hairlines between lanes.
  final Color divider;

  /// Tiles sit this far inside their cell, so two in one lane read as two.
  static const double inset = 4;
  static const double radius = 10;

  /// How long the board takes to slide one row after an advance.
  static const double slideFor = 0.09;

  /// How long a hit tile takes to pop and fade.
  static const double hitFor = 0.25;

  /// How long a lane wash lasts.
  static const double flashFor = 0.15;

  static double _easeOut(double p) => 1 - math.pow(1 - p, 3).toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    // The row buffered above the field must never paint over the subtitle.
    canvas.clipRect(Offset.zero & size);
    final laneWidth = size.width / TileGame.lanes;
    final rowHeight = size.height / TileGame.visibleRows;
    final now = game.elapsed;

    Rect cell(int lane, double y) => Rect.fromLTWH(
      lane * laneWidth + inset,
      y * rowHeight + inset,
      laneWidth - 2 * inset,
      rowHeight - 2 * inset,
    );

    void wash(int lane, double age, Color color) {
      if (age < 0 || age >= flashFor) return;
      canvas.drawRect(
        Rect.fromLTWH(lane * laneWidth, 0, laneWidth, size.height),
        Paint()..color = color.withValues(alpha: 0.22 * (1 - age / flashFor)),
      );
    }

    // 1. Dividers — the quiet edges two thumbs steer by.
    final dividerPaint = Paint()
      ..color = divider
      ..strokeWidth = 1;
    for (var i = 1; i < TileGame.lanes; i++) {
      final x = laneWidth * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), dividerPaint);
    }

    // 2. Lane washes: the tap's echo, and the lane a tile got away in.
    for (final flash in flashes) {
      wash(flash.lane, now - flash.at, flash.hit ? hit : miss);
    }
    for (final d in game.departed) {
      if (!d.hit) wash(d.lane, now - d.at, miss);
    }

    // 3. Tiles on their way out, under the live board.
    for (final d in game.departed) {
      final age = now - d.at;
      if (d.hit) {
        // Rides the slide down one row, flashes oxygen, pops to 1.08, fades.
        final p = (age / hitFor).clamp(0.0, 1.0);
        final rect = cell(d.lane, d.y + _easeOut((age / slideFor).clamp(0, 1)));
        final color = Color.lerp(hit, tile, p)!.withValues(alpha: 1 - p);
        final scale = 1 + 0.08 * p;
        canvas
          ..save()
          ..translate(rect.center.dx, rect.center.dy)
          ..scale(scale)
          ..translate(-rect.center.dx, -rect.center.dy);
        _drawTile(canvas, rect, color);
        canvas.restore();
      } else {
        // Frozen at the miss line: turns ember, shakes, dissolves.
        final p = (age / TileGame.resolvedFor).clamp(0.0, 1.0);
        final dx = math.sin(p * 4 * math.pi) * 6 * (1 - p);
        final alpha = p < 0.5 ? 1.0 : 1 - (p - 0.5) * 2;
        _drawTile(
          canvas,
          cell(d.lane, d.y).shift(Offset(dx, 0)),
          miss.withValues(alpha: alpha),
        );
      }
    }

    // 4. The board: target first, each row one above the last, the whole
    // thing easing down a row right after an advance.
    final sinceAdvance = now - game.lastAdvanceAt;
    final slide = game.lastAdvanceAt < 0 || sinceAdvance >= slideFor
        ? 0.0
        : 1 - _easeOut(sinceAdvance / slideFor);
    final rows = game.rows;
    for (var k = rows.length - 1; k >= 0; k--) {
      final y = (k == 0 ? game.targetY : TileGame.home - k) - slide;
      final rect = cell(rows[k], y);
      if (k == 0) {
        // The gap to fill: a soft glow marks the one tile that is slipping.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.inflate(6),
            const Radius.circular(radius + 6),
          ),
          Paint()
            ..color = tile.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
        );
      }
      _drawTile(canvas, rect, tile);
    }
  }

  void _drawTile(Canvas canvas, Rect rect, Color color) => canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(radius)),
    Paint()..color = color,
  );

  @override
  bool shouldRepaint(TileFieldPainter old) =>
      old.game != game ||
      old.tile != tile ||
      old.hit != hit ||
      old.miss != miss ||
      old.divider != divider;
}
