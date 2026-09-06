import Flutter
import Foundation
import OSLog
import UIKit
import WatchConnectivity
import WidgetKit

/// The phone's half of the link to Cirrus on the wrist.
///
/// Pure Swift over the App Group, deliberately: iOS launches the app in the
/// **background** to take delivery of a `transferUserInfo`, and at that moment
/// there may be no Flutter engine, no `JourneyStore` and no Firebase. Relaying a
/// tap must not need any of them, and it does not — a watch tap becomes an
/// ordinary row in `lp.outbox`, which the app drains through
/// `JourneyStore.logPuff(at:)` on its next foreground exactly like a tap on the
/// home-screen widget. One drain path, one implementation of the maths.
///
/// Every decision lives in `WatchWire`; this class holds the `WCSession` and
/// the one method channel, and nothing else.
final class CirrusWatchLink: NSObject {

    static let shared = CirrusWatchLink()

    /// Counts and booleans only — never the mirror, never the `sid`.
    ///
    /// This whole seam fails silently by nature: a payload that is refused, a
    /// delegate that is never called and a watch that is not paired all look
    /// identical from the outside, which is exactly the shape of bug that cost
    /// this repo a day over App Check and another over `androidName`. Read the
    /// log rather than guessing:
    ///
    ///     xcrun simctl spawn <udid> log stream --predicate 'subsystem == "com.quitvape.lastPuff.watch"'
    private static let log = Logger(subsystem: "com.quitvape.lastPuff.watch", category: "link")

    private static let channelName = "cirrus/watch"

    /// Push the current mirror to the watch. Dart calls this straight after it
    /// writes the mirror, so the wrist is as fresh as the widget.
    private static let methodSync = "sync"

    private var session: WCSession? {
        WCSession.isSupported() ? .default : nil
    }

    /// Activated in `didFinishLaunchingWithOptions`, before anything else.
    ///
    /// The delegate must exist before iOS delivers a background payload: a
    /// `transferUserInfo` that arrives while nothing is listening is held, but a
    /// session that is never activated hears none of them at all — and the taps
    /// would sit on the watch until someone opened the app by hand.
    func start() {
        guard let session else { return }
        session.delegate = self
        if session.activationState != .activated { session.activate() }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(push),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    /// Registers the Dart-facing channel. Called from the app delegate once the
    /// implicit engine exists.
    func attach(messenger: FlutterBinaryMessenger?) {
        guard let messenger else { return }
        FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
            .setMethodCallHandler { [weak self] call, result in
                guard call.method == Self.methodSync else {
                    result(FlutterMethodNotImplemented)
                    return
                }
                self?.push()
                result(nil)
            }
    }

    /// Hands the current mirror document to the watch.
    ///
    /// `updateApplicationContext` and not a message: it is latest-wins, it
    /// persists, and it is delivered the next time the watch connects even if
    /// that is tomorrow — which is precisely what a mirror wants. A message
    /// needs both ends awake and reachable and would simply be lost.
    ///
    /// It is also how sign-out reaches the wrist: `buildMirror` emits
    /// `hasJourney: false`, and the watch stops drawing numbers the moment it
    /// lands. It does not empty the wrist's queue — that follows a change of
    /// `sid`, because this same mirror is what every cold start pushes before
    /// `restoreSession` answers. See `WatchWire.applyContext`.
    @objc func push() {
        guard let session else { return }
        guard
            session.activationState == .activated,
            session.isPaired,
            let payload = WatchWire.contextPayload()
        else {
            Self.log.info(
                "push skipped — state \(session.activationState.rawValue) paired \(session.isPaired) installed \(session.isWatchAppInstalled)"
            )
            return
        }
        Self.log.info("push — paired, installed \(session.isWatchAppInstalled)")
        // Throws only for a malformed dictionary or an inactive session, both of
        // which are guarded above. There is nothing a user could do about it and
        // the next foreground pushes again, so it fails quietly like every other
        // write on this seam.
        try? session.updateApplicationContext(payload)
    }
}

extension CirrusWatchLink: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        Self.log.info(
            "activated \(state == .activated) paired \(session.isPaired) installed \(session.isWatchAppInstalled) error \(error != nil)"
        )
        if state == .activated { push() }
    }

    /// Taps from the wrist.
    ///
    /// `WatchWire.relay` drops a batch minted against a different account and
    /// de-duplicates ids it has already applied, then appends each survivor with
    /// the time the human actually tapped — so a puff taken at 23:58 and
    /// delivered at 00:04 still belongs to the day it happened on.
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        let count = (userInfo[WatchKeys.fieldEvents] as? [[String: Any]])?.count ?? -1
        let landed = WatchWire.relay(userInfo)
        Self.log.info("relay — \(count) event(s) offered, \(landed) landed")
        guard landed > 0 else { return }
        // The home-screen widget adds the still-pending queue on top of the
        // mirror, so it is stale the moment this lands.
        WidgetCenter.shared.reloadTimelines(ofKind: CirrusKeys.kind)
    }

    /// The watch asking for a fresh mirror, when it happens to be reachable.
    /// Only ever an optimisation — the pushed context arrives on its own.
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        // Two kinds of message arrive here: a batch of taps, and a request for a
        // fresh mirror. They are told apart by the envelope, not by a verb.
        guard WatchWire.isTapBatch(message) else {
            Self.log.info("message — answering with the mirror")
            replyHandler(WatchWire.contextPayload() ?? [:])
            return
        }
        let landed = WatchWire.relay(message)
        Self.log.info("message — \(landed) tap(s) landed")
        if landed > 0 { WidgetCenter.shared.reloadTimelines(ofKind: CirrusKeys.kind) }
        // The receipt goes back even when nothing landed — a `−` at zero or a
        // batch from another account has still been consumed, and asking again
        // would never change the answer. `receipt` returns nil only for an
        // envelope this build could not open, which must NOT be acknowledged.
        replyHandler(WatchWire.receipt(for: message) ?? [:])
    }

    /// Both required on iOS. A watch switching to another phone deactivates the
    /// session; re-activating is what keeps this one usable when it comes back.
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        // A watch was just paired, or the app installed on it. It has no mirror
        // yet and cannot ask for one until it runs, so send it now.
        push()
    }
}
