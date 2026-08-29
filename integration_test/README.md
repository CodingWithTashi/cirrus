# On-device end-to-end suites

These drive the **real app** — real router, real stores, real platform
channels — on a real device. The widget suite pins each piece on its own;
this is the only harness that catches what needs a tree to be built,
disposed or navigated. It found three bugs on its first three runs
(docs/08 §12).

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
| `b_onboarding` | All 19 steps with real keypad taps and a real 3s hold, the age gate, back navigation |
| `c_core_loop` | Log, undo, repair tokens, slip recovery, panic, offline logging |
| `d_social` | Feed, compose, report, block, coach, coach offline |
| `e_settings_screens` | All 20 routes, 4 shell tabs, 404, theme, locale, sign-out, delete |
| `f_firebase_backend` | The real backend: auth, journey persistence, callables, erasure |

## App Check

Every callable sets `enforceAppCheck: true`, so `f_firebase_backend`
only passes on a device whose debug token is registered:

```
firebase appcheck:debugtokens:create <token> --project alastpuff \
  --app 1:826701239342:android:6f8f39f49c52ee24e4bbbf --force
```

The token is printed to logcat on every launch
(`adb logcat | grep "debug token"`) and **rotates on every reinstall**.

Register it **before** the first run. The client backs off after repeated
rejections (`Too many attempts`) and then keeps failing even once the
token is valid — at which point the only way out is a reinstall, which
rotates the token again.

## Harness notes

- **Never `pumpAndSettle`.** Several screens animate forever by design
  (the breathing pacer, the flame, the progress ring) and it hangs until
  the timeout. Use `E2E.settle()` / `waitFor()` / `waitForText()`.
- **Find by localized text.** The app has zero hardcoded UI strings, so
  the tests read like the screens do.
- `showing()` matches text that is in the tree but off-screen — the
  offline banner always is. Use `visible()` when it matters.
