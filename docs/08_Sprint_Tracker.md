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
| **Platforms** | **iOS + Android together** | Aug 29, 2026 — overrides PRD §15 item 4 ("iOS-first, Android V2") |
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

### ⛔ Verified blockers

| ID | Blocker | Evidence | Sprint |
|---|---|---|---|
| ~~**B1**~~ | ✅ **RESOLVED Aug 29.** The four modules are written and committed (`09305ad`). **Root cause:** `lib/` in `functions/.gitignore` was unanchored, so it matched `functions/src/lib/` as well as the tsc output — the modules were almost certainly written once and silently never committed. Pattern anchored to `/lib/`. | `npm run verify` green: typecheck + lint + **33 tests / 4 files**, incl. `parsers.test.ts` which could not previously resolve its imports. `npm run build` emits to `lib/src/`; barrel loads all 9 functions. | S0 ✅ |
| **B2** | [UNBLOCKED, not yet deployed] Billing was **already on Blaze** - the tracker assumed an upgrade was needed and that was wrong - and the Cloud Functions API is now enabled, so `functions:list` answers instead of 403. Deps installed, build emits, barrel loads all 9. **Remaining: the two secret values** (`GEMINI_API_KEY`, `REVENUECAT_WEBHOOK_TOKEN`); deploy fails without them. Gen-2 also wants `cloudbuild`/`artifactregistry`/`run`/`eventarc`. | `gcloud billing projects describe alastpuff` -> `billingEnabled: true` | S0 |
| **B3** | **Client cannot call the backend.** No `cloud_functions`, no `firebase_app_check` in `pubspec.yaml`; zero `httpsCallable` in `lib/`. All 5 callables set `enforceAppCheck: true` and would reject the app anyway. | `pubspec.yaml`, import grep | S1 |
| **B4** | **No billing SDK.** No RevenueCat / Superwall / `in_app_purchase`. Paywall is 634 lines of non-transacting UI; "premium" is a client-written enum in the user's *own* Firestore doc; "restore purchases" is a snackbar. | `paywall_screens.dart`, `journey_store.dart:344`, `settings_screens.dart:267` | S1 |
| **B5** | **Community + Coach fake in production.** Their providers have no `switch` on `backendModeProvider` → `FakeCommunityApi`/`FakeCoachApi` on a real phone, over memory that resets on restart. The "AI coach" is `if (text.contains('crav'))` over 18 canned templates. | `lib/data/stores/providers.dart:59-87` | S2, S3 |
| **B6** | **iOS cannot build against Firebase.** No `GoogleService-Info.plist`, no `.entitlements`, no URL schemes for Google Sign-In. | `ios/Runner/` | S0 |
| **B7** | **Zero analytics, crash reporting, push.** `firebase_messaging` declared but never imported. Danger-hour settings schedule nothing. | `pubspec.yaml`, import grep | S4 |
| **B8** | **No local persistence.** No `shared_preferences`/`hive`. Theme, locale, notifications, danger hours all wipe on restart. | `lib/data/stores/settings_store.dart` | S4 |
| **B9** | **Both hourly crons would no-op forever.** They query `users where recalcHourUtc == n`, but `users/{uid}` docs are created only by `syncUserContext`, which nothing calls. | `taperRecalc.ts:42`, `weeklyInsight.ts:49` | S2 |
| **B10** | **`createReply` promised but missing.** Rules set `create: if false` on replies citing a callable that doesn't exist → replies can never be created. `moderatePost` also only triggers on `posts/{postId}`, so replies would go unmoderated. | `firestore.rules:70`, `functions/src/index.ts` | S3 |
| **B11** | **Coach's actual words discarded.** `CoachReplyCodec.decode` reads only `template`/`args`/`showWeekCard`, dropping the `text` field `aiCoachChat` returns — the client would render a canned template instead of Ember's real reply. | `lib/data/dto/coach_codec.dart` | S2 |
| **B12** | **Streak parity broken.** The TS port omits the repair-token exception present in Dart, so the server counts a token-saved day as a break — Ember would quote a lower streak than Home shows. | `streakEngine.ts:21` vs `streak_engine.dart:29-30` | S2 |
| **B13** | 🔨 **HALF DONE.** The `.gitignore` line protecting the service-account key is now **committed** (`09305ad`), so the protection survives a `git checkout`. **Still open: rotate the key** in the GCP console — it sat unencrypted in the working tree and only the founder can rotate it. | `git show HEAD:.gitignore`; key confirmed never tracked | S0 |
| **B14** | **Lock-screen widget absent** though founder-locked for MVP (Doc 3 header). No iOS widget extension target, no Android app widget. | `ios/Runner.xcodeproj` targets, `android/` | S0 decision |
| ~~**B15**~~ | [RESOLVED Aug 29] **The name is Cirrus** (founder). Renamed test-first: 4 keys x 5 locales, `android:label`, `CFBundleDisplayName`, pubspec. Internal identifiers (`last_puff` package, `LastPuffApp`, `undoLastPuff`) deliberately unchanged - no user sees them. **Bundle IDs unchanged and still a founder call:** moving off `com.quitvape.last_puff` means re-registering both Firebase apps. | `flutter test` 52/52; `test/brand_name_test.dart` guards all 5 locales | S0 done |
| **B16** | **No CI, no fastlane, no store assets**, default Flutter launcher icons. | repo root, `assets/` | S0 |
| **B17** | 🆕 **NO macOS / Xcode — the dev machine is Windows.** iOS cannot be built, run, signed, or submitted from here at all. Config files can be written (and the `GoogleService-Info.plist` pulled via `firebase apps:sdkconfig`), but nothing iOS is *verifiable* until it touches a Mac. **This is the single biggest threat to "both platforms Oct 15"** — larger than any code item, because no amount of work here retires it. Options: a Mac, or macOS CI (Codemagic / GitHub Actions `macos` runner); submission still needs the Apple account. | `flutter doctor` on win32; no Xcode toolchain | **S0 — founder decision** |

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
- [ ] `S0-1` Apple Developer Program enrollment ($99/yr) — **start today**
- [ ] `S0-2` App Store Connect: Paid Apps agreement + **banking & tax forms** ← blocks all IAP testing
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
- [ ] `S0-17` Add `ios/Runner/GoogleService-Info.plist`
- [ ] `S0-18` Add URL schemes for Google Sign-In in `Info.plist`
- [ ] `S0-19` Add `Runner.entitlements` — Sign in with Apple + push
- [ ] `S0-20` Verify a clean iOS build reaches the sign-in screen

