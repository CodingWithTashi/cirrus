# Cirrus on Apple Watch

The watch app and its watch-face complication: day number, today's count against
the line, and `+`/`−` that log a puff from the wrist while the phone app is
closed. The fourth one-tap logging surface `docs/01 §7` names, after the app, the
home-screen widget and Siri.

It is the **same mirror, the same queue and the same guards** as both home-screen
widgets. `CirrusShared.swift` and `CirrusOutbox.swift` are not copied here — they
are members of this target, the complication's, the iOS widget's and Runner's, so
the taper curve, the day clamp, the seven-day limit window and the
no-journey refusals have exactly one implementation. Two implementations of the
same maths in this repo have already drifted once.

## What is in here

| File | What it is |
| --- | --- |
| `CirrusWatchApp.swift` | The `App` entry. Starts the link, and re-syncs on every foreground. |
| `WatchLink.swift` | The wrist's `WCSession` and nothing else — activation, delivery, acknowledgement, haptics, and the `@Published` state SwiftUI redraws from. |
| `WatchWire.swift` | **The protocol both devices speak, with no WatchConnectivity import.** Every decision the feature can get wrong is a pure function in here over two containers, which is what lets `test/ios_watch_contract_test.dart` play both devices in one process. Also a member of Runner. |
| `WatchHomeView.swift` | The one screen, and its three states. |
| `WatchPalette.swift` | Midnight Ember, with the hexes in comments so a test can diff them against `LpColors.midnight()`. |
| `Info.plist` | `WKApplication` + `WKCompanionAppBundleIdentifier`. Both version keys resolve only via `Generated.xcconfig`. |
| `CirrusWatch.entitlements` | The App Group, and nothing else. |
| `Assets.xcassets` | The watch app icon (a copy of the iOS 1024, pinned equal by the test) and the volt accent colour. |

`../CirrusWatchComplication/` holds the WidgetKit bundle for the face:
`accessoryCircular`, `accessoryCorner`, `accessoryInline`, `accessoryRectangular`
— and on watchOS 10 the rectangular family earns a Smart Stack slot for free.
It is embedded in this app's `PlugIns/`, and it is deliberately palette-free: a
watch face tints its own complications and the person chose that tint.

## Why WatchConnectivity, and not the App Group

**An App Group does not cross the phone↔watch boundary.** The name in this
target's entitlements is the same string the iPhone uses and resolves to a
completely different store, because it is a different device. So the watch keeps
its own container with the same four keys, and the phone↔watch link stands in for
what the widget gets for free:

| Direction | Primitive | Why this one |
| --- | --- | --- |
| mirror → watch | `updateApplicationContext` | Latest-wins, persists, delivered the next time the watch connects even if that is tomorrow. Exactly "mirror" semantics. |
| taps → phone | `transferUserInfo` | FIFO, survives this app being killed and the watch rebooting, and **wakes the iPhone app in the background** to take delivery. Exactly "outbox" semantics. |
| a fresh pull | `sendMessage` | Only while reachable, and only ever an optimisation. |

On the phone, `ios/Runner/CirrusWatchLink.swift` relays each tap through
`CirrusOutbox.append(delta:at:)`, so it becomes an ordinary row in `lp.outbox`
that `WidgetCoordinator` drains through `JourneyStore.logPuff(at:)` exactly like a
tap on the home-screen widget. **No second drain path, and the phone mints its
own `seq`** so `lp.seq` keeps one writer per container.

The relay is pure Swift over the container on purpose: iOS launches the app in
the *background* to take that delivery, and at that moment there may be no
Flutter engine, no `JourneyStore` and no Firebase.

### `sid` — the one field the wrist needed and the widget never did

The home-screen widget shares a container with the app, so
`WidgetCoordinator.discardQueued()` forgets its queue the instant someone signs
out. A watch may be out of range at that moment, which opens two leaks on a
shared phone: it keeps *showing* the last person's count, and a tap made on the
old account *lands* on the new one.

`buildMirror` therefore carries `sid`, the same opaque account id analytics and
billing bind to. The rule, exactly:

