import Foundation

/// The contract between the widget and the Flutter app.
///
/// Every name here is mirrored in `lib/data/stores/pending_puffs.dart`,
/// `lib/data/stores/widget_mirror.dart` and the Android
/// `CirrusWidgetData.kt`. A key renamed on one side blanks the widget and
/// throws nothing, which is why `test/android_widget_test.dart` pins the Dart
/// and Kotlin halves against each other — do the same here if this ever grows
/// a test target.
///
/// **Every key has exactly one writer.** Neither `UserDefaults` nor
/// `SharedPreferences` offers compare-and-swap, so a key written by both
/// processes is a read-modify-write race and a tap can simply vanish:
///
///  - `mirror`, `cursor` — the app writes, we read.
///  - `outbox`, `seq`    — we write, the app reads.
enum CirrusKeys {
    /// Must match `HomeWidgetStore.appGroupId` in Dart AND the App Group
    /// enabled on BOTH app ids in the developer portal. A one-character
    /// difference builds, signs, installs and runs, and every read returns
    /// nil for ever.
    static let appGroup = "group.com.quitvape.lastPuff"

    static let mirror = "lp.mirror"
    static let outbox = "lp.outbox"
    static let cursor = "lp.cursor"
    static let seq = "lp.seq"

    /// Must equal the `iOSName` the Dart side passes to `HomeWidget.updateWidget`
    /// and the `kind:` of `WidgetCenter.reloadTimelines`. A mismatch is silent.
    static let kind = "CirrusWidget"

    static let schema = 1
}

extension UserDefaults {
    static var cirrus: UserDefaults? { UserDefaults(suiteName: CirrusKeys.appGroup) }
}

/// What the app last told us about the journey.
///
/// Nothing is recomputed here except the day number and which day's limit
/// applies. Everything else would be a second implementation of the taper
/// curve, and two implementations of the same maths in this repo have already
/// drifted once.
struct CirrusMirror {
    var hasJourney = false
    /// Which account these numbers belong to — the opaque id the app files its
    /// journey under, absent when nobody is signed in.
    ///
    /// The home-screen widget never needs it: it lives in the same container as
    /// the app, so sign-out forgets its queue synchronously. The watch cannot
    /// be reached synchronously, so it is the one surface that has to be able
    /// to ask "are these still the same person's numbers?" — see
    /// `WatchWire.applyContext`.
    var sid = ""
    var dayKey = ""
    var planStartDayKey = ""
    var dayNumber = 0
    /// Plan length; 0 when the mirror predates the field.
    var totalDays = 0
    var puffs = 0
    var limit = 0
    var streak = 0
    var flame = "🔥"
    var limits: [String: Int] = [:]
    var copyDay = ""
    var copyDayFreedom = ""
    var copyDayPastOne = ""
    var copyDayPastOther = ""
    var copyLeftAhead = ""
    var copyLeftTight = ""
    var copyOverLimit = ""
    var copyEmptyTitle = ""
    var copyEmptyBody = ""
    /// The watch app's empty-card body. `copyEmptyBody` says "Tap to open
    /// Cirrus", which watchOS cannot do — it has no way to launch its companion
    /// iPhone app. Unused by the widget, and carried in the same document so
    /// the wrist needs no ARB file of its own.
    var copyWatchOpenPhone = ""

    /// Never throws. An unreadable mirror renders as "no journey yet", which is
    /// the honest empty state rather than a blank rectangle.
    ///
    /// `defaults` exists so one process can hold two containers: the watch app
    /// and the phone speak the same struct over WatchConnectivity, and
    /// `test/ios_watch_contract_test.dart` plays both sides at once. Every
    /// in-app and in-extension call site takes the default.
    static func read(_ defaults: UserDefaults? = .cirrus) -> CirrusMirror {
        decode(defaults?.string(forKey: CirrusKeys.mirror))
    }

    /// The parser itself, over the document rather than the container it sits
    /// in — because the watch receives that same document over the air and must
    /// not grow a second decoder for it (`WatchWire.applyContext`).
    static func decode(_ raw: String?) -> CirrusMirror {
        guard
            let raw,
            let data = raw.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            json["v"] as? Int == CirrusKeys.schema
        else { return CirrusMirror() }

        let copy = json["copy"] as? [String: Any] ?? [:]
        var mirror = CirrusMirror()
        mirror.copyEmptyTitle = copy["emptyTitle"] as? String ?? ""
        mirror.copyEmptyBody = copy["emptyBody"] as? String ?? ""
        mirror.copyWatchOpenPhone = copy["watchOpenPhone"] as? String ?? ""
        guard json["hasJourney"] as? Bool == true else { return mirror }

        mirror.hasJourney = true
        mirror.sid = json["sid"] as? String ?? ""
        mirror.dayKey = json["dayKey"] as? String ?? ""
        mirror.planStartDayKey = json["planStartDayKey"] as? String ?? ""
        mirror.dayNumber = json["dayNumber"] as? Int ?? 0
        mirror.totalDays = json["totalDays"] as? Int ?? 0
        mirror.puffs = json["puffs"] as? Int ?? 0
        mirror.limit = json["limit"] as? Int ?? 0
        mirror.streak = json["streak"] as? Int ?? 0
        mirror.flame = json["flame"] as? String ?? "🔥"
        mirror.limits = json["limits"] as? [String: Int] ?? [:]
        mirror.copyDay = copy["day"] as? String ?? ""
        mirror.copyDayFreedom = copy["dayFreedom"] as? String ?? ""
        mirror.copyDayPastOne = copy["dayPastOne"] as? String ?? ""
        mirror.copyDayPastOther = copy["dayPastOther"] as? String ?? ""
        mirror.copyLeftAhead = copy["leftAhead"] as? String ?? ""
        mirror.copyLeftTight = copy["leftTight"] as? String ?? ""
        mirror.copyOverLimit = copy["overLimit"] as? String ?? ""
        return mirror
    }
}

