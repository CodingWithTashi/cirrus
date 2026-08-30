# 📄 DOC 8 — SPRINT TRACKER
## Project "LastPuff" / store name "Cirrus" — the build board

**Version:** 1.0 · **Created:** Aug 29, 2026 · **Depends on:** Docs 1–7 · **Status:** LIVE — this file is updated as work lands.

> **Purpose:** the single source of truth for *what is actually built, what is next, and what stands between today and revenue.* Docs 1–7 say what to build. This says where we are.
>
> **Target: $44,000/month net — Puff Count's documented peak — by month 6 post-launch. Not $10K.**

---

## 0. HOW TO USE THIS FILE

- **Status vocabulary:** `✅ done` (verified, evidence cited) · `🔨 in progress` · `⛔ blocked` · `⬜ not started` · `❓ unverified` (believed done, never checked — treat as not done).
- **Never mark ✅ without evidence.** Every done row carries a file path, a command, or a console URL. This whole document was built from a repo audit precisely because the specs had drifted from reality.
- **Update cadence:** at the end of each working session, and at every sprint boundary.
- **Blocker IDs (`B1`…`B16`) are stable** — tasks reference them so you can trace any task back to the audited defect that created it.
- Docs 1–7 are frozen specs. When this file and a spec disagree, **§7 Spec Conflict Register** is the tiebreaker.

---

## 1. LOCKED TARGETS

| Decision | Value | Set |
|---|---|---|
| **Revenue goal** | **$44,000/mo net by M6 post-launch** (≈ Apr 15, 2027) | Aug 29, 2026 — supersedes PRD §1's $10K/mo |
| **Launch date** | **Oct 15, 2026** — soft launch per Doc 6 §1 | Aug 29, 2026 |
| **Platforms** | **Android at launch; iOS fast-follow** | Aug 29, 2026 - revised. The original "both platforms" call was made before B17 was known: there is no Mac, so iOS cannot be built or submitted at all. Android is already wired (google-services.json, release signing) and is the market Puff Count never entered. |
| **Pricing** | $2.99/wk · $7.99/mo · $39.99/yr · 3-day trial | Founder-locked, PRD §11 |
| **Days remaining to launch** | **47** | as of Aug 29, 2026 |

**The constraint on all new work:** every feature must occupy a stage of the hook loop in Doc 3 §1 — external trigger → internal trigger → ≤1-tap action → variable reward → investment. Features that sit *beside* the loop don't ship.

---

## 2. REVENUE MODEL

### ⚠️ Correction to PRD §13

PRD §13 states blended **net** ARPU ≈ **$9.60/mo** and concludes 1,050 subs ≈ $10.1K net. **That number is gross.** It never applies the 15% store commission PRD §11 cites two sections earlier. Every plan built on $9.60 overstates revenue by ~17%.

Recomputed from the locked prices (`lib/core/utils/lp_pricing.dart`), 15% Small Business commission, 4.348 weeks/month, and PRD §13's own 50/25/25 tier mix:

| Tier | Gross | Net | Net per month | Mix |
|---|---|---|---|---|
| Weekly | $2.99/wk | $2.5415/wk | **$11.05** | 50% |
| Monthly | $7.99/mo | $6.7915/mo | **$6.79** | 25% |
| Annual | $39.99/yr | $33.99/yr | **$2.83** | 25% |

> **Blended net ARPU = 0.50($11.05) + 0.25($6.79) + 0.25($2.83) = $7.93/mo**

Consequence: PRD's own $10K target needs **1,261 active subs, not 1,050**.

### The funnel to $44K/mo net

> **Android-first note (Aug 29).** Per-subscriber economics are unchanged: the prices are the same on Play, and Play's first-$1M rate is also 15%, so **blended net ARPU stays $7.93** and the sub counts below still hold. What changes is *reach*, not unit economics - and honestly, the direction is unclear rather than simply worse. Puff Count has no Android at all (uncontested), but US Gen-Z skews iOS and quit-vaping search volume differs by store. **Do not re-derive the download target from guesses** - the first four weeks of real Play install and conversion data replace the 17,240/month figure. Until then it stands as the iOS-era estimate.

Working backwards at PRD §13's own conversion rates:

| Stage | Required | Rate applied |
|---|---|---|
| **Net MRR** | **$44,000** | target (= $51,765 gross) |
| Active blended subs | **5,549** | ÷ $7.93 net ARPU |
| New subs / month (steady state) | **1,665** | × 30% blended monthly churn |
| Trial starts / month | **2,896** | ÷ 57.5% trial→paid |
| Onboarding completions / month | **12,066** | ÷ 24% trial-start rate |
| **Downloads / month** | **≈ 17,240** | ÷ 70% onboarding completion |

The 15% Small Business rate holds throughout — $44K/mo is $528K/yr, safely under the $1M cliff where it becomes 30%.

### ⚠️ The seasonality problem

Doc 6 §1 treats **10–20K downloads in January alone** as the peak-effort target. This model needs **~17K/month sustained** — and M6 lands in **April 2027**, *after* the New-Year wave decays. PRD §3 notes habit apps swing ~2× between the January peak and the summer trough.

**So the milestone is restated:**
- **Primary gate — hit $44K/mo run-rate during the Jan–Feb 2027 wave (S9).** That is when the volume exists.
- **M6 gate — still be at $44K/mo in April 2027 (S11).** That is a *retention* problem, not an acquisition one.

### Levers, ranked by leverage

| # | Lever | Effect | Where it's worked |
|---|---|---|---|
| 1 | **Churn 30% → 20%** | Cuts required downloads by ~a third (17.2K → 11.5K/mo) | S7, S10 — the single highest-value work post-launch |
| 2 | **Tier mix / price ladder** | $3.99/wk test; fix the "$7.99/mo is 38% cheaper than 4× weekly" cannibalization (PRD §11) | S11 |
| 3 | **Trial→paid** | Superwall tests 1, 5, 6 (Doc 2 §6) | S7 |
| 4 | **Download volume** | Most expensive lever; the one the docs lean on hardest | S8, S9 |

---

## 3. STATUS BOARD

### ✅ Genuinely production-grade

| Area | Evidence |
|---|---|
| **UI layer** — 21 feature folders, ~11.3K lines, all **52/52 design frames** in both themes | `lib/features/`, `docs/design/HANDOFF_COMPLETION.md` |
| **Domain engines** — Taper, Money, Streak, DangerHours, Dependence, InitialJourney; unit-tested | `lib/domain/logic/`, `test/domain/` |
| **19-step onboarding** — full A1→D6 flow, exhaustive switch, age gate at 18 | `lib/features/onboarding/` |
| **Localization** — 5 locales at **646/646 key parity**, zero gaps | `lib/l10n/app_{en,es,fr,de,pt}.arb` |
| **Auth + Journey on Firebase** (Android) | `firebase_auth_repository.dart`, `firebase_journey_repository.dart` |
| **Error/offline handling** — banner, dialogs, crash screen, retry | `lib/core/widgets/lp_error.dart`, `test/widgets/error_handling_test.dart` |
| **Firestore** — `(default)` database live, NATIVE mode; hosting site `alastpuff` provisioned | `firebase firestore:databases:list` |
| **Android release signing** | `android/key.properties` present |
| **Every deployed function has a caller** — the integration gap closed Aug 29 (§11) | `test/data/plan_advice_test.dart`, `test/widgets/{panic_session,weekly_insight,moderation_queue}_test.dart` |

### ⛔ Verified blockers