> The wrist forgets its mirror, queue, cursor and id when the incoming context
> says `hasJourney: false`, **or** when both the stored and incoming `sid` are
> non-empty and differ. An **absent** incoming `sid` is deliberately *not* a
> change — the phone's first push after a cold launch can beat its own async uid
> lookup, and reading "not resolved yet" as "different person" would throw away
> a good mirror and a queue of real taps on every single launch. The phone drops
> a relayed batch whose `sid` is not its own mirror's.

Signing out is the fifth thing on `CLAUDE.md`'s forget-list, and the only one
that cannot be done synchronously — so it is done by construction instead: the
sign-out mirror carries `hasJourney: false` with no `sid`, and the wrist forgets
the moment it arrives.

## The Xcode targets are generated, not hand-made

```
/usr/bin/ruby tool/ios_watch_target.rb          # idempotent; a no-op once present
```

System Ruby, because that is the one CocoaPods' `xcodeproj` gem is installed
against. Same reasoning as `tool/ios_widget_target.rb`: the wizard is thirty
seconds of GUI nobody can review and a hand-edited pbxproj is thirty UUIDs nobody
can verify. `pubspec.yaml` still prescribes
`git checkout ios/Runner.xcodeproj/project.pbxproj` after
`dart run flutter_launcher_icons`; with the targets committed that is safe, and
if it ever is not, re-run the script.

Watch app `com.quitvape.lastPuff.watch`, complication
`…watch.complication`, watchOS 10.0, Swift 5.0 pinned (so Xcode 26's
Swift-6 / main-actor defaults never apply), three configurations all based on
`Flutter/Generated.xcconfig` — **unlinked, the archive uploads and App Store
Connect rejects it with `ITMS-90473`, and a watch app's version must equal the
host's exactly.** Runner gets a target dependency plus an *Embed Watch Content*
copy phase (`dstSubfolderSpec 16`, `$(CONTENTS_FOLDER_PATH)/Watch` — **not**
PlugIns, where an `.app` builds, installs and is not recognised as watch content
at all). Neither target enters the Runner scheme.

## Building and running

**Flutter knows about watch companions, and changes its own build once one
exists.** It finds this target by reading `ios/CirrusWatch/Info.plist` for a
`WKCompanionAppBundleIdentifier` equal to the host's bundle id (the cheap path —
the literal id here means the expensive per-scheme scan is never reached, which
is why the watch needs no scheme of its own). Then three things change, all in
`flutter_tools/lib/src/ios/mac.dart`:

1. **`-sdk` is omitted**, so WatchKit dependencies are not built against the iOS
   SDK.
2. **`-d <device-id>` becomes mandatory for a simulator build.** Without it:
   `A device ID is required to build an app with a watchOS companion app.` It
   looks like a broken project and is not.
3. **`ONLY_ACTIVE_ARCH`/`ARCHS` are no longer passed**, because the watch app
   cannot be built for the Flutter app's architecture. Which incidentally
   *removes* the alternating-arch pod rebuild the widget README warns about:
   every build is now the both-archs shape.

```
flutter build ios --simulator --debug -d <sim-udid> \
  --dart-define=LP_BACKEND=firebase --dart-define-from-file=.dart_defines.json
ls build/ios/iphonesimulator/Runner.app/Watch/CirrusWatch.app/PlugIns/
flutter run -d <sim-udid> --dart-define=LP_BACKEND=firebase --dart-define-from-file=.dart_defines.json
flutter build ipa                                   # archives from the workspace
```

To compile just the watch side — seconds, and it touches no pod:

```
cd ios && xcodebuild -project Runner.xcodeproj -target CirrusWatch \
  -sdk watchsimulator -configuration Debug CODE_SIGNING_ALLOWED=NO \
  SYMROOT=/tmp/cirrus-watch OBJROOT=/tmp/cirrus-watch build
```

Pass `SYMROOT`/`OBJROOT` or don't bother passing `BUILD_DIR`: `SYMROOT` defaults
to `$(SRCROOT)/build`, so a bare invocation leaves **220 MB in `ios/build/`** —
which is not in any `.gitignore` and turns up as untracked noise in the next
`git status`.

