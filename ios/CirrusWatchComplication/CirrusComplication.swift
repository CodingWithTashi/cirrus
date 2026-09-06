import SwiftUI
import WidgetKit

/// The count on the watch face.
///
/// Almost certainly the most-read surface this feature has: a glance costs
/// nothing, where opening even a watch app costs a deliberate act. It reads the
/// watch's own container with the same `CirrusMirror.read` and
/// `CirrusOutbox.pendingToday` the app and both widgets use, so a tap logged on
/// the wrist shows here immediately, before the phone has heard about it.
///
/// Deliberately palette-free. A watch face tints its complications itself and
/// the person chose that tint; painting Midnight Ember over it would fight the
/// system exactly the way a solid rectangle on the iOS lock screen does.
/// `.accessoryRectangular` also earns a Smart Stack slot for free.

/// This bundle's WidgetKit `kind`.
///
/// Local rather than in `CirrusKeys`, which is the phone widget's contract with
/// Dart: nothing on the Flutter side ever names this one. `WatchLink` reloads
/// with `reloadAllTimelines()`, so a rename here cannot silently stop the face
/// updating the way a mismatched `CirrusKeys.kind` would.
private let cirrusWatchKind = "CirrusWatch"

struct CirrusWatchEntry: TimelineEntry {
    let date: Date
    let mirror: CirrusMirror
    let today: CirrusToday
}

struct CirrusWatchProvider: TimelineProvider {

    private func entry(_ date: Date = Date()) -> CirrusWatchEntry {
        let mirror = CirrusMirror.read()
        return CirrusWatchEntry(
            date: date,
            mirror: mirror,
            today: cirrusToday(mirror, pending: CirrusOutbox.pendingToday())
        )
    }

    func placeholder(in context: Context) -> CirrusWatchEntry { entry() }

    func getSnapshot(in context: Context, completion: @escaping (CirrusWatchEntry) -> Void) {
        completion(entry())
    }

    /// One entry, reloaded at the next LOCAL midnight — built as the next
    /// calendar day, never `+ 86400`, which moves an hour across a DST boundary.
    /// The app reloads timelines itself on every tap and on every mirror that
    /// arrives, so this is only the floor.
    func getTimeline(in context: Context, completion: @escaping (Timeline<CirrusWatchEntry>) -> Void) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))
            ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry()], policy: .after(midnight)))
    }
}

struct CirrusWatchComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CirrusWatchEntry

    var body: some View {
        content.containerBackground(for: .widget) { Color.clear }
    }

    @ViewBuilder
    private var content: some View {
        // No journey means no number. The same rule the phone widget follows,
        // and a watch face is the most public place it could be broken: those
        // digits would belong to nobody who is signed in.
        if !entry.mirror.hasJourney {
            switch family {
            case .accessoryInline: Text("Cirrus")
            case .accessoryCorner: Image(systemName: "wind")
            default:
                VStack(spacing: 1) {
                    Image(systemName: "wind")
                    Text(entry.mirror.copyEmptyTitle.isEmpty ? "Cirrus" : entry.mirror.copyEmptyTitle)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        } else {
            switch family {
            case .accessoryInline:
                Text(inline)
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.today.dayLabel(entry.mirror))
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(counts)
                        .font(.system(size: 20, weight: .bold))
                        .monospacedDigit()
                    Text(entry.today.statusLine(entry.mirror))
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
            case .accessoryCorner:
                Text("\(entry.today.count)")
                    .font(.system(size: 18, weight: .bold))
                    .monospacedDigit()
                    .widgetCurvesContent()
                    .widgetLabel { gauge }
            default:
                gauge
            }
        }
    }

    /// `count / limit`, or the count alone when the limit is not knowable —
    /// `cirrusToday` answers -1 past the mirror's seven-day window, and saying
    /// nothing is the honest form of "no invented numbers" on a surface that
    /// cannot do the maths itself.
    private var counts: String {
        entry.today.knowsLimit
            ? "\(entry.today.count) / \(entry.today.limit)"
            : "\(entry.today.count)"
    }

    private var inline: String {
        entry.today.knowsLimit
            ? "\(entry.today.dayLabel(entry.mirror)) · \(counts)"
            : entry.today.dayLabel(entry.mirror)
    }

    private var gauge: some View {
        Gauge(value: fraction) {
            Text("\(entry.today.count)")
        } currentValueLabel: {
            Text("\(entry.today.count)").monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    /// Zero when the limit is unknown OR zero. `limitOn` returns 0 on the last
    /// plan day and every maintenance day after it, and dividing by it would
    /// draw a full ring on precisely the days a single puff puts someone over.
    private var fraction: Double {
        guard entry.today.knowsLimit, entry.today.limit > 0 else { return 0 }
        return min(Double(entry.today.count) / Double(entry.today.limit), 1)
    }
}

struct CirrusWatchComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: cirrusWatchKind, provider: CirrusWatchProvider()) { entry in
            CirrusWatchComplicationView(entry: entry)
        }
        .configurationDisplayName("Cirrus")
        .description("Today's puffs against your plan.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular,
        ])
    }
}

@main
struct CirrusWatchComplicationBundle: WidgetBundle {
    var body: some Widget { CirrusWatchComplication() }
}
