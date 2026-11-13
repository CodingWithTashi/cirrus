# On-device end-to-end suites

These drive the **real app** — real router, real stores, real platform
channels — on a real device. The widget suite pins each piece on its own;
this is the only harness that catches what needs a tree to be built,
disposed or navigated. It found three bugs on its first three runs
(docs/10 §5).

## Running

Against the fake backend — fast, deterministic, no production writes:

```
flutter test integration_test -d emulator-5554 --dart-define=LP_BACKEND=fake
```

Against **production Firebase** — creates one throwaway account and
deletes it in `tearDownAll`:

```
flutter test integration_test/f_firebase_backend_test.dart \
  -d emulator-5554 --dart-define=LP_BACKEND=firebase
```

| Suite | Covers |
|---|---|
| `a_launch_auth` | Cold start, the auth gate, sign-in, wrong password, offline, duplicate email |
| `b_onboarding` | The 21-step first session (13 quiz questions, cigarettes included) with real keypad taps and a real 3s hold, the age gate, back navigation |
| `c_core_loop` | Log, undo, repair tokens, slip recovery, panic, offline logging |
| `d_social` | Feed, compose, report, block, coach, coach offline |
| `e_settings_screens` | A sweep of every screen route, 4 shell tabs, 404, theme, locale, sign-out, delete |
| `f_firebase_backend` | The real backend: auth, journey persistence, callables, erasure |
| `g_day1_tour` | The Day-1 walkthrough gate — showcase barrier, `IgnorePointer`, disabled tabs and `PopScope` exercised together on a real tree |
| `h_panic_games` | The panic arcade — a real round, drags, flicks, pill swaps and a mid-round exit; disposal and the router are what only a device sees |
| `i_monetisation` | The free/premium surfaces: every door opens a real paywall and closes back, the panic flow never reaches one, and a purchase lands on "You're in." then pops to where the paywall came from |
| `j_craving_and_quiet_hours` | A craving closed with back starts the next one clean (clock, step, intensity), and the quiet-hours rail drags inside the real sheet — a horizontal drag through the modal's own dismiss-drag and scroll view |
| `k_retention` | The REAL notification scheduler and OS permission on the fake backend's data (docs/10 §51.5): the second notification ask against the OS's own answer and its system dialog, a week of evening check-ins on the device clock, one delivered and tapped through the shade, and the day-3 offer card with a closable paywall. Needs a never-asked install (`adb uninstall com.quitvape.last_puff` first) and an adb driver for the dialog and the shade — the test prints `E2E-MARKER:` lines and waits |
| `m_reminder_tap` | A tapped reminder reaches Dart with its kind — the real scheduler, the OS's own notification and the app's own app delegate, with nothing of the app's data. Written for the iOS notification-delegate fix (docs/10 §52); needs a hand on the permission sheet and the notification, and a phone that is not in Do Not Disturb |
| `n_zero_day_and_new_plan` | The Nov 12 retention round on a real font (docs/10 §52): cold turkey's Day 1 under the walkthrough barrier, the zero-day Home button in all six languages, Undo taking its slip back, starting a new plan from Home, and the sign-out dialog |
| `p_safety_and_date` | docs/15 stage A on a real font: the cigarettes step and the one-rule card, the Home question card for an account never asked, More help for the device's real region and for every listed country (Call/Source/research hand the right URI to the opener), a slip that asks before it moves the date (keep, add 2, add 1 with a grammatical caption, no Add at the ceiling or on cold turkey, "talk it through" stretches nothing), the stretch ceiling, an Adjust that changes the date only, and the real launcher opening a dialler and a browser. Prints `E2E-MARKER: shot <name>` lines that pause 2.5s so an adb driver can screenshot |
| `o_quit_program` | docs/15 stage B on a real font and the REAL notification scheduler: a cold-turkey quit day's Home card (title, question, four buttons hit-testable), a mood answered and the written reply read off the engine, tomorrow's 09:00 message pending on the OS with the `program` payload, id 5001 and its full body (read through `pendingNotificationRequests()`, so a phone in Do Not Disturb does not hide it), the daily-message switch taking down ids 4000–4006 and 5000–5002 and leaving the trial reminder alone, the day-7 nicotine check-up and the one rule behind "cigarettes", the Stress sheet's breathing ring, Slipped's doors with nothing moved, and the 90-day card. Prints `E2E-MARKER: shot <name>` lines. Needs no adb driver for assertions; a tap on the notification itself stays with `m_reminder_tap` |
| `l_sign_in_fallback` | A failed identity sheet on a real font: "Continue with email" and the retry share one row, and email is one tap away |