| ID | Blocker | Evidence | Sprint |
|---|---|---|---|
| ~~**B1**~~ | ✅ **RESOLVED Aug 29.** The four modules are written and committed (`09305ad`). **Root cause:** `lib/` in `functions/.gitignore` was unanchored, so it matched `functions/src/lib/` as well as the tsc output — the modules were almost certainly written once and silently never committed. Pattern anchored to `/lib/`. | `npm run verify` green: typecheck + lint + **33 tests / 4 files**, incl. `parsers.test.ts` which could not previously resolve its imports. `npm run build` emits to `lib/src/`; barrel loads all 9 functions. | S0 ✅ |
| ~~**B2**~~ | [RESOLVED Aug 29] **All 9 functions live** in us-central1 (Node 22, gen-2). Needed 3 service-agent IAM bindings, one retry past first-deploy Eventarc/bucket races, and an Artifact Registry cleanup policy (1 day) so old images stop billing. | `firebase functions:list` -> 9 of 9 | S0 done |
| ~~**B3**~~ | [RESOLVED Aug 29] **The client reaches the backend.** `cloud_functions` + `firebase_app_check` added, App Check debug token registered for emulator-5554, `LpFunctions` is the single door (injects IANA timezone + locale, maps wire errors to the domain taxonomy). Proven on device: signing in wrote a real `users/{uid}` doc via the deployed `syncUserContext`. | `tz=America/New_York`, `locale=en-US`, `recalcHourUtc=5` in production Firestore | S1 done |
| **B4** | **No billing SDK.** No RevenueCat / Superwall / `in_app_purchase`. Paywall is 634 lines of non-transacting UI; "premium" is a client-written enum in the user's *own* Firestore doc; "restore purchases" is a snackbar. | `paywall_screens.dart`, `journey_store.dart:344`, `settings_screens.dart:267` | S1 |
| ~~**B5**~~ | [RESOLVED Aug 29] Coach and community switch on `backendModeProvider`. `FirebaseCoachRepository` calls `aiCoachChat`; `FirebaseCommunityRepository` reads Firestore (rules expose only live) and writes via `createPost`/`createReply`, with `FieldValue.increment` for reactions and reports. **Open sub-item:** `isMine`/`myReactions` are session-scoped until the `reactions{uid: emoji}` change (S3-7). | `lib/data/stores/providers.dart` | S2-S3 done |
| **B6** | **iOS cannot build against Firebase.** No `GoogleService-Info.plist`, no `.entitlements`, no URL schemes. **Deferred to the iOS fast-follow** with B17. Note the plist is not actually hard to get - `firebase apps:sdkconfig IOS <appId>` returns it - the blocker is having no machine to build on. | `ios/Runner/` | iOS fast-follow |
| ~~**B7**~~ | [RESOLVED Aug 29] Crashlytics on both error paths (async errors recorded non-fatal, so the crash-free gate is not understated); `PushService` registers the FCM token through `syncUserContext` and asks permission only from the D4 CTA; `LpAnalytics` emits the docs/02 §7 funnel with `screen_completed` fired centrally. **Still blocked: Mixpanel needs a project token.** | verified on emulator-5554 | S4 done |
| ~~**B8**~~ | [RESOLVED Aug 29] `SettingsPersistence` stores the whole state object, so a field cannot be saved on write and forgotten on read. Restore is not awaited in `build()`; tests pin it off for determinism. | `test/data/settings_persistence_test.dart`, 5 cases | S4 done |
| ~~**B9**~~ | [RESOLVED Aug 29] **The crons have rows to page over.** `syncUserContext` now runs on every path that establishes a session (restore, email, Apple, Google, and journey creation, which is where guest onboarding mints its anonymous uid). `users` went from 0 documents to 1 the moment a real sign-in happened. | production Firestore `users/{uid}` | S2 done |
| ~~**B10**~~ | [RESOLVED Aug 29] `createReply` written and deployed, plus `moderateReply` (moderatePost only triggered on posts, so replies would never have been classified), `replyAuthors` rules, and reply anonymization in `deleteUserData`. | `functions/test/integration/createReply.test.ts` | S3 done |
| ~~**B11**~~ | [RESOLVED Aug 29] `CoachReply.text` threaded through codec, store and view; the model's words render verbatim and templates stay the fallback. Blank text decodes as null so it can never render an empty bubble. | `test/widgets/coach_reply_test.dart`, `dto_roundtrip_test` | S2 done |
| ~~**B12**~~ | [RESOLVED Aug 29] Streak parity fixed — TS had TWO divergences, not one: the missing repair-token clause, and anchoring on `isConfirmed` so a single slip returned 0 and erased the whole streak. | `functions/test/streakEngine.test.ts`, 9 parity cases | S2 done |
| **B13** | 🔨 **HALF DONE.** The `.gitignore` line protecting the service-account key is now **committed** (`09305ad`), so the protection survives a `git checkout`. **Still open: rotate the key** in the GCP console — it sat unencrypted in the working tree and only the founder can rotate it. | `git show HEAD:.gitignore`; key confirmed never tracked | S0 - key rotation still open |
| **B14** | **Lock-screen widget absent** though founder-locked for MVP (Doc 3 header). No iOS widget extension target, no Android app widget. | `ios/Runner.xcodeproj` targets, `android/` | S0 decision |
| ~~**B15**~~ | [RESOLVED Aug 29] **The name is Cirrus** (founder). Renamed test-first: 4 keys x 5 locales, `android:label`, `CFBundleDisplayName`, pubspec. Internal identifiers (`last_puff` package, `LastPuffApp`, `undoLastPuff`) deliberately unchanged - no user sees them. **Bundle IDs unchanged and still a founder call:** moving off `com.quitvape.last_puff` means re-registering both Firebase apps. | `flutter test` 52/52; `test/brand_name_test.dart` guards all 5 locales | S0 done |
| **B16** | **No CI, no fastlane, no store assets**, default Flutter launcher icons. | repo root, `assets/` | S0 |
| ~~**B17**~~ | [ANSWERED Aug 29] No macOS/Xcode on the dev machine. **Resolved by descoping iOS from the Oct 15 launch**, not by fixing the machine. iOS becomes a fast-follow and needs a Mac or macOS CI before it can ship. Everything iOS-shaped (B6, plist, entitlements, StoreKit) moves out of S0-S6. | `flutter doctor` on win32 | iOS fast-follow |

### 🔒 Security & correctness backlog (found in audit, none blocking S0)

| Item | Where | Sprint |
|---|---|---|
| `createPost` trusts client `alias`/`avatarEmoji`/`dayN` with no validation; daily cap is check-then-write, not transactional | `createPost.ts` | S3 |
| ~~`posts` update rule allows arbitrary `reportCount`~~ ✅ **FIXED Aug 29** — reports are now `+1 or nothing`. **`reactions` map contents still unconstrained** — the real fix is per-user keying (`reactions{uid: emoji}`), a data-model change | `firestore.rules`, `test/rules/` | S3 |
| ~~Replies world-readable unmoderated~~ ✅ **FIXED Aug 29** — replies now read only at `status == 'live'`, which also pins the contract `createReply` (B10) must satisfy | `firestore.rules`, `test/rules/` | S3 |
| `rcWebhook` uses non-constant-time token compare; no replay/ordering protection | `rcWebhook.ts:37` | S1 |
| `moderation` queue has **no reader** — no admin UI, no admin claim, nothing surfaces it | `moderatePost.ts` writes only | S3 |
| `aiCoachChat` streaming path logs no token usage → primary path has zero cost telemetry | `aiCoachChat.ts:111-132` | S2 |
| `moderatePost` sets `live` + `flag` on model outage, contradicting its fail-closed docstring | `moderatePost.ts` | S3 |
| Journey persists as one whole-document `set()` per mutation — no merge semantics, so multi-device writes clobber; Doc 3 §2's 2s write-coalescing is unimplemented | `firebase_journey_repository.dart:38`, `journey_store.dart:37` | S4 |

---

## 4. SPRINTS TO LAUNCH — 47 days

### 🔴 The real critical path

Code is **not** the binding constraint. External approvals are, and they run on calendars we don't control:

1. **Apple Developer enrollment + Paid Apps agreement + banking/tax forms** — routinely days to weeks, and **no in-app purchase can be tested until it clears**. This is the classic silent launch-killer.
2. **Google Play Console + merchant account.**
3. **App Review** for an app that is simultaneously nicotine-adjacent, health-claim-adjacent, and UGC-bearing. Guideline 1.2 requires moderation + report + block + a 24h response commitment. Budget 1–2 rounds.

**All three start on day one of S0, before any feature code.**

### ⚖️ Scope decision required in S0 — the widget

Doc 3 marks the lock-screen widget founder-locked for MVP. It is the only MVP item needing **two separate native codebases** (Swift WidgetKit + Kotlin Glance) plus App Group plumbing — Doc 5 §3 budgets 1–2 days of native work *per platform* and warns "don't let the dev skip it."

