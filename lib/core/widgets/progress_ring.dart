import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';

/// Glowing progress ring (Home counter, plan build, panic breathing base).
/// Animates between progress values with a spring-ish ease.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.size,
    this.strokeWidth = 9,
    this.color,
    this.trackColor,
    this.glow = true,
    this.child,
  });

  /// 0..1 (values above 1 clamp; the ring is full).
  final double progress;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final bool glow;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0, 1).toDouble()),
      duration: LpMotion.slow,
      curve: LpMotion.ease,
      builder: (context, value, _) => CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(
          progress: value,
          color: color ?? lp.voltStrong,
          track: trackColor ?? lp.border,
          strokeWidth: strokeWidth,
          glow: glow,
        ),
        child: SizedBox.square(
          dimension: size,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.strokeWidth,
    required this.glow,
  });

  final double progress;
  final Color color;
  final Color track;
  final double strokeWidth;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = 2 * math.pi * progress;
    if (glow) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawArc(rect, -math.pi / 2, sweep, false, glowPaint);
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}
