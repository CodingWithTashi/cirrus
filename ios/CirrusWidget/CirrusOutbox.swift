import Foundation

/// Puffs logged on the widget while the app was not running.
///
/// Deliberately tiny and Foundation-only: an `AppIntent` runs in the extension
/// process with a short budget, and this is the only record that the user
/// logged anything. The app drains it on its next launch or resume, through
/// the same `JourneyStore.logPuff(at:)` the in-app button uses — so day keys,
/// hour buckets, over-limit transitions and the repair-token wallet have one
/// implementation, not two.
enum CirrusOutbox {

    /// Well above honest use, and it bounds what one drain can be handed.
    static let maxEvents = 1000

    private static func events(_ defaults: UserDefaults) -> [[String: Any]] {
        guard
            let raw = defaults.string(forKey: CirrusKeys.outbox),
            let data = raw.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            json["v"] as? Int == CirrusKeys.schema,
            let list = json["e"] as? [[String: Any]]
        else { return [] }
        return list
    }

    private static func cursor(_ defaults: UserDefaults) -> Int {
        Int(defaults.string(forKey: CirrusKeys.cursor) ?? "") ?? 0
    }

    private static func dayOf(_ epochMillis: Double) -> String {
        cirrusTodayKey(Date(timeIntervalSince1970: epochMillis / 1000))
    }

    /// How far the reader of this queue has taken responsibility.
    ///
    /// A String, because Dart writes it through `saveWidgetData<String>`. On the
    /// phone that reader is the app; on the watch it is the link handing taps to
    /// the phone, and the watch app is then this key's one writer in its own
    /// container.
    static func drained(in suite: UserDefaults? = .cirrus) -> Int {
        guard let defaults = suite else { return 0 }
        return cursor(defaults)
    }

    /// The queued events above `cursor`, oldest first.
    ///
    /// The widget never needs this — on the phone Dart reads the outbox itself.
    /// It exists so the watch can hand its queue over the radio in the order it
    /// happened, which is load-bearing: the over-limit crossing, the repair
    /// token and the slip flow all turn on *which* puff crossed the line.
    static func queued(above cursor: Int, in suite: UserDefaults? = .cirrus) -> [[String: Any]] {
        guard let defaults = suite else { return [] }
        return events(defaults)
            .filter { ($0["s"] as? Int ?? 0) > cursor }
            .sorted { ($0["s"] as? Int ?? 0) < ($1["s"] as? Int ?? 0) }
    }

    /// Net deltas still pending AND belonging to today.
    ///
    /// "Still pending" is the load-bearing half: once the app has drained an
    /// event it is inside `mirror.puffs`, and counting it here as well would
    /// show a number one higher than the user's own record.
    static func pendingToday(_ suite: UserDefaults? = .cirrus) -> Int {
        guard let defaults = suite else { return 0 }
        let cursor = cursor(defaults)
        let today = cirrusTodayKey()
        return events(defaults).reduce(0) { sum, event in
            guard
                let seq = event["s"] as? Int, seq > cursor,
                let at = (event["t"] as? NSNumber)?.doubleValue, dayOf(at) == today,
                let delta = event["d"] as? Int
            else { return sum }
            return sum + delta
        }
    }

    /// Appends one tap. Returns the count the widget should now draw, or nil
    /// when it was refused — no journey to log against, or a `−` at zero.
    ///
    /// `at` is the moment the human tapped, which is not always now: a tap
    /// relayed from the watch was made before the phone heard about it, and a
    /// puff taken at 23:58 belongs to that day even when it arrives at 00:04.
    /// `suite` is the container to append into — see `CirrusMirror.read`.
    @discardableResult
    static func append(
        delta: Int,
        at: Date = Date(),
        in suite: UserDefaults? = .cirrus
    ) -> Int? {
        guard let defaults = suite else { return nil }
        let mirror = CirrusMirror.read(defaults)
        guard mirror.hasJourney else { return nil }

        let before = cirrusToday(mirror, pending: pendingToday(defaults))
        let step = delta > 0 ? 1 : -1
        // Today-based, exactly as the widget's own `−` is: a relayed `−` from
        // yesterday is checked against today's count. `undoPuffs(1, at:)`
        // no-ops on a day holding no puffs, so the worst case is a queued
        // event the drain discards — never a negative day.
        if step < 0 && before.count <= 0 { return nil }

        let cursor = cursor(defaults)
        // Pruning below the cursor is what stops the queue growing without
        // bound. Only we write this key, so only we may prune it.
        var kept = events(defaults).filter { ($0["s"] as? Int ?? 0) > cursor }
        guard kept.count < maxEvents else { return nil }

        let seq = max(defaults.integer(forKey: CirrusKeys.seq), cursor) + 1
        kept.append([
            "i": "\(seq)-\(UUID().uuidString.prefix(12))",
            "s": seq,
            // Int, not the Double `timeIntervalSince1970 * 1000` produces:
            // JSONSerialization would write a fractional number, and the Dart
            // decoder reads epoch millis. A dropped event is worse than a lost
            // puff — it never advances the cursor, so it stays "pending" for
            // ever, keeps inflating the count the widget draws, and eventually
            // fills the queue until every further tap is refused.
            "t": Int(at.timeIntervalSince1970 * 1000),
            "d": step,
        ])

        guard
            let data = try? JSONSerialization.data(
                withJSONObject: ["v": CirrusKeys.schema, "e": kept]
            ),
            let encoded = String(data: data, encoding: .utf8)
        else { return nil }

        defaults.set(encoded, forKey: CirrusKeys.outbox)
        defaults.set(seq, forKey: CirrusKeys.seq)
        return before.count + step
    }
}
