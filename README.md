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

`.github/workflows/ci.yml` runs on pushes to `main` and pull requests: Flutter analyze and test, with a check that the generated localizations match the ARB files. `.github/workflows/functions.yml` runs whenever the backend changes: the functions gate, and the Firestore rules and integration suites on the emulator. The landing site deploys from the Release workflow (below), or by hand from `cirrus-landing-deploy.yml` for a preview.

## Where to read next

- `CLAUDE.md` — architecture, the invariants that have already bitten, and how to test
- `docs/08_Sprint_Tracker.md` — what is done, what is blocked, what is next
- `docs/10_Build_Log.md` — the dated history behind the board
- `functions/README.md` — why any server code exists, and the client/server ownership rule
- `integration_test/README.md` — running the suites on a device, and App Check
- `cirrus-landing/README.md` — the site, its content rules and SEO

## Releases (GitHub Actions + fastlane)

Pushes and pull requests only run analyze and test (`ci.yml`). Nothing ships until you run **Actions → Release → Run workflow** on `main` and tick what to release:

- **Android**: builds the AAB and uploads it to the chosen Play track (internal, alpha = closed testing, beta = open testing, production).
- **iOS**: builds with the match profiles and uploads to TestFlight. Submit it for review in App Store Connect.
- **Web**: deploys the landing site to cirrusquit.com (`cirrus-landing-deploy.yml`).

Both store builds use `version:` from `pubspec.yaml`, so bump the build number before every release; each job stops before building if the Play track or TestFlight already has it. The lanes live in `fastlane/Fastfile` (`bundle exec fastlane lanes` lists them).

### One-time setup

Shared by every app on the team, done once:

- An App Store Connect Team API key with the App Manager role.
- A Google Play service account, `play-publisher`, with a JSON key.
- The private match repo `CodingWithTashi/ios-certificates`, its passphrase, and a fine-grained token with Contents: Read-only on it.

For this app:

1. **Play Console:** Users and permissions → the `play-publisher` service account → add this app with permission to release to testing tracks and production.
2. **iOS profiles:** on your Mac, with Homebrew Ruby on `PATH`, run `bundle install`, then `bundle exec fastlane ios certs`. Run it again when the profiles expire.
3. **Secrets:** add these to the repo (Settings → Secrets and variables → Actions).

| Secret | Value |
|---|---|
| `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` | Cloudflare Pages deploy (web) |
| `ANDROID_KEYSTORE_BASE64` | Base64 of the upload keystore (`base64 -i <keystore>.jks`) |
| `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | The upload keystore's passwords and alias |
| `PLAY_STORE_JSON_KEY` | The service account's JSON key, pasted whole |
| `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` | The Team API key's Key ID, the Issuer ID, and the `.p8` file's contents |
| `MATCH_PASSWORD` | The match repo passphrase |
| `IOS_CERT_TOKEN` | The `ios-certificates` token, pasted as GitHub shows it |
