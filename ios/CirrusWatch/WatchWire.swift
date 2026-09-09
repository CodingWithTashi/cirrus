import Foundation

/// Keys that exist only on one side of the phone↔watch link.
///
/// Deliberately **not** in `CirrusKeys`: `test/ios_widget_test.dart` pins the
/// `lp.*` set declared in `CirrusShared.swift` equal to the Dart one, and
/// neither key here has a Dart reader or writer. Both are native-only, and each
/// still obeys the one-writer rule — `WatchKeys.sid` belongs to the watch app,
/// `WatchKeys.seen` to `CirrusWatchLink` on the phone.
enum WatchKeys {
    /// The account the watch's cached mirror belongs to.
    static let sid = "lp.watchSid"

    /// The ids of relayed taps the phone has already applied.
    static let seen = "lp.watchSeen"

    /// The highest seq the phone has taken responsibility for.
    ///
    /// Deliberately NOT `lp.cursor`. The phone queues a relayed tap in its own
    /// `lp.outbox` and only folds it into the journey on its next drain, which
    /// can be hours away — so between the receipt and the drain the tap is real,
    /// accepted, and invisible in the mirror. The cursor answers "is this
    /// reflected in the numbers I hold"; this answers "have I sent it". Keeping
    /// them apart is what stops the count dropping back a second after a tap.
    static let sent = "lp.watchSent"

    /// The mirror's identity when the last hand-over happened, as
    /// `<dayKey>|<puffs>`. A mirror that differs from it is one that has been
    /// through the phone's drain, which is when the cursor may finally move.
    ///
    /// Since Sep 8 2026 this is the fallback for a phone that does not name the
    /// seq its mirror reflects (`fieldReflected`). It guessed, and once the
    /// phone started draining a relayed tap within the second the guess was
    /// wrong in both directions: two hand-overs bracketing one mirror retired
    /// the second tap early (the count dropped by one), and a mirror that beat
    /// its own receipt left the mark pointing at the drained count, so the tap
    /// was never retired at all (one too high, for ever).
    static let mark = "lp.watchMark"

    /// When the craving the breathing screen is pacing began, as a
    /// `timeIntervalSince1970`.
    ///
    /// Watch-only and journey-free: it counts a clock, never a puff, so it
    /// crosses no wire and reaches no journey. It lives in the container rather
    /// than in view state because watchOS tears the app down on a wrist-down,
    /// and a craving timer that restarts at 0:00 would quietly flatter the
    /// person reading it.
    static let breatheStartedAt = "lp.watchBreatheStart"

    /// What each relayed wrist tap became on the phone, as
    /// `[sid: <account>, e: [[watchSeq, phoneSeq], …]]`. Phone-only, written by
    /// `relay`, read by `contextPayload` — so the phone can tell the wrist
    /// EXACTLY which of its taps a mirror already includes, instead of leaving
    /// the wrist to infer it from a mark. A refused tap is recorded too, against
    /// the phone's seq at the time: it was consumed, and the wrist must stop
    /// counting it as soon as the phone is that far along.
    static let relayed = "lp.watchRelayed"
    static let relayedSid = "sid"
    static let relayedEntries = "e"

    /// Envelope version. A payload from a version this build does not know is
    /// dropped rather than guessed at — the same stance `CirrusMirror.read`
    /// takes on `lp.mirror`.
    static let version = 1

    /// How many relayed ids to remember.
    ///
    /// Not a rare case: a foreground deliberately re-offers everything the
    /// mirror has not confirmed (`tapPayload(retrying:)`), so this ring is what
    /// makes asking twice free rather than double-counting. It only has to
    /// outlive the window between a hand-over and the phone's next drain.
    static let seenLimit = 200

    /// Envelope fields. Single letters for the same reason the outbox uses
    /// them: every payload crosses a radio link on a battery.
    static let fieldVersion = "v"
    static let fieldMirror = "m"
    static let fieldEvents = "e"
    static let fieldSid = "sid"
    /// The seq the phone has taken responsibility for, in a reply.
    static let fieldThrough = "u"
    /// In a context: the highest watch seq whose tap this mirror already
    /// counts. Absent from a phone that has relayed nothing for this account,
    /// from a no-journey mirror, and from any phone built before Sep 8 2026 —
    /// the watch then falls back to `mark`.
    static let fieldReflected = "r"
}

