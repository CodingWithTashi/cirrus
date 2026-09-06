import SwiftUI
import WidgetKit

// MARK: - Palette
//
// Midnight Ember, mirrored from lib/app/theme/lp_colors.dart. Written out here
// rather than read from an asset catalogue so the values stay diffable against
// the Dart tokens. Unlike Android — where the widget follows the system theme
// through values-night, because the launcher inflates it in its own process —
// a WidgetKit view draws itself, so it simply wears the brand.

extension Color {
    static let cwSurface = Color(red: 0.086, green: 0.102, blue: 0.133) // #161A22
    static let cwSurfaceLow = Color(red: 0.063, green: 0.075, blue: 0.102) // #10131A
    static let cwBorder = Color(red: 0.137, green: 0.165, blue: 0.212) // #232A36
    static let cwTextDim = Color(red: 0.604, green: 0.639, blue: 0.698) // #9AA3B2
    static let cwVolt = Color(red: 0.784, green: 0.961, blue: 0.259) // #C8F542
    static let cwOnVolt = Color(red: 0.039, green: 0.047, blue: 0.063) // #0A0C10
    static let cwDanger = Color(red: 1.0, green: 0.361, blue: 0.361) // #FF5C5C
}

struct CirrusEntry: TimelineEntry {
    let date: Date
    let mirror: CirrusMirror
    let today: CirrusToday
}

struct CirrusProvider: TimelineProvider {
    private func entry(_ date: Date = Date()) -> CirrusEntry {
        let mirror = CirrusMirror.read()
        return CirrusEntry(
            date: date,
            mirror: mirror,
            today: cirrusToday(mirror, pending: CirrusOutbox.pendingToday())
        )
    }

    func placeholder(in context: Context) -> CirrusEntry { entry() }

    func getSnapshot(in context: Context, completion: @escaping (CirrusEntry) -> Void) {
        completion(entry())
    }

    /// One entry now, and a reload at the next local midnight.
    ///
    /// The day number and the count both change there, and nothing reloads a
    /// widget on its own. The rest of the time the app drives reloads through
    /// `HomeWidget.updateWidget` on every real change, and the App Intent
    /// reloads after its own tap — so this is the floor, not the mechanism.
    func getTimeline(in context: Context, completion: @escaping (Timeline<CirrusEntry>) -> Void) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let midnight = calendar.date(
            byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())
        ) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry()], policy: .after(midnight)))
    }
}

// MARK: - Pieces

private struct EmptyCard: View {
    let mirror: CirrusMirror

    var body: some View {
        VStack(spacing: 4) {
            Text(mirror.copyEmptyTitle.isEmpty ? "Start your plan" : mirror.copyEmptyTitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.cwVolt)
            Text(mirror.copyEmptyBody.isEmpty ? "Tap to open Cirrus" : mirror.copyEmptyBody)
                .font(.system(size: 12))
                .foregroundStyle(Color.cwTextDim)
                .multilineTextAlignment(.center)
        }
    }
}

private struct DayPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(Color.cwVolt)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.cwVolt.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.cwVolt.opacity(0.2), lineWidth: 1)
            )
    }
}

private struct PlusLabel: View {
    var body: some View {
        Text("+")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Color.cwOnVolt)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(Color.cwVolt, in: Capsule())
    }
}

private struct MinusLabel: View {
    let enabled: Bool

    var body: some View {
        Text("\u{2212}")
            .font(.system(size: 18))
            .foregroundStyle(Color.cwTextDim.opacity(enabled ? 1 : 0.35))
            .frame(width: 48, height: 40)
            .background(Color.cwSurfaceLow, in: Capsule())
            .overlay(Capsule().stroke(Color.cwBorder, lineWidth: 1))
    }
}

/// The `+` and `−`.
///
/// iOS 17 logs in place. On iOS 16 there is no interactive widget at all, so
/// the buttons are not drawn — the whole card is a deep link into the app
/// instead. A control that looks interactive and silently does nothing is the
/// failure this codebase has already named once.
private struct Controls: View {
    let canRemove: Bool

