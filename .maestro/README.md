# Maestro end-to-end flows

Black-box UI tests that drive the installed app through its accessibility
tree — the only harness here that sees the real keyboard, the real splash and
the real store sheets, from outside the process. They complement, never
replace, `flutter test integration_test` (which runs inside the app).

## Flows

| File | Covers | Ends on |
| --- | --- | --- |
| `flows/01_sign_in.yaml` | Continue with email → Log in link → wrong password shakes → right password | Home (day line, SOS, LOG PUFF) |
| `flows/02_register.yaml` | Fresh email, short password refused in place, account created | Onboarding welcome |
| `flows/03_onboarding.yaml` | Register, then all 12 questions, coach name, hold-to-commit, rating and push declined | Paywall (“Your plan is ready.”) |
| `flows/04_home.yaml` | Header, ring, money and cravings cards, quick links, the four shell tabs | Home |
| `flows/05_puff_logging.yaml` | One tap = one puff, Undo, three taps = three puffs, press-and-hold ticks | Home |
| `flows/06_panic.yaml` | SOS → breathe → why → loop breakers → it passed → survived, count +1 | Home |
| `flows/07_settings.yaml` | Rename the coach, appearance, theme (Tide), language (French) and back | Settings |
| `flows/08_sign_out.yaml` | Log a puff, sign out via the confirm dialog, sign back in, puff still counted | Home |
| `flows/09_community_feed.yaml` | Seeded posts, pinned SOS, tag filters, a reaction toggling, a reply in a thread | Feed |
| `flows/10_community_post.yaml` | Composer rules (too short, where-to-buy, tag required), a Win, an SOS, SOS cooldown, the 3-a-day cap | Feed |
| `flows/11_coach.yaml` | Greeting, chips, a chip reply, a typed reply, progress with the week card, memories, rename in the thread, the panic hand-off | Coach |

`shared/` holds the subflows they reuse (`launch`, `register`, `sign_in`,
`dismiss_keyboard`, `dismiss_push_ask`, `go_back`, `open_composer`);
`config.yaml` keeps them out of directory runs. Flows
04–08 read the numbers off the screen with `copyTextFrom` and compare in JS,
so they hold on any day's seed rather than pinning "52 of 93".

## Running

Build the app on the **fake backend** so nothing touches Firebase, App Check
or RevenueCat and every run starts from the same seeded data:

```
# iOS simulator (the watch companion means -d is mandatory)
flutter run -d <simulator-udid> --no-resident --dart-define=LP_BACKEND=fake
maestro --device <simulator-udid> test .maestro

# Android device/emulator
flutter build apk --debug --dart-define=LP_BACKEND=fake && adb install -r build/app/outputs/flutter-apk/app-debug.apk
maestro --device <adb-serial> test .maestro
```

The bundle id differs per platform (`com.quitvape.lastPuff` on iOS,
`com.quitvape.last_puff` on Android), so every header picks it from
`maestro.platform`. A flow's own `env:` block wins over `-e`, which is why
nothing platform-specific lives there; `PASSWORD`/`EMAIL` do, as defaults for
the fake backend — against Firebase, edit `01`'s env block to a real account.

From Claude Code the same flows run through the Maestro MCP (`list_devices`
→ `run` with `files`/`dir`), and the live viewer is at http://127.0.0.1:9999/.

## What the selectors rely on

- **Text is matched against Flutter's semantics labels**, full-string regex,
  case-insensitive. Escape `?` and `$` (`'What year were you born\?'`, `'\$25'`).
- **Cards merge title and subtitle with a newline** (“2–5\na few rounds”), and
  Home merges its date line with “Today”. Match those with a dot-all regex:
  `'(?s)2–5.*'`, `'(?s).*Day \d+ of \d+.*Today'`.
- **Text fields have no label of their own.** They are reached relative to the
  caption above them: `tapOn: { below: { text: 'EMAIL' }, index: 0 }`.
- **The keyboard hides what is under it.** The register screen autofocuses
  its email field, which pushes “Already have one? Log in” off the tree;
  `shared/dismiss_keyboard.yaml` taps the iOS “done” key or `hideKeyboard`
  on Android. The coach composer's return key is “send” instead, so
  `11_coach.yaml` submits typed messages with `pressKey: Enter`.
- **Keypad digits can collide with the number on screen.** The birth year is
  typed as 1985 so no digit is already showing; the puffs keypad is anchored
  `below` the “Not sure? Estimate…” link because the rolling counter passes
  through every value; the spend hero is one “$0” node so bare digits are safe.
- **Hold to commit** is a real press: `longPressOn: 'Hold to commit'` (the
  ring's semantics label; the 1.8 s hold is shorter than Maestro's long press).
- The rating step taps **Not now** and the push step **Maybe later** so no OS
  sheet is involved. Turning either on is a separate flow to write.

## Accessibility issues found by these flows — all fixed on Sep 8 2026

Found by `inspect_screen` on the iPhone 16 Pro simulator (iOS 18.3). What
Maestro reads is what VoiceOver reads.

- **Panic flow frames at 1/devicePixelRatio, and a slider drag emptying the
  tree (iOS).** After the switch out of the breathing step, every frame on
  the why-step, the next step and the Survived screen was reported at one
  third of its real position; dragging the intensity slider then emptied the
  accessibility tree until restart. Bisected on the app to the Material
  `Slider` itself: a `CupertinoSlider` in the same spot is clean end to end.
  `06_panic.yaml` taps every CTA by text on purpose — a text tap lands only
  when the frames are right, so the flow is the regression check.
- **`BackChevron`, the composer FAB, every post's `…` menu and the coach's
  send arrow had no label.** Now "Back", "New post", "Post options" (so
  Report, Mute and Block exist for a screen reader — the controls 1.2 asks
  for) and "Send".
- **The offline pill stayed readable while hidden.** It leaves the tree now.

`test/widgets/chrome_semantics_test.dart` and
`test/widgets/panic_slider_test.dart` pin the widget side, and the flows
reach every one of these by its label now (`shared/go_back.yaml`,
`shared/open_composer.yaml`, `11_coach.yaml`).

## Deliberately not covered yet

Report, Mute and Block (the menu is labelled now, so a flow can follow).
The panic games arena. The coach's free-message cap (the demo account is
Premium). Sign in with Apple / Google (native sheets). The OS sheets for
rating and push. The in-app inbox: on the fake backend only another alias's
reply can fill it, and every flow here is one person.
