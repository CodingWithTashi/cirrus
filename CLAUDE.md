# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

LastPuff — a quit-vaping Flutter app (store name "Cirrus"; the name is still an open founder decision, see `docs/08`). The data layer is **API-shaped with two backends behind one seam**: session lifecycle and all persistence go through async repositories over the domain contracts. `backendModeProvider` picks who answers — **mobile (Android/iOS) runs real Firebase** for auth + journey (`Firebase*Repository`), while desktop/web/tests stay on the in-memory `FakeServer` demo backend with simulated latency (everything resets on restart there). `--dart-define=LP_BACKEND=fake|firebase` overrides the platform default. Community/Coach are still fake **everywhere, including production mobile** — their providers have no `switch` on `backendModeProvider` at all, so a real phone answers them from process-lifetime memory.

There is also a **written-but-unwired TypeScript Cloud Functions backend in `functions/`** (AI coach, moderation, RevenueCat webhook, crons). It is not a future plan — the code exists — but it has never compiled, never deployed, and the app has no way to call it. See "Server (`functions/`)" below before assuming any server behavior is live.

**`docs/08_Sprint_Tracker.md` is the live build board** — what is actually done, what is blocked, and the current targets ($44K/mo net by M6; launch Oct 15 2026 on both platforms). Read it before planning work; it supersedes the revenue and phasing numbers in `docs/01`.

## Commands

```
flutter pub get                              # install deps (also triggers l10n codegen)
flutter run                                  # run on connected device/emulator
flutter test                                 # all tests (must stay green)
flutter test test/domain/taper_engine_test.dart   # single test file
flutter test --plain-name "streak"           # tests matching a name
flutter analyze                              # lint (flutter_lints defaults)
flutter gen-l10n                             # regenerate l10n after editing .arb files
```

Server (`functions/`, npm — run from that directory):

```
npm install                                  # no node_modules in the checkout yet
npm run verify                               # typecheck + lint + vitest — THE deploy gate
npm test                                     # vitest only
npm run serve                                # build + emulators (functions, firestore, auth)
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only functions             # predeploy runs `verify`, so a red gate blocks it
```

## Architecture

Strict MVVM with Riverpod 2.x `Notifier`s as view models, layered as a one-way dependency chain:

- `lib/domain/` — pure Dart, no Flutter imports. Models (`models.dart`, `journey_state.dart`, `enums.dart`), **async backend contracts** (`repositories/repositories.dart`: `AuthRepository`, `JourneyRepository`, `CommunityRepository`, `CoachRepository`, plus the `AuthException` types), and the calculation engines in `logic/`: `TaperEngine`, `MoneyEngine`, `StreakEngine`, `DangerHours`, `DependenceEngine`. All displayed numbers come from these engines — the brand rule is "no invented numbers", so never hardcode a stat a mock shows.
- `lib/data/` — the backend-shaped stack, bottom-up:
  - `api/` — typed wire interfaces speaking `Map<String, dynamic>` JSON (`AuthApi`, `JourneyApi`, `CommunityApi`, `CoachApi`); `api/fake/` implements them over `FakeServer`, the in-memory JSON "database" (accounts, journey docs, posts; latency via `apiLatencyProvider`, tests override to zero). **FakeServer invariant: every op mutates synchronously, only the ack is delayed** — this keeps write-behind clients and server-computed coach args consistent.
  - `dto/` — hand-rolled JSON codecs (`JourneyCodec`, `PostCodec`, `CoachReplyCodec`, `codec_helpers.dart`). Day-map keys are `'yyyy-MM-dd'` **local midnight** (never epoch math); enums encode by `.name` with safe fallbacks. **Any new model field must be added to its codec AND `test/data/dto_roundtrip_test.dart`.**
  - `repositories/` — thin `Api*Repository` implementations of the domain contracts (JSON ↔ domain only, no logic), plus the real backend: `FirebaseAuthRepository`/`FirebaseJourneyRepository` (`firebase_common.dart` holds the shared journey-doc helpers and `guardAuth`, the ONE place Firebase/Google error codes map to the domain taxonomy — `network-request-failed` → `NoConnectionException`, dismissed native sheets → `SignInCancelledException`). The journey persists as a single Firestore doc `journeys/{uid}` of `JourneyCodec` JSON; guest onboarding (Frame Map) falls back to anonymous auth. Both backends mint identical day-1 journeys via `domain/logic/journey_factory.dart` (`InitialJourney.build`).
  - `stores/` — Riverpod view models. `JourneyStore`: awaited async lifecycle (`logIn`/`register`/`signInWithApple`/`restoreSession`/`startJourney`; optimistic sync `signOut`/`deleteAccount`/`seedDemoJourney`), and **every other mutation is synchronous + optimistic through `_commit(next)`** = set state + `unawaited(save)` write-behind — views may read fresh state right after a command; keep new mutations on that pattern. `providers.dart` is the composition root and documents the backend swap point: REST replaces `api/fake/`, Firebase replaces either the Api or Api*Repository bodies; stores and views never change.
  - `seed/seed_data.dart` — the demo day-12 journey (single source; the fake backend serializes it through the codecs, so the JSON round-trip runs in production code).