    var body: some View {
        if #available(iOS 17.0, *) {
            HStack(spacing: 8) {
                Button(intent: LogPuffIntent(delta: -1)) { MinusLabel(enabled: canRemove) }
                    .buttonStyle(.plain)
                    .disabled(!canRemove)
                Button(intent: LogPuffIntent(delta: 1)) { PlusLabel() }
                    .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Home-screen families

/// Day number on top, count below — the same reading order as Android.
struct CirrusHomeView: View {
    let entry: CirrusEntry
    let wide: Bool

    var body: some View {
        content.containerBackgroundCompat()
    }

    @ViewBuilder
    private var content: some View {
        if entry.mirror.hasJourney {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    DayPill(text: entry.today.dayLabel(entry.mirror))
                    Spacer()
                    Text(entry.mirror.flame).font(.system(size: 15))
                }
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text("\(entry.today.count)")
                        .font(.system(size: wide ? 44 : 34, weight: .bold))
                        .foregroundStyle(entry.today.over ? Color.cwDanger : Color.white)
                    if entry.today.knowsLimit {
                        Text("/ \(entry.today.limit)")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.cwTextDim)
                    }
                }
                if wide, entry.today.knowsLimit, entry.today.limit > 0 {
                    ProgressView(
                        value: min(Double(entry.today.count) / Double(entry.today.limit), 1)
                    )
                    .tint(entry.today.over ? Color.cwDanger : Color.cwVolt)
                }
                Text(entry.today.statusLine(entry.mirror))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cwTextDim)
                    .lineLimit(2)
                Spacer(minLength: 4)
                Controls(canRemove: entry.today.count > 0)
            }
        } else {
            EmptyCard(mirror: entry.mirror)
        }
    }
}

// MARK: - Lock-screen families
//
// The half of design frame 52 that Android cannot host at all: it has no
// phone lock-screen widget. Accessory families are monochrome by system
// design, so no palette is applied here.

struct CirrusAccessoryView: View {
    let entry: CirrusEntry
    let rectangular: Bool

    var body: some View {
        content.containerBackgroundCompat()
    }

    @ViewBuilder
    private var content: some View {
        if rectangular {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.today.dayLabel(entry.mirror))
                    .font(.system(size: 11, weight: .semibold))
                Text(
                    entry.today.knowsLimit
                        ? "\(entry.today.count) / \(entry.today.limit)"
                        : "\(entry.today.count)"
                )
                .font(.system(size: 18, weight: .bold))
            }
        } else {
            Gauge(value: gaugeValue) {
                Text("\(entry.today.count)")
            } currentValueLabel: {
                Text("\(entry.today.count)")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        }
    }

    private var gaugeValue: Double {
        guard entry.today.knowsLimit, entry.today.limit > 0 else { return 0 }
        return min(Double(entry.today.count) / Double(entry.today.limit), 1)
    }
}

private extension View {
    /// `.containerBackground` is required from iOS 17 — without it the widget
    /// draws on a system default background and StandBy misbehaves. It does
    /// not exist on 16, hence the shim.
    @ViewBuilder
    func containerBackgroundCompat() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                LinearGradient(
                    colors: [Color.cwSurface, Color.cwSurfaceLow],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        } else {
            self.padding(12).background(Color.cwSurface)
        }
    }
}

// MARK: - Widget

struct CirrusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: CirrusKeys.kind, provider: CirrusProvider()) { entry in
            CirrusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Cirrus")
        .description("Log a puff and see your day, without opening the app.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
        ])
    }
}

struct CirrusWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CirrusEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CirrusAccessoryView(entry: entry, rectangular: false)
        case .accessoryRectangular:
            CirrusAccessoryView(entry: entry, rectangular: true)
        case .systemMedium:
            CirrusHomeView(entry: entry, wide: true)
        default:
            CirrusHomeView(entry: entry, wide: false)
        }
    }
}

@main
struct CirrusWidgetBundle: WidgetBundle {
    var body: some Widget { CirrusWidget() }
}
