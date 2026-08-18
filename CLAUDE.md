# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

LastPuff — a quit-vaping Flutter app. The data layer is **API-shaped but fake-backed**: session lifecycle and all persistence go through async repositories over a JSON-speaking API seam, answered today by an in-memory `FakeServer` with simulated latency. Everything resets on app restart; Firebase or a REST backend (docs/05) later replaces only the seam (see Architecture), not stores or views.

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

## Architecture

Strict MVVM with Riverpod 2.x `Notifier`s as view models, layered as a one-way dependency chain:

- `lib/domain/` — pure Dart, no Flutter imports. Models (`models.dart`, `journey_state.dart`, `enums.dart`), **async backend contracts** (`repositories/repositories.dart`: `AuthRepository`, `JourneyRepository`, `CommunityRepository`, `CoachRepository`, plus the `AuthException` types), and the calculation engines in `logic/`: `TaperEngine`, `MoneyEngine`, `StreakEngine`, `DangerHours`, `DependenceEngine`. All displayed numbers come from these engines — the brand rule is "no invented numbers", so never hardcode a stat a mock shows.
- `lib/data/` — the backend-shaped stack, bottom-up:
  - `api/` — typed wire interfaces speaking `Map<String, dynamic>` JSON (`AuthApi`, `JourneyApi`, `CommunityApi`, `CoachApi`); `api/fake/` implements them over `FakeServer`, the in-memory JSON "database" (accounts, journey docs, posts; latency via `apiLatencyProvider`, tests override to zero). **FakeServer invariant: every op mutates synchronously, only the ack is delayed** — this keeps write-behind clients and server-computed coach args consistent.
  - `dto/` — hand-rolled JSON codecs (`JourneyCodec`, `PostCodec`, `CoachReplyCodec`, `codec_helpers.dart`). Day-map keys are `'yyyy-MM-dd'` **local midnight** (never epoch math); enums encode by `.name` with safe fallbacks. **Any new model field must be added to its codec AND `test/data/dto_roundtrip_test.dart`.**
  - `repositories/` — thin `Api*Repository` implementations of the domain contracts (JSON ↔ domain only, no logic).
  - `stores/` — Riverpod view models. `JourneyStore`: awaited async lifecycle (`logIn`/`register`/`signInWithApple`/`restoreSession`/`startJourney`; optimistic sync `signOut`/`deleteAccount`/`seedDemoJourney`), and **every other mutation is synchronous + optimistic through `_commit(next)`** = set state + `unawaited(save)` write-behind — views may read fresh state right after a command; keep new mutations on that pattern. `providers.dart` is the composition root and documents the backend swap point: REST replaces `api/fake/`, Firebase replaces either the Api or Api*Repository bodies; stores and views never change.
  - `seed/seed_data.dart` — the demo day-12 journey (single source; the fake backend serializes it through the codecs, so the JSON round-trip runs in production code).
- `lib/features/<name>/` — one folder per screen/flow. Views read state via providers and issue commands through `.notifier`. Async lifecycle CTAs pass `busy:` to `LpButton` and guard navigation with `mounted` after awaits.
- `lib/app/` — `app_router.dart` (go_router with a `StatefulShellRoute` 4-tab shell: Home/Stats/Community/Coach; all route paths live in the `Routes` class) and the theme. The router redirects journey-requiring paths to `/auth` while `journey == null`, but **deliberately allows authed visits to `/auth` and `/onboarding`** so the Frame Map can preview every screen — don't "fix" that. Lifecycle callers must set journey state **before** navigating into gated paths (awaiting the store call does this).
- `lib/core/` — shared widgets (`LpCard`, `LpChip`, charts, `RollingNumber`, `ProgressRing`, `NewIdConfetti`, `PushPreviewCard`, …) and utils. **All price strings and the invite URL live only in `core/utils/lp_pricing.dart` (`LpPricing`/`LpLinks`)** — reuse, don't duplicate.

### Error handling

Every failure has a designated friendly surface — never invent per-screen phrasing or let an error escape raw:

