# Evidence: the A2UI dependency gate (plan task U1)

Wednesday Nov 25 2026, 18:32 to 19:22 EST, on the founder's Mac: macOS 27.2.1, Xcode 27.2 (27B52), Flutter 3.50.0
(Dart 3.14.0), Android Gradle Plugin 9.3.1, Gradle 9.6.0, Kotlin 2.4.20. Plan:
`docs/superpowers/plans/2026-11-25-coach-cards.md`, task U1.

The question: `a2ui_flutter` 0.5.0 force-depends on the native `video_player` plugin. Does the real app still build
on Android and on iOS with it, and what does it cost in size?

This file states what was run and what came out. It makes no recommendation.

## Results

| Check | Result |
|---|---|
| `flutter pub get` with the three exact pins | **Resolved.** 13 packages added, none changed, none removed |
| Android release APK, before the dependency | **Built.** 29,536,564 bytes |
| Android release APK, after the dependency | **Built.** 30,196,297 bytes |
| Size difference, as the repo stands (nothing imports the packages) | **+659,733 bytes: +0.66 MB (0.63 MiB), +2.23%** |
| iOS simulator build in the repo, watch app included | **Built** (exit 0, 6 min 16 s) |
| iOS build without the watch app, in a scratch copy | **Not run**: it was the fallback for a failed in-repo build, and the in-repo build did not fail |
| `flutter test`, whole suite, after all of the above | **2,895 passed, 0 failed** |
| `flutter analyze` | **No issues found** |

The +0.66 MB is the native half only. The Dart half is zero today because nothing in `lib/` imports the packages
yet, so the compiler drops them. See "The Dart half" below for what it becomes once something does.

## What was added

`pubspec.yaml`, under `dependencies`, no caret:

```yaml
  a2ui_flutter: 0.5.0
  a2ui_core: 0.9.0
  json_schema_builder: 0.1.7
```

`pubspec.lock` went from 155 packages to 168. Added:

| Package | Version | Kind |
|---|---|---|
| a2ui_flutter | 0.5.0 | direct |
| a2ui_core | 0.9.0 | direct |
| json_schema_builder | 0.1.7 | direct |
| video_player | 2.14.1 | transitive |
| video_player_android | 2.13.0 | transitive |
| video_player_avfoundation | 2.12.5 | transitive |
| video_player_platform_interface | 6.9.0 | transitive |
| video_player_web | 2.4.0 | transitive |
| preact_signals | 7.0.0 | transitive |
| path_parsing | 1.1.0 | transitive |
| decimal | 3.2.7 | transitive |
| rational | 2.2.3 | transitive |
| email_validator | 3.0.0 | transitive |

No existing package changed version: the lockfile diff is 104 added lines and no removed line.

## Android

The command, run twice in the repo, once before `pubspec.yaml` was touched and once after `flutter pub get`:

```
flutter build apk --release --target-platform android-arm64 --analyze-size
```

| | APK file | Flutter's "Built" line | `--analyze-size` total | Gradle time |
|---|---|---|---|---|
| Before | 29,536,564 bytes | 29.5MB | 28 MB | 200.8 s |
| After | 30,196,297 bytes | 30.2MB | 29 MB | 463.3 s |
| Difference | +659,733 bytes | +0.7MB | | |

Neither APK was installed on anything. A sideloaded release APK cannot pass App Check; these were for size only.

### What grew

Read from the two APKs entry by entry (compressed size inside the APK). Both hold 1,528 entries.

| Entry | Before | After | Difference |
|---|---|---|---|
| `classes.dex` | 4,033,152 | 4,691,188 | **+658,036** |
| `resources.arsc` | 415,316 | 418,448 | +3,132 |
| `assets/dexopt/baseline.prof` and `.profm` | 6,164 | 7,705 | +1,541 |
| `assets/flutter_assets/NOTICES.Z` | 117,286 | 118,523 | +1,237 |
| `classes2.dex` | 82,137 | 82,128 | -9 |
| `META-INF/services/*` (8 entries renamed by R8) | | | +1 |
| every `.so` under `lib/` | | | 0 |