**Foundation**
- [ ] `S0-21` GitHub Actions CI: `flutter analyze` + `flutter test` + `npm run verify` on every push (B16)
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
- [ ] `S2-7` Panic flow calls `panicSession`; free tier keeps the breathing screen with no AI — **never hard-block mid-crisis** (Doc 4 §7)
- [ ] `S2-8` **Run Doc 4 §9 eval suite — 15/15 required on both models.** Includes prompt-extraction, under-18 redirect, self-harm → 988, and no-dosing-advice cases. Non-negotiable before beta.
- [ ] `S2-9` Verify `MODEL_FREE`/`MODEL_PREMIUM` IDs against Google's live catalog (defaults target the 3.1 line because 2.5 Flash-Lite retires 2026-10-16)
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
- [~] `S3-7` Rules: `reportCount` now increment-only and replies gated on `status == 'live'` (done Aug 29, `test/rules/` 28 tests). **Still open: `reactions` per-user keying** — needs the data-model change from `reactions{emoji: count}` to `reactions{uid: emoji}`
- [ ] `S3-8` `moderatePost` fail-closed on model outage — hold as `pending`, not `live`
- [ ] `S3-9` **Build the moderation queue reader** — nothing on disk can surface `moderation/*`. Required for the Guideline 1.2 24h commitment.
- [ ] `S3-10` Real report / block / delete-own-content paths
- [ ] `S3-11` SOS: 60-min pin, buddy + last-5 notify, "23 people had your back" (Doc 3 §9)
- [ ] `S3-12` Seed the feed — founder posts + beta testers, via `seedTextId` ids so l10n still resolves

**Exit criteria:** two real devices see each other's posts and replies · a blocked post never reaches a reader · the founder can review the flag queue.

---

### S4 — LOOP · Sep 28 – Oct 4

**Goal:** close the hook loop and make the funnel visible.

- [ ] `S4-1` Push permission + FCM handling; the D4 pre-permission screen stops being a mock (B7)
- [ ] `S4-2` `flutter_local_notifications` scheduling danger hours on-device — deliberately *not* a server cron (see `functions/src/index.ts` header)
- [ ] `S4-3` Enforce Doc 3 §8 caps: max 3 pushes/day, quiet hours 23:00–08:00
- [ ] `S4-4` `shared_preferences` so theme/locale/notifications/danger hours **survive restart** (B8)
- [ ] `S4-5` Mixpanel + Firebase Analytics on Doc 2 §7's full event list (`onboarding_start` → `winback_converted`)
- [ ] `S4-6` Crashlytics — `lib/app/app_errors.dart:26` has been holding the slot
- [ ] `S4-7` `onTrialWillEnd` → honest trial-ending push; win-back card 24h after decline ($3.99 founding month)
- [ ] `S4-8` Implement Doc 3 §2's **2-second write coalescing**; every tap currently rewrites the whole journey doc
- [ ] `S4-9` Funnel dashboard saved in Mixpanel with a **>15% per-screen drop-off alert** (Doc 2 §7)
- [ ] `S4-10` StoreKit `in_app_review` at D3 — today it's a pastiche of the native sheet

**Exit criteria:** danger-hour push fires 10 min before a real bucket · settings survive restart · the full onboarding funnel is visible in Mixpanel.

---

### S5 — HARDEN · Oct 5 – Oct 11 · 🚩 **Beta ends Oct 10**

**Goal:** survive review, and survive users.

- [ ] `S5-1` Store listings both platforms — Doc 6 §4 title/subtitle/keywords; **first screenshot = the dependence-badge moment**
- [ ] `S5-2` Privacy labels: "Data not collected for tracking". We ship no ad SDKs — market it (PRD §6)
- [ ] `S5-3` Age rating 17+/18+; medical disclaimer; "support tool, not medical treatment"
- [ ] `S5-4` Privacy policy + terms **live at real URLs**; auto-renew disclosures on the paywall
- [ ] `S5-5` Account deletion via `deleteUserData` — replace `FirebaseAuthRepository.deleteAccount()`'s partial wipe, which leaves `users/{uid}` and community posts behind
- [ ] `S5-6` UGC compliance pack: moderation + report + block + 24h response commitment
- [ ] `S5-7` **Doc 3 §12 acceptance checklist**, all gates — incl. 400 puffs/day × 3 days offline with zero loss, and Comeback ×2 verified at 47h59m / expired at 48h01m
- [ ] `S5-8` **Crash-free ≥ 99.5%** on the beta cohort
- [ ] `S5-9` Widen test coverage — Firebase repositories, onboarding, paywall, entitlement transitions all currently have **zero** tests
- [ ] `S5-10` **Submit to App Store + Play**

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
| 13 | Buddy system — Doc 3 §7/§9 assume it; `functions/README.md` says descoped Aug 2026 | **Descoped.** Buddy UI exists (`lib/features/buddy/`) but has no backend. Decide in S3 whether to hide it |

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