/// Today as the widget should draw it: the mirror plus anything not drained.
struct CirrusToday {
    let dayNumber: Int
    /// The last plan day — Home's "Freedom Day 🏆".
    let isFreedomDay: Bool
    /// Days past the plan's end; 0 during the plan. Home's maintenance line.
    let daysPast: Int
    let count: Int
    let limit: Int
    let left: Int
    let over: Bool
    let knowsLimit: Bool

    /// The one line the widget composes itself, following exactly the rule
    /// Home already uses so the two surfaces can never contradict each other.
    /// The templates arrive pre-localized carrying a `%1$d`, because the count
    /// is a value the widget changes on its own.
    func statusLine(_ mirror: CirrusMirror) -> String {
        guard knowsLimit else { return "" }
        if over { return mirror.copyOverLimit }
        let template = Double(left) > Double(limit) * 0.25
            ? mirror.copyLeftAhead
            : mirror.copyLeftTight
        return template.isEmpty ? "" : String(format: template, left)
    }

    /// The day line, with Home's upper clamp: the last plan day is Freedom
    /// Day and every day after it is maintenance, said so. The same
    /// `dayLine` the Android provider draws; a mirror from an older app (no
    /// `totalDays`) or a blank template falls back to the plain count so the
    /// line is never empty.
    func dayLabel(_ mirror: CirrusMirror) -> String {
        let plain = mirror.copyDay.isEmpty ? "" : String(format: mirror.copyDay, dayNumber)
        func filled(_ template: String, _ value: Int) -> String {
            let line = String(format: template, value)
            return line.trimmingCharacters(in: .whitespaces).isEmpty ? plain : line
        }
        if daysPast == 1, !mirror.copyDayPastOne.isEmpty {
            return filled(mirror.copyDayPastOne, daysPast)
        }
        if daysPast > 1, !mirror.copyDayPastOther.isEmpty {
            return filled(mirror.copyDayPastOther, daysPast)
        }
        if isFreedomDay, !mirror.copyDayFreedom.isEmpty {
            return mirror.copyDayFreedom
        }
        return plain
    }
}

/// Local midnight, `yyyy-MM-dd` — the same key the app's day map uses.
func cirrusTodayKey(_ date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

/// Whole LOCAL calendar days since the epoch.
///
/// Deliberately counted with `Calendar`, not by dividing an instant: local
/// midnight east of Greenwich falls on the previous UTC date, so arithmetic on
/// the raw interval is a day out for half the world.
private func epochDay(_ date: Date = Date()) -> Int? {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone.current
    return calendar.dateComponents(
        [.day],
        from: Date(timeIntervalSince1970: 0),
        to: calendar.startOfDay(for: date)
    ).day
}

/// `yyyy-MM-dd` -> whole local calendar days since the epoch.
private func epochDay(fromDayKey key: String) -> Int? {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: key) else { return nil }
    return epochDay(date)
}

/// Folds the mirror and the pending taps into what the widget draws.
///
/// The day number comes from the plan's start date in whole calendar days —
/// never a 24-hour interval, which across a DST boundary lands on the wrong
/// date. Which day's limit applies is a lookup in the mirror's own seven-day
/// window; past that the widget says it does not know rather than guessing,
/// which is "no invented numbers" applied to a surface that cannot do the maths.
func cirrusToday(_ mirror: CirrusMirror, pending: Int) -> CirrusToday {
    let today = cirrusTodayKey()
    let fresh = mirror.dayKey == today
    let count = max(0, (fresh ? mirror.puffs : 0) + pending)

    let limit = mirror.limits[today] ?? (fresh ? mirror.limit : -1)
    let knowsLimit = limit >= 0
    // No `limit > 0` clause: `JourneyState.limitOn` returns 0 on the last plan
    // day and every maintenance day after it, and the app's own `isOverLimit`
    // is a bare `puffs > limit`.
    let over = knowsLimit && count > limit

    var dayNumber = mirror.dayNumber
    if let start = epochDay(fromDayKey: mirror.planStartDayKey), let today = epochDay() {
        dayNumber = max(1, today - start + 1)
    }

    // The same upper clamp Home applies. Without it the launcher read "day 31"
    // of a 30-day plan while Home said "1 day past Freedom Day" — the Android
    // bug of Sep 5 2026, fixed on both sides the same day.
    let knowsPlanLength = mirror.totalDays > 0
    let isFreedomDay = knowsPlanLength && dayNumber == mirror.totalDays
    let daysPast = knowsPlanLength ? max(0, dayNumber - mirror.totalDays) : 0

    return CirrusToday(
        dayNumber: dayNumber,
        isFreedomDay: isFreedomDay,
        daysPast: daysPast,
        count: count,
        limit: limit,
        left: knowsLimit ? max(0, limit - count) : 0,
        over: over,
        knowsLimit: knowsLimit
    )
}
