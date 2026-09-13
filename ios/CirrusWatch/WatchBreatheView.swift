import SwiftUI
import WatchKit

/// PANIC · BREATHE, on the wrist.
///
/// A **breathing aid and nothing else**, deliberately. It logs nothing, queues
/// nothing and tells no server: `CirrusOutbox` carries a puff delta clamped to
/// ±1 and turning it into a general command queue — to count a survived craving
/// from here — would touch the seq minting, the id dedupe and the two cursors
/// that the phone↔watch contract test exists to protect. The phone's panic flow
/// is where a craving is recorded; this is where it is ridden out.
///
/// Everything drawn is either the pacer's own maths (ported and proved frame
/// for frame in `test/ios_watch_contract_test.dart`) or a string from the
/// mirror. No journey number appears on this screen at all, which is why the
/// craving clock can be owned here without inventing anything.
struct WatchBreatheView: View {

    @ObservedObject var link: WatchLink

    /// Frozen in Always-On: a 30fps orb at a 1Hz refresh looks broken, and the
    /// countdown is a number nobody can act on with the screen dimmed.
    @Environment(\.isLuminanceReduced) private var dimmed

    private static let pacer = BreathPacer()

    /// When this craving started.
    ///
    /// In the watch's own container rather than `@State`, because watchOS tears
    /// the app down aggressively: someone who lowers their wrist mid-hold and
    /// raises it forty seconds later must read `0:40`. A restarted clock would
    /// reset the one honest number on the screen — and flatter them, which is
    /// the same failure as inventing one.
    @State private var startedAt = Date()

    /// Where the CURRENT breath cycle began — deliberately not `startedAt`.
    ///
    /// The two anchor different things and conflating them was a bug: the
    /// craving clock is persisted and resumes (a wrist lowered mid-hold and
    /// raised forty seconds later must still read 0:40), but the BREATH must
    /// start at the top of an inhale every time the screen is opened. Sharing
    /// one anchor meant a second craving twenty minutes later opened two-thirds
    /// through an inhale, or partway down an exhale — telling somebody to
    /// breathe out when they had just arrived.
    @State private var cycleAnchor = Date()
    @State private var phase: BreathPhase = .inhale

    var body: some View {
        ZStack {
            // The panic ground, not the ordinary card's — the one visual tell
            // that this screen is a different mode.
            Color.cwPanicVoid.ignoresSafeArea()
            content
        }
        .onAppear(perform: begin)
    }

    @ViewBuilder
    private var content: some View {
        if link.mirror.hasJourney {
            paced
        } else if link.mirror.copyEmptyTitle.isEmpty {
            WaitingCard()
        } else {
            EmptyCard(mirror: link.mirror)
        }
    }