- `lib/features/<name>/` — one folder per screen/flow. Views read state via providers and issue commands through `.notifier`. Async lifecycle CTAs pass `busy:` to `LpButton` and guard navigation with `mounted` after awaits.
- `lib/app/` — `router/app_router.dart` (go_router with a `StatefulShellRoute` 4-tab shell: Home/Stats/Community/Coach; all route paths live in the `Routes` class) and the theme. The router redirects journey-requiring paths to `/auth` while `journey == null`, but **deliberately allows authed visits to `/auth` and `/onboarding`** so the Frame Map can preview every screen — don't "fix" that. Lifecycle callers must set journey state **before** navigating into gated paths (awaiting the store call does this).
- `lib/core/` — shared widgets (`LpCard`, `LpChip`, charts, `RollingNumber`, `ProgressRing`, `NewIdConfetti`, `PushPreviewCard`, …) and utils. **All price strings and the invite URL live only in `core/utils/lp_pricing.dart` (`LpPricing`/`LpLinks`)** — reuse, don't duplicate.

### Server (`functions/`) — written, not running

TypeScript Cloud Functions 2nd gen. `index.ts` is a thin barrel exporting 9 functions: `aiCoachChat`, `panicSession`, `syncUserContext`, `deleteUserData`, `createPost`, `moderatePost`, `taperRecalc`, `weeklyInsight`, `rcWebhook`. (`dangerHourPush` from docs/05 §7 is deliberately absent — danger-hour reminders are deterministic, so they're scheduled on-device.) Layout: `ai/` (the `TextModel` seam — only `ai/gemini.ts` imports a vendor SDK, so swapping providers is one new implementation; all prompts live in `ai/prompts.ts`), `domain/` (a TS port of the Dart engines), `handlers/`, `config.ts` (all secrets/params via `defineSecret`/`defineString`).

**Four facts to check before you touch or trust it:**

1. **`functions/src/lib/` does not exist** — 23 imports across all 9 handlers reference `../lib/{firestore,guards,logger,usage}`. `tsc` fails, so `verify` fails, so `predeploy` blocks deploy. Nothing here has ever run.
2. **Cloud Functions have never been deployed** and the API has never been enabled on project `alastpuff`. No `functions/lib/`, no `functions/node_modules/`, no `.firebase/`.
3. **The app cannot call any of it** — no `cloud_functions` and no `firebase_app_check` in `pubspec.yaml`, and every callable sets `enforceAppCheck: true`, so they would reject the client even once wired.
4. **The crons are inert by construction** — both query `users where recalcHourUtc == n`, but `users/{uid}` docs are created only by `syncUserContext`, which nothing calls.

**The one architectural rule** (`firestore.rules`, `functions/README.md`): ownership is split. `journeys/{uid}` is **client-owned** — `FirebaseJourneyRepository.save()` does a whole-document `set()` on every optimistic mutation, so **any server-written field here is destroyed by the next puff tap**. `users/{uid}` is **server-owned** (entitlement, `aiUsage`, `planAdvice`), readable by its owner and writable only by the Admin SDK. Entitlement lives there for a reason: if a client could write it, it would grant itself Premium. Today the app still writes `profile.tier` into its own journey doc — that is the self-granted-entitlement hole, not the intended design.

Community collections: `posts` (created only via the `createPost` callable so no uid lands on the post), `postAuthors` (the server-only uid↔post map that makes account deletion possible without breaking anonymity), `moderation` (founder review queue). **`createReply` is referenced by `firestore.rules` but was never written**, so replies cannot be created by anyone.

### Error handling

Every failure has a designated friendly surface — never invent per-screen phrasing or let an error escape raw:

- **Taxonomy**: repositories throw `NoConnectionException` (offline) or auth-specific `AuthException`s (`domain/repositories`). `data/network/connectivity.dart` polls a DNS probe (5s); `FakeServer` reads it synchronously and becomes unreachable offline, exactly like a real backend.
- **Surfaces** (all in `core/widgets/lp_error.dart` unless noted): app-level offline pill overlaid via `MaterialApp.builder` (`OfflineBanner`); `showLpErrorDialog(context, error:, onRetry:)` for awaited lifecycle CTAs — `lpErrorCopy` picks offline vs generic copy; `LpErrorState` for failed content areas (community feed pattern: `FeedStatus` + `retryFeed()`); go_router `errorBuilder` → `RouteNotFoundScreen`; the coach fails in-thread via `CoachTemplate.connectionLost` (and refunds the free message); `LpCrashScreen` (core/widgets) replaces the red error box — it may render in a broken tree, so it's the ONE place with non-ARB copy and raw palette hexes (annotated); `LpErrors.install()` (app/app_errors.dart, called in main) routes uncaught async errors to a throttled "backstage" snack.
- **Local-first stance**: optimistic mutations `.ignore()` wire failures (`_commit`, community write-behinds) — the banner tells the story; never surface a dialog for a background save. `restoreSession` failure lands on sign-in, never a stuck splash.
- **Tests**: anything that pumps the app or wires the fake backend must use `fastBackendOverrides()` from `test/helpers.dart` (pins `BackendMode.fake` — the test platform reports android, which would otherwise construct the Firebase repositories — plus zero latency + polling off; `online: false` simulates airplane mode). No Firebase mocks anywhere. Error surfaces are covered in `test/widgets/error_handling_test.dart`.

### Demo model (fake backend only)

The sign-in screen gates its identity buttons by `defaultTargetPlatform`: Apple on iOS/macOS, Google on Android, email everywhere. On the fake backend, email login (any email; password < 6 chars = "wrong", enforced in `FakeAuthApi`, not views) restores the seeded day-12 journey (@quietfox). "Sign in with Apple"/register open a fresh account → 19-step onboarding → paywall → the backend creates the day-1 journey. Within one app session, mutations persist across logout→login (write-behind JSON on `FakeServer`); registering the demo email `maya@quitmail.com` fails as already-in-use. The Frame Map (`/frames`, reachable from the sign-in screen and Settings) lists all 52 design frames; `seedDemoJourney()` keeps its jumps synchronous — don't make them await.

### Theming

Two palettes as an `LpColors` `ThemeExtension` — Midnight Ember (dark, brand default) and Daylight Ember (light). Widgets read semantic tokens via `context.lp`; **never raw hex in widgets** (the only two sanctioned exceptions are annotated: the Apple sign-in button and the iOS rating-sheet link blue). `lp.caution`/`lp.cautionText` are the only sanctioned yellows. `LpChip` maps accent colors to text tokens itself — pass `selectedColor: lp.oxygen`/`lp.ember`, never a text color. Fonts: Space Grotesk (display) + Inter (body), bundled in `assets/fonts`.

### Localization

Zero hardcoded UI strings. ARB files in `lib/l10n/app_{en,es,fr,de,pt}.arb`, generated into `lib/l10n/gen` (never edit generated files). Use `context.l10n` (`core/utils/l10n_ext.dart`). Content that lives in data is stored as ids/enums and resolved to l10n in views: coach replies via `CoachTemplate` enums, community seed posts via `seedTextId`, seeded goal names via ids (g1/g2/onboarding-goal). ARB templates must not add symbols around already-formatted values (e.g. no extra '%' around a formatted percent).

## Specs and design source

- `docs/01–07` are the frozen product specs; `docs/07` is the brand/design brief.
- **`docs/08_Sprint_Tracker.md` is the only living doc** — build status, blockers (`B1`–`B16`, each with an evidence path), sprint plan, and the current revenue model. Update it as work lands; when it disagrees with `docs/01–07`, it wins.
- The visual source of truth is a Claude Design project exported into the four `docs/design/*handoff*` bundles (byte-identical `project/` folders; 52 frames across Runs 1/2/2-Light/3). Per-frame implementation status, deliberate deviations, and past fix rounds are tracked in `docs/design/HANDOFF_COMPLETION.md`.

### Spec conflicts — these resolutions win over the spec text

**Already resolved in code — do not regress:**

- `TaperEngine` implements pure `round(B×(1−d/P)^1.5)` with tail clamps `≤3, ≤1, 0` (matches docs/03's worked B=200/P=30 table; the prose formula contradicts it). Pinned by `test/domain/taper_engine_test.dart`.
- Health timeline anchors to rolling `lastPuffAt`, not Freedom Day (docs/03 §6 self-contradicts).
- Dependence badge thresholds follow docs/02 B2 (151–300 = Heavy/orange, 301+ = Severe/red); the Run 1 mock labeling 200 as "Severe" is wrong.
- Home/Money figures are engine-computed, not the mock's "$47"/"$312" (not reproducible under docs/03 §4 math).

**Doc-vs-doc contradictions — the winner is named, nothing to regress yet:**

- **docs/01 §13's blended ARPU of "$9.60/mo net" is wrong** — it never applies the 15% store commission docs/01 §11 cites. True net is **$7.93/mo** at the locked prices and the 50/25/25 mix. Never quote §13's figure or its $10K target; `docs/08` carries the corrected model.
- Onboarding is **19 steps** (docs/02), not docs/01 §12's "≈14". Code implements 19.
- Premium coach cap is **100 msgs/day** (docs/04 §7), not docs/01 §10's "unlimited". Marketing may say unlimited; the server enforces 100.
- `taperRecalc` uses **trailing 3 days** (docs/03 §3.3), not docs/05 §7's "7-day" — docs/03's math is the one `taperEngine.ts` implements.
- Apple Watch is **V2** (docs/05 §3), not docs/01 §8's V1.1 — it's a separate native mini-app.
- **Quit Buddies is descoped** (founder decision Aug 2026, `functions/README.md`), so docs/03 §7's buddy-ping and §9's SOS buddy-notify have no server side. `lib/features/buddy/` still ships the UI — don't build backend for it without checking whether the screen should be hidden instead.

## Gotchas (each was a real bug — don't reintroduce)

- `TweenAnimationBuilder` with a begin-less `Tween(end:)` never animates its first build — `RollingNumber`, `GlowProgressBar`, `BarChart`, `ProgressRing` all carry an explicit `begin`.
- `BarChart` must fold (not `reduce`) — callers pass runtime `List<int>` into a `List<num>` param and `reduce`'s covariant `combine` throws.
- `StreakEngine.currentStreak` skips an unconfirmed today (anchors to yesterday) so an in-progress day dims the flame instead of zeroing it — unit-tested.
- Seed data: a day's actual puffs must stay ≤ that day's curve limit or the streak chain silently breaks.
- `PanicFlow` clears snackbars on entry (the 5s undo snack otherwise outlives the route push and covers "Skip to my why").
- `showLpSnack` carries a fallback timer that force-closes the snack at `duration + 250ms` — the framework skips its own timeout for action snack bars under accessible navigation (which some environments report spuriously), leaving "Undo" snacks up forever. Don't remove it; route all snacks through `showLpSnack`.
- Auth form screens (Register/Login/Forgot) wrap their Column in `_AuthScrollView` (scroll under min-height + `IntrinsicHeight`, same idiom as the community composer) — a bare Column overflows when the keyboard opens.
- The FakeServer's connectivity gate reads the connectivity store **synchronously** (never await a probe inside `respond`) — an async gap there breaks the sync-apply invariant.
- App-pumping tests without `fastBackendOverrides()` do real DNS lookups and leak the 5s poll timer.
- **Never write a server-owned field onto `journeys/{uid}`.** The client `set()`s the whole document on every optimistic mutation, so the next puff tap silently destroys it. Server state goes in `users/{uid}`.
- **Two implementations of the same math drift, and already have** — `streakEngine.ts` omits the repair-token exception that `streak_engine.dart:29-30` applies, so the server counts a token-saved day as a break. Any change to a shared engine must land in both `test/domain/*_test.dart` and `functions/test/*.test.ts`, or the coach starts quoting numbers the Home screen contradicts.
- `CoachReplyCodec.decode` reads only `template`/`args`/`showWeekCard` — it **drops the `text` field** `aiCoachChat` returns, so a real model reply would render as the canned `generic1` template. Fix the codec before wiring the coach.
- `functions/alastpuff-*-adminsdk-*.json` is a live service-account private key. It must stay gitignored and must never be committed; deployed functions use Application Default Credentials and don't need it.
