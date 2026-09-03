# Cirrus (`last_puff`)

Cirrus is a quit-vaping app: a taper plan computed from the user's own numbers, a panic flow for cravings, an AI coach called Ember, and an anonymous community. Flutter on Android and iOS, Firebase behind it, TypeScript Cloud Functions for everything a client must not be trusted with.

The internal project name is LastPuff; the store name is Cirrus.

## Layout

| Path | What it is |
|---|---|
| `lib/` | The Flutter app — MVVM with Riverpod, pure-Dart engines in `lib/domain/`, two backends behind one seam (`FakeServer` in memory, Firebase on device) |
| `test/`, `integration_test/` | Widget/unit suites, and the on-device suites that drive the real app |
| `functions/` | Cloud Functions (2nd gen) on project `alastpuff` — coach, moderation, billing mirror, crons |
| `firestore.rules`, `firestore.indexes.json` | Firestore security rules and indexes |
| `cirrus-landing/` | The marketing site (Astro on Cloudflare Pages, cirrusquit.com) |
| `hosting/` | Firebase Hosting: the retired legal pages. The `hosting.redirects` block in `firebase.json` 301s `/privacy` and `/terms` to `cirrusquit.com`, and that redirect outlives the files — every build ever installed still asks for the old URL. **Those two paths only, never a `/**` catch-all:** Firebase emails password-reset links to `/__/auth/action` on this same site, and a blanket redirect risks sending every reset click to the marketing home page |
| `docs/` | Product specs (`01`–`07`, frozen), the build board (`08`), the QA round (`09`), the build log (`10`), the AI pipeline explainer (`11`), and the design handoff |
| `tool/device.ps1` | Build, install and run on a device against real Firebase with the right defines |

## Commands

```
flutter pub get                          # deps + l10n codegen
flutter analyze                          # lint
flutter test                             # unit + widget suites
./tool/device.ps1                        # run on a device against real Firebase (Windows)
./tool/device.ps1 -Test                  # the on-device end-to-end suites
flutter build appbundle --release --dart-define-from-file=.dart_defines.json
 flutter build appbundle --release 
cd functions
npm install                              # first run
npm run verify                           # typecheck + lint + tests — the deploy gate
npm run serve                            # local emulators
```

The full command reference, including the emulator suites and the moderation eval gate, is in `CLAUDE.md`.

## Local files you need and must never commit

- `.appcheck_token` and `.dart_defines.json` — the pinned App Check debug token (see `integration_test/README.md`)
- `functions/.env` — `GEMINI_API_KEY`, `REVENUECAT_WEBHOOK_TOKEN` (production secrets live in Secret Manager)
- `android/key.properties` and the upload keystore

All of them are gitignored. `functions/.env.alastpuff` is tracked on purpose: it holds deploy parameters, not secrets.

## CI

`.github/workflows/ci.yml` runs on every push: Flutter analyze and test (with a check that the generated localizations match the ARB files), the functions gate, and the Firestore rules and integration suites on the emulator. The landing site deploys by hand from `cirrus-landing-deploy.yml`.

## Where to read next

- `CLAUDE.md` — architecture, the invariants that have already bitten, and how to test
- `docs/08_Sprint_Tracker.md` — what is done, what is blocked, what is next
- `docs/10_Build_Log.md` — the dated history behind the board
- `functions/README.md` — why any server code exists, and the client/server ownership rule
- `integration_test/README.md` — running the suites on a device, and App Check
- `cirrus-landing/README.md` — the site, its content rules and SEO