**The watch only does anything on the Firebase backend.**
`widgetCoordinatorProvider` is null on the fake backend by design, so
`LP_BACKEND=fake` gives an app whose wrist never receives a mirror. Same as both
home-screen widgets.

## The paired-simulator loop

```
xcodebuild -downloadPlatform watchOS                # ~4 GB, once
PHONE=$(xcrun simctl create "Cirrus iPhone 26" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-3)
WATCH=$(xcrun simctl create "Cirrus Watch" com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-11-46mm com.apple.CoreSimulator.SimRuntime.watchOS-26-2)
xcrun simctl pair "$WATCH" "$PHONE" && xcrun simctl boot "$PHONE" && xcrun simctl boot "$WATCH"
```

Leave a signed-in journey on the phone the way the widget loop does — with
`flutter run`, not `flutter test`, because a test run tears the app down and the
whole point is what it leaves behind. **It writes to production `alastpuff`**;
`E2E_STEP=teardown` deletes the throwaway account afterwards:

```
flutter run -d $PHONE -t integration_test/j_widget_session_test.dart --no-resident \
  --dart-define=LP_BACKEND=firebase --dart-define-from-file=.dart_defines.json
```

Then install and launch the watch app, and read the wrist's own container:

```
xcrun simctl install "$WATCH" build/ios/iphonesimulator/Runner.app/Watch/CirrusWatch.app
xcrun simctl launch "$WATCH" com.quitvape.lastPuff.watch
C=$(xcrun simctl get_app_container "$WATCH" com.quitvape.lastPuff.watch groups | head -1)
xcrun simctl spawn "$WATCH" defaults read "$C/Library/Preferences/group.com.quitvape.lastPuff.plist"
```

Read it through `simctl spawn defaults read`, **not `plutil -p` on the file** —
the same trap as the widget's: writes go through the simulator's cfprefsd and the
file on disk lags by seconds.

**The loop that matters**, and what it proves:

| Step | Expected |
| --- | --- |
| Phone signed in, watch app opened | `lp.mirror` in the watch's container with today's `dayNumber`, `puffs`, seven `limits` and `sid`; the screen draws the day pill and the count |
| Kill the phone app; `+`, `+`, `−` on the wrist | the wrist reads +2; `lp.outbox` on the WATCH holds seq 1–4 with integral `t`; the phone has nothing yet |
| Launch the phone app | the phone's `lp.outbox` holds four events, `lp.seq 4`, Home's count is +2; the watch's `lp.cursor` is 4 and its queue is empty |
| Launch again | nothing changes (the id dedupe) |
| Sign out on the phone | the wrist flips to "Start your plan / Open Cirrus on your iPhone"; its queue, cursor and `sid` are gone; `+` refuses with a failure haptic |
| Complication on a face | the gauge draws count-against-limit and follows a tap immediately |

## What only the founder can do

- **Developer portal — done (Sep 6 2026), and worth knowing why.**
  `com.quitvape.lastPuff.watch.widget` ("Cirrus Watch Complication") and
  `com.quitvape.lastPuff.watch` both exist and both carry App Group
  `group.com.quitvape.lastPuff`. A device build signs and completes:
  `✓ Built build/ios/iphoneos/Runner.app`.

  **`.complication` is a reserved suffix** — Apple refuses
  `<watch app>.complication` from automatic signing *and* from the portal by
  hand, so it is the word, not the tooling. `.widget` registers instantly. If a
  future extension hits the same wall, that is the first thing to try.

  Two traps if these rows ever need rebuilding: the **App Groups tick does not
  survive registration** (set it again on the saved identifier, and pick the
  group through *Configure*), and a failure here falls back to a wildcard
  profile which cannot carry App Groups, so the App-Group errors that follow are
  a cascade rather than the actual problem.

  Two stray App IDs from the failed attempts — `com.quitvape.lastPuff.watchkitapp`
  and `com.quitvape.lastPuff.watchface` — are unused and can be deleted at
  leisure. Nothing references them.