/// The protocol the phone and the watch speak, with **no WatchConnectivity
/// import anywhere in it.**
///
/// That absence is the point. Every decision this feature can get wrong lives
/// in here as a pure function over two `UserDefaults` containers, so
/// `test/ios_watch_contract_test.dart` compiles this file with `swiftc` and
/// plays both devices in one process — the whole two-device loop provable from
/// `flutter test`, with no simulator and no radio. `WatchLink` (watch) and
/// `CirrusWatchLink` (phone) hold the `WCSession` and nothing else.
///
/// An App Group does not cross the phone↔watch boundary, so the watch keeps its
/// own container with the same four keys. `lp.mirror` and `lp.cursor` are
/// Dart's on the phone and the watch app's on the watch: the single-writer rule
/// holds **per container**, not globally.
enum WatchWire {

    // MARK: - Phone → watch

    /// The application context the phone pushes.
    ///
    /// It carries the mirror document verbatim, exactly as it sits in the App
    /// Group, so the watch decodes it with the same `CirrusMirror.decode` the
    /// widget uses. One parser, one schema, one place a field can go missing.
    static func contextPayload(from suite: UserDefaults? = .cirrus) -> [String: Any]? {
        guard let defaults = suite, let raw = defaults.string(forKey: CirrusKeys.mirror) else {
            return nil
        }
        var payload: [String: Any] = [
            WatchKeys.fieldVersion: WatchKeys.version,
            WatchKeys.fieldMirror: raw,
        ]
        if let reflected = reflected(in: defaults, for: CirrusMirror.decode(raw)) {
            payload[WatchKeys.fieldReflected] = reflected
        }
        return payload
    }

    /// The highest watch seq whose tap the phone has folded into the journey
    /// the mirror describes — or nil when there is nothing honest to say: a
    /// no-journey mirror (it carries no count and may never move a cursor),
    /// nothing ever relayed, or a ledger kept for another account.
    ///
    /// Read off the phone's own `lp.cursor`, which Dart writes only after the
    /// journey write is durable and BEFORE the mirror that follows it is
    /// pushed (`WidgetCoordinator` parks a mid-drain push for exactly that
    /// reason). So a mirror that says `r: 7` includes wrist tap 7 and everything
    /// before it, and the wrist can retire those and keep counting the rest.
    static func reflected(in defaults: UserDefaults, for mirror: CirrusMirror) -> Int? {
        guard mirror.hasJourney, let ledger = defaults.dictionary(forKey: WatchKeys.relayed) else {
            return nil
        }
        let ledgerSid = ledger[WatchKeys.relayedSid] as? String ?? ""
        if !ledgerSid.isEmpty, !mirror.sid.isEmpty, ledgerSid != mirror.sid { return nil }
        let cursor = CirrusOutbox.drained(in: defaults)
        let entries = ledger[WatchKeys.relayedEntries] as? [[Int]] ?? []
        return entries.filter { $0.count == 2 && $0[1] <= cursor }.map { $0[0] }.max() ?? 0
    }