**Recommendation: slip the widget to V1.1 (S8).** The hook model's External Trigger stage is still covered by danger-hour push, which is far cheaper to build. Everything else in S0–S6 either earns revenue or is required to pass review; the widget does neither on day one.

**If the widget stays in MVP, S4 or S5 must give up something else.** That trade is recorded here rather than made silently. → **Decision owner: founder. Due: Sep 1.**

---

### S0 — UNBLOCK · Aug 29 – Sep 6

**Goal:** clear every hard blocker and start every clock that runs without us.

**Administrative (start Day 1 — these have the longest lead times)**
- [ ] `S0-1` Apple Developer Program enrollment ($99/yr) — **moved to the iOS fast-follow**; not on the Oct 15 path
- [ ] `S0-2` ~~App Store Connect~~ → **Play Console: banking & tax / merchant setup** ← still the long pole, still blocks all IAP testing
- [ ] `S0-3` Google Play Console ($25) + merchant account
- [x] `S0-4` ✅ **Cirrus** (decided Aug 29; rename shipped). Original note: **Name decision (B15):** "LastPuff" vs "Cirrus". Blast radius — ASO title/subtitle/keywords (Doc 6 §4), store listings, domain, TikTok/IG/YT handles, the wordmark concept in Doc 7 §4 (built on the literal "LastPuff" ligature), 3 ARB keys, `AndroidManifest.xml`, `Info.plist`, Firebase display name. **Founder decision.**
- [ ] `S0-5` Doc 7 §1 due-diligence: domain, handles, USPTO/CIPO trademark check — all currently unchecked
- [ ] `S0-6` Widget in-or-out decision (see above)

**Security**
- [x] `S0-7` **Commit the `.gitignore` line** protecting the service-account key — done (`09305ad`); also anchored `functions/.gitignore`'s `lib/` pattern, which was hiding `src/lib/`
- [ ] `S0-7b` **Rotate the service-account key** in the GCP console (B13). Founder-only; it has sat unencrypted in the working tree.

**Backend — make it compile and deploy**
- [x] `S0-8` Write `functions/src/lib/firestore.ts` — `db`, `FieldValue`, `Timestamp`, `journeyDoc`, `userDoc`, `postsCol`, `moderationDoc`, `coachMessages`, `insightDoc`, `UserDoc` type (B1)
- [x] `S0-9` Write `functions/src/lib/guards.ts` — `requireCaller` (uid + `timeZone` + `locale`), `requireText`, `asEnum` (B1)
- [x] `S0-10` Write `functions/src/lib/logger.ts` — `log`, `safeMeta` (B1)
- [x] `S0-11` Write `functions/src/lib/usage.ts` — `tierFor`, `claimCoachMessage`, `refundCoachMessage`, `countPanicSession`. **Transactional**; watch the pre/post-increment boundary that decides the free-tier off-by-one.
- [x] `S0-12` `npm install && npm run verify` green (typecheck + lint + 4 vitest files)
- [ ] `S0-13` Enable Cloud Functions API + **upgrade project to Blaze** (B2)
- [ ] `S0-14` `firebase functions:secrets:set GEMINI_API_KEY` and `REVENUECAT_WEBHOOK_TOKEN`
- [ ] `S0-15` Deploy rules + indexes, then functions. Verify `firebase functions:list` returns 9.
- [ ] `S0-16` Confirm Firestore location matches `REGION`; set a **GCP budget alert** (README checklist)

**iOS — currently unbuildable against Firebase (B6)**
- [ ] `S0-17` *(iOS fast-follow)* Add `ios/Runner/GoogleService-Info.plist` — obtainable now via `firebase apps:sdkconfig`
- [ ] `S0-18` *(iOS fast-follow)* URL schemes for Google Sign-In
- [ ] `S0-19` *(iOS fast-follow)* `Runner.entitlements` — Sign in with Apple + push
- [ ] `S0-20` *(iOS fast-follow)* Verify a clean iOS build — **needs a Mac; cannot be done here**

**Foundation**
- [x] `S0-21` CI running three jobs: Flutter (incl. an l10n-drift check), functions verify, and an emulator job for rules + integration
- [ ] `S0-22` Branded app icons both platforms; replace default Flutter icons (B16)

**Exit criteria:** `npm run verify` green · 9 functions deployed and listed · iOS builds against Firebase · both store accounts submitted with banking started · name decided · key rotated · CI green.

---

### S1 — MONEY · Sep 7 – Sep 13

**Goal:** make one real dollar arrive. Nothing else in this tracker matters if this doesn't work.

- [ ] `S1-1` Add `cloud_functions` + `firebase_app_check` to `pubspec.yaml` (B3)
- [ ] `S1-2` Register App Check (Play Integrity + App Attest) — every callable has `enforceAppCheck: true`, so without this **every call is rejected**; without it enforced, `aiCoachChat` is a public Gemini proxy
- [ ] `S1-3` Add `purchases_flutter` (RevenueCat) (B4)
- [ ] `S1-4` Create products both stores: `weekly_299` · `monthly_799` · `yearly_3999`, 3-day trial on all
- [ ] `S1-5` **Set RevenueCat `app_user_id` = Firebase uid** — `rcWebhook` writes `users/{app_user_id}` and silently depends on this
- [ ] `S1-6` Wire real purchase into `PaywallScreen._startTrial()` and the tier CTAs
- [ ] `S1-7` Real `restorePurchases()` behind both call sites (currently a snackbar)
- [ ] `S1-8` **Replace client-written tier with the server mirror.** `setTier()` writing `profile.tier` into the user's own journey doc is a self-granted entitlement. Read `users/{uid}.entitlement` instead; entitlement flip must apply **within 60s** (Doc 3 §11)
- [ ] `S1-9` `rcWebhook`: constant-time token compare + replay/ordering guard
- [ ] `S1-10` Native fallback paywall if the remote paywall SDK fails to load (Doc 5 §1 mitigation)
- [ ] `S1-11` Sandbox purchase + restore verified **on both platforms**

**Exit criteria:** a sandbox purchase on iOS *and* Android flips `users/{uid}.entitlement`, and the app reflects premium within 60s. Restore works from a clean install.

---

### S2 — BRAIN · Sep 14 – Sep 20 · 🚩 **Beta opens Sep 15**

**Goal:** Ember becomes real. This is the differentiator no competitor has.

- [ ] `S2-1` `coachRepositoryProvider` switches on `backendModeProvider`; add `FirebaseCoachRepository` calling `aiCoachChat` (B5)
- [ ] `S2-2` **`CoachReplyCodec` must read the `text` field** — today it drops it and renders `generic1`, discarding every word Ember says (B11)
- [ ] `S2-3` Call `syncUserContext` on launch + on locale/tz change, so `users/{uid}` exists and **both crons stop no-opping** (B9)
- [ ] `S2-4` FCM token registration through `syncUserContext.fcmTokens`
- [ ] `S2-5` **Fix streak parity (B12)** — port the repair-token exception into `streakEngine.ts`; add a parity test mirroring `streak_and_money_test.dart`
- [ ] `S2-6` Token-usage logging on the **streaming** path (today only the non-streaming branch logs) + a cumulative per-user cost ledger
- [x] `S2-7` Done Aug 29. Panic flow calls `panicSession` on open and on "it passed"; the answer only ever narrows the **AI option**, which becomes the paywall route rather than vanishing. Never awaited by the UI — a craving does not wait on a round-trip. `test/widgets/panic_session_test.dart`
- [ ] `S2-8` **Run Doc 4 §9 eval suite — 15/15 required on both models.** Includes prompt-extraction, under-18 redirect, self-harm → 988, and no-dosing-advice cases. Non-negotiable before beta.
- [x] `S2-9` Done Aug 29 — and the ids were **wrong**: `gemini-3.1-flash` does not exist, so the coach had never answered anybody. Now pinned to `gemini-3.7-flash` / `gemini-3.5-flash-lite`, both verified against production. `aiCoachChat` logs the live catalogue on a 404, so the next wrong id names its own fix instead of failing silently
- [ ] `S2-10` TestFlight + Play closed testing: 30–50 testers from r/QuitVaping per Doc 6 §3 ("50 free lifetime spots")

