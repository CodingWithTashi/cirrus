import SwiftUI

/// The week, on the wrist — the same seven days Stats draws on the phone.
///
/// It computes nothing. The bars, the denominator, which day was hard, which
/// was the best one, the percent and the money all arrive decided in the
/// mirror; `cirrusWeek` turns counts into heights, which is layout, and folds
/// in taps the phone has not taken yet so this screen and the day card can
/// never disagree about today.
struct WatchWeekView: View {

    @ObservedObject var link: WatchLink

    var body: some View {
        ZStack {
            Color.cwVoid.ignoresSafeArea()
            content
                .padding(.horizontal, 4)
        }
    }

    /// The same three states the day card has, decided the same way. A wrist
    /// with no journey shows words, never seven empty bars and a `$0` — those
    /// numbers would belong to nobody signed in.
    @ViewBuilder
    private var content: some View {
        // `weekPuffs` empty means the mirror predates this screen (a phone
        // build older than the week card, kept across an app update). The card
        // would draw a blank title, no bars and a bare `0` — numbers presented
        // as the reader's own. `CirrusWatchApp` does not build this page in
        // that state; this is the second lock on the same door.
        if link.mirror.hasJourney, !link.mirror.weekPuffs.isEmpty {
            card
        } else if link.mirror.copyEmptyTitle.isEmpty {
            WaitingCard()
        } else {
            EmptyCard(mirror: link.mirror)
        }
    }

    private var card: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(link.mirror.copyWeekTitle)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(Color.cwTextDim)
                    // "PUFFS THIS WEEK" is 15 characters in English and 20 in
                    // French. A 41mm is 176pt wide.
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                // Absent, not zero: there is no honest comparison to draw on an
                // account younger than two weeks, and 0 would claim a flat one.
                if let vsLast = link.mirror.weekVsLast,
                   !link.mirror.copyVsLast.isEmpty {
                    Text(String(format: link.mirror.copyVsLast, link.mirror.weekVsLastLabel))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(vsLast <= 0 ? Color.cwVolt : Color.cwEmber)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                WeekBars(bars: cirrusWeek(link.mirror, today: link.today))

                Rectangle()
                    .fill(Color.cwBorder)
                    .frame(height: 1)

                HStack(alignment: .top, spacing: 10) {
                    FooterStat(
                        value: link.mirror.savedText,
                        label: link.mirror.copySavedLabel,
                        tint: .cwVolt
                    )
                    FooterStat(
                        value: "\(link.mirror.cravingsBeaten)",
                        label: link.mirror.copyCravingsLabel,
                        tint: .white
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Pieces

/// A fixed bar area rather than a `GeometryReader`: deterministic, and it
/// cannot participate in the intrinsic-height walk that took the Health screen
/// down on the phone.
private struct WeekBars: View {
    let bars: [CirrusWeekBar]

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                RoundedRectangle(cornerRadius: 3)
                    .fill(tint(bar.tone))
                    .frame(maxWidth: .infinity)
                    .frame(height: max(2, 56 * bar.height))
            }
        }
        .frame(height: 56)
    }

    /// The same mapping `_EditableBars` uses on the phone: the hard day in
    /// ember, the best day in volt, everything else in the border grey. No
    /// glow — an offscreen shadow per bar, per frame, is the wrong trade on a
    /// watch.
    private func tint(_ tone: CirrusWeekTone) -> Color {
        switch tone {
        case .hardest: return .cwEmber
        case .best: return .cwVolt
        case .plain: return .cwBorder
        }
    }
}

private struct FooterStat: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.cwTextDim)
                // "ahorrado hasta hoy" needs the second line.
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
