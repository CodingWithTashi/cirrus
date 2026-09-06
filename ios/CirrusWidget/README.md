# CirrusWidget — the iOS half

The WidgetKit extension behind the Cirrus home-screen widget: day number on
top, today's count below, `+`/`−` that log a puff while the app is dead. It is
**built, embedded and simulator-verified** (Sep 5 2026, docs/10 §28) — the
same loop Android passed on a Pixel 8 in docs/10 §23, driven on an iPhone 16
Pro simulator (iOS 18.3) by `ios/RunnerUITests`.

The Dart side is platform-agnostic: `WidgetMirror` writes the same JSON the
Android provider reads, `PendingPuffs` drains the same outbox, and
`HomeWidgetStore` declares the App Group before its first write.

## What is in here

| File | What it is |
|---|---|
| `CirrusShared.swift` | The mirror contract — key names, the `CirrusMirror` decoder, and `cirrusToday()`, which folds the mirror plus anything still queued into what the widget draws. The Swift twin of `CirrusWidgetData.kt`. |
| `CirrusOutbox.swift` | The queue a tap appends to, and the pending-count the widget adds on top. Foundation only, no dependencies. |
| `LogPuffIntent.swift` | The iOS-17 `AppIntent` behind the `+`/`−`. `openAppWhenRun = false` is the whole point. |
| `CirrusWidget.swift` | The WidgetKit bundle, timeline provider and SwiftUI views: `systemSmall`, `systemMedium`, and the two lock-screen families Android cannot host at all. |
| `Info.plist` | Extension bundle metadata. Both version keys resolve only via `Generated.xcconfig` — see "The Xcode target". |
| `CirrusWidget.entitlements` | The App Group, and nothing else. |

## The Xcode target is generated, not hand-made

`ios/Runner.xcodeproj` gains the `CirrusWidget` app-extension target from a
script, using the same `xcodeproj` gem CocoaPods edits the project with:

```
/usr/bin/ruby tool/ios_widget_target.rb      # idempotent; no-op once the target exists
```

It creates the target (iOS 16.0, Swift 5.0, bundle id
`com.quitvape.lastPuff.CirrusWidget`, automatic signing on team `PZFFFQ5T9X`),
gives it Debug/Profile/Release all based on **`Flutter/Generated.xcconfig`**
(the only place `FLUTTER_BUILD_NAME`/`FLUTTER_BUILD_NUMBER` exist — unlinked,
the archive uploads and App Store Connect rejects it with `ITMS-90473`),
`SKIP_INSTALL = YES`, links WidgetKit and SwiftUI SDKROOT-relative, adds the
four Swift files to Sources, and gives Runner a target dependency plus an
*Embed Foundation Extensions* copy phase into `PlugIns/`. It deliberately does
**not** touch the Runner scheme: Flutter parses `xcodebuild -showBuildSettings`
last-wins and must only ever see Runner's block.

Why a script: the wizard is thirty seconds of GUI nobody can review, and a
hand-edited pbxproj is thirty UUIDs nobody can verify. `pubspec.yaml` still
prescribes `git checkout ios/Runner.xcodeproj/project.pbxproj` after
`dart run flutter_launcher_icons`; with the target committed that is safe, and
if it ever is not, re-running the script puts it back.

`test/ios_widget_test.dart` pins all of it — the target, its three configs and
their xcconfig link, the embed phase, the entitlements on **both** sides, every
key and field name against the Dart contract, and the Ember hexes against
`lp_colors.dart`. `test/ios_widget_contract_test.dart` goes further on a Mac:
it compiles `CirrusShared.swift` + `CirrusOutbox.swift` with `swiftc` and
round-trips a Dart-built mirror through the real Swift and a Swift-written
outbox through the real Dart decoder (skipped where there is no Xcode).

## Building and running

```
flutter build ios --simulator --debug --dart-define=LP_BACKEND=firebase --dart-define-from-file=.dart_defines.json
ls build/ios/iphonesimulator/Runner.app/PlugIns/          # CirrusWidget.appex
flutter run -d <ios-device> --dart-define=LP_BACKEND=firebase --dart-define-from-file=.dart_defines.json
flutter build ipa                                          # archives from the workspace
```

**The widget only does anything on the Firebase backend.** `widgetCoordinatorProvider`
is `null` on the fake backend by design (a stale outbox draining into the
in-memory demo journey would advance the cursor and lose a real account's
puffs), so `LP_BACKEND=fake` shows an app with a dead widget. That is the same
on Android.

Verifying the container on a simulator:

```
xcrun simctl get_app_container booted com.quitvape.lastPuff groups
xcrun simctl spawn booted defaults read "<container>/Library/Preferences/group.com.quitvape.lastPuff.plist"
```

Read it through `simctl spawn … defaults read`, not `plutil -p` on the file:
the extension writes through the simulator's cfprefsd, and the file on disk
can lag it by seconds — `lp.seq 2` on disk while `lp.seq 3` is the truth.

## The simulator loop, automated

Adding a widget, tapping it and killing the app in between all happen in
Springboard, outside the app's process, where no Flutter test can go. So the
iOS loop is three pieces the Mac side interleaves:

1. **A signed-in journey**, left on the device by an integration entrypoint
   run with `flutter run` (a test run would tear it down):
   ```
   flutter run -d <udid> -t integration_test/j_widget_session_test.dart \
     --dart-define=LP_BACKEND=firebase --dart-define-from-file=.dart_defines.json \
     --dart-define=E2E_EMAIL=e2e-widget-$(date +%s)@cirrus-test.app --no-resident
   ```
   Then reinstall the normal build; `restoreSession` lands on Home. The same
   command with `--dart-define=E2E_STEP=teardown` deletes the account through
   `deleteUserData` when you are done. **Writes to production `alastpuff`.**
2. **`ios/RunnerUITests/CirrusWidgetUITests.swift`**, an XCUITest that drives
   Springboard. Its target and scheme come from `tool/ios_uitests_target.rb`
   (same gem, same idempotence; the Runner scheme is untouched). Build once,
   then run steps one at a time:
   ```
   xcodebuild build-for-testing -workspace ios/Runner.xcworkspace -scheme RunnerUITests \
     -sdk iphonesimulator -destination "id=<udid>" BUILD_DIR="$PWD/build/ios" \
     ONLY_ACTIVE_ARCH=YES ARCHS=arm64
   xcodebuild test-without-building -xctestrun ~/Library/Developer/Xcode/DerivedData/Runner-*/Build/Products/RunnerUITests_*.xctestrun \
     -destination "id=<udid>" -only-testing:RunnerUITests/CirrusWidgetUITests/testAddWidget
   ```
   Steps: `testAddWidget`, `testAddMediumWidget`, `testTapPlus`, `testTapMinus`,
   `testTerminateApp`, `testLaunchApp`, `testDumpWidget`. Springboard puts a
   new widget on whichever page has room, so every step pages until it finds
   the `+` (found by its accessibility label, "Log a puff").
3. **The plist and screenshots** between steps (`xcrun simctl io booted screenshot`).

What Sep 5 2026 proved on iOS 18.3, in this order: the mirror lands in the
group before sign-in (empty card) and after (day 1, 0/190, seven `limits`);
the widget appears in the gallery drawing live numbers; with the app
**terminated**, `+` `+` `−` queue `seq` 1–3 with integral `t` and the widget
reads 1; launching the app drains exactly one puff (Home's Day-1 checklist
ticks "Log your first puff"), `lp.cursor` becomes 3 and the widget still
reads 1; a second launch changes nothing; `−` at 1 queues `seq` 4 and dims
itself at 0; `−` at 0 is disabled, so the tap falls through to opening the
app, and nothing is queued; the medium family draws its bar.

## What only the founder can do

- **Developer portal: done (Sep 5 2026).** App Group
  `group.com.quitvape.lastPuff` exists, and both App IDs —
  `com.quitvape.lastPuff` and `com.quitvape.lastPuff.CirrusWidget` — carry it
  under App Groups (verified in the portal). Xcode's automatic signing
  registered all three by itself: Flutter passes `-allowProvisioningUpdates`
  on every signed build, simulator builds included. If a device build ever
  refuses to sign the host app, check those three rows first — an entitlement
  the profile does not grant fails the app, not just the extension.
- No runtime permission exists on iOS for a widget, and nothing in Firebase
  changes: the extension never touches Firebase or App Check.
- Lock-screen (accessory) families are compiled and rendered by the same
  views, but were not driven on the simulator — Springboard's lock-screen
  editor is not automated here. Add one by hand on a phone before the
  listing claims it.

## Things that will bite

- **`kind` must match in three places** — `CirrusKeys.kind`,
  `HomeWidgetStore.iOSName`, and `reloadTimelines(ofKind:)`. Pinned by the
  Dart tests; a mismatch is completely silent.
- **The extension does not inherit the app's fonts.** These views use the
  system font on purpose. If you ever add Space Grotesk, the TTF must be a
  member of the *extension's* resources and listed in *its* `UIAppFonts` — and
  the failure mode is no crash, just SF Pro everywhere.
- **iOS 16 has no interactive widget.** `Controls` draws nothing there by
  design; the card is a tap into the app instead. Do not "fix" that by drawing
  buttons that cannot act.
- **The widget wears Midnight Ember always.** A WidgetKit view draws itself,
  so it does not follow the system theme the way the Android widget must
  (the launcher inflates that one). Both deviations are documented in
  CLAUDE.md's theming section.
- **`static var` on an `AppIntent` is a Swift 6 error.** `title` is a computed
  property and `openAppWhenRun` a `let` for that reason; keep `SWIFT_VERSION`
  at 5.0 on the target so Xcode's new-target defaults never apply either.
- **Changing the arch set or the `BUILD_DIR` string recompiles every pod.**
  `flutter build ios --simulator` builds both simulator archs, `flutter run
  -d <sim>` builds arm64 only, and a UI-test build passes its own `BUILD_DIR`;
  alternating between them cost three ~18-minute gRPC rebuilds in one session.
  Pick one shape per session — `flutter run -d <udid> --no-resident` for the
  install, `ONLY_ACTIVE_ARCH=YES ARCHS=arm64 BUILD_DIR=$PWD/build/ios` (absolute,
  from the repo root) for the UI tests — and stay with it.
