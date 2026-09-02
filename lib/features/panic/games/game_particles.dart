import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A fixed pool of sparks the arena fires on a clear, a perfect trial, a
/// passed best. Each spark is drawn analytically from its birth, so a frame
/// is a loop over the pool and never a mutation. Positions are
/// field-normalized; [enabled] false (reduced motion) makes [emit] a no-op.
class ParticleSystem {
  ParticleSystem({this.capacity = 96, math.Random? random})
    : _random = random ?? math.Random(7);

  final int capacity;
  final math.Random _random;
  final List<_Spark> _pool = [];
  int _next = 0;
  bool enabled = true;

  /// Normalized units per second squared.
  static const double gravity = 1.6;

  int aliveAt(double now) => _pool.where((s) => s.aliveAt(now)).length;

  /// [count] sparks from ([x], [y]) at game second [at]; [spread] is the
  /// launch speed in widths per second.
  void emit({
    required double x,
    required double y,
    required double at,
    required int count,
    bool volt = false,
    double spread = 0.5,
  }) {
    if (!enabled) return;
    for (var i = 0; i < count; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = spread * (0.4 + 0.6 * _random.nextDouble());
      final spark = _Spark(
        x: x,
        y: y,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - spread * 0.3,
        born: at,
        life: 0.35 + _random.nextDouble() * 0.3,
        size: 2 + _random.nextDouble() * 3,
        volt: volt,
      );
      if (_pool.length < capacity) {
        _pool.add(spark);
      } else {
        _pool[_next] = spark;
        _next = (_next + 1) % capacity;
      }
    }
  }

  void _draw(Canvas canvas, Size size, double now, Color volt, Color oxygen) {
    for (final s in _pool) {
      final t = now - s.born;
      if (t < 0 || t >= s.life) continue;
      final p = t / s.life;
      final alpha = p < 0.7 ? 1.0 : 1 - (p - 0.7) / 0.3;
      final x = (s.x + s.vx * t) * size.width;
      final y = (s.y + s.vy * t + 0.5 * gravity * t * t) * size.width;
      canvas.drawCircle(
        Offset(x, y),
        s.size * (1 - 0.4 * p),
        Paint()..color = (s.volt ? volt : oxygen).withValues(alpha: alpha),
      );
    }
  }
}

class _Spark {
  const _Spark({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.born,
    required this.life,
    required this.size,
    required this.volt,
  });

  final double x;
  final double y;
  final double vx;
  final double vy;
  final double born;
  final double life;
  final double size;
  final bool volt;

  bool aliveAt(double now) => now >= born && now - born < life;
}

/// Draws the sparks over a field, repainting off the frame clock.
class GameParticlesPainter extends CustomPainter {
  GameParticlesPainter({
    required this.system,
    required this.now,
    required Listenable repaint,
    required this.volt,
    required this.oxygen,
  }) : super(repaint: repaint);

  final ParticleSystem system;

  /// The session clock, read at paint time.
  final double Function() now;
  final Color volt;
  final Color oxygen;

  @override
  void paint(Canvas canvas, Size size) =>
      system._draw(canvas, size, now(), volt, oxygen);

  @override
  bool shouldRepaint(GameParticlesPainter old) =>
      old.system != system || old.volt != volt || old.oxygen != oxygen;
}
