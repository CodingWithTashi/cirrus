import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/lp_colors.dart';
import '../utils/lp_haptics.dart';

/// Fires [ConfettiBurst] + the celebrate haptic whenever [ids] gains a member
/// after the first build — "a milestone crossed while watching". Whatever was
/// already earned when the screen opened never re-celebrates.
class NewIdConfetti extends StatefulWidget {
  const NewIdConfetti({super.key, required this.ids});

  final Set<String> ids;

  @override
  State<NewIdConfetti> createState() => _NewIdConfettiState();
}

class _NewIdConfettiState extends State<NewIdConfetti> {
  late final Set<String> _seen = {...widget.ids};
  bool _burst = false;
  int _burstCount = 0;

  @override
  void didUpdateWidget(NewIdConfetti old) {
    super.didUpdateWidget(old);
    if (widget.ids.difference(_seen).isEmpty) return;
    _seen.addAll(widget.ids);
    LpHaptics.celebrate();
    setState(() {
      _burst = true;
      _burstCount++;
    });
    Future<void>.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) setState(() => _burst = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_burst) return const SizedBox.shrink();
    return KeyedSubtree(
      key: ValueKey(_burstCount),
      child: const ConfettiBurst(),
    );
  }
}

/// Ember+Volt particle burst for TRUE milestones only (docs/07 §3).
/// Respects reduced-motion: renders nothing when animations are disabled.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.particleCount = 42});

  final int particleCount;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final random = math.Random(7);
    _particles = List.generate(widget.particleCount, (i) {
      final angle = random.nextDouble() * 2 * math.pi;
      final speed = 0.35 + random.nextDouble() * 0.65;
      return _Particle(
        angle: angle,
        speed: speed,
        size: 4 + random.nextDouble() * 5,
        spin: (random.nextDouble() - 0.5) * 10,
        volt: i.isEven,
        round: random.nextBool(),
        drift: (random.nextDouble() - 0.5) * 0.3,
      );
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();
    final lp = context.lp;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(
            particles: _particles,
            t: _controller.value,
            volt: lp.volt,
            ember: lp.ember,
          ),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.spin,
    required this.volt,
    required this.round,
    required this.drift,
  });

  final double angle;
  final double speed;
  final double size;
  final double spin;
  final bool volt;
  final bool round;
  final double drift;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.particles,
    required this.t,
    required this.volt,
    required this.ember,
  });

  final List<_Particle> particles;
  final double t;
  final Color volt;
  final Color ember;

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0) return;
    final origin = Offset(size.width / 2, size.height * 0.32);
    final maxRadius = size.shortestSide * 0.55;
    final eased = Curves.easeOutCubic.transform(t);
    final fade = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;

    for (final p in particles) {
      final distance = maxRadius * p.speed * eased;
      final gravity = 90 * t * t;
      final position =
          origin +
          Offset(
            math.cos(p.angle) * distance + p.drift * distance,
            math.sin(p.angle) * distance * 0.8 + gravity,
          );
      final paint = Paint()
        ..color = (p.volt ? volt : ember).withValues(alpha: fade.clamp(0, 1));
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(p.spin * t);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 1.6,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
