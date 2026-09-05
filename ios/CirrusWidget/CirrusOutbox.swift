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

    /// Net deltas still pending AND belonging to today.
    ///
    /// "Still pending" is the load-bearing half: once the app has drained an
    /// event it is inside `mirror.puffs`, and counting it here as well would
    /// show a number one higher than the user's own record.
    static func pendingToday() -> Int {
        guard let defaults = UserDefaults.cirrus else { return 0 }
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
    @discardableResult
    static func append(delta: Int) -> Int? {
        guard let defaults = UserDefaults.cirrus else { return nil }
        let mirror = CirrusMirror.read()
        guard mirror.hasJourney else { return nil }

        let before = cirrusToday(mirror, pending: pendingToday())
        let step = delta > 0 ? 1 : -1
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
            "t": Int(Date().timeIntervalSince1970 * 1000),
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
