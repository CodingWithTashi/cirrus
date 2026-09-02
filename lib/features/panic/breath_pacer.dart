import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// The three beats of a paced breath.
enum BreathPhase { inhale, hold, exhale }

/// Where one breath is right now: the phase, how far through it, the whole
/// seconds left, and how full the lungs read on screen.
class BreathMoment {
  const BreathMoment({
    required this.phase,
    required this.progress,
    required this.cycleProgress,
    required this.remaining,
    required this.scale,
    this.pulse = 0,
  });

  final BreathPhase phase;

  /// 0..1 through the current phase.
  final double progress;

  /// 0..1 through the whole breath — the pointer's lap around the ring. One
  /// lap per breath, the way Calm's bubble runs its pointer, so the eye can
  /// see how far off the next inhale is even while nothing else moves.
  final double cycleProgress;

  /// Seconds left in the phase, counting down 4·3·2·1 — never 0, because the
  /// moment it would read 0 the next phase has already started.
  final int remaining;

  /// Diameter of the breath orb as a fraction of "full lungs", 0..1.
  final double scale;

  /// 0..1 glow swell through the hold (a two-second sine, Headspace's "gentle
  /// pulsing glow"), 0 in every other phase. Full lungs must not look frozen.
  final double pulse;
}

/// The clock every part of the breathing screen reads — the orb, the arc, the
/// labels, the countdown and the haptics — as pure math, so a test can ask
/// "what does the screen show one second in" without pumping a frame.
///
/// Defaults to Dr. Weil's 4-7-8 (docs/03 §7): inhale four, hold seven, exhale
/// eight. The orb grows through the inhale, stays full through the hold and
/// shrinks through the exhale on a sine ease — the sinusoidal pacer the HRV
/// biofeedback literature uses, and the ease-in-out Apple Watch Breathe,
/// Calm and Headspace all settle on. (The cubic ease-in-out sits nearly still
/// for its first half-second, which is exactly the moment a frightened user
/// is deciding whether the thing moves at all.)
///
/// [minScale] is the orb at empty lungs. Apple's petals collapse to 0.15, but
/// this orb carries the instruction text, so it rests at 0.4: the growth over
/// the first second is still a quarter of the orb — unmistakable — while the
/// label stays inside a visible shape.
class BreathPacer {
  const BreathPacer({
    this.inhale = 4,
    this.hold = 7,
    this.exhale = 8,
    this.minScale = 0.4,
  });

  final int inhale;
  final int hold;
  final int exhale;
  final double minScale;

  int get cycleSeconds => inhale + hold + exhale;

  Duration get cycle => Duration(seconds: cycleSeconds);

  /// Seconds in [phase], for the countdown's ceiling.
  int secondsIn(BreathPhase phase) => switch (phase) {
    BreathPhase.inhale => inhale,
    BreathPhase.hold => hold,
    BreathPhase.exhale => exhale,
  };

  /// [t] is 0..1 through the cycle — an `AnimationController`'s value. A
  /// value of exactly 1 is the start of the next breath, never a 20th second.
  BreathMoment at(double t) {
    final cycleProgress = t % 1;
    final seconds = cycleProgress * cycleSeconds;
    if (seconds < inhale) {
      final progress = seconds / inhale;
      return BreathMoment(
        phase: BreathPhase.inhale,
        progress: progress,
        cycleProgress: cycleProgress,
        remaining: (inhale - seconds).ceil(),
        scale: _scale(Curves.easeInOutSine.transform(progress)),
      );
    }
    final holdEnd = inhale + hold;
    if (seconds < holdEnd) {
      final held = seconds - inhale;
      return BreathMoment(
        phase: BreathPhase.hold,
        progress: held / hold,
        cycleProgress: cycleProgress,
        remaining: (holdEnd - seconds).ceil(),
        scale: 1,
        pulse: 0.5 - 0.5 * math.cos(2 * math.pi * held / _pulseSeconds),
      );
    }
    final progress = (seconds - holdEnd) / exhale;
    return BreathMoment(
      phase: BreathPhase.exhale,
      progress: progress,
      cycleProgress: cycleProgress,
      remaining: (cycleSeconds - seconds).ceil(),
      scale: _scale(1 - Curves.easeInOutSine.transform(progress)),
    );
  }

  /// Period of the hold-phase glow swell.
  static const double _pulseSeconds = 2;

  /// Fraction of the cycle at which each phase begins — the tick marks on the
  /// track, so the eye can see where the hold ends before it gets there.
  List<double> get phaseStarts => [
    0,
    inhale / cycleSeconds,
    (inhale + hold) / cycleSeconds,
  ];

  /// Maps 0..1 "lung fullness" onto the orb's scale range.
  double _scale(double fullness) => minScale + (1 - minScale) * fullness;
}