    private var paced: some View {
        VStack(spacing: 6) {
            Text(link.mirror.copyBreathePattern)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.cwOxygen.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // The ring redraws off a wall clock, so a dropped frame or a
            // wrist-down never accumulates drift: the phase is DERIVED from
            // elapsed time, never stepped.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: dimmed)) { timeline in
                let moment = Self.pacer.at(cycleFraction(at: timeline.date))
                BreathOrb(moment: moment, showPointer: !dimmed)
            }
            .frame(maxHeight: .infinity)

            // Text turns over only on whole seconds, so it stays out of the
            // 30fps loop entirely — the same reason the phone's painter takes
            // `repaint:` rather than rebuilding its widget tree.
            TimelineView(.periodic(from: cycleAnchor, by: 1)) { timeline in
                let moment = Self.pacer.at(cycleFraction(at: timeline.date))
                VStack(spacing: 3) {
                    HStack(spacing: 5) {
                        Text(verb(moment.phase))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        if !dimmed {
                            Text("\(moment.remaining)")
                                .font(.system(size: 15, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(Color.cwOxygen)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                    Text(timerLine(at: timeline.date))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.cwTextDim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .onChange(of: moment.phase) { _, next in
                    // Fired from the 1Hz timeline, never from inside the
                    // drawing closure: a haptic in a render pass is a side
                    // effect SwiftUI is free to run more than once a frame.
                    beat(next)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }

    // MARK: - The clock

    private func begin() {
        let stored = UserDefaults.cirrus?.double(forKey: WatchKeys.breatheStartedAt) ?? 0
        let age = Date().timeIntervalSince1970 - stored
        // Stale, never set, or a clock that moved backwards: this is a new
        // craving. Thirty minutes is past any single one and short enough that
        // tomorrow's open starts from zero.
        if stored <= 0 || age < 0 || age > 30 * 60 {
            startedAt = Date()
            UserDefaults.cirrus?.set(
                startedAt.timeIntervalSince1970,
                forKey: WatchKeys.breatheStartedAt
            )
        } else {
            startedAt = Date(timeIntervalSince1970: stored)
        }
        // Whatever the craving clock says, the breath starts here.
        cycleAnchor = Date()
        phase = .inhale
    }

    private func cycleFraction(at date: Date) -> Double {
        date.timeIntervalSince(cycleAnchor) / Double(Self.pacer.cycleSeconds)
    }

    private func verb(_ phase: BreathPhase) -> String {
        switch phase {
        case .inhale: return link.mirror.copyBreatheIn
        case .hold: return link.mirror.copyBreatheHold
        case .exhale: return link.mirror.copyBreatheOut
        }
    }

    /// The phone's own line, counting UP with an approximate window. Nothing on
    /// either device can know when a particular craving peaks, so nothing here
    /// counts down to one.
    private func timerLine(at date: Date) -> String {
        let elapsed = max(0, date.timeIntervalSince(startedAt))
        let template = elapsed >= 300
            ? link.mirror.copyCravingTimerLate
            : link.mirror.copyCravingTimer
        // An older phone build carries no template. Hiding the line beats
        // drawing a bare "1:23" with nothing to say what it counts.
        guard !template.isEmpty else { return "" }
        return String(format: template, cirrusTimerText(elapsed))
    }

    /// One tap per phase change, and none in between.
    ///
    /// A deliberate deviation from `panic_screens.dart`, which also ticks every
    /// whole second: on a phone that is a selection click under a fingertip, on
    /// a wrist it is thirty-five taps a minute against the Taptic Engine — a
    /// real battery draw, and it stops reading as a rhythm. Apple's own Breathe
    /// fires on transitions only.
    private func beat(_ next: BreathPhase) {
        guard next != phase else { return }
        phase = next
        switch next {
        case .inhale: WKInterfaceDevice.current().play(.directionUp)
        case .hold: WKInterfaceDevice.current().play(.click)
        case .exhale: WKInterfaceDevice.current().play(.directionDown)
        }
    }
}

// MARK: - The orb

/// Four of the phone painter's six layers.
///
/// Dropped: the 22pt Gaussian bloom (a per-frame offscreen pass, and at wrist
/// size most of the screen) and the pointer's blurred halo. Kept: the track,
/// the three phase ticks — the only thing that shows where the hold ends — the
/// gradient orb, and the elapsed arc, which is what is always visibly moving.
///
/// The orb is sized by its FRAME, never `.scaleEffect`: scaling would thin the
/// 1.5pt rim to nothing at rest.
private struct BreathOrb: View {
    let moment: BreathMoment
    let showPointer: Bool

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let diameter = side * moment.scale

            ZStack {
                Circle()
                    .stroke(Color.cwOxygen.opacity(0.18), lineWidth: 1.5)
                    .frame(width: side, height: side)

                PhaseTicks(starts: BreathPacer().phaseStarts)
                    .stroke(Color.cwOxygen.opacity(0.45), lineWidth: 1.5)
                    .frame(width: side, height: side)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.cwOxygen.opacity(0.30 + 0.25 * fullness),
                                Color.cwOxygen.opacity((0.30 + 0.25 * fullness) * 0.5),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: max(1, diameter / 2)
                        )
                    )
                    .overlay(Circle().stroke(Color.cwOxygen.opacity(0.6), lineWidth: 1.5))
                    .frame(width: diameter, height: diameter)
                    // A cacheable shadow in place of the phone's per-frame
                    // blur; its ALPHA still breathes with the hold.
                    .shadow(
                        color: Color.cwOxygen.opacity(0.14 + 0.16 * fullness + 0.12 * moment.pulse),
                        radius: 8
                    )

                if showPointer {
                    Circle()
                        .trim(from: 0, to: max(0.0001, moment.cycleProgress))
                        .stroke(
                            Color.cwOxygen.opacity(0.85),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: side, height: side)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// 0..1 lung fullness, recovered from the scale the pacer reports.
    private var fullness: Double {
        let minScale = BreathPacer().minScale
        return (moment.scale - minScale) / (1 - minScale)
    }
}

/// The three marks where a phase begins, so the eye can see the hold ending
/// before it gets there.
private struct PhaseTicks: Shape {
    let starts: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        for start in starts {
            let angle = start * 2 * .pi - .pi / 2
            let outer = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            let inner = CGPoint(
                x: center.x + cos(angle) * (radius - 5),
                y: center.y + sin(angle) * (radius - 5)
            )
            path.move(to: inner)
            path.addLine(to: outer)
        }
        return path
    }
}
