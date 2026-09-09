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
            // Horizontal paging, NOT `.verticalPage`: the day card scrolls, and
            // vertical paging would fight that same gesture for the Crown.
            //
            // The two extra pages exist only with a journey. A signed-out wrist
            // is one card you cannot page away from, which is the honest shape
            // — there is no week and nothing to pace against.
            TabView {
                WatchHomeView(link: link)
                // Gated on the DATA, not just on having a journey. A mirror
                // written by a phone build older than these screens is a valid
                // `hasJourney: true` document with none of their fields in it —
                // and the watch keeps the last mirror across an app update, so
                // this is the ordinary first launch after updating, not an edge
                // case. Without the second half of each condition the week page
                // drew a blank title, no bars and a bare `0` under a blank
                // label, which reads as "you have beaten no cravings" to
                // somebody who has beaten forty.
                if link.mirror.hasJourney, !link.mirror.weekPuffs.isEmpty {
                    WatchWeekView(link: link)
                }
                if link.mirror.hasJourney, !link.mirror.copyBreatheIn.isEmpty {
                    WatchBreatheView(link: link)
                }
            }
            .tabViewStyle(.page)
            // BOTH of these belong on the container, never on a page: a
            // `TabView` builds pages lazily, so a hook on the day card would
            // re-fire on every swipe back — and `awake()` pulls and flushes.
            // "A lifecycle callback you did not see fire" is this feature's
            // recurring bug, so there is exactly one of each in this file.
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