- **Taxonomy**: repositories throw `NoConnectionException` (offline) or auth-specific `AuthException`s (`domain/repositories`). `data/network/connectivity.dart` polls a DNS probe (5s); `FakeServer` reads it synchronously and becomes unreachable offline, exactly like a real backend.
- **Surfaces** (all in `core/widgets/lp_error.dart` unless noted): app-level offline pill overlaid via `MaterialApp.builder` (`OfflineBanner`); `showLpErrorDialog(context, error:, onRetry:)` for awaited lifecycle CTAs — `lpErrorCopy` picks offline vs generic copy; `LpErrorState` for failed content areas (community feed pattern: `FeedStatus` + `retryFeed()`); go_router `errorBuilder` → `RouteNotFoundScreen`; the coach fails in-thread via `CoachTemplate.connectionLost` (and refunds the free message); `LpCrashScreen` (core/widgets) replaces the red error box — it may render in a broken tree, so it's the ONE place with non-ARB copy and raw palette hexes (annotated); `LpErrors.install()` (app/app_errors.dart, called in main) routes uncaught async errors to a throttled "backstage" snack.
- **Local-first stance**: optimistic mutations `.ignore()` wire failures (`_commit`, community write-behinds) — the banner tells the story; never surface a dialog for a background save. `restoreSession` failure lands on sign-in, never a stuck splash.
- **Tests**: anything that pumps the app or wires the fake backend must use `fastBackendOverrides()` from `test/helpers.dart` (zero latency + polling off; `online: false` simulates airplane mode). Error surfaces are covered in `test/widgets/error_handling_test.dart`.

### Demo model

Email login (any email; password < 6 chars = "wrong", enforced in `FakeAuthApi`, not views) restores the seeded day-12 journey (@quietfox). "Sign in with Apple"/register open a fresh account → 19-step onboarding → paywall → the backend creates the day-1 journey. Within one app session, mutations persist across logout→login (write-behind JSON on `FakeServer`); registering the demo email `maya@quitmail.com` fails as already-in-use. The Frame Map (`/frames`, reachable from the sign-in screen and Settings) lists all 52 design frames; `seedDemoJourney()` keeps its jumps synchronous — don't make them await.

### Theming

Two palettes as an `LpColors` `ThemeExtension` — Midnight Ember (dark, brand default) and Daylight Ember (light). Widgets read semantic tokens via `context.lp`; **never raw hex in widgets** (the only two sanctioned exceptions are annotated: the Apple sign-in button and the iOS rating-sheet link blue). `lp.caution`/`lp.cautionText` are the only sanctioned yellows. `LpChip` maps accent colors to text tokens itself — pass `selectedColor: lp.oxygen`/`lp.ember`, never a text color. Fonts: Space Grotesk (display) + Inter (body), bundled in `assets/fonts`.

### Localization

Zero hardcoded UI strings. ARB files in `lib/l10n/app_{en,es,fr,de,pt}.arb`, generated into `lib/l10n/gen` (never edit generated files). Use `context.l10n` (`core/utils/l10n_ext.dart`). Content that lives in data is stored as ids/enums and resolved to l10n in views: coach replies via `CoachTemplate` enums, community seed posts via `seedTextId`, seeded goal names via ids (g1/g2/onboarding-goal). ARB templates must not add symbols around already-formatted values (e.g. no extra '%' around a formatted percent).

## Specs and design source

- `docs/01–07` are the product specs; `docs/07` is the brand/design brief.
- The visual source of truth is a Claude Design project exported into the four `docs/design/*handoff*` bundles (byte-identical `project/` folders; 52 frames across Runs 1/2/2-Light/3). Per-frame implementation status, deliberate deviations, and past fix rounds are tracked in `docs/design/HANDOFF_COMPLETION.md`.

### Spec conflicts already resolved in code — do not regress to the spec text

- `TaperEngine` implements pure `round(B×(1−d/P)^1.5)` with tail clamps `≤3, ≤1, 0` (matches docs/03's worked B=200/P=30 table; the prose formula contradicts it). Pinned by `test/domain/taper_engine_test.dart`.
- Health timeline anchors to rolling `lastPuffAt`, not Freedom Day (docs/03 §6 self-contradicts).
- Dependence badge thresholds follow docs/02 B2 (151–300 = Heavy/orange, 301+ = Severe/red); the Run 1 mock labeling 200 as "Severe" is wrong.
- Home/Money figures are engine-computed, not the mock's "$47"/"$312" (not reproducible under docs/03 §4 math).

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
