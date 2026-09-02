import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_typography.dart';
import '../../domain/logic/tile_game.dart';

/// The playfield of the 60-second panic game (docs/09 §8): four full-bleed
/// columns behind hairline dividers, a board of volt tiles with the target
/// in the bottom row, the tapped lane washing oxygen on a hit and ember on
/// a miss, and the combo as a ghost number behind it all — Piano Tiles 2's
/// trick, so the reward lands where the eyes already are instead of
/// pulling them to the header.
///
/// Every pointer-down is one tap in one lane, handed straight to
/// [onLaneTap]. A raw [Listener] rather than a gesture detector: it fires on
/// the down event with no arena to wait on, and two thumbs landing in the
/// same frame are two events. One tap is one hit, always — the engine
/// resolves at most one tile per call.
///
/// Sized by its parent (an `Expanded`), never by its content. A `Stack` with
/// fitted children: nothing here reports an intrinsic size that an
/// `IntrinsicHeight` above could choke on.
class TileField extends StatelessWidget {
  const TileField({
    super.key,
    required this.game,
    required this.frame,
    required this.flashes,
    required this.combo,
    required this.onLaneTap,
  });

  /// The live engine. Public so tests can read where the target is.
  final TileGame game;

  /// Ticks once per frame; the painter repaints off it without a rebuild.
  final Listenable frame;

  /// Recent taps, for the lane wash. Owned and pruned by the screen.
  final List<LaneFlash> flashes;

  final int combo;
  final ValueChanged<int> onLaneTap;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return LayoutBuilder(
      builder: (context, constraints) {
        final laneWidth = constraints.maxWidth / TileGame.lanes;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => onLaneTap(
            (event.localPosition.dx / laneWidth).floor().clamp(
              0,
              TileGame.lanes - 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: GhostCombo(combo: combo)),
              RepaintBoundary(
                child: CustomPaint(
                  painter: TileFieldPainter(
                    game: game,
                    flashes: flashes,
                    repaint: frame,
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

/// The combo as a huge, faint number behind the tiles. Appears from
/// [threshold] hits, pops on every hit, fades when a miss drops it — the last
/// value stays on screen through the fade rather than snapping to zero.
class GhostCombo extends StatefulWidget {
  const GhostCombo({super.key, required this.combo});

  final int combo;

  static const int threshold = 3;

  @override
  State<GhostCombo> createState() => _GhostComboState();
}

class _GhostComboState extends State<GhostCombo> {
  late int _shown = widget.combo;

  @override
  void didUpdateWidget(GhostCombo old) {
    super.didUpdateWidget(old);
    if (widget.combo >= GhostCombo.threshold) _shown = widget.combo;
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final visible = widget.combo >= GhostCombo.threshold;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: Duration(milliseconds: visible ? 80 : 260),
        child: TweenAnimationBuilder<double>(
          // A new key per hit restarts the pop; explicit begin so the first
          // build animates too (the begin-less Tween gotcha).
          key: ValueKey(visible ? widget.combo : -1),
          tween: Tween(begin: visible ? 1.16 : 1.0, end: 1.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Text(
            '$_shown',
            style: LpType.numberHero(
              lp.voltText.withValues(alpha: 0.16),
              size: 120,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints one frame of the field straight off the engine — `repaint:` keeps
/// the widget tree out of the 60 fps loop entirely.
///
/// The board is drawn where the engine says it is, plus one purely visual
/// touch: for [slideFor] after every advance the rows are drawn one row
/// higher and ease down into place, so a hit reads as the board scrolling
/// rather than the tiles teleporting. The engine's positions are already
/// final the moment the tap lands — the slide never delays an input.
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

    // 1. Dividers — the quiet edges two thumbs steer by.
    final dividerPaint = Paint()
      ..color = divider
      ..strokeWidth = 1;
    for (var i = 1; i < TileGame.lanes; i++) {
      final x = laneWidth * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), dividerPaint);
    }

    // 2. Lane washes — the tap's own echo, fading over [flashFor].
    for (final flash in flashes) {
      final age = now - flash.at;
      if (age < 0 || age >= flashFor) continue;
      canvas.drawRect(
        Rect.fromLTWH(flash.lane * laneWidth, 0, laneWidth, size.height),
        Paint()
          ..color = (flash.hit ? hit : miss).withValues(
            alpha: 0.22 * (1 - age / flashFor),
          ),
      );
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