**Exit criteria:** a real device gets a real Gemini reply that renders as Ember's own words · evals 15/15 · beta build in testers' hands.

---

### S3 — MOAT · Sep 21 – Sep 27

**Goal:** the community goes real. This is the feature Puff Count deleted and our stated moat.

- [ ] `S3-1` `communityRepositoryProvider` switches on backend mode; add `FirebaseCommunityRepository` (B5)
- [ ] `S3-2` Wire `createPost` callable
- [ ] `S3-3` **Write `createReply` (B10)** — rules already deny direct creates citing a callable that was never built — reply read contract already pinned by the rules suite: replies must be written `pending` and flipped by moderation
- [ ] `S3-4` Extend `moderatePost` to trigger on replies too
- [ ] `S3-5` Tighten reply read rule with a `status == 'live'` filter (today any signed-in user reads unmoderated replies)
- [ ] `S3-6` Validate `alias`/`avatarEmoji`/`dayN` server-side against the real journey; make the 3-post cap **transactional**
- [x] `S3-7` Done Aug 29. `reportCount` increment-only, replies gated on status, and reaction counts moved server-side: clients write only `posts/{id}/reactors/{uid}` and `onReaction` derives the aggregate. **Not** `reactions{uid: emoji}` as docs/05 suggests — that would have made every reactor's uid public on a world-readable post
- [ ] `S3-8` `moderatePost` fail-closed on model outage — hold as `pending`, not `live`
- [x] `S3-9` **Moderation queue readable end to end.** Callables built Aug 29; the **client** (contract, repository, store, screen, Settings entry gated on the `admin` claim) landed the same day. The store is deliberately non-optimistic — a refused decision keeps its row, and a failed load never renders as an empty queue. `test/widgets/moderation_queue_test.dart`. **Still founder-side: granting your account the claim.**
- [ ] `S3-10` Real report / block / delete-own-content paths
- [ ] `S3-11` SOS: the 60-min pin is **done** and the panic flow now routes into it (composer pre-tagged `sos`). Still open: notifying the last-5 responders and the "23 people had your back" count (Doc 3 §9). The buddy half of this line is dropped with the buddy system
- [ ] `S3-12` Seed the feed — founder posts + beta testers, via `seedTextId` ids so l10n still resolves

**Exit criteria:** two real devices see each other's posts and replies · a blocked post never reaches a reader · the founder can review the flag queue.

---

### S4 — LOOP · Sep 28 – Oct 4

**Goal:** close the hook loop and make the funnel visible.

- [ ] `S4-1` Push permission + FCM handling; the D4 pre-permission screen stops being a mock (B7)
- [ ] `S4-2` `flutter_local_notifications` scheduling danger hours on-device — deliberately *not* a server cron (see `functions/src/index.ts` header)
- [ ] `S4-3` Enforce Doc 3 §8 caps: max 3 pushes/day, quiet hours 23:00–08:00
- [ ] `S4-4` `shared_preferences` so theme/locale/notifications/danger hours **survive restart** (B8)
- [x] `S4-5` 🔨 **Firebase Analytics complete** — all 16 docs/02 §7 events fire, including `puff_logged`, which the north star (Weekly Active Quitters) cannot be computed without. Per-step events come from the onboarding VM's central choke point; habit events from the store, not the four views that call it. **Mixpanel still needs a project token.**
- [ ] `S4-6` Crashlytics — `lib/app/app_errors.dart:26` has been holding the slot
- [ ] `S4-7` `onTrialWillEnd` → honest trial-ending push; win-back card 24h after decline ($3.99 founding month)
- [ ] `S4-8` Implement Doc 3 §2's **2-second write coalescing**; every tap currently rewrites the whole journey doc
- [ ] `S4-9` Funnel dashboard saved in Mixpanel with a **>15% per-screen drop-off alert** (Doc 2 §7)
- [ ] `S4-10` StoreKit `in_app_review` at D3 — today it's a pastiche of the native sheet

**Exit criteria:** danger-hour push fires 10 min before a real bucket · settings survive restart · the full onboarding funnel is visible in Mixpanel.

---

### S5 — HARDEN · Oct 5 – Oct 11 · 🚩 **Beta ends Oct 10**

**Goal:** survive review, and survive users.

- [ ] `S5-1` **Play** store listing (iOS listing moves to the fast-follow) — Doc 6 §4 title/subtitle/keywords; **first screenshot = the dependence-badge moment**
- [ ] `S5-2` Privacy labels: "Data not collected for tracking". We ship no ad SDKs — market it (PRD §6)
- [ ] `S5-3` Age rating 17+/18+; medical disclaimer; "support tool, not medical treatment"
- [ ] `S5-4` Privacy policy + terms **live at real URLs**; auto-renew disclosures on the paywall
- [x] `S5-5` Done Aug 29. `deleteAccount()` calls `deleteUserData`; it is the **one lifecycle command that is not optimistic** — the dialog awaits it and reports failure, because a deletion that silently failed while the UI said it succeeded is a broken promise, not a sync delay. `test/data/account_deletion_test.dart`
- [ ] `S5-6` UGC compliance pack: moderation + report + block + 24h response commitment
- [ ] `S5-7` **Doc 3 §12 acceptance checklist**, all gates — incl. 400 puffs/day × 3 days offline with zero loss, and Comeback ×2 verified at 47h59m / expired at 48h01m
- [ ] `S5-8` **Crash-free ≥ 99.5%** on the beta cohort
- [ ] `S5-9` Widen test coverage — Firebase repositories, onboarding, paywall, entitlement transitions all currently have **zero** tests
- [ ] `S5-10` **Submit to Google Play**

**Exit criteria:** both submissions in review · crash-free ≥ 99.5% · acceptance checklist green.

---

### S6 — SHIP · Oct 12 – Oct 15

**Goal:** launch.

- [ ] `S6-1` Doc 6 §9 launch-week checklist, all 8 items
- [ ] `S6-2` 20+ real beta testimonials collected (feeds the D3 screen — must be real, per our own honesty positioning)
- [ ] `S6-3` Paywall A/B test #1 armed (3-day vs 7-day trial)
- [ ] `S6-4` Reddit thank-you post to the beta cohort — they carry the first reviews
- [ ] `S6-5` "We're live" video across all channels + waitlist email
- [ ] `S6-6` Launch-day monitoring: crash rate, funnel, AI spend, `AI_COST_PANIC` kill-switch ready

**🚩 Gates to validate (Doc 6 §1):** D1 ≥ 45% · trial start ≥ 20% · crash-free ≥ 99.5%.

---

## 5. POST-LAUNCH TO M6

| Sprint | Dates | Goal | Gate |
|---|---|---|---|
| **S7 Instrument** | Oct 16 – Nov 15 | First MRR. Superwall tests 1–2. **Attack churn — the #1 lever.** Fix the worst funnel drop-off. | Positive MRR; churn trend measured |
| **S8 V1.1** | Nov 16 – Dec 20 | Lock-screen + home widget (if slipped from MVP); **referral loop**; weekly AI insight; 6 SEO posts + the cost calculator live | 100+ video library; ASO climbing |
| **S9 THE WAVE** | Dec 21 – Jan 31 | "Quitters of January" challenge; creator deals live Dec 27 ($3/1K guaranteed views, start with 5); Apple Search Ads from Dec 26 at $20/day, kill anything >$6 CPI | **$44K/mo run-rate** |
| **S10 Defend** | Feb 1 – Mar 15 | Hold through the seasonal trough. Churn work, annual-mix push, FR/DE/PT ASO — **the app is already fully translated**, so this is listing work only | Churn ≤ 20% |
| **S11 Scale** | Mar 16 – Apr 15 | Price ladder ($3.99/wk new users, grandfather existing); cigarette + pouch modes; B2B pilot | **M6: $44K/mo net sustained** |

**Kill criterion (Doc 6 §8):** if by Dec 1 we've posted 100+ videos with <1K downloads, the content angle is wrong — not the market. Shift weight to the best-performing format. *"January is the judge."*