- **All of it is dex.** `classes.dex` is 1,175,660 bytes larger uncompressed (8,785,960 to 9,961,620). The new
  classes are `androidx.media3` (ExoPlayer with its DASH, HLS, RTSP and SmoothStreaming sources) and
  `io.flutter.plugins.videoplayer`: the "before" dex holds no string naming either, the "after" dex does.
  `video_player_android` 2.13.0 declares media3 1.9.2 (`media3-exoplayer`, `-hls`, `-dash`, `-rtsp`,
  `-smoothstreaming`).
- **No native library was added.** The same eight `.so` entries at the same sizes. `libflutter.so` is 11,346,352
  bytes in both.
- **`libapp.so` (the Dart code) is 11,142,104 bytes in both**, with different contents. In the `--analyze-size`
  breakdown no A2UI package appears in either build. The "after" build holds about 1.1 KB of video_player Dart
  (`video_player_android` 644 bytes, `video_player_platform_interface` 447): the plugin registering itself.

## The Dart half (an estimate, from a scratch copy)

Not part of the plan's steps. The in-repo number cannot include Dart code, because the plan adds no import in U1.
To see what the import costs, the source was copied to a scratch folder outside the repo (no secrets, debug
signing), one probe file was added there that keeps the A2UI code reachable from `main()`, and the same Android
command was run. The scratch copy is deleted. Nothing in the repo imports the packages.

| Build | APK file | Against "before" |
|---|---|---|
| Before the dependency | 29,536,564 | |
| After, as the repo stands | 30,196,297 | +0.66 MB, +2.23% |
| Probe A: `MessageProcessor` + a one-component catalog of our own + `A2uiSurface` | 30,851,657 | **+1.32 MB (1.25 MiB), +4.45%** |
| Probe B: probe A plus the package's own `basicCatalog()` | 32,755,857 | **+3.22 MB (3.07 MiB), +10.90%** |

- Probe A changed one entry against the in-repo "after" APK: `libapp.so`, +655,360 bytes. By package in
  `--analyze-size`: `a2ui_core` 447,688, `json_schema_builder` 63,312, `preact_signals` 11,908, `a2ui_flutter`
  10,721, `email_validator` 8,804, `decimal` 5,729, the video_player packages about 1,100.
- Probe B changed two: `libapp.so`, +2,555,904 bytes, and the icon font, +3,655. The largest single mover is
  `package:flutter`, 2,240,319 to 3,337,759: the package's basic components are written against
  `package:flutter/material.dart`, which is a second copy of Material beside the app's `material_ui`. `a2ui_core`
  is 571,540, `a2ui_flutter` 90,883, `video_player_android` 49,515, `video_player` 20,037.
- These are probes, not U2. Probe A is the smallest use that renders a surface; the real surface adds its own
  widgets on top. Probe B makes every basic component reachable. Where U2 lands depends on whether it references
  anything from `package:a2ui_flutter/basic_catalog.dart`.

## iOS

### In the repo, as the plan writes it

```
flutter build ios --simulator --no-codesign -d 50D3E519-6362-413B-B080-3F265843CB5C
```

(iPhone 17, iOS 27.2.) **Exit 0**, `✓ Built build/ios/iphonesimulator/Runner.app`, 6 min 16 s in all: Swift
Package Manager integration 87.1 s, `pod install` 0.9 s, Xcode build 251.7 s. This is a Debug simulator build.

Checked in the built app:

- `Runner.app/Watch/CirrusWatch.app` is there (x86_64 and arm64), and `PlugIns/CirrusWidget.appex`. The watch app
  was built, not skipped.
- `video_player_avfoundation_video_player_avfoundation.bundle` is in `Runner.app`, `Runner.debug.dylib` holds the
  `video_player_avfoundation.VideoPlayerPlugin` symbols, and the generated registrant registers
  `VideoPlayerPlugin`.