- **A real Apple Watch.** The hardware checklist is below, and until it is done
  the store listing must stay silent about the watch. `B21` is the standing
  lesson: advertising a surface that is not proven is the bait-and-switch clause
  in Apple 3.1.2(a).
- Nothing in Firebase changes: the watch never touches Firebase or App Check.

### Hardware checklist — owed before the listing claims watch support

Only three things a simulator cannot say, and each is a real code path:

1. **A handover.** Log a puff with the phone on cellular and the watch on wifi,
   and again mid-transition. `transferUserInfo` should still land.
2. **Out of range at tap time.** Walk away from the phone, log three puffs, come
   back. All three must arrive, in order, once — and the wrist's cursor must not
   have moved until they did.
3. **The background launch.** Force-quit the phone app, log a puff on the wrist,
   and *do not* open the phone app. iOS should wake it to take delivery; the tap
   must be in `lp.outbox` before anything is opened by hand.

Plus the two ordinary ones: the app appears in the Watch app's list and installs
alongside the phone app, and the complication can be added to a real face.

## Things that will bite

- **`-d` is mandatory now.** See "Building and running" — a `--simulator` build
  without it fails with a message that reads like a broken project.
- **The watch app does not inherit the app's fonts.** Space Grotesk and Inter are
  bundled for the Flutter app; this target sees neither. The views use the system
  font on purpose, and the failure mode if you "fix" it wrongly is no crash, just
  SF everywhere. Same as the widget.
- **An App Group is per-device.** The identical string in the entitlements is not
  the phone's store. Anything you expect to read across the boundary has to
  travel through `WatchWire`.
- **`@Published` off the main thread.** WatchConnectivity answers on its own
  queue; `WatchLink.onMain` is why the screen does not tear.
- **`WKRunsIndependentlyOfCompanionApp` must stay absent.** Every number here
  comes from the phone's mirror, so a standalone install could only ever show the
  empty card — offering it would be advertising a surface that cannot work.
- **`didFinish` is the transport's opinion and it lies on a simulator.** It fires
  with no error for payloads the phone never receives. That is why taps go by
  `sendMessage` whenever the phone is reachable, and why the cursor moves on the
  phone's own receipt rather than on delivery.
- **Two cursors, deliberately.** `lp.watchSent` is what has been handed over (the
  send floor); `lp.cursor` is what the *mirror* reflects. The phone queues a
  relayed tap and only folds it into the journey on its next drain, so collapsing
  the two makes the count drop back a second after a tap. `lp.watchMark` is how
  `applyContext` recognises the mirror that finally includes them.
- **Reading the diagnostics.** `simctl spawn <udid> log stream` is broken here
  (`getpwuid_r did not find a match for uid 501`), and `log show` hides
  `Logger.info` unless you pass `--info` — so a first attempt looks exactly like
  "the code never ran". Use:
  `xcrun simctl spawn <udid> log show --last 2m --info --predicate 'subsystem == "com.quitvape.lastPuff.watch"'`
- **The watch's device window can vanish.** Simulator sometimes shows a black
  `Cirrus Watch – External Display` window instead of the device, and it matches
  the same `name contains "Cirrus Watch"` lookup — so clicks go into the void and
  a working feature looks broken. `xcrun simctl shutdown` + `boot` the watch
  brings the real window back. It also opens on top of the iPhone window, so move
  it and `AXRaise` it before clicking.
- **Locating the `+` for an automated tap.** `xcrun simctl` has no tap command;
  System Events does, if the terminal has Accessibility. The watch screen is
  416×496 device px and the window keeps that aspect, so a coordinate found in a
  `simctl io screenshot` maps onto the window by scale — crop below ~0.7 of the
  height first, or the volt progress bar merges with the volt capsule.
- **The watch icon is a copy of the iOS 1024**, so it goes stale silently after
  `dart run flutter_launcher_icons` changes the art. `test/ios_watch_test.dart`
  compares the two byte for byte — that failure is the reminder to re-copy it.