`j_widget_session_test.dart` is **not** part of a fake-backend run: it is a `flutter run` entrypoint that leaves a signed-in production account on the device for the widget and watch passes, and it refuses to start on the fake backend.

## App Check

Every callable enforces App Check (`ENFORCE_APP_CHECK=true` in
`functions/.env.alastpuff`), so `f_firebase_backend` only passes on a device
whose debug token is registered:

```
firebase appcheck:debugtokens:create <token> --project alastpuff \
  --app 1:826701239342:android:6f8f39f49c52ee24e4bbbf --force   # Android
firebase appcheck:debugtokens:create <token> --project alastpuff \
  --app 1:826701239342:ios:042418c48b5e6f38e4bbbf --force       # iOS
```

The two Firebase apps are separate registrations. The token is **pinned**
via `--dart-define=LP_APPCHECK_DEBUG_TOKEN` (read from the gitignored
`.appcheck_token`), so it no longer rotates per install — `tool/device.ps1`
(Windows) passes the define and registers the token; on macOS run the
commands above by hand and pass `--dart-define-from-file=.dart_defines.json`
to `flutter test integration_test`. Without the define the build mints a
throwaway token that is unregistered by construction.

Register it **before** the first run. The client backs off after repeated
rejections (`Too many attempts`) and keeps failing even once the token is
valid — the only way out is a reinstall (`adb uninstall com.quitvape.last_puff`
/ `xcrun devicectl device uninstall app --device <udid> com.quitvape.lastPuff`),
which `device.ps1` does for you after registering.

## Running on a real phone over wireless adb (Nov 2026 notes)

- **Keep the screen on yourself.** The screen-off timer counts real input only; a test's taps are Flutter's, not Android's, so the phone locks a few minutes after your last touch whatever the timeout says — and a locked phone stalls the test ("did not complete"). Send a harmless `input keyevent KEYCODE_WAKEUP` every ~20s for the length of a run, and set `screen_off_timeout` long.
- **A PIN lock opens only for a roll then a swipe,** all in one on-device `adb shell` burst (the display dozes between separate commands): `input keyevent KEYCODE_WAKEUP; sleep 1; input touchscreen roll 0 -20; sleep 0.4; input touchscreen swipe 300 1800 320 500 150; sleep 1.2; input text <PIN>; sleep 0.6; input keyevent KEYCODE_ENTER`. A plain swipe from the nav-bar strip, `wm dismiss-keyguard` and the Menu key do not open the bouncer, and the bouncer is a secure window, so screenshots of it are black.
- **Do not pump frames after the app has been sent to the background.** A test that launches an external app (`tel:`, a browser) and then calls `tester.pump` or `E2E.waitFor` stalls, and does not recover when the app is brought back. Use a plain `Future.delayed` after the launch and end the test. On a phone with two phone apps, `tel:` raises Android's "Open with" chooser and leaves it on screen: dismiss it (or the next run cannot take focus).
- **Never run two suites at once** and never `adb shell` inside a `while read` loop without `</dev/null` (it eats the loop's stdin).
- **Watch the battery.** A wireless run drains ~1% every 3–4 minutes and the phone dies mid-suite.

## Harness notes

- **Never `pumpAndSettle`.** Several screens animate forever by design
  (the breathing pacer, the flame, the progress ring) and it hangs until
  the timeout. Use `E2E.settle()` / `waitFor()` / `waitForText()`.
- **Find by localized text.** The app has zero hardcoded UI strings, so
  the tests read like the screens do.
- `showing()` matches text that is in the tree but off-screen — the
  offline banner always is. Use `visible()` when it matters.
