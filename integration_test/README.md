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
| `b_onboarding` | The 20-step first session with real keypad taps and a real 3s hold, the age gate, back navigation |
| `c_core_loop` | Log, undo, repair tokens, slip recovery, panic, offline logging |
| `d_social` | Feed, compose, report, block, coach, coach offline |
| `e_settings_screens` | A sweep of every screen route, 4 shell tabs, 404, theme, locale, sign-out, delete |
| `f_firebase_backend` | The real backend: auth, journey persistence, callables, erasure |
| `g_day1_tour` | The Day-1 walkthrough gate — showcase barrier, `IgnorePointer`, disabled tabs and `PopScope` exercised together on a real tree |
| `h_panic_games` | The panic arcade — a real round, drags, flicks, pill swaps and a mid-round exit; disposal and the router are what only a device sees |

## App Check

Every callable sets `enforceAppCheck: true`, so `f_firebase_backend`
only passes on a device whose debug token is registered:

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

## Harness notes

- **Never `pumpAndSettle`.** Several screens animate forever by design
  (the breathing pacer, the flame, the progress ring) and it hangs until
  the timeout. Use `E2E.settle()` / `waitFor()` / `waitForText()`.
- **Find by localized text.** The app has zero hardcoded UI strings, so
  the tests read like the screens do.
- `showing()` matches text that is in the tree but off-screen — the
  offline banner always is. Use `visible()` when it matters.
