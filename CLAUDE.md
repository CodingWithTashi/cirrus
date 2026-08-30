# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

LastPuff — a quit-vaping Flutter app (store name **Cirrus**). The data layer is **API-shaped with two backends behind one seam**: session lifecycle and all persistence go through async repositories over the domain contracts. `backendModeProvider` picks who answers — **mobile (Android/iOS) runs real Firebase**, while desktop/web/tests stay on the in-memory `FakeServer` demo backend with simulated latency (everything resets on restart there). `--dart-define=LP_BACKEND=fake|firebase` overrides the platform default. **Every** contract switches on that provider now: auth, journey, community, coach, panic, moderation, and the server-state reads.

The **TypeScript Cloud Functions backend in `functions/`** is deployed and live on project `alastpuff`, and the app calls it through `LpFunctions`. See "Server (`functions/`)" below.

**`docs/08_Sprint_Tracker.md` is the live build board** — what is actually done, what is blocked, and the current targets ($44K/mo net by M6; **Android at launch Oct 15 2026, iOS a fast-follow** — there is no Mac, so iOS cannot be built or submitted at all). Read it before planning work; it supersedes the revenue and phasing numbers in `docs/01`.

## Commands

```
flutter pub get                              # install deps (also triggers l10n codegen)
./tool/device.ps1                            # build+install+run on device vs REAL Firebase
./tool/device.ps1 -Test                      # the on-device E2E suites
flutter run                                  # run on connected device/emulator
flutter test                                 # all tests (must stay green)
flutter test test/domain/taper_engine_test.dart   # single test file
flutter test --plain-name "streak"           # tests matching a name
flutter analyze                              # lint (flutter_lints defaults)
flutter gen-l10n                             # regenerate l10n after editing .arb files
```

Server (`functions/`, npm — run from that directory):

```
npm install                                  # first run only
npm run verify                               # typecheck + lint + vitest — THE deploy gate
npm test                                     # vitest only
npm run serve                                # build + emulators (functions, firestore, auth)
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only functions             # predeploy runs `verify`, so a red gate blocks it
```

## Architecture

Strict MVVM with Riverpod 2.x `Notifier`s as view models, layered as a one-way dependency chain:

- `lib/domain/` — pure Dart, no Flutter imports. Models (`models.dart`, `journey_state.dart`, `enums.dart`), **async backend contracts** (`repositories/repositories.dart`: `AuthRepository`, `JourneyRepository`, `CommunityRepository`, `CoachRepository`, `PanicRepository`, `ModerationRepository`, `ServerStateRepository`, `UserContextRepository`, plus the `AuthException` types), and the calculation engines in `logic/`: `TaperEngine`, `MoneyEngine`, `StreakEngine`, `DangerHours`, `DependenceEngine`. All displayed numbers come from these engines — the brand rule is "no invented numbers", so never hardcode a stat a mock shows.
- `lib/data/` — the backend-shaped stack, bottom-up:
  - `api/` — typed wire interfaces speaking `Map<String, dynamic>` JSON (`AuthApi`, `JourneyApi`, `CommunityApi`, `CoachApi`); `api/fake/` implements them over `FakeServer`, the in-memory JSON "database" (accounts, journey docs, posts; latency via `apiLatencyProvider`, tests override to zero). **FakeServer invariant: every op mutates synchronously, only the ack is delayed** — this keeps write-behind clients and server-computed coach args consistent.
  - `dto/` — hand-rolled JSON codecs (`JourneyCodec`, `PostCodec`, `CoachReplyCodec`, `codec_helpers.dart`). Day-map keys are `'yyyy-MM-dd'` **local midnight** (never epoch math); enums encode by `.name` with safe fallbacks. **Any new model field must be added to its codec AND `test/data/dto_roundtrip_test.dart`.**
  - `repositories/` — thin `Api*Repository` implementations of the domain contracts (JSON ↔ domain only, no logic), plus the real backend: `FirebaseAuthRepository`/`FirebaseJourneyRepository` (`firebase_common.dart` holds the shared journey-doc helpers and `guardAuth`, the ONE place Firebase/Google error codes map to the domain taxonomy — `network-request-failed` → `NoConnectionException`, dismissed native sheets → `SignInCancelledException`). The journey persists as a single Firestore doc `journeys/{uid}` of `JourneyCodec` JSON; guest onboarding (Frame Map) falls back to anonymous auth. Both backends mint identical day-1 journeys via `domain/logic/journey_factory.dart` (`InitialJourney.build`).
  - `stores/` — Riverpod view models. `JourneyStore`: awaited async lifecycle (`logIn`/`register`/`signInWithApple`/`restoreSession`/`startJourney`; optimistic sync `signOut`/`deleteAccount`/`seedDemoJourney`), and **every other mutation is synchronous + optimistic through `_commit(next)`** = set state + `unawaited(save)` write-behind — views may read fresh state right after a command; keep new mutations on that pattern. `providers.dart` is the composition root and documents the backend swap point: REST replaces `api/fake/`, Firebase replaces either the Api or Api*Repository bodies; stores and views never change.
  - `seed/seed_data.dart` — the demo day-12 journey (single source; the fake backend serializes it through the codecs, so the JSON round-trip runs in production code).