    /// Stores a pushed context on the watch. Returns whether the wrist had to
    /// forget an account, or nil when the payload was not one we understand —
    /// in which case the caller keeps whatever it already had, because blanking
    /// a good mirror on a garbled delivery would be the worse failure.
    @discardableResult
    static func applyContext(
        _ payload: [String: Any],
        into suite: UserDefaults? = .cirrus
    ) -> Bool? {
        guard
            let defaults = suite,
            payload[WatchKeys.fieldVersion] as? Int == WatchKeys.version,
            let raw = payload[WatchKeys.fieldMirror] as? String
        else { return nil }

        let incoming = CirrusMirror.decode(raw)
        let stored = defaults.string(forKey: WatchKeys.sid) ?? ""

        // A DIFFERENT account is the only thing that empties this wrist.
        //
        // `hasJourney: false` looks like it should be one — signing out is
        // exactly that mirror — but so is every cold start of the phone app:
        // `_WidgetSync` builds its first mirror before `restoreSession` has
        // answered, pushes `hasJourney: false`, and pushes the real one a moment
        // later. Treating that as "somebody else" threw away a wrist full of
        // un-handed-over taps every time the user opened the app. Watched
        // happen on a simulator; see docs/10 §29.
        //
        // An EMPTY incoming sid is not a change either — the first push of a
        // cold launch can beat the app's own async uid lookup.
        //
        // What actually protects the next person is the sid on BOTH ends: this
        // wipe when their mirror arrives, and `relay` refusing a batch whose sid
        // is not the phone's own — which covers the window where the watch has
        // not heard about them yet. The wipe is the tidy-up, not the guard.
        let changed = !stored.isEmpty && !incoming.sid.isEmpty && stored != incoming.sid
        if changed { forget(defaults) }

        // The cursor moves only when the mirror has actually been through the
        // phone's drain — which is what `mark` detects. Until then the taps stay
        // "pending" on the wrist and keep counting, because they are real and
        // the mirror does not know about them yet.
        //
        // `incoming.hasJourney` is part of the test on purpose: a no-journey
        // mirror carries no count, so it says nothing about whether the phone
        // has drained. Letting it move the cursor would stop the wrist counting
        // taps the phone is still holding — the dip again, on every cold start.
        if !changed, incoming.hasJourney {
            if let reflected = payload[WatchKeys.fieldReflected] as? Int {
                // A phone that names the seq its numbers include. The cursor
                // follows it exactly — never backwards, and never past this
                // wrist's own seq: a ledger the phone kept for a previous
                // install of the watch app can name seqs this wrist has not
                // minted yet, and retiring those would swallow its next taps.
                // The mark is moot beside it.
                let target = min(reflected, defaults.integer(forKey: CirrusKeys.seq))
                if target > CirrusOutbox.drained(in: defaults) {
                    defaults.set(String(target), forKey: CirrusKeys.cursor)
                }
                defaults.removeObject(forKey: WatchKeys.mark)
            } else if let held = defaults.string(forKey: WatchKeys.mark),
                      held != markOf(incoming) {
                // A phone from before Sep 8 2026: the mark heuristic.
                defaults.set(String(defaults.integer(forKey: WatchKeys.sent)), forKey: CirrusKeys.cursor)
                defaults.removeObject(forKey: WatchKeys.mark)
            }
        }

        defaults.set(raw, forKey: CirrusKeys.mirror)
        if !incoming.sid.isEmpty { defaults.set(incoming.sid, forKey: WatchKeys.sid) }
        return changed
    }

    /// A mirror's identity for the purpose above: the day it is about and the
    /// count it carries. Anything that changes either has been through a drain.
    private static func markOf(_ mirror: CirrusMirror) -> String {
        "\(mirror.dayKey)|\(mirror.puffs)"
    }

    /// Everything the wrist must forget when it changes hands.
    ///
    /// Called from exactly one place, and only for a **different `sid`** — never
    /// for `hasJourney: false`, which is also what every phone cold start pushes
    /// before `restoreSession` answers. The watch's half of the sign-out list is
    /// therefore not a wipe at all: signing out shows the empty card and keeps
    /// the queue, and it is `relay`'s sid check on the phone that stops those
    /// taps ever reaching the next account.
    ///
    /// `lp.mirror` is left to the caller, which overwrites it — the empty-state
    /// copy travels in that same document and the watch needs it to draw an
    /// honest card.
    static func forget(_ defaults: UserDefaults) {
        defaults.removeObject(forKey: CirrusKeys.outbox)
        defaults.removeObject(forKey: CirrusKeys.cursor)
        defaults.removeObject(forKey: CirrusKeys.seq)
        defaults.removeObject(forKey: WatchKeys.sid)
        defaults.removeObject(forKey: WatchKeys.sent)
        defaults.removeObject(forKey: WatchKeys.mark)
        // The craving clock is device-scoped state that is account-SHAPED, the
        // same trap `celebratedMilestones` set on the phone: left behind, the
        // next person to open the breathing page is told they have been in a
        // craving for ten minutes they never had.
        defaults.removeObject(forKey: WatchKeys.breatheStartedAt)
    }

    // MARK: - Watch → phone