No watchOS simulator runtime is installed on this Mac (`xcrun simctl list runtimes` lists iOS only). The build did
not need one: Xcode 27.2 carries the watchOS 27.2 and watchOS Simulator 27.2 SDKs (`xcodebuild -showsdks`), and a
runtime is what running on a simulator needs.

### What that build rewrote under `ios/`

`ios/` was identical to HEAD before it. `git status --short ios` after:

```
 M ios/Podfile.lock
 M ios/Runner.xcodeproj/project.pbxproj
 M ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
?? ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/
?? ios/Runner.xcworkspace/xcshareddata/swiftpm/
```

- `Podfile.lock`: 1,756 lines to 16. Only the `Flutter` pod is left; every plugin is a Swift package now.
- `project.pbxproj` (24 lines added, 44 removed): adds the local package `FlutterGeneratedPluginSwiftPackage`
  (reference, product dependency, a Frameworks entry); removes Runner's `[CP] Embed Pods Frameworks` and
  `[CP] Copy Pods Resources` phases.
- `Runner.xcscheme` (18 lines added): a build pre-action, "Run Prepare Flutter Framework Script".
- Two new, identical `Package.resolved` files, 22 pins (Firebase 13.1.1, GoogleSignIn 10.1.0, RevenueCat 5.103.0
  and their dependencies). None is for video_player: `video_player_avfoundation` is a local package with no
  remote dependency.

None of the rewritten content names video_player or A2UI. It is the CocoaPods-to-SwiftPM migration that
`CLAUDE.md` says the first iOS build on Flutter 3.50 performs. That it would have happened without the new
dependency is an inference: iOS was not built at HEAD's `pubspec.yaml` to compare.

Nothing under `ios/` was edited by hand. The full `flutter test` run was made after this rewrite and passed, and
the five suites that read `ios/` (`ios_widget_test`, `ios_watch_test`, `ios_push_test` and the two contract tests)
were run again by name with the two Android source tests and `test/app`: 184 passed.

### Without the watch app, in a scratch copy

Not run. It was planned for the case where the in-repo build failed on the missing watch platform, and it did
not fail.

## Other files the commands regenerated

- `flutter pub get` rewrote the seven files under `lib/l10n/gen/`. Their diff against HEAD is byte for byte what
  it was before (compared with the Stage 0 patch).
- Ignored, derived: `.dart_tool/`, `.flutter-plugins-dependencies`, `ios/Flutter/Generated.xcconfig`,
  `ios/Flutter/flutter_export_environment.sh`, `ios/Flutter/Flutter.podspec`, `ios/Flutter/ephemeral/`,
  `ios/Pods/`, `ios/Runner/GeneratedPluginRegistrant.m`,
  `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`, `build/`.
- Outside the repo: `--analyze-size` wrote `~/.flutter-devtools/apk-code-size-analysis_01.json` (before), `_02`
  (after), `_03` (probe A) and `_04` (probe B), 13.7 MB each.

## Not proven

- **Nothing ran.** No APK or app was installed or launched, on a device or a simulator. That the app starts with
  `VideoPlayerPlugin` registered on either platform is untested.
- **No iOS device, release or archive build.** Only the Debug simulator build. `flutter build ipa` was not run,
  and no iOS size was measured.
- **No App Bundle.** The number is for one arm64 release APK. What Play serves (an `.aab`, split and compressed)
  was not built or measured.
- **The real Dart cost.** The two probes bracket it; U2's own number does not exist until U2 does.
- **CI.** The release workflow was not run with the new lockfile or the rewritten `ios/`.
- **That the `ios/` rewrite is independent of the dependency** (see above).

## Notes

- `android/app/build.gradle.kts` was changed in the working tree at 18:46:29, 18 seconds after the "after" APK
  build ended, and not by this task: the brace closing `compileOptions { … }` is gone. Both in-repo APK builds
  finished before that. The Android command above will not run in the repo again until the brace is back. The
  probes used HEAD's copy of the file.