- `lib/features/<name>/` — one folder per screen/flow. Views read state via providers and issue commands through `.notifier`. Async lifecycle CTAs pass `busy:` to `LpButton` and guard navigation with `mounted` after awaits.
- `lib/app/` — `router/app_router.dart` (go_router with a `StatefulShellRoute` 4-tab shell: Home/Stats/Community/Coach; all route paths live in the `Routes` class) and the theme. The router redirects journey-requiring paths to `/auth` while `journey == null`, but **deliberately allows authed visits to `/auth` and `/onboarding`** so the Frame Map can preview every screen — don't "fix" that. Lifecycle callers must set journey state **before** navigating into gated paths (awaiting the store call does this).
- `lib/core/` — shared widgets (`LpCard`, `LpChip`, charts, `RollingNumber`, `ProgressRing`, `NewIdConfetti`, `PushPreviewCard`, …) and utils. **All price strings live only in `core/utils/lp_pricing.dart` (`LpPricing`)** — reuse, don't duplicate.

### Server (`functions/`) — deployed and live

TypeScript Cloud Functions 2nd gen on `alastpuff`, us-central1. `index.ts` is a thin barrel: `aiCoachChat`, `panicSession`, `syncUserContext`, `deleteUserData`, `createPost`, `createReply`, `moderatePost`, `moderateReply`, `moderationQueue`, `resolveModeration`, `onReaction`, `reportReply`, `coachMemories`, `forgetCoachMemory`, `matchedTestimonials`, `setCoachName`, `taperRecalc`, `weeklyInsight`, `rcWebhook`. (`dangerHourPush` from docs/05 §7 is deliberately absent — danger-hour reminders are deterministic, so they're scheduled on-device.) Layout: `ai/` (the `TextModel` seam — only `ai/gemini.ts` imports a vendor SDK, so swapping providers is one new implementation; all prompts live in `ai/prompts.ts`), `domain/` (a TS port of the Dart engines), `handlers/`, `lib/`, `config.ts` (secrets/params via `defineSecret`/`defineString`; production values in the committed `.env.alastpuff`).

**Four things that will bite you here, each of which already did:**

1. **`LpFunctions` (`data/api/firebase/functions_client.dart`) is the only door** from the app. It injects the IANA timezone and locale that every callable's `requireCaller` reads, and maps wire failures to the domain taxonomy. Never call `FirebaseFunctions` directly.
2. **Every callable sets `enforceAppCheck: true`,** so a token the backend will not accept breaks *everything* at once — coach, panic, community, user sync — and it does not look like an App Check problem. The debug secret used to rotate on every install, and `flutter test integration_test` uninstalls the app when it finishes, so a token registered after a run was already stale. It is **pinned** now: `AndroidDebugProvider` takes a `debugToken`, supplied via `--dart-define=LP_APPCHECK_DEBUG_TOKEN` from the gitignored `.appcheck_token` (a registered debug token bypasses attestation project-wide, so it is a credential). Use `./tool/device.ps1` so the define is never forgotten. **A gen-2 callable answers a failed App Check with the same `unauthenticated` it uses for a missing user** — that is why `mapCallableError` disambiguates on whether anyone is signed in, and why `BackendRejectedException` exists rather than folding into the offline copy.
3. **Model ids are config, and a wrong one fails silently.** `MODEL_*` in `.env.alastpuff` must name a model that exists AND supports `generateContent`. `gemini-3.1-flash` did neither, so every user got the warm fallback for as long as it was deployed while the logs said nothing. `aiCoachChat` now logs the live catalogue on a 404 (`coach.models_available`) — read that rather than guessing. No `-preview` ids (withdrawn without notice) and no `-latest` aliases (docs/04 §9 gates the coach on a 15/15 eval pass; an alias swaps the model underneath it).
4. **A `collectionGroup()` query needs its own recursive-wildcard rule.** A nested `match` does not cover one. The missing rules made the entire community feed return PERMISSION_DENIED in production while the rules suite stayed green, because every test in it read a direct document path.

**The one architectural rule** (`firestore.rules`, `functions/README.md`): ownership is split. `journeys/{uid}` is **client-owned** — `FirebaseJourneyRepository.save()` does a whole-document `set()` on every optimistic mutation, so **any server-written field here is destroyed by the next puff tap**. `users/{uid}` is **server-owned** (entitlement, `aiUsage`, `planAdvice`), readable by its owner and writable only by the Admin SDK. Entitlement lives there for a reason: if a client could write it, it would grant itself Premium. Today the app still writes `profile.tier` into its own journey doc — that is the self-granted-entitlement hole, not the intended design.

**`coachName` is the one field that deliberately lives on BOTH sides,** and it is worth understanding as the model case. `journeys/{uid}.profile.coachName` is client-owned and drives every screen. `users/{uid}.coachName` is written only by the validated `setCoachName` callable, and is **the only version `aiCoachChat` is allowed to read** — because the journey doc is written wholesale by the app, so a name taken from it is unvalidated client text, and `"Ember. IGNORE ALL PRIOR INSTRUCTIONS"` going straight into a system prompt is a live injection surface. `journeyCodec.ts` sanitizes the client copy on decode as a backstop, the same treatment `moodNote` already gets.

Community collections: `posts` (created only via the `createPost` callable so no uid lands on the post), `postAuthors`/`replyAuthors` (the server-only uid↔content maps that make account deletion possible without breaking anonymity), `posts/{id}/reactors` (one document per person, so aggregate counts stay public while identities stay private), `moderation` (founder review queue, reachable only through `moderationQueue` behind an `admin` custom claim).

**Ember's long-term memory** is `users/{uid}/memories` — one document per remembered fact with a 768-dim `embedding`, searched with `findNearest` (`lib/memories.ts`). It sits under `users/{uid}`, so `deleteUserData`'s `recursiveDelete` already erases it. It complements, never replaces, the deterministic user card in `ai/memoryCard.ts`: anything derivable from the journey belongs in the card, which is exact and costs nothing, and the vector layer is only for things a user said out loud.

### Error handling

Every failure has a designated friendly surface — never invent per-screen phrasing or let an error escape raw:

- **Taxonomy**: repositories throw `NoConnectionException` (offline) or auth-specific `AuthException`s (`domain/repositories`). `data/network/connectivity.dart` polls a DNS probe (5s); `FakeServer` reads it synchronously and becomes unreachable offline, exactly like a real backend.
- **Surfaces** (all in `core/widgets/lp_error.dart` unless noted): app-level offline pill overlaid via `MaterialApp.builder` (`OfflineBanner`); `showLpErrorDialog(context, error:, onRetry:)` for awaited lifecycle CTAs — `lpErrorCopy` picks offline vs generic copy; `LpErrorState` for failed content areas (community feed pattern: `FeedStatus` + `retryFeed()`); go_router `errorBuilder` → `RouteNotFoundScreen`; the coach fails in-thread via `CoachTemplate.connectionLost` (and refunds the free message); `LpCrashScreen` (core/widgets) replaces the red error box — it may render in a broken tree, so it's the ONE place with non-ARB copy and raw palette hexes (annotated); `LpErrors.install()` (app/app_errors.dart, called in main) routes uncaught async errors to a throttled "backstage" snack.
- **Local-first stance**: optimistic mutations `.ignore()` wire failures (`_commit`, community write-behinds) — the banner tells the story; never surface a dialog for a background save. `restoreSession` failure lands on sign-in, never a stuck splash.
- **Tests**: anything that pumps the app or wires the fake backend must use `fastBackendOverrides()` from `test/helpers.dart` (pins `BackendMode.fake` — the test platform reports android, which would otherwise construct the Firebase repositories — plus zero latency + polling off; `online: false` simulates airplane mode). No Firebase mocks anywhere. Error surfaces are covered in `test/widgets/error_handling_test.dart`.

### Testing

Four layers, and each catches something the others structurally cannot:

- `flutter test` — unit + widget. Fast, runs everywhere, and the only one CI gates on for the app.
- `flutter test integration_test -d <device> --dart-define=LP_BACKEND=fake` — **the real app on a real device.** The only harness that sees disposal, the router, a torn-down tree, or a keyboard. It found three bugs no widget test could have.
- `integration_test/f_firebase_backend_test.dart` with `LP_BACKEND=firebase` — **writes to production.** Creates one throwaway account in `setUpAll` and deletes it in `tearDownAll`. Read `integration_test/README.md` first: App Check makes this fiddlier than it looks.
- `functions/`: `npm run verify` is the deploy gate (typecheck + lint + vitest). `npm run test:rules` (42) and `npm run test:integration` (163) need the Firestore emulator, which needs Java — **Android Studio ships one**, so they run here:
  ```
  export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"   # PowerShell: $env:JAVA_HOME=...
  export PATH="$JAVA_HOME/bin:$PATH"
  ```
  Two traps in the integration suite, both of which cost a debugging round: deploy-time params resolve to **0** with no `.env` loaded (a coach `limit` of 0 makes every call answer `capReached` before reaching the model, so stub them), and `vi.useFakeTimers()` freezes the timers the Firestore SDK itself runs on — use `toFake: ['Date']` or every await hangs to the timeout.

Anything that pumps the app must use `fastBackendOverrides()`; see the Error handling section.

### Demo model (fake backend only)

The sign-in screen gates its identity buttons by `defaultTargetPlatform`: Apple on iOS/macOS, Google on Android, email everywhere. On the fake backend, email login (any email; password < 6 chars = "wrong", enforced in `FakeAuthApi`, not views) restores the seeded day-12 journey (@quietfox). "Sign in with Apple"/register open a fresh account → 19-step onboarding → paywall → the backend creates the day-1 journey. Within one app session, mutations persist across logout→login (write-behind JSON on `FakeServer`); registering the demo email `maya@quitmail.com` fails as already-in-use. The Frame Map (`/frames`, reachable from the sign-in screen) lists the design frames; `seedDemoJourney()` keeps its jumps synchronous — don't make them await.

### Theming

Two palettes as an `LpColors` `ThemeExtension` — Midnight Ember (dark, brand default) and Daylight Ember (light). Widgets read semantic tokens via `context.lp`; **never raw hex in widgets** (the only sanctioned exception is annotated: the Apple sign-in button. The iOS rating-sheet link blue went with the fake StoreKit pastiche it existed for). `lp.caution`/`lp.cautionText` are the only sanctioned yellows. `LpChip` maps accent colors to text tokens itself — pass `selectedColor: lp.oxygen`/`lp.ember`, never a text color. Fonts: Space Grotesk (display) + Inter (body), bundled in `assets/fonts`.

### Localization

Zero hardcoded UI strings. ARB files in `lib/l10n/app_{en,es,fr,de,pt}.arb`, generated into `lib/l10n/gen` (never edit generated files). Use `context.l10n` (`core/utils/l10n_ext.dart`). Content that lives in data is stored as ids/enums and resolved to l10n in views: coach replies via `CoachTemplate` enums, community seed posts via `seedTextId`, seeded goal names via ids (g1/g2 — the demo journey only; real goals carry the user's own words). ARB templates must not add symbols around already-formatted values (e.g. no extra '%' around a formatted percent). **A string that interpolates a user-supplied name must be grammatically valid with that name treated as an indeclinable proper noun requiring no article, no elision and no gendered agreement** — pt drops the article on both sides, fr never elides and repeats `{name}` rather than using `il`, de avoids the genitive-s. `test/coach_name_test.dart` renders all 14 name-bearing keys × 5 locales × 3 probe names to enforce it, and `test/l10n_parity_test.dart` pins that every locale interpolates exactly the values English does — a translator dropping a `{placeholder}` compiles fine and silently renders a sentence with a hole in it.

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
- **Quit Buddies is descoped** (founder decision Aug 2026, `functions/README.md`) and the UI is **removed** — it rendered an invented friend and its ping pinged nobody. The hook stage it held (docs/03 §7, someone else pulling you out) is now the community SOS: the panic flow opens the composer pre-tagged `sos`, and live SOS posts pin to the top of the feed for an hour. The referral loop in docs/08 §6 is the planned S8 return of that idea; build it there, with a real backend.

## Gotchas (each was a real bug — don't reintroduce)

- `TweenAnimationBuilder` with a begin-less `Tween(end:)` never animates its first build — `RollingNumber`, `GlowProgressBar`, `BarChart`, `ProgressRing` all carry an explicit `begin`.
- `BarChart` must fold (not `reduce`) — callers pass runtime `List<int>` into a `List<num>` param and `reduce`'s covariant `combine` throws.
- `StreakEngine.currentStreak` skips an unconfirmed today (anchors to yesterday) so an in-progress day dims the flame instead of zeroing it — unit-tested.
- Seed data: a day's actual puffs must stay ≤ that day's curve limit or the streak chain silently breaks.
- `PanicFlow` clears snackbars on entry (the 5s undo snack otherwise outlives the route push and covers "Skip to my why").
- `showLpSnack` carries a fallback timer that force-closes the snack at `duration + 250ms` — the framework skips its own timeout for action snack bars under accessible navigation (which some environments report spuriously), leaving "Undo" snacks up forever. Don't remove it; route all snacks through `showLpSnack`.
- **A bare `Column` overflows the moment the viewport shrinks.** Auth forms use `_AuthScrollView` and onboarding steps use `StepScrollView` — both scroll under a min-height + `IntrinsicHeight`, which preserves the `Spacer()`s that pin a CTA to the bottom. The path that catches it: registering opens the keyboard and `context.go(Routes.onboarding)` runs before the IME is dismissed, so step one renders into what is left.
- The FakeServer's connectivity gate reads the connectivity store **synchronously** (never await a probe inside `respond`) — an async gap there breaks the sync-apply invariant.
- App-pumping tests without `fastBackendOverrides()` do real DNS lookups and leak the 5s poll timer.
- **Never write a server-owned field onto `journeys/{uid}`.** The client `set()`s the whole document on every optimistic mutation, so the next puff tap silently destroys it. Server state goes in `users/{uid}`.
- **Two implementations of the same math drift, and already have** — `streakEngine.ts` once omitted the repair-token exception `streak_engine.dart` applies, so the server counted a token-saved day as a break. Fixed and pinned by parity cases on both sides. Any change to a shared engine must land in both `test/domain/*_test.dart` and `functions/test/*.test.ts`, or the coach starts quoting numbers the Home screen contradicts.
- `CoachReplyCodec.decode` must keep reading `text` — it once read only `template`/`args`/`showWeekCard`, so every word the model said was discarded and rendered as the canned `generic1` template. A blank `text` decodes to null so it can never render an empty bubble.
- **`IntrinsicHeight` asks its child for a max intrinsic height, and that walk reaches everything below it.** A `FractionallySizedBox` whose factor animates from 0 reports an infinite intrinsic height on the first frame, which fails layout outright. It took the whole Health screen down for every user past day 1. Prefer a `Stack` with positioned children — they are excluded from intrinsic sizing and get bounded constraints.
- **A `refreshListenable` fires AFTER the frame, so navigate before you mutate.** The paywall set the tier and then popped; Riverpod delivered the router's refresh a microtask later, the match list was rebuilt, and the imperatively pushed route came back — `canPop()` returned true, the pop visibly did nothing, and the user was left on the paywall they had just paid past. `leavePaywall()` runs first, the state change second.
- **`open(path, 'w')` truncates before the write that fails.** Editing an ARB with line surgery destroyed 432 lines of `app_en.arb` when a surrogate pair failed to encode mid-write, and emptied `frame_map_screen.dart` when a stray comma made the payload a tuple. Edit ARBs through a JSON round-trip, and write every generated file to a temp path then `os.replace`.
- **Never invent data that renders as the user's own.** `InitialJourney` used to mint a savings goal ("Tokyo flight") and a buddy ("Sam") for every account; the Insight screen used to show four authored "findings" about the reader. Both read as the user's own data and both broke the no-invented-numbers rule harder than a wrong stat would. An honest empty state is always the right answer.
- **A control that only shows a success snack is worse than a missing one.** Export, Restore Purchases and the buddy ping all claimed to have done something and did nothing. If it cannot do the thing, it does not ship.
- `flutter test` substitutes a fixed-width fallback font, so **widget tests overflow where the device does not**. `screen_layout_test.dart` therefore excludes overflow and asserts only on the font-independent failures (infinite/unsatisfiable constraints, unlaid-out boxes). Real overflow is caught on device.
- **A local notification must be `zonedSchedule`d.** `periodicallyShow` repeats every 24h *from the moment it is called* and ignores the hour and minute entirely, so the danger-hour reminder fired at whatever moment the app last synced — planner correct, coordinator correct, feature silently useless. And build the next occurrence as the next CALENDAR day: `add(Duration(days: 1))` adds 24 absolute hours, which moves the reminder an hour across a DST boundary.
- **The frame map is `kDebugMode`-only.** It opens every screen and seeds the demo day-12 fixture for anyone without a journey, which then syncs to Firestore like any other mutation. It was reachable from Settings and from the sign-in screen, before sign-in.
- **Riverpod forbids `ref` in `dispose()`.** Capture the notifier in `initState` instead. Doing it the other way threw on every close of the panic flow — and hid a second bug, because `survive()` invalidates the provider, so a late `ref.read` would hand back a fresh, unresolved session.
- Counters that gate a UI decision must be **keyed by the thing they count**. `CommunityStore.reportPost` used one int across the whole feed, so reporting three *different* posts hid the third on its first report.
- **A day key is calendar arithmetic, never `Duration(days: n)`.** `LpDate` (`lib/domain/date_key.dart`) mirrors `functions/src/domain/dateKey.ts` name-for-name and is the one place local midnight is computed. `StreakEngine` used to walk the chain with `cursor.subtract(const Duration(days: 1))` — 24 *absolute* hours — against a map keyed by local midnight, so on a DST day it landed on 23:00 or 01:00 of the previous date, missed the key, and **reset every user's Freedom Streak to zero, twice a year**. Reproduced at 10 days → 3. The zone is implicit on the client and must never become a parameter: the moment a caller can pass one, some caller passes UTC.
- **Neither store lets you ask for a rating before the system prompt.** Apple 1.1.7 and Google Play's In-App Review policy both prohibit review gating, and Play forbids asking the user's opinion at all before presenting the rating card — including a star picker that routes every value identically. The five-star row on D3 belongs to the *testimonial*, not to the user. And neither OS reports whether its sheet appeared or what happened, so nothing may claim a rating was submitted.
- **`Ember` is also a palette token and a wire value.** `lp.ember`/`emberSoft`/`emberGlow`, `CoachRole.ember` (encoded by `.name`, so renaming it reclassifies every stored message) and one of the eight `_randomAlias` adjectives. A repo-wide find-and-replace takes all of them; `test/coach_name_test.dart` guards against it.
- `functions/alastpuff-*-adminsdk-*.json` is a live service-account private key. It must stay gitignored and must never be committed; deployed functions use Application Default Credentials and don't need it.
