# CirrusWidget — the iOS half

Everything in this folder is **written but never compiled**. It was authored on
Windows, where no part of it can be built, run or verified. Treat it as a first
draft that has had a careful review, not as working code.

The Dart side is already done and platform-agnostic: `WidgetMirror` writes the
same JSON document the Android provider reads, `PendingPuffs` drains the same
outbox, and `HomeWidgetStore` declares the App Group before its first write. The
moment the target below exists, both work.

## What is in here

| File | What it is |
|---|---|
| `CirrusShared.swift` | The mirror contract — key names, the `CirrusMirror` decoder, and `cirrusToday()`, which folds the mirror plus anything still queued into what the widget draws. The Swift twin of `CirrusWidgetData.kt`. |
| `CirrusOutbox.swift` | The queue a tap appends to, and the pending-count the widget adds on top. Foundation only, no dependencies. |
| `LogPuffIntent.swift` | The iOS-17 `AppIntent` behind the `+`/`−`. `openAppWhenRun = false` is the whole point. |
| `CirrusWidget.swift` | The WidgetKit bundle, timeline provider and SwiftUI views: `systemSmall`, `systemMedium`, and the two lock-screen families Android cannot host at all. |
| `Info.plist` | Extension bundle metadata. Both version keys resolve only via `Generated.xcconfig` — see step 7. |
| `CirrusWidget.entitlements` | The App Group, and nothing else. |

## Expect it not to compile first time

It has never been through a Swift compiler. Assume a first pass of ordinary
build errors — a wrong API spelling, a `some View` inference complaint, an
availability annotation in the wrong place. That is expected and cheap to fix;
what has been reasoned about carefully is the *logic*, not the syntax.

Two things worth knowing while you triage:

- **`CirrusShared.swift` and `CirrusOutbox.swift` are the ones that matter.** If
  the views need reshaping to satisfy the compiler that is cosmetic, but those
  two files are the wire contract, and any change to a key name or a field type
  there has to match `lib/data/stores/pending_puffs.dart`,
  `lib/data/stores/widget_mirror.dart` and the Kotlin. There is no test on the
  Swift side to catch drift — `test/android_widget_test.dart` pins Dart against
  Kotlin only.
- **`@main` lives on `CirrusWidgetBundle`** at the bottom of `CirrusWidget.swift`.
  Xcode's own template also generates an `@main`; delete the template's, or the
  build fails with two entry points.

## Three bugs a code review already caught here

Fixed in the files as they stand, and listed because each would have been
invisible until a user hit it:

1. **`"t"` was written as a `Double`.** `timeIntervalSince1970 * 1000` produces
   a fractional JSON number and the Dart decoder reads epoch millis, so every
   iOS-queued puff would have been silently dropped — and worse than dropped: a
   rejected event never advances the cursor, so it stays "pending" for ever,
   keeps inflating the count the widget draws, and eventually fills the queue
   until every further tap is refused. Now `Int(...)`, and the Dart side accepts
   any `num` as a second line of defence.
2. **The day number was derived from an epoch instant.** Local midnight east of
   Greenwich falls on the previous UTC date, so the arithmetic was a day out for
   roughly half the world. The mirror now ships `planStartDayKey` as
   `yyyy-MM-dd` and `epochDay(fromDayKey:)` parses it with `Calendar`.
3. **Over-limit could never show once the limit reached 0.** `JourneyState.limitOn`
   returns 0 on the last plan day and every maintenance day after it, so a
   `limit > 0` guard meant a calm card and a full progress bar on exactly the
   days one puff puts someone over. The guard is gone; `over` is a bare
   `count > limit`, matching the app.

## What Xcode has to do that a file edit cannot

`project.pbxproj` is deliberately **not** edited. Two reasons, and the second is
specific to this repo:

1. A malformed one gives *"The project 'Runner' is damaged and cannot be
   opened"*, which names no line and blocks every iOS build until it is
   reverted.
2. `pubspec.yaml` already documents that `dart run flutter_launcher_icons`
   rewrites this exact file, and the prescribed recovery is
   `git checkout ios/Runner.xcodeproj/project.pbxproj`. That command would
   silently delete a hand-added target. A target Xcode created is re-added by
   the wizard in thirty seconds; a hand-edit means re-deriving thirty UUIDs.

## The order matters

**Steps 1–2 must happen before step 5 lands on any machine that builds.** An
entitlements file claiming an App Group the provisioning profile does not grant
fails to code-sign — and it fails the **host app**, not just the extension. The
next iOS build breaks for a reason unrelated to whatever you were doing.