- Disk: free space went from 32 GiB to 13 GiB over the session. Part of that is these builds (`build/` grew from
  2.5 GB to 6.1 GB, the Gradle caches and Xcode's DerivedData grew too), and part is another build that was
  running on the Mac for a different project at the same time.

## Logs

Under `.superpowers/sdd/2026-11-25-coach-cards/`:

| File | What it is |
|---|---|
| `laneU-apk-before.log` | The Android build and its `--analyze-size` report, before the dependency |
| `laneU-pub-get.log` | `flutter pub get` with the three pins |
| `laneU-apk-after.log` | The same Android build, after |
| `laneU-ios-inrepo.log` | The iOS simulator build in the repo |
| `laneU-dartsize-A.log`, `laneU-dartsize-B.log` | The two scratch probes |
| `laneU-seam-red.log`, `laneU-seam-red-folder.log`, `laneU-seam-green.log` | `test/app/a2ui_seam_test.dart` failing on the missing pins, failing on a planted import, and passing |
| `laneU-flutter-test.log`, `laneU-analyze.log` | The full suite and the analyzer, after the builds |
| `laneU-flutter-test-final.log`, `laneU-analyze-final.log` | Both again at the end, after a wording change to the `pubspec.yaml` comment and one test message: 2,895 passed, no issues |
| `laneU-ios-android-source-tests.log` | The suites that read `ios/` and `android/`, by name |

---

# Evidence: on the iPhone simulator, fake backend (plan task P1, the simulator half)

Wednesday Nov 25 2026, 20:33 to 21:10 and 21:18 to 21:32 EST, on the founder's Mac. iPhone 17 simulator, iOS 27.2
(`50D3E519-6362-413B-B080-3F265843CB5C`), Flutter 3.50.0, Xcode 27.2, a Debug build with the watch app,
`--dart-define=LP_BACKEND=fake`. Nothing here touched production, App Check or the Pixel, and no app code was
changed.

The question: the coach cards and the exercise registry had passed every unit and widget test and had never run
on a device or a simulator. Do they work on one?

This section states what was run and what came out. It makes no recommendation.

## Results

`flutter test integration_test/u_coach_cards_test.dart -d 50D3E519-6362-413B-B080-3F265843CB5C --dart-define=LP_BACKEND=fake -r expanded`,
run twice, the same outcome both times. Result line of the second run: **`07:47 +6 -1: Some tests failed.`**
The six cases the plan and its amendments ask for passed. The one failure is a seventh case this task added.

| # | Case | Run 1 | Run 2 |
|---|---|---|---|
| 1 | a card opens breathing and back returns to the chat | passed | passed |
| 2 | a game from the chat ends back in the chat | passed | passed |
| 3 | a craving handed over continues | passed | passed |
| 4 | a free account sees none | passed | passed |
| 5 | saying it passed in the chat counts the craving (A2) | passed | passed |
| 6 | the reply stays readable above three cards | passed | passed |
| 7 | the same, laid out in a 360 by 640 view (a probe, not in the plan) | **failed** | **failed** |

The Xcode build took 60.6 s on a warm `build/ios`; the seven cases take 7 min 47 s. Every line quoted here is in
`simulator/results.txt`, copied from the logs.

## What each case read off the simulator

1. **Three cards, each one touchable.** The craving chip's reply carried breathing, Orbs and SOS, in that order.
   A hit test through the binding at each card's centre, (181, 316), (181, 420) and (181, 530), reached the card:
   nothing was drawn over any of them and none was past the thread's edge. The breathing card opened
   `/panic/exercise/breathing?src=coach` with the ring; the screen's chevron returned to `/coach` with the reply and
   all three cards still there. `coach_ui_shown` was recorded once (`launchers: 3, panic: false`) and not again on
   the way back, `coach_ui_dropped` never, `exercise_opened` once, `exercise_finished` once with `passed: false`,
   and no `craving_outcome`.
2. **A game from the chat ends in the chat.** The Orbs card opened `/panic/game?g=orbs&src=coach`. After a real
   60-second round, "It passed" led to the Survived screen, which said "Back to the chat" and not "Back to today";
   that button landed on `/coach` with no `panic` query. `cravingsSurvivedTotal` went from 23 to 24. One `begin()`,
   one `survived` call (no strength, `orbs`, `coach`), one `craving_outcome`.
3. **A craving handed over continues.** Home's SOS, to the loop at 8 out of 10, then "Talk to coach": the app went
   to `/coach?panic=8` and reported nothing about the craving. A typed message got exactly one card (breathing),
   with `coach_ui_shown` `launchers: 1, panic: true`. With the keyboard up (328 points) that card could still be
   touched. Tapping it opened the ring, and `panicProvider` held the `startedAt` noted on the loop screen and
   strength 8, with `begin()` still called once. "It passed" there reported one `survived` with strength 8,
   `breathing`, `coach`, and the count rose by one.
4. **A free account sees none.** With the subscription row expired the same chip got a reply and no card; the
   surface under the reply measured zero height, and neither `coach_ui_shown` nor `coach_ui_dropped` was recorded.
5. **"It passed" said in the chat counts the craving.** Back from the breathing exercise without having said it
   passed, the chip row led with "It passed" and "Still strong". Tapping "It passed" raised the count by one,
   reported one `survived` (`breathing`, `coach`) and one `craving_outcome`, put the words in the composer and
   sent nothing (the thread and `coach_message_sent` were unchanged). A second tap changed nothing.
6. **The reply above three cards, on this simulator: on screen.** See the next section.

Analytics and the panic repository were replaced by recording stand-ins for these runs, because analytics reports
from release builds only and the fake backend's panic repository does not count its calls. Neither draws anything.

## Where the reply sits above its cards

The thread scrolls to its end when a reply lands, and the cards come after the words. Measured in logical pixels:

| | View | Thread | Reply's words | Three cards | Result |
|---|---|---|---|---|---|
| iPhone 17 simulator | 402 × 874 | 122 to 605 (483 tall) | 160 to 244 (4 lines, 84) | 270 to 581 (311) | all of the words on screen |
| A 360 × 640 view (probe) | 360 × 640 | 84 to 405 (321 tall) | −62 to 44 (5 lines, 105) | 70 to 381 (311) | **none of the words on screen** |

- **On the iPhone 17 the reply's words were fully on screen above the three cards** (case 6, both runs:
  `hiddenAbove=0 centre=true firstLine=true lastLine=true`). The thread had scrolled 220 points to do it: the
  person's own "I'm craving" bubble is cut off at the top, and the reply's bubble starts about 23 points below the
  thread's top edge. `simulator/14_reply_above_cards.png`.