    /// The taps the watch has not handed over yet, oldest first, or nil when
    /// there is nothing to send.
    ///
    /// `retrying` is the safety net under a transport that lies. Normally the
    /// floor is whichever marker is further along, so nothing is re-sent while
    /// the cursor lags behind the hand-over. But `sent` can be advanced by a
    /// `didFinish` that reported success for a payload the phone never received
    /// — watched happen (docs/10 §29) — and from the wrist an unconfirmed
    /// hand-over is indistinguishable from one that never arrived. Those taps
    /// would then be counted on the wrist for ever and never reach the phone.
    ///
    /// So a foreground with the phone actually reachable asks again from the
    /// **cursor**: everything the mirror has not confirmed. The phone's id
    /// dedupe makes asking twice free; leaving a real puff stranded is not.
    static func tapPayload(
        from suite: UserDefaults? = .cirrus,
        retrying: Bool = false
    ) -> [String: Any]? {
        guard let defaults = suite else { return nil }
        let cursor = CirrusOutbox.drained(in: defaults)
        let floor = retrying ? cursor : max(cursor, defaults.integer(forKey: WatchKeys.sent))
        let pending = CirrusOutbox.queued(above: floor, in: defaults)
        guard !pending.isEmpty else { return nil }
        return [
            WatchKeys.fieldVersion: WatchKeys.version,
            WatchKeys.fieldSid: defaults.string(forKey: WatchKeys.sid) ?? "",
            WatchKeys.fieldEvents: pending,
        ]
    }

    /// The highest seq a payload covers — derived, so nothing has to be
    /// remembered between sending a batch and hearing what became of it.
    ///
    /// It is what an acknowledgement names, and what `markHandedOver` records.
    /// It is **not** where the cursor goes: that follows the mirror. Both halves
    /// fail toward "handed over twice", which the phone's id dedupe absorbs,
    /// rather than "silently lost", which nothing can recover — the same choice
    /// `WidgetCoordinator._drain` documents on the other side.
    static func through(_ payload: [String: Any]) -> Int? {
        (payload[WatchKeys.fieldEvents] as? [[String: Any]])?
            .compactMap { $0["s"] as? Int }
            .max()
    }

    /// Records that everything up to `seq` has been handed to the phone.
    ///
    /// It does **not** move the cursor. The phone has the taps but has not yet
    /// folded them into the journey, so the wrist must keep counting them or its
    /// number visibly drops back a second after a tap — which is the surest way
    /// to make somebody tap again. The mark taken here is what lets
    /// `applyContext` recognise the mirror that finally includes them.
    ///
    /// On the phone `lp.cursor` belongs to Dart; on the watch there is no Dart,
    /// so the watch app is its one writer. Written as a String because that is
    /// what Dart's `saveWidgetData<String>` produces and `CirrusOutbox` parses.
    static func markHandedOver(through seq: Int, in suite: UserDefaults? = .cirrus) {
        guard let defaults = suite else { return }
        defaults.set(seq, forKey: WatchKeys.sent)
        defaults.set(markOf(CirrusMirror.read(defaults)), forKey: WatchKeys.mark)
    }

    /// The phone's answer to a batch it was handed directly.
    ///
    /// `nil` when the envelope is from a version this build does not understand
    /// — and the distinction matters: a `through` returned for an envelope that
    /// was never opened would let the wrist drop real taps on the floor, where
    /// staying silent leaves them queued for a build that can read them.
    ///
    /// A batch that WAS understood is acknowledged even when nothing landed:
    /// a `−` at zero, or a batch from an account this phone is not signed in
    /// to, has been consumed and must not be asked again.
    static func receipt(for payload: [String: Any]) -> [String: Any]? {
        guard
            payload[WatchKeys.fieldVersion] as? Int == WatchKeys.version,
            let through = through(payload)
        else { return nil }
        return [WatchKeys.fieldVersion: WatchKeys.version, WatchKeys.fieldThrough: through]
    }

    /// The seq a receipt acknowledges, or nil when it is not one.
    static func acknowledged(_ reply: [String: Any]) -> Int? {
        guard reply[WatchKeys.fieldVersion] as? Int == WatchKeys.version else { return nil }
        return reply[WatchKeys.fieldThrough] as? Int
    }

