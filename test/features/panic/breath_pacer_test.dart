import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/features/panic/breath_pacer.dart';

/// The 4-7-8 clock behind the breathing ring (docs/09 §7).
///
/// The failure this pins: the orb used to rest at 0.8 of full, so the whole
/// inhale moved it by a fifth over four seconds — below what the eye reads
/// as motion at a glance, and the founder saw a pressed button.
void main() {
  const pacer = BreathPacer();

  /// Cycle-fraction for a moment [seconds] into the breath.
  double at(double seconds) => seconds / pacer.cycleSeconds;

  test('the cycle is 4-7-8, nineteen seconds', () {
    expect(pacer.cycleSeconds, 19);
    expect(pacer.cycle, const Duration(seconds: 19));
    expect(pacer.phaseStarts, [0, 4 / 19, 11 / 19]);
  });

  test('frame one is the start of an inhale, lungs empty, counting from 4', () {
    final m = pacer.at(0);
    expect(m.phase, BreathPhase.inhale);
    expect(m.remaining, 4);
    expect(m.scale, pacer.minScale);
    expect(m.progress, 0);
    expect(m.cycleProgress, 0);
    expect(m.pulse, 0);
  });

  test('the inhale is unmistakable within one second', () {
    // A quarter of the way through the inhale the orb has already grown by
    // more than a fifth of its resting diameter — the acceptance check in
    // docs/09 §7 is "visibly growing within one second of the screen
    // appearing".
    final rest = pacer.at(0).scale;
    final oneSecond = pacer.at(at(1)).scale;
    expect(oneSecond / rest, greaterThan(1.2));
    expect(oneSecond, greaterThan(0.47));
  });

  test('the orb only ever grows through the inhale', () {
    var last = -1.0;
    for (var s = 0.0; s < 4; s += 0.05) {
      final scale = pacer.at(at(s)).scale;
      expect(scale, greaterThanOrEqualTo(last), reason: 'at ${s}s');
      last = scale;
    }
    expect(last, closeTo(1, 0.02));
  });

  test('the hold is full lungs, seven seconds, glow pulsing', () {
    final start = pacer.at(at(4));
    expect(start.phase, BreathPhase.hold);
    expect(start.remaining, 7);
    expect(start.scale, 1);
    expect(start.pulse, closeTo(0, 1e-9));

    // The two-second swell peaks a second in and is back down at two.
    expect(pacer.at(at(5)).pulse, closeTo(1, 1e-9));
    expect(pacer.at(at(6)).pulse, closeTo(0, 1e-9));

    final end = pacer.at(at(10.99));
    expect(end.phase, BreathPhase.hold);
    expect(end.remaining, 1);
    expect(end.scale, 1);
  });

  test('the exhale empties the lungs over eight seconds', () {
    final start = pacer.at(at(11));
    expect(start.phase, BreathPhase.exhale);
    expect(start.remaining, 8);
    expect(start.scale, 1);
    expect(start.pulse, 0);

    var last = 2.0;
    for (var s = 11.0; s < 19; s += 0.05) {
      final scale = pacer.at(at(s)).scale;
      expect(scale, lessThanOrEqualTo(last), reason: 'at ${s}s');
      last = scale;
    }
    expect(last, closeTo(pacer.minScale, 0.02));
    expect(pacer.at(at(18.99)).remaining, 1);
  });

  test('the countdown never shows 0 and never exceeds the phase', () {
    for (var s = 0.0; s < 19; s += 0.01) {
      final m = pacer.at(at(s));
      expect(m.remaining, inInclusiveRange(1, pacer.secondsIn(m.phase)));
    }
  });

  test('the pointer laps once per breath and wraps cleanly', () {
    expect(pacer.at(at(9.5)).cycleProgress, closeTo(0.5, 1e-9));
    // A controller value of exactly 1 is the next breath's first frame, not
    // a twentieth second.
    final wrapped = pacer.at(1);
    expect(wrapped.phase, BreathPhase.inhale);
    expect(wrapped.remaining, 4);
    expect(wrapped.scale, pacer.minScale);
  });
}
