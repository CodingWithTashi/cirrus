import Combine
import Foundation
import OSLog
import WatchConnectivity
import WatchKit
import WidgetKit

/// The wrist's half of the link: a `WCSession` and nothing else.
///
/// Every decision lives in `WatchWire`, which imports no WatchConnectivity and
/// is therefore provable from `flutter test`. What is left here is the part only
/// a real radio can exercise — activation, delivery, acknowledgement — plus
/// publishing the result so SwiftUI can redraw.
///
/// **The count is recomputed from the clock at tap time, never read off the
/// pixels.** A wrist showing yesterday still files today's puff on today; that
/// is `cirrusToday`'s job and this class never second-guesses it.
final class WatchLink: NSObject, ObservableObject {

    static let shared = WatchLink()

    /// Counts and booleans only. Same reasoning as the phone's half — read
    /// `subsystem == "com.quitvape.lastPuff.watch"` rather than guessing which
    /// end of the radio dropped something.
    private static let log = Logger(subsystem: "com.quitvape.lastPuff.watch", category: "wrist")

    /// What the mirror last said. Its `hasJourney` is the gate on everything:
    /// no journey means the empty card, never a count and never a working `+`.
    @Published private(set) var mirror = CirrusMirror()

    /// The mirror folded with anything this watch has not handed over yet.
    @Published private(set) var today = cirrusToday(CirrusMirror(), pending: 0)

    /// Taps still queued on the wrist. Drawn as a small dot, because "logged
    /// here but not on the phone yet" is true and worth saying.
    @Published private(set) var queued = 0

    private var session: WCSession? {
        WCSession.isSupported() ? .default : nil
    }

    // MARK: - Lifecycle

    func start() {
        guard let session else { return }
        session.delegate = self
        if session.activationState != .activated { session.activate() }
        // `awake()` and not a lesser version of it: `.onChange(of: scenePhase)`
        // does NOT fire on a launch that is already active, so a cold start
        // would otherwise never pull and never flush — the wrist would sit on
        // whatever context happened to be waiting and hold its queue until the
        // user backgrounded the app and came back. Found on a simulator, which
        // is the only place it could be found.
        awake()
    }

    /// Re-read the container, ask for a fresh mirror, hand over anything still
    /// queued. Every step is idempotent, which is what lets both a cold start
    /// and a foreground call it, and is why coming forward is this feature's
    /// self-heal rather than a special case.
    func awake() {
        adopt(session?.receivedApplicationContext)
        refresh()
        pull()
        // Retrying: a hand-over the mirror has never confirmed may never have
        // arrived, and a foreground is the cheapest moment to ask again.
        flush(retrying: true)
    }

    // MARK: - Logging

    /// One tap is one puff. Always — the ramp that turned 18 taps into 68 puffs
    /// is not repeated here, and `CirrusOutbox.append` clamps the magnitude to 1
    /// regardless of what it is handed.
    ///
    /// Returns whether the tap was taken, so the caller can say so with a
    /// haptic rather than silently doing nothing.
    @discardableResult
    func log(delta: Int) -> Bool {
        guard CirrusOutbox.append(delta: delta) != nil else {
            WKInterfaceDevice.current().play(.failure)
            return false
        }
        WKInterfaceDevice.current().play(.click)
        refresh()
        WidgetCenter.shared.reloadAllTimelines()
        flush()
        return true
    }

    // MARK: - Private

    private func refresh() {
        let mirror = CirrusMirror.read()
        let pending = CirrusOutbox.pendingToday()
        let queued = CirrusOutbox.queued(above: CirrusOutbox.drained()).count
        onMain {
            self.mirror = mirror
            self.today = cirrusToday(mirror, pending: pending)
            self.queued = queued
        }
    }

    /// Stores a received context and reports whether anything changed. An
    /// unparseable payload leaves what we had — see `WatchWire.applyContext`.
    private func adopt(_ payload: [String: Any]?) {
        guard let payload, let forgot = WatchWire.applyContext(payload) else { return }
        // The wrist just changed hands. Nothing is queued any more, so a
        // repaint is the whole of the work.
        if forgot { WidgetCenter.shared.reloadAllTimelines() }
        refresh()
    }