    /// Whether a payload is a batch of taps rather than a request for a mirror.
    static func isTapBatch(_ payload: [String: Any]) -> Bool {
        payload[WatchKeys.fieldEvents] != nil
    }

    /// Applies a batch of relayed watch taps to the **phone's** outbox.
    ///
    /// Three refusals, each closing something real:
    ///
    ///  * a payload from an envelope version this build does not know;
    ///  * a batch minted against a different account. The phone's own mirror is
    ///    the authority: a tap made while person A was signed in must never
    ///    land on person B, and on a shared phone that is the whole reason
    ///    `sid` exists;
    ///  * an id already applied, so a re-sent transfer cannot double-count.
    ///
    /// Each survivor goes through `CirrusOutbox.append`, so the phone mints its
    /// **own** seq and `lp.seq` keeps exactly one writer per container. The app
    /// then drains it through `JourneyStore.logPuff(at:)` like any widget tap —
    /// no second drain path, and no second copy of the taper maths.
    ///
    /// Returns how many taps actually landed, so the caller knows whether the
    /// home-screen widget is now stale.
    @discardableResult
    static func relay(_ payload: [String: Any], into suite: UserDefaults? = .cirrus) -> Int {
        guard
            let defaults = suite,
            payload[WatchKeys.fieldVersion] as? Int == WatchKeys.version,
            let events = payload[WatchKeys.fieldEvents] as? [[String: Any]]
        else { return 0 }

        let mine = CirrusMirror.read(defaults)
        guard mine.hasJourney else { return 0 }

        let sid = payload[WatchKeys.fieldSid] as? String ?? ""
        if !sid.isEmpty, !mine.sid.isEmpty, sid != mine.sid { return 0 }

        var seen = defaults.stringArray(forKey: WatchKeys.seen) ?? []
        // The ledger of what each wrist tap became here. Kept per account: a
        // ledger left by the last person on this phone says nothing about the
        // next person's wrist. An EMPTY stored sid is adopted rather than
        // treated as different — the phone can relay before its own uid lookup
        // has answered, exactly as `applyContext` allows on the watch.
        let ledger = defaults.dictionary(forKey: WatchKeys.relayed) ?? [:]
        let ledgerSid = ledger[WatchKeys.relayedSid] as? String ?? ""
        var entries = ledger[WatchKeys.relayedEntries] as? [[Int]] ?? []
        if !ledgerSid.isEmpty, !mine.sid.isEmpty, ledgerSid != mine.sid { entries = [] }
        var landed = 0
        for event in events.sorted(by: { ($0["s"] as? Int ?? 0) < ($1["s"] as? Int ?? 0) }) {
            guard
                let id = event["i"] as? String, !seen.contains(id),
                let seq = event["s"] as? Int,
                let delta = event["d"] as? Int,
                let millis = (event["t"] as? NSNumber)?.doubleValue
            else { continue }
            // An UNSEEN id at or below a seq already on the ledger is a wrist
            // whose seq space restarted — the watch app reinstalled on the same
            // account. Its old entries would otherwise name its new taps as
            // already counted.
            if let top = entries.last?.first, seq <= top { entries = [] }
            let at = Date(timeIntervalSince1970: millis / 1000)
            // A REFUSED tap is remembered too. `append` returns nil for a `−`
            // at zero, and forgetting that would let the next re-send ask the
            // same question for ever. It goes on the ledger as well, against
            // the phone's seq as it stands: consumed, so the wrist retires it
            // as soon as the phone is that far along.
            if CirrusOutbox.append(delta: delta, at: at, in: defaults) != nil { landed += 1 }
            entries.append([seq, defaults.integer(forKey: CirrusKeys.seq)])
            seen.append(id)
        }
        if seen.count > WatchKeys.seenLimit { seen = Array(seen.suffix(WatchKeys.seenLimit)) }
        if entries.count > WatchKeys.seenLimit { entries = Array(entries.suffix(WatchKeys.seenLimit)) }
        defaults.set(seen, forKey: WatchKeys.seen)
        defaults.set(
            [WatchKeys.relayedSid: mine.sid, WatchKeys.relayedEntries: entries],
            forKey: WatchKeys.relayed
        )
        return landed
    }
}
