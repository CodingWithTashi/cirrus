import Foundation

/// The 4-7-8 pacer, on the wrist.
///
/// A port of `lib/features/panic/breath_pacer.dart`, and the ONLY arithmetic
/// this watch app owns that the phone also owns. That is a rule broken on
/// purpose and paid for in kind: `test/ios_watch_contract_test.dart` compiles
/// this file with `swiftc` and compares every frame of the 19-second cycle
/// against the real Dart `BreathPacer`, because two implementations of the same
/// maths in this repo have already drifted once (`streakEngine.ts` vs
/// `streak_engine.dart`) and that one only miscounted a streak. This one is
/// what somebody breathes to.
///
/// **Foundation only — no SwiftUI, no WatchKit.** Same discipline
/// `WatchWire.swift` keeps, and for the same reason: it is what lets the test
/// harness compile and run it with no simulator.
///
/// The timings are literals here rather than mirror fields on purpose. Shipping
/// them would mean a wrist on a stale mirror paces a different breath from one
/// on a fresh mirror — worse than either — and it would put clinical content
/// (Weil's 4-7-8, docs/03 §7) in a document instead of in code a test can read.
enum BreathPhase: String {
    case inhale
    case hold
    case exhale
}

/// Where one breath is right now. Mirrors Dart's `BreathMoment` field for field.
struct BreathMoment {
    let phase: BreathPhase
    /// 0..1 through the current phase.
    let progress: Double
    /// 0..1 through the whole breath — one lap of the arc per breath.
    let cycleProgress: Double
    /// Whole seconds left in the phase, counting 4·3·2·1 and never 0: the
    /// moment it would read 0 the next phase has already started.
    let remaining: Int
    /// Diameter of the orb as a fraction of "full lungs", 0..1.
    let scale: Double
    /// 0..1 glow swell through the hold, 0 in every other phase. Full lungs
    /// must not look frozen.
    let pulse: Double
}

/// Flutter's cubic Bézier easing, reproduced exactly.
///
/// **`Curves.easeInOutSine` is not a sine.** It is
/// `Cubic(0.445, 0.05, 0.55, 0.95)` — see
/// `packages/flutter/lib/src/animation/curves.dart:1735`, and the solver at
/// `:396`. Writing the obvious `0.5 - 0.5 * cos(pi * t)` here produces a curve
/// that looks entirely plausible and is visibly out of step with the phone.
///
/// Two details that are the whole game:
///
///  * the bisection SEARCHES on `(a, c)` — the two **x** control points — and
///    RETURNS `(b, d)`, the **y** ones. Swapping the pairs still compiles, still
///    eases, and is wrong.
///  * `transform` short-circuits at exactly 0 and 1 rather than solving. Every
///    phase boundary lands on 0, which is the first frame anyone sees.
struct FlutterCubic {
    let a: Double
    let b: Double
    let c: Double
    let d: Double

    static let easeInOutSine = FlutterCubic(a: 0.445, b: 0.05, c: 0.55, d: 0.95)

    /// Flutter's `_cubicErrorBound`. Part of the contract, not a tuning knob:
    /// the search stops here, so the value changes the output.
    static let errorBound = 0.001

    func evaluate(_ a: Double, _ b: Double, _ m: Double) -> Double {
        3 * a * (1 - m) * (1 - m) * m + 3 * b * (1 - m) * m * m + m * m * m
    }

    func transform(_ t: Double) -> Double {
        if t == 0.0 || t == 1.0 { return t }
        var start = 0.0
        var end = 1.0
        while true {
            let midpoint = (start + end) / 2
            let estimate = evaluate(a, c, midpoint)
            if abs(t - estimate) < Self.errorBound {
                return evaluate(b, d, midpoint)
            }
            if estimate < t {
                start = midpoint
            } else {
                end = midpoint
            }
        }
    }
}

struct BreathPacer {
    let inhale: Int
    let hold: Int
    let exhale: Int
    /// The orb at empty lungs. It rests at 0.4 rather than collapsing, because
    /// it carries the instruction text.
    let minScale: Double

    init(inhale: Int = 4, hold: Int = 7, exhale: Int = 8, minScale: Double = 0.4) {
        self.inhale = inhale
        self.hold = hold
        self.exhale = exhale
        self.minScale = minScale
    }

    var cycleSeconds: Int { inhale + hold + exhale }

    func secondsIn(_ phase: BreathPhase) -> Int {
        switch phase {
        case .inhale: return inhale
        case .hold: return hold
        case .exhale: return exhale
        }
    }

    /// Fraction of the cycle at which each phase begins — the tick marks.
    var phaseStarts: [Double] {
        [
            0,
            Double(inhale) / Double(cycleSeconds),
            Double(inhale + hold) / Double(cycleSeconds),
        ]
    }

    /// Period of the hold-phase glow swell, in seconds.
    private static let pulseSeconds = 2.0

    /// [t] is 0..1 through the cycle. A value of exactly 1 is the start of the
    /// next breath, never a 20th second.
    ///
    /// **`t - floor(t)`, never `truncatingRemainder`.** Dart's `%` on doubles
    /// takes the sign of the DIVISOR, so `-0.25 % 1` is `0.75`; Swift's
    /// remainder keeps the dividend's sign and would answer `-0.25`, putting a
    /// negative elapsed time — a clock that stepped backwards — into the middle
    /// of the exhale instead of the start of the breath.
    func at(_ t: Double) -> BreathMoment {
        let cycleProgress = t - floor(t)
        let seconds = cycleProgress * Double(cycleSeconds)

        if seconds < Double(inhale) {
            let progress = seconds / Double(inhale)
            return BreathMoment(
                phase: .inhale,
                progress: progress,
                cycleProgress: cycleProgress,
                remaining: Int(ceil(Double(inhale) - seconds)),
                scale: scaled(FlutterCubic.easeInOutSine.transform(progress)),
                pulse: 0
            )
        }

        let holdEnd = Double(inhale + hold)
        if seconds < holdEnd {
            let held = seconds - Double(inhale)
            return BreathMoment(
                phase: .hold,
                progress: held / Double(hold),
                cycleProgress: cycleProgress,
                remaining: Int(ceil(holdEnd - seconds)),
                scale: 1,
                pulse: 0.5 - 0.5 * cos(2 * Double.pi * held / Self.pulseSeconds)
            )
        }

        let progress = (seconds - holdEnd) / Double(exhale)
        return BreathMoment(
            phase: .exhale,
            progress: progress,
            cycleProgress: cycleProgress,
            remaining: Int(ceil(Double(cycleSeconds) - seconds)),
            scale: scaled(1 - FlutterCubic.easeInOutSine.transform(progress)),
            pulse: 0
        )
    }

    /// Maps 0..1 "lung fullness" onto the orb's scale range.
    private func scaled(_ fullness: Double) -> Double {
        minScale + (1 - minScale) * fullness
    }
}

/// `m:ss`, the twin of Dart's `LpFormat.timer`.
///
/// ASCII digits and no locale grouping, exactly as the phone renders it — the
/// craving timer must read identically on both screens.
func cirrusTimerText(_ elapsed: TimeInterval) -> String {
    let total = max(0, Int(elapsed))
    return String(format: "%d:%02d", total / 60, total % 60)
}
