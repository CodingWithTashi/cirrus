import SwiftUI

/// Cirrus on the wrist.
///
/// A companion app, deliberately: everything it draws comes from the phone's
/// mirror, and everything it logs goes back into the phone's outbox. It computes
/// nothing the Dart engines own — the day number and which day's limit applies
/// are the only two things recomputed natively, exactly as on both home-screen
/// widgets, and for the same reason (a slept-through midnight must not need the
/// phone).
///
/// See `ios/CirrusWatch/README.md` for the build and simulator loop.
@main
struct CirrusWatchApp: App {

    @StateObject private var link = WatchLink.shared
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            WatchHomeView(link: link)
                .onAppear { link.start() }
                // Every foreground re-reads the container, asks the phone for a
                // fresh mirror and pushes anything still queued. All three are
                // idempotent, which is what makes coming forward the feature's
                // self-heal rather than a special case.
                .onChange(of: phase) { _, new in
                    if new == .active { link.awake() }
                }
        }
    }
}