---

## 6. BACKLOG — proposed additions, hook-mapped

Every candidate must occupy a hook stage. Recommendation: take the first two; the rest are wave-timed.

| Addition | Hook stage | Why it earns its place | Target |
|---|---|---|---|
| **Referral loop** — "quit with a friend, both get a month free" | Investment + External trigger | Downloads are the binding constraint at 17.2K/month. A viral coefficient is the only acquisition lever with no per-install cost. Already PRD V1.1; `LpLinks.invite()` exists as a clipboard stub. | S8 |
| **Web vaping-cost calculator** | Top of funnel | Doc 6 §5 already names it the link magnet. Hosting site `alastpuff` is **already provisioned** — zero app risk, pure download upside. | S8 |
| **"Quitters of January" group challenge** | Variable reward + Investment | The biggest acquisition moment of the year; turns a solo streak social exactly when retention matters most. PRD V2 → pull forward. | S9 |
| **Streak insurance as a premium perk** | Investment | Attacks churn, the highest-leverage lever in the model. Extends repair tokens already built. | S10 |

---

## 7. SPEC CONFLICT REGISTER

Resolutions already in code (from `CLAUDE.md`) plus contradictions found across Docs 1–7. **This table is the tiebreaker.**

| # | Conflict | Resolution |
|---|---|---|
| 1 | Taper formula prose vs the worked B=200/P=30 table | **Table wins** — `round(B×(1−d/P)^1.5)` + tail clamps. Pinned by `taper_engine_test.dart` |
| 2 | Health timeline anchor (Doc 3 §6 self-contradicts) | **Rolling `lastPuffAt`** |
| 3 | Dependence thresholds — Run 1 mock labels 200 "Severe" | **Doc 2 B2 wins:** 151–300 Heavy, 301+ Severe |
| 4 | Home/Money figures vs the mock's "$47"/"$312" | **Engine-computed.** "No invented numbers" outranks mock fidelity |
| 5 | Onboarding screen count — PRD §12 "≈14" vs Doc 2 "19" | **Doc 2 wins (19).** Code already implements 19 |
| 6 | Premium coach cap — PRD "Unlimited" vs Doc 4 §7 "100/day soft cap" | **Doc 4 wins.** Marketing may say "unlimited"; the server enforces 100 |
| 7 | AI cost target — PRD "<$0.40/user/mo" vs Doc 5 "<$0.25 blended" | **Doc 5 wins** (stricter) |
| 8 | `taperRecalc` window — Doc 5 §7 "trailing 7-day" vs Doc 3 §3.3 "trailing 3 days" | **Doc 3 wins** — its math is the buildable one and matches `taperEngine.ts` |
| 9 | Apple Watch — PRD §8 V1.1 vs Doc 5 §3 V2 | **Doc 5 wins (V2).** Separate native mini-app |
| 10 | PRD §3 stray "$4.99/wk" | Leftover from before the $2.99 lock. **Ignore** |
| 11 | Name — PRD §15 "OPEN" vs other doc headers vs Firebase "Cirrus" | **RESOLVED Aug 29: Cirrus.** Rename shipped; `docs/01 §15` item 1 is stale |
| 12 | Firestore model — Doc 5 §6 per-day subcollections vs implemented single `journeys/{uid}` doc | **Single doc stands for MVP** (deliberate, documented in `firebase_common.dart`). Revisit if the 1MB ceiling or multi-device merge becomes real |
| 13 | Buddy system — Doc 3 §7/§9 assume it; `functions/README.md` says descoped Aug 2026 | **Descoped, and the UI is now removed** (Aug 29). It rendered an invented friend and its ping pinged nobody. The hook stage it held is the community SOS instead: the panic flow opens the composer pre-tagged `sos`, and live SOS posts pin to the feed for an hour. docs/08 §6's referral loop is the planned S8 return of the idea, with a real backend |

---

## 8. RISK REGISTER

### From PRD §14

| Risk | Severity | Mitigation |
|---|---|---|
| Paid social rejects nicotine-adjacent ads | High | Creator deals + Apple Search Ads + SEO; organic TikTok is the primary engine |
| Apple review: health claims | Medium | Sourced claims only, "support tool not medical treatment", 17+/18+, disclaimer |
| AI cost blowout | Medium | Free caps, model routing, `AI_COST_PANIC` kill-switch, budget alarm at $20/day |
| January seasonality trough | Medium | Annual-plan push each January; V2 modes widen audience |
| Copycats | Medium | Community + brand voice + founder-led content |
| Influencer ops eat founder time | Medium | Fixed 4h/week block; templates; VA by month 4 |
| Solo-founder burnout | High | Fixed content batching days, scope discipline |

### New — found in this audit

| Risk | Severity | Mitigation |
|---|---|---|
| **Apple banking/tax approval slips past Oct 15** | **High** | `S0-2` on day one. No IAP testing is possible until it clears. Most likely single cause of a missed date |
| **App Review rejection on UGC (Guideline 1.2)** | **High** | Full compliance pack in S5; budget 1–2 rounds inside the Oct 5–15 window |
| **Both platforms in 47 days with a solo team** | **High** | The widget slip is the designated release valve. If S2 slips, cut Android to a fast-follow rather than shipping an unreviewed iOS build |
| **AI cost with no cumulative ledger** | Medium | `S2-6`; `maxInstances: 40` and the kill-switch are the current backstops |
| **Two implementations of the same math drift** | Medium | B12 is proof it already happened. Parity tests required both sides for any engine change |
| **$44K by M6 requires sustaining January volume through April** | **High** | Restated as a churn problem: S7 and S10 exist for exactly this |

---

## 9. METRICS

### Weekly scorecard — Sundays, 15 min

Downloads · onboarding completion % · trial start % · trial→paid % · active subs · **net MRR** · blended churn · D1/D7/D30 · crash-free % · AI cost/user · videos posted · best video views.

### Launch gates (Doc 6 §1) — Oct 15

`D1 ≥ 45%` · `trial start ≥ 20%` · `crash-free ≥ 99.5%`

### Guardrails (PRD §13)

D1 ≥ 45% · D7 ≥ 25% · D30 ≥ 12% · craving-survived rate ≥ 70% · store rating ≥ 4.6 · refunds < 3% · **AI cost/user < $0.25/mo** (Doc 5, stricter than PRD) · ≥1 organic video >1M views/month.

### The $44K tracking line

| Month | Downloads/mo | Active subs | Net MRR |
|---|---|---|---|
| M1 (Nov) | — | — | — |
| M3 (Jan) — the wave | ~17,000 | ~5,500 | **$44K run-rate** |
| M6 (Apr) — the real gate | ~17,000 sustained | **5,549** | **$44,000** |

**North star:** Weekly Active Quitters — users who logged ≥4 days/week.

---

*Built from a full repo audit on Aug 29, 2026. Every ✅ and every blocker in §3 carries its evidence. Anything unverified is marked ❓ and treated as not done.*

---

## 10. END-TO-END VERIFICATION LOG

Real runs on a real device against the real backend. Nothing here is inferred.

| Date | What was exercised | Result |
|---|---|---|
| Aug 29, 2026 | Debug APK on `emulator-5554` (Android 17 / API 37) | Installs, launches, `FirebaseApp initialization successful`, no crash |
| Aug 29, 2026 | Brand rename on device | Wordmark renders **Cirrus** |
| Aug 29, 2026 | Email registration → **production Firebase Auth** | Account `e2e012809@…` created, uid `ySMGMESFRoSPOt34…`; verified via `firebase auth:export` |
| Aug 29, 2026 | Post-register routing | Lands on onboarding A1, as the router intends |
| Aug 29, 2026 | Cloud Functions deploy | 9/9 live; `moderatePost` + `aiCoachChat` needed one retry past first-deploy propagation |
| Aug 29, 2026 | **Automated E2E on emulator-5554** — 5 suites, 30 cases, driving the real app (`integration_test/`) | Fake backend: **30/30 green**. Auth, the full 19-step onboarding with real keypad taps and a real 3s hold, logging/undo/repair-tokens/slip, panic, community, coach, settings, all 20 routes, both themes |
| Aug 29, 2026 | E2E against **production Firebase** (`f_firebase_backend_test.dart`) | **8/8 green.** Auth · journey minted + persisted · `syncUserContext` writing `users/{uid}` (B9 proven in production) · a puff reaching the real document · `panicSession` counting a session and recording a survived craving · **Ember answering from the real Gemini model** · `createPost` accepted · `deleteUserData` erasing the account. Three production-blocking bugs had to be fixed to get here — see §12 |