1. **Developer portal → Identifiers → App Groups.** Create
   `group.com.quitvape.lastPuff`.
2. **Developer portal → Identifiers → App IDs.**
   - `com.quitvape.lastPuff` — enable App Groups, tick the group.
   - Create `com.quitvape.lastPuff.CirrusWidget` — enable App Groups, tick the
     same group. (An extension's bundle id must be prefixed by the host app's.)
3. **Open `Runner.xcworkspace`** — never `Runner.xcodeproj`. File → New →
   Target → iOS → **Widget Extension**. Product Name `CirrusWidget`. Uncheck
   *Include Configuration App Intent* and *Include Live Activity*. Embed in
   Application: **Runner**. Decline "Activate scheme?".
4. **Delete Xcode's generated stubs**, then drag in the four `.swift` files,
   `Info.plist` and `CirrusWidget.entitlements` from this folder. *Create
   groups*, not folder references. Target membership: **CirrusWidgetExtension
   only**, never Runner.
5. **Add the App Group to the host app.** In `ios/Runner/Runner.entitlements`,
   alongside the existing `applesignin` and `appattest-environment` keys:

   ```xml
   <key>com.apple.security.application-groups</key>
   <array>
       <string>group.com.quitvape.lastPuff</string>
   </array>
   ```

   Then Signing & Capabilities → **+ Capability → App Groups** on *both*
   targets, and confirm Xcode regenerates both provisioning profiles.
6. **Duplicate `Release` → `Profile`** for the new target (Project → Info →
   Configurations). Xcode creates only Debug and Release; Flutter needs all
   three, and without it `flutter run --profile` fails with *"The Xcode project
   does not define custom schemes"*.
7. **Set the extension's base configuration to `Flutter/Generated.xcconfig`**
   on all three configurations. `FLUTTER_BUILD_NAME` and `FLUTTER_BUILD_NUMBER`
   are defined nowhere else, and `Info.plist` here references both. Left
   unresolved, the archive succeeds, the upload finishes, and App Store Connect
   rejects it with `ITMS-90473: CFBundleVersion Mismatch`.
8. Set `SKIP_INSTALL = YES` on the extension (Xcode usually does). Without it
   archive validation fails with *"Found an unexpected .appex at the top
   level."*
9. `flutter pub get && cd ios && pod install`.
10. `flutter build ipa` — it runs `pod install` and drives the workspace itself.
    If you archive from Xcode instead, check the title bar says
    **Runner.xcworkspace**; the failure signature for the other one is
    `GeneratedPluginRegistrant.m:12:9 Module 'amplitude_flutter' not found`,
    which names the wrong thing entirely.

## Verifying it actually works

```bash
# the App Group container really is shared
xcrun simctl get_app_container booted com.quitvape.lastPuff groups
plutil -p "<container>/Library/Preferences/group.com.quitvape.lastPuff.plist"
# lp.mirror must be there. If the plist is missing entirely, the group id
# does not match between Runner.entitlements, the extension's, and Dart.

# the extension is embedded and signed with the group
ls build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/PlugIns/
codesign -d --entitlements :- \
  build/ios/archive/.../Runner.app/PlugIns/CirrusWidget.appex \
  | grep -A2 application-groups
```

An empty `PlugIns/` is the missing-embed-phase failure — the app builds and
runs perfectly and the widget never appears in the gallery, with no error
anywhere. Catch it here rather than in App Store Connect.

Then, on a device: add the widget, force the app closed, tap `+`, reopen, and
confirm Home moved by exactly one. That is the same loop verified on Android in
`docs/10 §23`.

## Things that will bite

- **`kind` must match in three places** — `CirrusKeys.kind` here,
  `HomeWidgetStore.iOSName` in Dart, and the `reloadTimelines(ofKind:)` call.
  `test/android_widget_test.dart` pins the first two; the third is in
  `LogPuffIntent.swift`. A mismatch is completely silent.
- **The extension does not inherit the app's fonts.** These views use the
  system font on purpose. If you ever add Space Grotesk, the TTF must be a
  member of the *extension's* resources and listed in *its* `UIAppFonts` — and
  the failure mode is no crash, just SF Pro everywhere.
- **iOS 16 has no interactive widget.** `Controls` draws nothing there by
  design; the card is a link into the app instead. Do not "fix" that by drawing
  buttons that cannot act.
