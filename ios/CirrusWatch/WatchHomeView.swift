import SwiftUI

/// The whole watch app: one glanceable screen, three states.
///
/// It is the same reading order as both home-screen widgets — day number on
/// top, count below, the line, then the controls — because the wrist and the
/// launcher are one product and a person should not have to re-learn the card.
/// Every string except one annotated fallback arrives pre-localized inside the
/// mirror, so this file adds nothing to the ARB files and cannot drift from the
/// app's language.
struct WatchHomeView: View {

    @ObservedObject var link: WatchLink

    var body: some View {
        ZStack {
            Color.cwVoid.ignoresSafeArea()
            content
                .padding(.horizontal, 4)
        }
    }

    /// The mirror alone decides which state this is — never a launch-scoped
    /// flag, which would show "waiting" on every cold start over a perfectly
    /// good cached mirror.
    ///
    /// A mirror with no journey still carries the empty-state copy, so an
    /// **empty** `copyEmptyTitle` is the one honest signal that no mirror has
    /// ever arrived here.
    @ViewBuilder
    private var content: some View {
        if link.mirror.hasJourney {
            logger
        } else if link.mirror.copyEmptyTitle.isEmpty {
            WaitingCard()
        } else {
            EmptyCard(mirror: link.mirror)
        }
    }

    private var logger: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    DayPill(text: link.today.dayLabel(link.mirror))
                    Spacer(minLength: 2)
                    StreakChip(mirror: link.mirror, fresh: fresh)
                }
                CountRow(today: link.today)
                if link.today.knowsLimit, link.today.limit > 0 {
                    LineBar(
                        fraction: Double(link.today.count) / Double(link.today.limit),
                        over: link.today.over
                    )
                }
                HStack(spacing: 5) {
                    Text(link.today.statusLine(link.mirror))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.cwTextDim)
                        .lineLimit(2)
                    if link.queued > 0 { QueuedDot() }
                }
                // A ROW, not a stack. Stacked full-width buttons came to ~219pt
                // against ~214pt of usable height on a 46mm — and a 41mm is
                // 14pt shorter still — so the `−` sat below the fold on every
                // watch made, half-drawn and untappable. This is the same
                // arrangement the iOS widget's small card uses for the same
                // reason, and the `+` still takes every point the `−` does not.
                HStack(spacing: 8) {
                    RemoveButton(enabled: link.today.count > 0) { link.log(delta: -1) }
                    LogButton { link.log(delta: 1) }
                }
            }
            .padding(.vertical, 2)
        }
    }

    /// Whether the mirror is about today. A streak the phone computed yesterday
    /// is not a number this screen may assert — the flame still burns, the
    /// count beside it does not.
    private var fresh: Bool { link.mirror.dayKey == cirrusTodayKey() }
}

// MARK: - States

/// No journey: signed out, deleted, or never onboarded.
///
/// The rule every widget surface inherits — no journey means a message, never a
/// count, a day number or a working `+`. A watch is on a wrist all day in front
/// of whoever glances at it, and those digits would belong to nobody signed in.
struct EmptyCard: View {
    let mirror: CirrusMirror

    var body: some View {
        VStack(spacing: 5) {
            CirrusMark()
            Spacer().frame(height: 3)
            Text(mirror.copyEmptyTitle)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.cwVolt)
            Text(mirror.copyWatchOpenPhone.isEmpty ? mirror.copyEmptyBody : mirror.copyWatchOpenPhone)
                .font(.system(size: 13))
                .foregroundStyle(Color.cwTextDim)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 6)
    }
}

/// No mirror has ever reached this watch.
///
/// The ONE hardcoded string in the feature, and it cannot be otherwise: the
/// copy travels inside the mirror, so a screen shown *because there is no
/// mirror* has nothing to read. Same sanctioned exception as `LpCrashScreen`,
/// which may render in a tree too broken to hold `Localizations`, and the
/// widget's own English fallbacks.
struct WaitingCard: View {
    var body: some View {
        VStack(spacing: 5) {
            CirrusMark()
            Spacer().frame(height: 3)
            // The SAME words the mirror's copy carries, hardcoded. This card
            // is shown precisely because no mirror has arrived to read them
            // from — and a wrist should not be able to tell the two states
            // apart, because the answer is identical either way: open the app
            // on the phone. It never shows the app's name at somebody: that is
            // a splash screen, not an instruction.
            Text("Start your plan")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.cwVolt)
            Text("Open Cirrus on your iPhone")
                .font(.system(size: 13))
                .foregroundStyle(Color.cwTextDim)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 6)
    }
}