**Test data left in production:** `e2e012809@cirrus.app` from the first session, plus two or three `e2e-*@cirrus-test.app` accounts from the E2E runs — including uid `SyM5xUe3s9ZYFl2tyKQyQbwO0v03`, created before the suite had a teardown. The suite now creates its account in `setUpAll` and deletes it in `tearDownAll`, so a red run no longer strands data. Delete the strays before launch.

**App Check, and the loop that actually works.** `flutter test integration_test` **uninstalls the app when it finishes**, so the App Check debug secret is destroyed and regenerated on the next run — a token registered after a run is already stale. Two further traps: the client backs off after repeated rejections (`Too many attempts`) and then keeps failing even once the token is valid, and `flutter test` overwrites `app-debug.apk` with the instrumented test APK, so a copy has to be kept aside. The sequence that works, every time:

```
flutter build apk --debug --dart-define=LP_BACKEND=firebase
cp build/app/outputs/flutter-apk/app-debug.apk /tmp/cirrus-app.apk
adb install -r -t /tmp/cirrus-app.apk
adb logcat -c && adb shell monkey -p com.quitvape.last_puff -c android.intent.category.LAUNCHER 1
adb logcat -d | grep "debug token"      # token is generated by THIS launch
firebase appcheck:debugtokens:create <token> --project alastpuff   --app 1:826701239342:android:6f8f39f49c52ee24e4bbbf --force
flutter test integration_test/f_firebase_backend_test.dart -d <device>   --dart-define=LP_BACKEND=firebase
```

Repeat from `adb install` for each subsequent run. **Revoke the token when testing ends.**

**Not yet exercised end-to-end on a device:** the coach, the community, moderation, and both crons. B3 is resolved and every one of these now has a client path (§11), so what remains is a device pass against the deployed backend — not missing code. The `taperRecalc` fix in §11 also needs a deploy before the advice a device reads is the corrected one.

---

## 11. THE INTEGRATION GAP — closed Aug 29 (second build session)

The first session ended with a specific, unglamorous finding: **several
functions were deployed, tested and working, and the app never called them.**
Nothing was broken. Nothing failed. The work simply had no client half, which
is the failure mode that survives a demo, a code review and a test suite.

| Was | Now | Pinned by |
|---|---|---|
| `deleteUserData` deployed; the app ran a **client-only** wipe that dropped the journey and the auth record and left `users/{uid}`, the coach transcript, cravings, insights and every community post standing, uid↔post mapping intact | Calls the callable. **The one lifecycle command that is not optimistic** — the dialog awaits it and reports failure. A deletion that silently failed while the UI said it succeeded is a broken promise, not a sync delay | `test/data/account_deletion_test.dart` |
| **2 of 16** docs/02 §7 events wired (`screen_completed`, `age_gate_blocked`) | All 16, incl. `puff_logged` — the north star (Weekly Active Quitters) is uncountable without it | funnel visible in Firebase; Mixpanel still needs a token |
| `panicSession` deployed and never called: sessions uncounted, free-tier AI allowance unenforceable | Called on open and on "it passed". Narrows the **AI option only**, to the paywall rather than to nothing (docs/04 §7 forbids hard-blocking mid-crisis); never awaited by the UI | `test/widgets/panic_session_test.dart` |
| `taperRecalc` wrote `planAdvice` nightly; **0 references in `lib/`** — the taper was the static curve | Read on session start and app resume, folded into the journey, and *shown*: what changed and why. Two guards carry it — advice applies only on the day it is for, and its stretch applies exactly once | `test/data/plan_advice_test.dart` (9 cases) |
| `weeklyInsight` generated a report every Sunday; **0 references** — the screen rendered authored copy over hardcoded bars | Rendered verbatim over charts built from that user's own logs. Authored cards stay the fallback for free tier, short weeks, skipped outages and the demo backend | `test/widgets/weekly_insight_test.dart` |
| `moderationQueue`/`resolveModeration` deployed, `moderation/*` server-only, **nothing could open it** | Contract → repository → store → screen, entry gated on the `admin` claim. Non-optimistic on purpose: a refused decision keeps its row, a failed load never renders as an empty queue | `test/widgets/moderation_queue_test.dart` |

### One real bug found while wiring

`taperRecalc.recalcOne` passed `day` to `adviseTomorrow`, which advises for
`day + 1`, while stamping the result `forDay: todayKey`. Because the cron
overwrites the document nightly, that advice was **replaced before the day it
applied to ever arrived** — the client would have read a limit computed from a
trailing window it never matched. `trailingDays` excludes today, so the run at
local 01:00 has exactly the three completed days needed to advise for the day
that just started. Fixed to `day - 1`, with day 1 skipped (nothing completed to
read). Pinned by `functions/test/integration/taperRecalc.test.ts`.

**Test coverage:** Flutter **106** (was 81) · functions 47 · rules 35 ·
integration 72 — **260 tests**.

**Still open, and still not code:**

| Item | Blocked on |
|---|---|
| Grant the `admin` claim | GCP/Admin SDK — founder only. The queue screen exists and is hidden until this lands |
| Deploy the `taperRecalc` fix | `firebase deploy --only functions` — the fix is committed, not shipped |
| Mixpanel | Project token |
| RevenueCat + `users/{uid}.entitlement` as the gate | Deliberately last, per founder (`B4`, `S1-8`). The client still reads `profile.tier` from its own journey doc; not exploitable today because `tierFor` reads the server mirror, but it must switch the day billing lands |
| `B13` rotate the service-account key · Play Console + banking · a Mac | Founder |

---

## 12. EMBER'S MEMORY — the coach becomes personal (Aug 29)

Founder direction: the coach must be **tailored to the individual**, backed by
a **vector database**, remembering both the onboarding answers and what the
user says — and judged on whether people feel fulfilled enough to keep using
the app. Retention, not chat.

Built as **two layers, kept separate on purpose.**

### Layer 1 — the user card (deterministic, exact, free)

Everything derivable from the journey. It cannot be wrong and costs no model
call, so anything that *can* live here does. It was carrying the numbers only;
it now also carries what the 19-step quiz actually collected:

| Was missing | Why it matters |
|---|---|
| `gender`, `attempts`, `frequency` — **decoded by the app, dropped by the server** | Ember could not tell a first-time quitter from someone on their sixth attempt, or an all-day vaper from a social one. The two facts that most change what is worth *saying* |
| **Savings goals** | "You're 62% of the way to the Tokyo flight" lands; "$312 saved" is a number. Verified live — Ember quoted the goal unprompted |
| **Mood notes and slip triggers** — the user's own words | The most personal thing in the whole document, and the card ignored it. Ember could see a bad day but not "work party tonight, nervous" next to it |

### Layer 2 — semantic memory (`users/{uid}/memories`, Firestore vector search)

For the half no amount of puff logging produces: *"my sister Maya is getting
married in March"*. One embedding of the message, `findNearest` over what they
have said before, injected as background knowledge.

| Decision | Why |
|---|---|
| `gemini-embedding-001` at **768 dims**, pinned in code not config | Recall quality on short first-person sentences is unchanged from 3072, at a quarter the index and storage. Pinned because changing it invalidates every stored vector — a swap needs a re-embed migration, so it is a code change |
| **Asymmetric task types** (`RETRIEVAL_DOCUMENT` / `RETRIEVAL_QUERY`) | A stored fact and the question that should find it are worded nothing alike. This is what closed the gap, and it is free |
| Extraction gated: skips chips and one-liners, runs on the **cheap** model, capped at 2/turn | The only part of the loop that costs money without producing anything the user sees today |
| Near-duplicates **merge**, store **LRU-capped at 200** | Otherwise ten mentions of the same dog fill all five recall slots, and recall latency grows with tenure — the users who earned the best coach would get the slowest one |
| Memories fenced as **background knowledge, never instructions** | Every memory is ultimately user-authored text. Unfenced, recall is a prompt-injection path straight into the system prompt |
| Lives under `users/{uid}` | `deleteUserData`'s `recursiveDelete` already sweeps it — erasure needed no new code |