- **In a 360 × 640 view the reply's words were entirely above the top of the thread** (case 7, both runs): the
  three cards and the space under them take 335 of the thread's 321 points, so the first card's top edge is
  clipped by 14 points and the lowest line of the reply ends 40 points above the thread. All three cards could
  still be touched. `simulator/15_small_view_reply_above_cards.png`.

What case 7 is and is not. It lays the real app out in a view the test declares to be 360 × 640 with a 24-point
status bar and no bottom inset, using the simulator's real text engine and the app's bundled fonts. It is not a
small phone: the simulator's screen does not show a view whose size was changed under it, so its picture is the
app's own layer tree painted to a PNG, not a screenshot of a device, and it has no status bar in it. The numbers
are layout numbers and are real; nothing else about a small phone was simulated.

## The neighbouring suites

Same simulator, same define, one file at a time.

| Suite | Result line |
|---|---|
| `h_panic_games_test.dart` | `04:12 +2: All tests passed!` |
| `j_craving_and_quiet_hours_test.dart` | `01:49 +2: All tests passed!` |
| `i_monetisation_test.dart` | `08:53 +11: All tests passed!` (run at 21:18, once the disk had room again) |
| `d_social_test.dart` | **not run** |
| `g_day1_tour_test.dart` | **not run** |