/// The Cirrus mark, as the store frame draws it: the ring, no wisp.
///
/// The REAL artwork at three scales, copied byte-for-byte from the
/// `ic_stat_cirrus` densities — the brand's own small-size treatment, which
/// drops the vapour wisp because below about 48pt it is a two-pixel scratch
/// that leaves the whole mark undersized. `test/ios_watch_test.dart` pins the
/// three files equal to their Android sources by digest, so the copy the watch
/// bundle needs (it cannot read Flutter's asset bundle) cannot drift.
///
/// Two earlier attempts were wrong and are worth naming: an arc traced off
/// these measurements was not the logo, and the full monochrome mark was the
/// logo but not this treatment — it carries the wisp. Do not "restore" it.
///
/// Alpha-only and template-rendered, so the mark takes `cwVolt` rather than
/// carrying a colour of its own.
struct CirrusMark: View {
    var side: CGFloat = 44

    var body: some View {
        Image("CirrusMark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.cwVolt)
            .frame(width: side, height: side)
            .shadow(color: Color.cwVolt.opacity(0.35), radius: 9)
    }
}

// MARK: - Pieces
//
// Deliberately the same shapes, sizes and tokens as `CirrusWidget.swift`'s
// `DayPill` / `PlusLabel` / `MinusLabel` / `LineBar`, scaled up for a wrist.
// They are not shared code: the widget's are `#available`-gated around
// `AppIntent`, which does not exist here, and a watch needs a bigger target.

private struct DayPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(Color.cwVolt)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.cwVolt.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.cwVolt.opacity(0.2), lineWidth: 1)
            )
    }
}

private struct StreakChip: View {
    let mirror: CirrusMirror
    let fresh: Bool

    var body: some View {
        HStack(spacing: 2) {
            Text(mirror.flame).font(.system(size: 14))
            if fresh, mirror.streak > 0 {
                Text("\(mirror.streak)")
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.cwEmber)
            }
        }
    }
}

private struct CountRow: View {
    let today: CirrusToday

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 5) {
            Text("\(today.count)")
                .font(.system(size: 42, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(today.over ? Color.cwDanger : Color.white)
            if today.knowsLimit {
                Text("/ \(today.limit)")
                    .font(.system(size: 15))
                    .monospacedDigit()
                    .foregroundStyle(Color.cwTextDim)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

private struct LineBar: View {
    let fraction: Double
    let over: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill((over ? Color.cwDanger : Color.cwVolt).opacity(0.12))
                Capsule()
                    .fill(over ? Color.cwDanger : Color.cwVolt)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: 6)
    }
}

/// Logged on the wrist, not yet on the phone. Honest rather than decorative:
/// the phone is where the journey lives, and until it has taken the tap the
/// number here is one this watch is holding alone.
private struct QueuedDot: View {
    var body: some View {
        Circle()
            .fill(Color.cwVolt)
            .frame(width: 5, height: 5)
            .accessibilityLabel("Not synced yet")
    }
}

// MARK: - Controls
//
// A tap on LOG PUFF is one puff. Always. No accelerating ramp, no press-and-hold
// multiplier — the ramp that turned 18 taps into 68 logged puffs is not coming
// back, and on a wrist an accidental repeat is even easier.

private struct LogButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("+")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.cwOnVolt)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.cwVolt, in: Capsule())
                // The bloom the mock carries under the primary action. Static,
                // so it costs one cached shadow rather than a per-frame pass.
                .shadow(color: Color.cwVolt.opacity(0.35), radius: 12)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        // In words, not a glyph: VoiceOver reads "+" as "plus", and these are
        // the labels a UI test taps by.
        .accessibilityLabel("Log a puff")
    }
}

private struct RemoveButton: View {
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\u{2212}")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.cwTextDim.opacity(enabled ? 1 : 0.35))
                // Wider than the widget's 48pt: a finger on a wrist is the
                // least precise pointer this app is ever tapped with.
                .frame(width: 62)
                .frame(height: 44)
                .background(Color.cwSurfaceLow, in: Capsule())
                .overlay(
                    Capsule().stroke(enabled ? Color.cwBorder : Color.cwSurface, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .disabled(!enabled)
        .accessibilityLabel("Remove a puff")
    }
}