### The surface: "What Ember remembers"

Settings → Privacy, beside Export and Delete. Lists every memory in plain
language with a **Forget this** button. An AI that quietly accumulates personal
disclosures with no way to look is a thing to be uneasy about — the opposite of
what makes someone keep opening the app — and "we never sell your data" (PRD §6)
is worth less if we cannot show what we hold. Forgetting is **never optimistic**:
a refused delete keeps the row and says so.

### Verified in production, not assumed

`f_firebase_backend_test.dart` is **10/10**. Two cases carry this feature: a
fact stated in one conversation and recalled in a later, differently-worded one
(`memory.recall` logged `kept=2 nearest=0.348`), and the see-it-then-forget-it
round trip.

One tuning note worth keeping: the first version of the recall test asked
*"what am I working toward"*, which the **user card** answers just as well from
the savings goal — so it passed for the wrong reason and then failed for the
right one. The threshold (`RECALL_MAX_DISTANCE`) is the one number here that
cannot be reasoned out from first principles, so `memory.recall` logs what was
considered, what survived, and the nearest distance. Tune it from that, never
from taste.

---

## 13. THE HONESTY PASS (Aug 29)

Founder instruction: *"make sure everything is real, no placeholder or dummy
data anywhere; remove unnecessary UI"* — and then, importantly: *"if the
feature is needed for the hook model, implement the logic rather than removing
it."* That second half changed one of the answers below.

"No invented numbers" is the brand rule (docs/07). It was being broken in the
one place that matters most: data wearing the user's own name.

| Found | Why it mattered | Now |
|---|---|---|
| **`InitialJourney` minted a savings goal ("Tokyo flight, $1300") and a buddy ("Sam, 19-day streak") for every real account** | The Money screen showed progress toward a stranger's holiday. Worse, once the coach's user card learned to read goals it began quoting that holiday back — a fabricated fact laundered into a personal one | Removed. Users set their own goal through the Money screen's existing sheet, which is *stronger* hook investment because it is theirs |
| **The Insight screen invented statistics about the reader** — "You vape 3× more after 10 p.m. on weekends", "Friday and Saturday account for 41% of your weekly puffs", identical for everybody, over hardcoded bars | The single most direct violation in the app, on a screen whose entire value is that the numbers are yours | Honest empty state naming what it is waiting for. The charts went too — a bar with no data behind it is a made-up number in costume |
| **Six controls did nothing but show a success snack** — Export data, Restore Purchases (×2), Support, buddy ping | "Restored" claimed to restore purchases that cannot exist: there is no billing SDK (B4) | Removed. Restore is a store requirement the day subscriptions ship and returns with them (S1-7) |
| **Quit Buddies shipped a full screen of a fabricated friend** | Descoped Aug 2026, no server side, and conflict #13 had been waiting on this decision since S3 | Removed — **but the hook stage was rebuilt, not deleted.** See below |
| 41 dead ARB strings (671 → 632 keys ×5), an unused `LpLinks`, a stale `onboarding-goal` name mapping, and a community alias fallback that would have signed a post `@quietfox` — the seeded demo identity | Dead weight, and one latent identity bug | Gone |

### The one that was nearly a mistake

Deleting the buddy feature also deleted a **stage of the hook loop** — docs/03
§7's "someone else pulls you out". Removing fabricated data is right; removing
the loop stage with it is not, and the founder caught that.

So the panic flow's third loop-breaker came back, implemented: it opens the
composer **pre-tagged `sos`**, live SOS posts already pin to the top of the
feed for an hour, and real quitters answer them. Same stage of the loop, using
only paths already proven end to end (`createPost`, the SOS pin, reactions,
replies). The composer takes its tag via `?tag=sos`, so it is one tap
mid-craving and deep-linkable from a push later. Covered on device by
`d_social_test.dart`.

**The general rule this leaves behind:** when placeholder data is propping up
a real hook stage, replace the stage with something true. Deleting it is the
easy fix and it costs a retention mechanism.

---

## 14. WHAT THE E2E PASS FOUND

Three real bugs, none of which any unit or widget test could have caught,
because all three need a real tree to be built, disposed, or navigated.

| Bug | Impact | Fix |
|---|---|---|
| **`HealthScreen` never painted.** `IntrinsicHeight` asked for a max intrinsic height; the walk reached the connector's `FractionallySizedBox`, whose reveal tween starts at 0. Dividing by zero produced an infinite constraint and layout failed. | Every non-last completed milestone triggered it, so the screen was broken for **every user past day 1, on every device, from the first frame**. It is one tap from Home. | Rebuilt as a `Stack` — positioned children are excluded from intrinsic sizing and get bounded constraints |
| **The panic takeover threw on every close.** `dispose()` read `ref`, which Riverpod forbids once the element is gone. Introduced this session by the `abandon()` wiring. | An uncaught error per craving, routed to `LpErrors` in release. Hid a second bug: `survive()` invalidates the provider, so the `ref.read` would have returned a fresh, unresolved session and counted every survived craving as abandoned too. | Notifier captured in `initState` |
| **`reportPost` counted reports globally, not per post.** One `int` across the whole feed. | Reporting three *different* posts hid the third on its **first** report — innocent content disappearing for the reporter. | Keyed by post id |

| **The AI coach had never worked.** `MODEL_FREE`/`MODEL_PREMIUM` were set to `gemini-3.1-*`, which does not exist: the API answered `404 models/gemini-3.1-flash is not found`. | **Ember returned `connectionLost` to every user, always** — the app's stated differentiator, dead in production. This is tracker item S2-9, and it was invisible: the handler swallowed `ModelUnavailableError` with **no log**, so an outage and "nobody used the coach today" looked identical. | The branch now logs the cause **and, on a 404, the live catalogue** — which is how the right ids were found rather than guessed. Pinned to `gemini-3.7-flash` (premium) and `gemini-3.5-flash-lite` (free + moderation), both **verified answering in production** with real token counts. Nothing on the 2.5 line, which retires 2026-10-16 |
| **The community feed could not load at all.** `fetchPosts` issues `collectionGroup` queries for replies and for the viewer's own reactions; a nested `match /posts/{id}/replies/{id}` does **not** cover a collection-group query, and no `{path=**}` rule existed. | `PERMISSION_DENIED` on every feed load on the real backend — the stated moat, showing its error state to every user. The rules suite stayed green because it only ever read direct document paths. | Added read-only `{path=**}` rules for `replies` and `reactors`, plus 7 rules tests that issue the group queries the app actually issues |
| **The welcome screen overflowed.** Registering opens the keyboard, `context.go(Routes.onboarding)` runs before the IME is dismissed, and step one renders into what is left. | A yellow-and-black overflow stripe on the first screen of the funnel every acquisition number in §2 divides through. | `StepScrollView` — scroll under min-height + IntrinsicHeight, the idiom the auth forms already used. `StepBody` and `WelcomeStep` both use it |

Two harness lessons worth keeping:

- **`flutter test` substitutes a fixed-width fallback font**, so text overflows spuriously. `screen_layout_test.dart` therefore excludes overflow and asserts only on the font-independent class. A sweep that failed on overflow would have reported twenty screens broken that the device lays out cleanly.
- **A regression test that passes with and without the fix is worse than none.** Every fix above is pinned by a test verified to fail against the pre-fix code. The one bug I could not reproduce in a widget test (`showLpSnack`'s backstop asserting on a disposed messenger) is guarded in code and documented here rather than given a test that proves nothing.

**Also verified for the first time:** the `AI_COST_PANIC` kill-switch (S6-6's launch-day backstop). Flipping it routed the coach to the cheap model and back, proven by `coach.turn` logging `model=gemini-3.5-flash-lite` then `model=gemini-3.7-flash` with real token counts — which also confirms the cost telemetry S2-6 asked for.

**Coverage now:** Flutter **229** (from 81 at session start) · E2E **38** on device, of which **8 run against production** · functions 47 · rules 42 · integration 72.

**The pattern in all seven.** Every one needed a real tree, a real device, or a real backend. Three could only ever have been caught in production: a model id that does not exist, a rules path that only a collection-group query reaches, and a keyboard that outlives its screen. No amount of unit or widget testing would have found them, and the app looked completely healthy without them.

---

## 15. STATE AS OF AUG 29, 2026 (end of first build session)

**Closed:** B1 B2 B3 B5 B7 B8 B9 B10 B11 B12 B15 B17 · plus two live security holes and one concurrency bug found by tests rather than by reading.

**Still open, and why:**

| Item | Blocked on |
|---|---|
| `B13` rotate the service-account key | GCP console — founder only |
| `B14` lock-screen widget | Deferred to V1.1 by the S0 scope decision |
| `B16` fastlane + store assets | Nothing — CI is done, these are not |
| `isMine` on a post | Undecidable without exposing `postAuthors` to readers, which is what keeps the feed anonymous. Session-scoped on purpose |
| Mixpanel | Needs a project token |
| RevenueCat / `ENTITLEMENT_MODE=mirror` | Deliberately last, per founder |
| Play Console, banking | Founder |

**Test coverage:** Flutter 81 · functions 47 · rules 35 · integration 67 — **230 tests**, from 0 runnable at session start.

**Deployed:** 14 Cloud Functions, Firestore rules (three times — the second closed two live holes, the third took reaction counts away from clients), indexes.

---

## 16. THE "NOTHING WORKS" SESSION (Aug 30)

Founder report: *"ai is not even working shows 'signal dropped mid…', nothing
seems working at the moment."*

**The backend was never broken.** All 16 functions were deployed with real
traffic; Gemini had answered with real token counts and vector recall had
worked (`nearest=0.348`) hours earlier. `flutter test` was 234/234 green and
`npm run verify` 64/64.

### The one cause, and why it looked like ten

`AppCheck token was rejected` on `aiCoachChat`, `panicSession` and
`syncUserContext`, in production logs, for every call from the device. Debug
builds used `AndroidDebugProvider()`, whose secret **rotates on every
install** — and `flutter test integration_test` uninstalls the app when it
finishes, so a token registered after a run was already stale.

Every callable sets `enforceAppCheck: true`, so the coach, panic, community
and user-sync all died at the same gate. And a gen-2 callable answers a failed
App Check with the same `unauthenticated` it uses for a missing user, which
the client filed under `NoConnectionException` — so **Ember told users who
were demonstrably online to try again once they reconnected**, and the real
cause was never named on any screen or in any log.

Fixed by pinning the debug secret (`AndroidDebugProvider` takes a `debugToken`,
so it is pure Dart — no native factory) and by giving a refused build its own
place in the taxonomy. `BackendRejectedException`, its own copy in five
locales, `CoachTemplate.backendRejected`, and a launch-time diagnostic that
prints whether a token was obtainable at all — which immediately earned itself
by catching a Pixel dozing with network restricted.

### Everything else was a last-hop disconnection

The pattern in almost every remaining defect: a feature fully built, unit
tested, and then discarding its own output one line from the finish.

| Built | Discarded at | Effect |
|---|---|---|
| `ReminderPlanner` computes hour + minute, coordinator fingerprints them | `periodicallyShow` ignores both and repeats every 24h **from the call** | The danger-hour nudge fired at whatever moment the app last synced. Forever. |
| Server stores both coach turns and feeds the model ten | Client returned an empty thread on build | Cold start looked like meeting Ember for the first time while it recalled last week |
| `aiCoachChat` has a streaming branch and `sendChunk` | Client called the callable unary, so `acceptsStreaming` was always false | The most alive thing in the product arrived as a finished paragraph after a spinner |
| `panicIntensity` + `PANIC_MODE_ADDENDUM` written and ready | No client ever sent it | A 9/10 craving got the same open-question register as a quiet Tuesday |
| FCM token collected on every sign-in | Nothing ever read the field; no handlers; `onTokenRefresh` had zero subscribers | Push dead end to end, and a device identifier held for no reason |
| Settings "Danger hours" editor persists a window | Nothing read it | The control controlled nothing |
| `moderateReply` writes `moderation/{replyId}` | Queue hydrated from the parent post; resolve wrote `moderation/{postId}` | Reply flags showed the wrong content, could never be resolved, returned daily |

### Invented numbers, again

- `_sosBackupBase = 17` — a constant floor under "N people have your back", on
  the one screen whose value is that somebody real is there. Now replies +
  reactions, hidden at zero.
- `replyingNow: tag == sos ? 3 : 0` — your own new post claimed three people
  were replying. The field is deleted: no backend could ever compute it.
- The reply flag was `showLpSnack('Reported')` with no repository call, under a
  comment reading "flagging a reply is one tap" — on the one surface
  Guideline 1.2 is actually about.

### Ship blockers found on the way

- **The frame map shipped to users.** Reachable from Settings and from the
  sign-in screen *before anyone signs in*; it seeds the demo day-12 fixture for
  anyone without a journey, which then syncs to Firestore. Now `kDebugMode`.
- **Registering orphaned the guest.** `register()` created a fresh account
  instead of linking the anonymous one, stranding the whole 19-step journey.
- **The Comeback badge was awarded by nothing** and inflated the "N/17" figure.
- **Under-18 resources copied a string to the clipboard** instead of opening.

### Verified

| What | Result |
|---|---|
| `f_firebase_backend_test` against production | **10/10**, three runs |
| Streaming reached production | `coach.turn` logging `streaming=True` with real token counts — a path that previously logged nothing at all |
| App Check rejections after the fix | **zero** |
| Flutter unit + widget | **279** (from 234) |
| Functions pure suite | **76** (from 64) |

**Still open, and honestly so:** billing remains out of scope by founder
decision (`ENTITLEMENT_MODE=ungated`); rules (42) and functions-integration
(72) run in CI only, because there is no Java on the dev machine; the
moderation queue cannot be opened on a device until the `admin` claim is
granted; Terms and Privacy stay plain text until the policy pages exist,
because a link to a 404 looks like the document exists.

### Closing the rest of it (Aug 30, later)

**The emulator suites were never CI-only.** Android Studio ships a JDK at
`Android Studio/jbr`, which is all the Firestore emulator needed. `test:rules`
and `test:integration` run locally in about twenty seconds, and the first thing
they did was catch three breakages from the `postId` → `flagId` change that
could not have been verified any other way.

Every server handler now has a test. Previously only their pure helpers did,
which is the wrong shape of coverage for this backend: `rcWebhook` is an
unauthenticated public endpoint granting entitlements, and every failure branch
of `aiCoachChat` returns a *cheerful* envelope, so an outage and a quiet day
look identical.

| Suite | Was | Now |
|---|---|---|
| Flutter unit + widget | 234 | **310** |
| functions pure | 64 | **76** |
| functions integration | 72 | **163** |
| rules | 42 | 42 |
| On-device E2E (fake) | 30 | 30 |
| On-device E2E (production) | 10 | 10 |

**Two more real bugs, both found by writing the tests:**

- **Upgrading from inside the app left you on the paywall.** `setTier` bumps
  the router's `refreshListenable`, Riverpod delivers that asynchronously, and
  the refresh rebuilt the match list a microtask later and restored the pushed
  route. `canPop()` said true, the pop visibly did nothing. Navigate first,
  mutate second.
- **Reply flags addressed the wrong document** in both directions — already
  fixed earlier that day, now actually verified against the emulator.

**Terms and Privacy are live** at `alastpuff.web.app/privacy` and `/terms`,
written from what the code actually does — what is stored, who processes it,
what `deleteUserData` erases, and that Ember's memory is readable and
deletable in Settings. The app footer links to them. `S5-4` is closed except
for a legal read-through, which is a founder call, not an engineering one.

**Still open, and all of it founder-side:** billing (`ENTITLEMENT_MODE=ungated`
by decision), the `admin` claim that makes the moderation queue openable on a
device, the service-account key rotation (`B13`), Play Console and banking,
Mixpanel's token, store assets and icons (`B16`), and iOS — which needs a Mac.

