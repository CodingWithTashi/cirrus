import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/lp_colors.dart';
import 'breath_pacer.dart';

/// The breathing ring (Frame 32): a thin track that marks "full lungs", an
/// orb that grows and shrinks inside it with the breath, and a pointer that
/// laps the track once per breath with the elapsed arc trailing behind it.
///
/// The three cues are borrowed from the three references that get this right
/// and layered so that something is always visibly moving:
/// - the orb's scale range (0.4 → 1) and its opacity rising with the inhale
///   are Headspace's numbers; Apple Watch Breathe collapses further (0.15)
///   but its petals carry no text;
/// - the pointer on an outer ring is Calm's bubble — one lap per breath, so
///   the seven-second hold still has motion in it;
/// - the glow swells on a two-second pulse through the hold (Headspace), so
///   full lungs never read as a frozen button.
///
/// The orb carries no text. The panic step captions it from below (Apple
/// Watch Breathe and Headspace both keep the shape empty): a circle with a
/// label in it is a button by convention, and a resting orb is narrower than
/// any 28-px verb, so the rim cut straight through the words. [child] stays
/// for a caller that wants something fixed-size on top in a [Stack] — it
/// never scales with the orb. Sized boxes only — no `IntrinsicHeight`
/// anywhere near an animated size (see the Health-screen gotcha in
/// CLAUDE.md).
class BreathRing extends StatelessWidget {
  const BreathRing({
    super.key,
    required this.animation,
    required this.pacer,
    required this.size,
    this.child,
  });

  /// 0..1 through the breath cycle, normally a repeating controller with
  /// [BreathPacer.cycle] as its duration.
  final Animation<double> animation;
  final BreathPacer pacer;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: BreathRingPainter(
                  animation: animation,
                  pacer: pacer,
                  orb: lp.oxygen,
                  ring: lp.oxygenText,
                ),
              ),
            ),
            ?child,
          ],
        ),
      ),
    );
  }
}

/// Paints one frame of the ring straight off the animation — `repaint:`
/// keeps the widget tree out of the 60 fps loop entirely.
class BreathRingPainter extends CustomPainter {
  BreathRingPainter({
    required this.animation,
    required this.pacer,
    required this.orb,
    required this.ring,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final BreathPacer pacer;

  /// Fill of the breath orb (Oxygen in both themes).
  final Color orb;

  /// Track, pointer, arc and tick marks — the text-contrast Oxygen, so the
  /// pointer stays visible on the light panic ground.
  final Color ring;

  /// The frame this painter would draw right now (tests read it).
  BreathMoment get moment => pacer.at(animation.value);

  // Geometry, in fractions of the box so the ring can be sized by layout.
  static const double _trackStroke = 2;
  static const double _arcStroke = 3;
  static const double _pointerRadius = 5;
  static const double _tickLength = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final m = moment;
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    // Room outside the track for the pointer and its glow.
    final trackRadius = outer - _pointerRadius - 6;
    // "Full" stops visibly short of the track, so the track reads as the
    // boundary the breath fills up to, not as the orb's own edge.
    final orbMaxRadius = trackRadius - 16;
    final orbRadius = orbMaxRadius * m.scale;
    // 0 at empty lungs, 1 at full — drives the opacity climb.
    final fullness = ((m.scale - pacer.minScale) / (1 - pacer.minScale)).clamp(
      0.0,
      1.0,
    );

    // 1. Track — the quiet outer boundary.
    canvas.drawCircle(
      center,
      trackRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _trackStroke
        ..color = ring.withValues(alpha: 0.18),
    );

    // 2. Phase ticks — where the inhale, the hold and the exhale begin.
    final tickPaint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = ring.withValues(alpha: 0.45);
    for (final start in pacer.phaseStarts) {
      final angle = -math.pi / 2 + 2 * math.pi * start;
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + dir * (trackRadius - _tickLength / 2),
        center + dir * (trackRadius + _tickLength / 2),
        tickPaint,
      );
    }

    // 3. Orb glow — brighter with fuller lungs, swelling through the hold.
    final glowAlpha = 0.14 + 0.16 * fullness + 0.12 * m.pulse;
    canvas.drawCircle(
      center,
      orbRadius + 6,
      Paint()
        ..color = orb.withValues(alpha: glowAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    // 4. Orb — a soft-centred fill with a defined rim, darker at full lungs
    // (the paced-breathing stimulus in the HRV literature: bigger AND
    // darker on the inhale, smaller AND lighter on the exhale).
    final fillAlpha = 0.30 + 0.25 * fullness;
    canvas.drawCircle(
      center,
      orbRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            orb.withValues(alpha: fillAlpha),
            orb.withValues(alpha: fillAlpha * 0.62),
            orb.withValues(alpha: fillAlpha * 0.5),
          ],
          stops: const [0, 0.7, 1],
        ).createShader(Rect.fromCircle(center: center, radius: orbRadius)),
    );
    canvas.drawCircle(
      center,
      orbRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = orb.withValues(alpha: 0.45 + 0.35 * fullness),
    );

    // 5. Elapsed arc — from twelve o'clock to the pointer.
    final rect = Rect.fromCircle(center: center, radius: trackRadius);
    final sweep = 2 * math.pi * m.cycleProgress;
    if (sweep > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _arcStroke
          ..strokeCap = StrokeCap.round
          ..color = ring.withValues(alpha: 0.85),
      );
    }

    // 6. Pointer — the one thing that never stops moving.
    final pointerAngle = -math.pi / 2 + sweep;
    final pointer =
        center +
        Offset(math.cos(pointerAngle), math.sin(pointerAngle)) * trackRadius;
    canvas.drawCircle(
      pointer,
      _pointerRadius + 3,
      Paint()
        ..color = ring.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(pointer, _pointerRadius, Paint()..color = ring);
  }

  @override
  bool shouldRepaint(BreathRingPainter old) =>
      old.animation != animation ||
      old.pacer != pacer ||
      old.orb != orb ||
      old.ring != ring;
}