    /// Hands the queue to the phone, by the best route available.
    ///
    /// **`sendMessage` whenever the phone is reachable, `transferUserInfo` when
    /// it is not** — and the reason is not speed, it is honesty about the
    /// acknowledgement.
    ///
    /// `transferUserInfo` is the durable primitive: FIFO, survives this app being
    /// killed and the watch rebooting, wakes the phone in the background. But the
    /// only receipt it offers is `didFinish`, which reports the *transport's*
    /// opinion — and on a paired pair of simulators that opinion is simply wrong:
    /// `didFinish` fires with no error for payloads the phone never receives
    /// (`docs/10 §29`). Advancing the cursor on that is the "silently lost"
    /// failure this whole design exists to avoid.
    ///
    /// A `sendMessage` reply is an **application-level** receipt: the phone has
    /// opened the envelope, applied what it could, and named the seq it has taken
    /// responsibility for. That is strictly stronger, and it is what the cursor
    /// moves on. The durable path stays for the case it was chosen for — a phone
    /// that is genuinely away — and its `didFinish` is trustworthy there, because
    /// on hardware it is Apple's documented contract.
    private func flush(retrying: Bool = false) {
        guard let session, session.activationState == .activated else { return }
        // One hand-over in flight at a time. Every payload covers everything
        // above the cursor, so five quick taps would otherwise send five
        // overlapping ones and wake the phone five times over. The phone's id
        // dedupe makes that harmless but not free, and a wrist is the most
        // battery-constrained thing this app runs on.
        guard session.outstandingUserInfoTransfers.isEmpty else { return }
        // Only ever retry over the channel that answers: asking again down the
        // durable route would queue a second copy behind the one already in
        // doubt, which helps nobody.
        guard let payload = WatchWire.tapPayload(retrying: retrying && session.isReachable)
        else { return }

        guard session.isReachable else {
            session.transferUserInfo(payload)
            Self.log.info("flush — queued \(WatchWire.through(payload) ?? -1), phone away")
            return
        }
        Self.log.info("flush — sending \(WatchWire.through(payload) ?? -1)")
        session.sendMessage(
            payload,
            replyHandler: { [weak self] reply in self?.settle(reply) },
            errorHandler: { [weak self] error in
                // Reachability is a snapshot and the phone can go between the
                // check and the send. Fall back to the durable route rather than
                // dropping the taps.
                Self.log.info("flush — send failed (\(error.localizedDescription)), queueing")
                self?.handOver(payload)
            }
        )
    }

    private func handOver(_ payload: [String: Any]) {
        guard let session, session.activationState == .activated else { return }
        session.transferUserInfo(payload)
    }

    /// Advances the cursor on the phone's own receipt, then sends whatever was
    /// logged while that batch was in flight.
    private func settle(_ reply: [String: Any]) {
        guard let seq = WatchWire.acknowledged(reply) else {
            // An answer we cannot read is not an acknowledgement. The taps stay
            // queued for a build that can read it.
            Self.log.info("flush — unreadable receipt, keeping the queue")
            return
        }
        Self.log.info("flush — phone took \(seq)")
        WatchWire.markHandedOver(through: seq)
        refresh()
        flush()
    }

    /// Asks for a fresh mirror. Only possible while the phone is reachable, and
    /// only ever an optimisation: the pushed context arrives on its own.
    private func pull() {
        guard let session, session.activationState == .activated, session.isReachable else {
            return
        }
        // A message with no events IS the request — `WatchWire.isTapBatch` is
        // what the phone tells them apart by, so there is nothing else to say.
        session.sendMessage(
            [WatchKeys.fieldVersion: WatchKeys.version],
            replyHandler: { [weak self] reply in
                Self.log.info("pull answered — \(reply.isEmpty ? "empty" : "mirror")")
                self?.adopt(reply)
            },
            errorHandler: { error in
                Self.log.info("pull failed — \(error.localizedDescription)")
                // The phone went away mid-question. The context push covers it.
            }
        )
    }

    /// WatchConnectivity answers on its own queue, and `@Published` must not be
    /// written off the main one.
    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }
}

extension WatchLink: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        Self.log.info("activated \(state == .activated) reachable \(session.isReachable)")
        guard state == .activated else { return }
        // Activation is asynchronous, so `start()`'s own `awake()` may have run
        // against a session that was not up yet. This is the one that counts.
        awake()
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        adopt(context)
    }

    /// The acknowledgement. The cursor moves here and nowhere else — a transfer
    /// that failed stays queued, and a queue handed over twice is absorbed by
    /// the phone's id dedupe.
    func session(
        _ session: WCSession,
        didFinish userInfoTransfer: WCSessionUserInfoTransfer,
        error: Error?
    ) {
        // A failed transfer is left queued and NOT retried from here. Retrying
        // in place would spin: the payload that failed is the payload
        // `tapPayload` would build again. The next foreground or reachability
        // change is what picks it back up.
        Self.log.info("didFinish — error \(error != nil)")
        if error != nil { return }
        guard let seq = WatchWire.through(userInfoTransfer.userInfo) else { return }
        WatchWire.markHandedOver(through: seq)
        refresh()
        // Anything logged while that transfer was in flight.
        flush()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Self.log.info("reachability — \(session.isReachable)")
        // `awake()`, not just `flush()`: the phone coming within reach is also
        // the first moment a pull can succeed, and on a cold launch
        // reachability is routinely still false when the session activates.
        guard session.isReachable else { return }
        awake()
    }
}