The last two were not run, and the third was run late, because of the disk, not because of anything in them. The task's rule was to start no
build with less than 6 GB free. Free space on the data volume was 14 GB before the simulator was booted and 5.6
to 6.6 GB in the minutes after (six 1 GB swap files were created between 20:24 and 20:30, and 17 were in use for
the rest of the session; what else on the Mac was using memory then was not looked into). It read 5,760 MB,
5,974 MB and 5,972 MB at 21:09 to 21:10, so the runner refused to start `i_monetisation` twice and the task
stopped there. At 21:18 it read 12,542 MB and `i_monetisation` ran and passed; when it ended at 21:31 the reading
was 4,065 MB (5,119 MB after the simulator was shut down), with another `flutter test` running elsewhere on the
Mac, so `d_social` and `g_day1_tour` were not started. Nothing was deleted to make room. The runs made here did not use the space up: free
space read between 6,058 and 6,520 MB at the start of each and within 310 MB of that at its end.

## Screenshots

All under `simulator/`, from the second run. 1206 × 2622 except the last.

| File | What it shows |
|---|---|
| `01_menu_three_cards.png` | The reply to the craving chip with Breathe with me, Orbs and Ask the community under it |
| `02_breathing_from_chat.png` | The breathing exercise opened from the card: chevron, ring, "How bad is it now?", "It passed" |
| `03_back_in_chat.png` | Back in the thread: the same reply and cards, and the chip row now led by "It passed" and "Still strong" |
| `04_orbs_from_chat.png` | The arena opened on Orbs from the card, four seconds into the round |
| `05_survived_back_to_chat.png` | The Survived screen after that round: 24, "0 orbs", the rating card, and the button "Back to the chat" |
| `06_chat_after_game.png` | The coach tab again after that button: the thread and its cards, the four ordinary chips, no "It passed" chip |
| `07_loop_before_handover.png` | The takeover's third step, 13 seconds into the craving, before "Talk to coach" |
| `08_chat_one_card.png` | The chat after the hand-over with the keyboard up: the typed message, a reply, and one card (breathing) |
| `09_breathing_same_craving.png` | The breathing exercise opened from that one card (the keyboard is gone) |
| `10_survived_after_handover.png` | The Survived screen for the handed-over craving: 24 and "Back to the chat" |
| `11_free_account_no_cards.png` | A free account's thread after the craving chip: the reply and no card, no gap |
| `12_back_with_lead_chips.png` | Back from breathing without "it passed": the two lead chips |
| `13_it_passed_in_chat.png` | After tapping the "It passed" chip: the words in the composer, nothing sent |
| `14_reply_above_cards.png` | Case 6: the reply's four lines fully on screen above three cards on the iPhone 17 |
| `15_small_view_reply_above_cards.png` | Case 7: the 360 × 640 layout (1080 × 1920, the app's own layer tree): three cards and no words |

## Not proven

- **Anything on Android.** The Pixel was not used. In particular the system Back key in case 1 has never run: on
  the simulator the way back is the screen's chevron. The Android branch of that case waits for an adb driver to
  press Back and was written, not executed.
- **`d_social` and `g_day1_tour` on the simulator** (above).
- **A real small phone.** Case 7 is a layout in a declared view. No device or simulator with a small screen was run.
- **A reply longer than the fake's.** Each of the fake backend's three craving replies was 4 lines on the
  iPhone 17 (25 to 32 words); one of them was 5 lines in the 360-wide view. What a longer reply does was not
  run.
- **The real backend.** No model reply, no card decided by `planBlocks`, no App Check (plan task P2).
- **An iPhone.** A simulator only: no haptics, no physical keyboard behaviour, no release build.

## Logs

Under `.superpowers/sdd/2026-11-25-coach-cards/`:

| File | What it is |
|---|---|
| `laneP-u-coach-cards-run1.log` | The first full run of the new suite: six passed; case 7 failed inside its own measurement (see the note below) |
| `laneP-u-coach-cards-probe1.log`, `laneP-u-coach-cards-probe2.log` | Case 7 alone, twice, while its measurement was being corrected |
| `laneP-u-coach-cards-run2.log` | The second full run, with the suite as it now stands: the screenshots are from this one |
| `laneP-h-panic-games.log`, `laneP-j-craving-quiet-hours.log` | The two neighbouring suites that ran |
| `laneP-i-monetisation-refused-2109.log`, `laneP-i-monetisation-refused-2110.log` | The two refused starts: one line each, the free space read |
| `laneP-i-monetisation.log` | The run that passed, at 21:18 |

A note on run 1's failure. Case 7 failed in both runs, for different reasons. In run 1 the test itself was wrong:
it required the reply's text to be found before measuring it, and a finder does not see a list's children that
are wholly outside its viewport, so it stopped with "found 0 widgets" before it had measured or pictured
anything. The measurement was changed to look off-stage and to treat missing words as a result. In run 2 it
failed on what it measures.

---

# On the Pixel 8, fake backend: the first attempt, refused (superseded below)

**This section is history. The suites did run on the phone later the same evening, from the coordinating
session: see "On the Pixel 8, fake backend" further down for the results.**

Wednesday Nov 25 2026, 21:13 to 21:18 EST. Nothing was installed on, removed from or run on the phone in this
attempt.

The run was prepared and then refused before it started: the command that would have run
`integration_test/u_coach_cards_test.dart` on the phone was denied by Claude Code's permission system
("Destructive or Unwanted Actions"). An integration run installs a debug build over the Cirrus on the phone and
uninstalls it when it ends, which loses that app's data and session. The denial was not worked around, and no
Android emulator exists on this Mac to use instead (`emulator -list-avds` lists none).

What was done to the phone, and undone: `screen_off_timeout` was raised from 60000 to 1800000 at 21:16 and put
back to 60000 at 21:18 (`laneP-pixel-keepawake.log`). Nothing else was changed.

The phone as read afterwards, over adb, read-only:

| | |
|---|---|
| Cirrus | still installed: `versionName=1.0.36`, last updated Nov 21, `base.apk` sha256 `e609f2f4…35a0`, the same as the backup in `~/Downloads/pixel_cirrus_1.0.36_backup/` |
| `screen_off_timeout` | 60000 |
| Do Not Disturb | on (`zen_mode=1`), untouched |
| Lock | unlocked (`isKeyguardShowing=false`) at 21:18 |
| Battery | 65%, not on power |

Not proven at that point (since run, see below): everything on Android. The six suites on the phone, the system Back key in case 1 of
`u_coach_cards` (written, never executed), and where the reply sits above three cards on this phone. No release
APK was built for a size figure in this round.

## Release APK size with the final code (Nov 25 2026, 21:52 EST)

Same command as U1's two measurements, run in the repo after every lane, the
scroll change and the review fixes were merged:
`flutter build apk --release --target-platform android-arm64 --analyze-size`.
The APK was not installed anywhere.

| Build | APK bytes | Against "before" |
|---|---|---|
| Before the a2ui pins (U1) | 29,536,564 | |
| After the pins, no surface code (U1) | 30,196,297 | +659,733 (+2.2%) |
| Final code | 30,982,729 | +1,446,165 (+1.45 MB, +4.9%) |

The final figure also contains the app code lanes U and X added after U1's
"before" build (the card surface, the chat changes, `surviveParked`), so it is
an upper bound on what the dependency itself costs. It sits beside U1's
probe A estimate (+1.32 MB, own catalog only) and well under probe B (+3.22 MB,
with the package's basic catalog). Nothing under `lib/` references that
catalog; `test/app/a2ui_seam_test.dart` fails if anything does.

Not measured: an App Bundle (Play's real download size) and any iOS size.

## On the Pixel 8, fake backend (Nov 25 2026, 21:53–22:09 EST)

Run from the coordinating session on the final code (after the scroll change
and the review fixes were merged), one file at a time, with an adb driver for
the system Back key and the screenshots. Pixel 8, Android 17, wireless adb.

| Suite | Result line |
|---|---|
| `u_coach_cards_test.dart` | `07:56 +6 -1: Some tests failed.` |
| `h_panic_games_test.dart` | `04:14 +2: All tests passed!` |
| `j_craving_and_quiet_hours_test.dart` | not run (the Mac's free disk fell to 4.3 GB, under the runner's floor) |
| `i_monetisation_test.dart` | not run on the Pixel |
| `d_social_test.dart` | not run on any device |
| `g_day1_tour_test.dart` | not run on any device |

`u_coach_cards`: the six planned cases pass, including case 1's system Back
key (pressed by the driver at 21:56:24; the thread and its cards came back).
The seventh case, the 360×640 view, is the one that failed, and on a stale
assertion rather than on the app. With the scroll change the reply is fully on
screen in that view:

```
view=360x640 thread=84..405 (321) reply=99..204 (105) hiddenAbove=0 cards=3 230..541 (311) firstLine=true lastLine=true
view-360x640 cards reachable: [true, true, false]
```

Before the change the same measurement on the simulator had the reply at
−62..44. The case still asked for all three cards to be touchable WITHOUT
scrolling, which is the layout the founder's decision replaced; the third card
now rests under the fold. The assertion was updated afterwards (first card
touchable, last card reachable after a scroll) and **has not been re-run on a
device**. At the phone's own size (411×914) everything fits: thread 110..669,
reply 224..308, cards 334..645.

Screenshots are in `pixel/u_coach_cards/` (01–14 from the phone's screen, 15
from the app's layer tree for the 360×640 view), marker lines in
`pixel/u_coach_cards-markers.txt`, the run summary in `pixel/summary.txt`.

Afterwards the backed-up build was reinstalled (`adb install -r` → Success,
`versionName=1.0.36`); its data and session were lost, as expected. Battery
62% → 59%.

## On the Pixel 8, later rounds (Nov 25 2026, 22:14–22:46 EST)

Same phone, same code, same runner, one file at a time from the coordinating
session. For the third round the runner's starting floor was lowered from 6 GB
to 3 GB because the debug build folder was warm; its stop-under-2-GB guard was
unchanged. Cirrus 1.0.36 was reinstalled after every round.

| Suite | Result line |
|---|---|
| `j_craving_and_quiet_hours_test.dart` | `01:52 +2: All tests passed!` |
| `g_day1_tour_test.dart` | `03:01 +8: All tests passed!` |
| `u_coach_cards_test.dart`, the 360×640 case alone, rewritten assertion | `00:55 +1: All tests passed!` |
| `i_monetisation_test.dart` | `08:40 +11: All tests passed!` |
| `d_social_test.dart` | `05:29 +7`, then "did not complete" |

The small-view case read `reply=99..204` in `thread=84..405`, `cards reachable:
[true, true, false]`, then `last card after a scroll: true`.

`d_social`: seven cases passed. The run then ended during 'a reply I send is
scrolled into view, however long the thread', with no failure text; that case
and the two coach cases after it have no result. The adb serial the run
started on was gone at its end, which points at the wireless link dropping.
That is an inference, not something the log states. A re-run was refused for
disk (2,719 MB free at 22:45).

Still without a device result on the final code: those three `d_social` cases,
and `u_coach_cards` run whole (its last full line is the `+6 -1` above).

Summaries are `main-pixel-summary-2.txt` to `-4.txt` and the logs
`main-pixel-<suite>.log`, in the ledger folder
(`.superpowers/sdd/2026-11-25-coach-cards/`, git-ignored).
