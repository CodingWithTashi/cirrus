# 📄 DOC 8 — SPRINT TRACKER
## Project "LastPuff" / store name "Cirrus" — the build board

**Version:** 2.0 · **Created:** Aug 29, 2026 · **Split:** Sep 2, 2026 — session history moved to `docs/10_Build_Log.md` · **Depends on:** Docs 1–7 · **Status:** LIVE — this file is updated as work lands.

> **Purpose:** the single source of truth for *what is actually built, what is next, and what stands between today and revenue.* Docs 1–7 say what to build. This says where we are.
>
> **Target: $44,000/month net — Puff Count's documented peak — by month 6 post-launch. Not $10K.**

---

## 0. HOW TO USE THIS FILE

- **Status vocabulary:** `✅ done` (verified, evidence cited) · `🔨 in progress` · `⛔ blocked` · `⬜ not started` · `❓ unverified` (believed done, never checked — treat as not done).
- **Never mark ✅ without evidence.** Every done row carries a file path, a command, or a console URL. This whole document was built from a repo audit precisely because the specs had drifted from reality.
- **Update cadence:** at the end of each working session, and at every sprint boundary.
- **Blocker IDs (`B1`…`B17`) are stable** — tasks reference them so you can trace any task back to the audited defect that created it.
- Docs 1–7 are frozen specs. When this file and a spec disagree, **§7 Spec Conflict Register** is the tiebreaker.

---

## 1. LOCKED TARGETS

| Decision | Value | Set |
|---|---|---|
| **Revenue goal** | **$44,000/mo net by M6 post-launch** (≈ Apr 15, 2027) | Aug 29, 2026 — supersedes PRD §1's $10K/mo |
| **Launch date** | **Oct 15, 2026** — soft launch per Doc 6 §1 | Aug 29, 2026 |
| **Platforms** | **Android at launch; iOS fast-follow** | Aug 29, 2026 - revised. The original "both platforms" call was made before B17 was known: at the time there was no Mac, so iOS could not be built or submitted. **Sep 1 2026: a Mac with Xcode 26.3 is on the desk and the iOS build runs on a physical iPhone with Sign in with Apple (B6)** — the launch order stands, the machine constraint is gone. Android is already wired (google-services.json, release signing) and is the market Puff Count never entered. |
| **Pricing** | $2.99/wk · $7.99/mo · $39.99/yr · **7-day trial** | Founder-locked, PRD §11. Trial length changed 3 → 7 days on Sep 1, 2026 (§7 #14) |

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

> **Sep 1 note:** the 57.5% trial→paid rate was assumed for a 3-day trial. The trial is now 7 days (§7 #14). A longer trial usually converts a smaller share of starts at a better-retained LTV, so the sub counts above are no longer internally consistent — re-baseline this row from the first four weeks of Play data rather than guessing a new rate.

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
| 2 | **Tier mix / price ladder** | **Annual first: $59.99/yr for new users** (§7 #28 — $39.99 is a *low-priced* annual in H&F terms, $17 install LTV vs $70), *then* the $3.99/wk test; fix the "$7.99/mo is 38% cheaper than 4× weekly" cannibalization (PRD §11) | S11 |
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
| **Every deployed function has a caller** — the integration gap closed Aug 29 (docs/10 §2) | `test/data/plan_advice_test.dart`, `test/widgets/{panic_session,weekly_insight,moderation_queue}_test.dart` |

### ⛔ Verified blockers

| ID | Blocker | Evidence | Sprint |
|---|---|---|---|
| ~~**B1**~~ | ✅ **RESOLVED Aug 29.** The four modules are written and committed (`09305ad`). **Root cause:** `lib/` in `functions/.gitignore` was unanchored, so it matched `functions/src/lib/` as well as the tsc output — the modules were almost certainly written once and silently never committed. Pattern anchored to `/lib/`. | `npm run verify` green: typecheck + lint + **33 tests / 4 files**, incl. `parsers.test.ts` which could not previously resolve its imports. `npm run build` emits to `lib/src/`; barrel loads all 9 functions. | S0 ✅ |
| ~~**B2**~~ | [RESOLVED Aug 29] **All 9 functions live** in us-central1 (Node 22, gen-2). Needed 3 service-agent IAM bindings, one retry past first-deploy Eventarc/bucket races, and an Artifact Registry cleanup policy (1 day) so old images stop billing. | `firebase functions:list` -> 9 of 9 | S0 done |
| ~~**B3**~~ | [RESOLVED Aug 29] **The client reaches the backend.** `cloud_functions` + `firebase_app_check` added, App Check debug token registered for emulator-5554, `LpFunctions` is the single door (injects IANA timezone + locale, maps wire errors to the domain taxonomy). Proven on device: signing in wrote a real `users/{uid}` doc via the deployed `syncUserContext`. | `tz=America/New_York`, `locale=en-US`, `recalcHourUtc=5` in production Firestore | S1 done |
| **B4** | **Code resolved Sep 2** (docs/10 §14). RevenueCat is wired end to end: `purchases_flutter` behind `BillingRepository`, the Cirrus paywall opens the store sheet, Restore is real on the paywall and in Settings, `profile.tier` is gone from the journey and the client tier is `entitlementProvider`. The Play public key (`billing_options.dart`) and the dashboard secrets landed Sep 2. **Open (founder):** RevenueCat's Play credential check (the service-account grant in Play Console), the `default` offering's `$rc_weekly` package, and the sandbox purchase + restore on device (S1-11). | `lib/data/repositories/revenuecat_billing_repository.dart`, `lib/data/stores/entitlement_store.dart`, `functions/src/handlers/rcWebhook.ts` | S1 · open: dashboard + sandbox |
| ~~**B5**~~ | [RESOLVED Aug 29] Coach and community switch on `backendModeProvider`. `FirebaseCoachRepository` calls `aiCoachChat`; `FirebaseCommunityRepository` reads Firestore (rules expose only live) and writes via `createPost`/`createReply`, with `FieldValue.increment` for reactions and reports. ~~**Open sub-item:** `isMine`/`myReactions` are session-scoped until the `reactions{uid: emoji}` change (S3-7).~~ `myReactions` moved to `reactors/{uid}` (S3-7); **`isMine` resolved Sep 1** — decided by the backend per account through the `users/{uid}/posts` mirror (docs/10 §13, H3). | `lib/data/stores/providers.dart` | S2-S3 done |
| ~~**B6**~~ | [RESOLVED Sep 1] **iOS builds against Firebase and signs in with Apple.** `ios/Runner/Runner.entitlements` (Sign in with Apple) wired via `CODE_SIGN_ENTITLEMENTS` on all three Runner configs under automatic signing (team `PZFFFQ5T9X`); App Check debug token registered for the **iOS app id** by hand with `firebase appcheck:debugtokens:create` (the two Firebase apps are separate registrations); deployment target 15.0 to match the Firebase 12 pods. **Not needed after all:** `GoogleService-Info.plist` (init goes through `DefaultFirebaseOptions.ios`) and URL schemes (Google is not offered on iOS). Verified on a physical iPhone: Apple sheet → Firebase `apple.com` user → `syncUserContext` wrote `users/{uid}` through App Check. Still open for submission: S0-23 (token revocation on delete), S0-24 (App Attest), push entitlement. | `ios/Runner/Runner.entitlements`, `test/app_smoke_test.dart`, `test/widgets/sign_in_identity_test.dart` | iOS fast-follow — unblocked |
| ~~**B7**~~ | [RESOLVED Aug 29] Crashlytics on both error paths (async errors recorded non-fatal, so the crash-free gate is not understated); `PushService` registers the FCM token through `syncUserContext` and asks permission only from the D4 CTA; the docs/02 §7 funnel fires with `screen_completed` emitted centrally. **Fully resolved Aug 30:** Amplitude takes the product-analytics slot docs/05 reserved for Mixpanel, behind the `AnalyticsSink` seam — the vocabulary (`domain/analytics/lp_events.dart`) and the vendors (`data/analytics/`) are now separate, and `FanOutAnalytics` sends one event to both Amplitude and Firebase Analytics. Swapping or dropping a vendor is one entry in `analyticsProvider`. Reports from the **release build only** (`kReleaseMode`), so profile runs and `flutter test` stay out of the funnel the drop-off alert reads. | verified on emulator-5554; `test/analytics_test.dart` (9 cases) | S4 done |
| ~~**B8**~~ | [RESOLVED Aug 29] `SettingsPersistence` stores the whole state object, so a field cannot be saved on write and forgotten on read. Restore is not awaited in `build()`; tests pin it off for determinism. | `test/data/settings_persistence_test.dart`, 5 cases | S4 done |
| ~~**B9**~~ | [RESOLVED Aug 29] **The crons have rows to page over.** `syncUserContext` now runs on every path that establishes a session (restore, email, Apple, Google, and journey creation, which is where guest onboarding mints its anonymous uid). `users` went from 0 documents to 1 the moment a real sign-in happened. | production Firestore `users/{uid}` | S2 done |
| ~~**B10**~~ | [RESOLVED Aug 29] `createReply` written and deployed, plus `moderateReply` (moderatePost only triggered on posts, so replies would never have been classified), `replyAuthors` rules, and reply anonymization in `deleteUserData`. | `functions/test/integration/createReply.test.ts` | S3 done |
| ~~**B11**~~ | [RESOLVED Aug 29] `CoachReply.text` threaded through codec, store and view; the model's words render verbatim and templates stay the fallback. Blank text decodes as null so it can never render an empty bubble. | `test/widgets/coach_reply_test.dart`, `dto_roundtrip_test` | S2 done |
| ~~**B12**~~ | [RESOLVED Aug 29] Streak parity fixed — TS had TWO divergences, not one: the missing repair-token clause, and anchoring on `isConfirmed` so a single slip returned 0 and erased the whole streak. | `functions/test/streakEngine.test.ts`, 9 parity cases | S2 done |
| **B13** | **Half resolved Aug 29.** The `.gitignore` rule protecting the service-account key is committed (`09305ad`; a glob since Sep 2, so a rotated key stays covered) and the key was never tracked. **Open: rotate the key** in the GCP console — it sat unencrypted in the working tree and only the founder can rotate it. | `git show HEAD:.gitignore`; key confirmed never tracked | S0 · open: rotation |
| **B14** | **Lock-screen widget absent** though founder-locked for MVP (Doc 3 header). No iOS widget extension target, no Android app widget. | `ios/Runner.xcodeproj` targets, `android/` | S0 decision |
| ~~**B15**~~ | [RESOLVED Aug 29] **The name is Cirrus** (founder). Renamed test-first: 4 keys x 5 locales, `android:label`, `CFBundleDisplayName`, pubspec. Internal identifiers (`last_puff` package, `LastPuffApp`, `undoLastPuff`) deliberately unchanged - no user sees them. **Bundle IDs unchanged and still a founder call:** moving off `com.quitvape.last_puff` means re-registering both Firebase apps. | `flutter test` 52/52; `test/brand_name_test.dart` guards all 5 locales | S0 done |
| **B16** | ~~No CI~~ **CI done** (S0-21 — `.github/workflows/ci.yml`: Flutter analyze + test + l10n-drift check, functions `verify`, an emulator job for the rules + integration suites). ~~Default launcher icons~~ **branded icons done** Aug 30 (`flutter_launcher_icons` from `assets/images/cirrus.png`, S0-22). **Open: no fastlane, no store assets.** | `.github/workflows/ci.yml`; `pubspec.yaml` `flutter_launcher_icons:` | S0 · open: fastlane + store assets |
| ~~**B17**~~ | [ANSWERED Aug 29] No macOS/Xcode on the dev machine. **Resolved by descoping iOS from the Oct 15 launch**, not by fixing the machine. iOS becomes a fast-follow and needs a Mac or macOS CI before it can ship. Everything iOS-shaped (B6, plist, entitlements, StoreKit) moves out of S0-S6. **Superseded Sep 1:** the dev machine is now a Mac (Xcode 26.3, iPhone paired wirelessly); iOS builds and runs — see B6. Launch order unchanged. | `flutter doctor` on win32; `flutter devices` on darwin | iOS fast-follow |
| ~~**B18**~~ | [RESOLVED Sep 2] **Play rejected the build for `USE_EXACT_ALARM`** — restricted to calendar and alarm-clock apps. It was never used: both `zonedSchedule` calls have always been `inexactAllowWhileIdle`, the branch that never checks the permission. Both exact-alarm permissions removed. The same pass found the load-bearing entry that WAS missing — `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver` were never declared, so every reminder this app has ever scheduled fired into nothing (docs/10 §16). **Open (founder):** re-upload to all tracks, clear the App content exact-alarm declaration if it was submitted, and eyeball a real nudge on device. | `test/android_manifest_test.dart` (6); the built `app-release.aab` has neither permission and both receivers | S0 · open: resubmit |
| ~~**B19**~~ | [RESOLVED Sep 2] **Play console: "your manifest includes the `AD_ID` permission — answer 'yes' or remove it."** Nothing in this app reads an advertising ID; `firebase_analytics` merged it in transitively (`play-services-measurement-api:23.2.0`, blame report line 1255), which is why it looked like a false alarm. It was not — the permission WAS in the shipped bundle, and Amplitude's `TrackingOptions.adid` defaults to **true**, so the SDK attached an advertising ID to every Android event using the `play-services-ads-identifier` library Firebase drags in. Founder decision Sep 2 2026: **remove, not declare** — docs/05 defers an MMP to month 3+ and the launch engine is organic, so the ID buys nothing and would put an advertising identifier on the Data Safety form of a quit-nicotine app. Removed in the manifest (`tools:node="remove"` on `AD_ID` + `ACCESS_ADSERVICES_AD_ID`) AND in the SDK (`TrackingOptions(adid: false)`) — one decision, two files. `ACCESS_ADSERVICES_ATTRIBUTION` stays: Privacy Sandbox measurement, not an identifier, unrestricted. **Open (founder):** answer **No** to the console question, and keep Data Safety free of an advertising ID (pairs with `S4-9`). | `test/android_manifest_test.dart` (6); rebuilt `app-release.aab` permission dump has neither AD_ID | S0 · open: console answer |
| **B20** | **Play payments profile: BillDesk KYC due Sep 15 2026.** Play Console banner on every page: *"Sales to users outside of India will be paused if your payments profile primary contact does not complete KYC verification with BillDesk by September 15, 2026."* The application is logged as *in progress*. If it lapses, Cirrus stays installable everywhere but **cannot sell a subscription outside India** — which is the entire $44K model, three weeks before an Oct 15 launch. Play warns the review "may include document reviews, live video calls, and location verification", so it is not a same-day task. Primary contact **tengurmey36@gmail.com**; documents go to **onboarding@billdesk.com**. **Open (founder), and the hardest deadline on this board.** | Play Console → any page banner; Kharag Edition, account `5910382695653514663` | S0 · founder |
| **B21** | **The live store listing advertises a home-screen widget that does not exist.** The published description says it twice — *"A home screen widget lets you count puffs without opening the app"* and, under FREE FOREVER, *"Puff counter, widget, streaks…"*. There is no widget: one Kotlin file (`MainActivity.kt`), no `home_widget` dependency, no Glance, no `AppWidgetProvider`, no iOS extension — see **B14**, which says so directly. This is a misrepresentation on the store page, a guaranteed one-star theme, and a direct breach of the honesty positioning the product is built on. Two ways out: **cut both claims now** and restore them when the widget ships, or pull the widget forward. **Open (founder).** | live listing `com.quitvape.last_puff`; `pubspec.yaml`; `android/app/src/main/kotlin/` | S5 · founder |

### 🔒 Security & correctness backlog (found in audit, none blocking S0)

| Item | Where | Sprint |
|---|---|---|
| `createPost` trusts client `alias`/`avatarEmoji`/`dayN` with no validation; daily cap is check-then-write, not transactional | `createPost.ts` | S3 |
| ~~`posts` update rule allows arbitrary `reportCount`~~ ✅ **FIXED Aug 29** — reports are now `+1 or nothing`. **`reactions` map contents still unconstrained** — the real fix is per-user keying (`reactions{uid: emoji}`), a data-model change | `firestore.rules`, `test/rules/` | S3 |
| ~~Replies world-readable unmoderated~~ ✅ **FIXED Aug 29** — replies now read only at `status == 'live'`, which also pins the contract `createReply` (B10) must satisfy | `firestore.rules`, `test/rules/` | S3 |
| ~~`rcWebhook` uses non-constant-time token compare; no replay/ordering protection~~ ✅ **Fixed Sep 2** — `timingSafeEqual`, and every event triggers a fetch-and-reconcile of the subscriber snapshot, so ordering and replay fall out (S1-9, docs/10 §14) | `rcWebhook.ts` | S1 |
| ~~`moderation` queue has **no reader** — no admin UI, no admin claim, nothing surfaces it~~ ✅ **Fixed Aug 29** — `moderationQueue` + `resolveModeration` callables and the admin-claim-gated Settings screen (S3-9); the founder still has to grant the claim | `functions/src/handlers/moderationQueue.ts`, `test/widgets/moderation_queue_test.dart` | S3 |
| ~~`aiCoachChat` streaming path logs no token usage → primary path has zero cost telemetry~~ ✅ **Fixed Aug 29** — both paths log `inputTokens`/`outputTokens` on `coach.turn` (docs/10 §5); the cumulative per-user ledger is still open (S2-6) | `aiCoachChat.ts` | S2 |
| ~~`moderatePost` sets `live` + `flag` on model outage, contradicting its fail-closed docstring~~ ✅ **FIXED Aug 31** — `hold` action, fail-closed on every failure path, slur prefilter; see S3-8 | `moderatePost.ts`, `ai/moderation.ts`, `ai/prefilter.ts` | S3 |
| Journey persists as one whole-document `set()` per mutation — no merge semantics, so multi-device writes clobber; Doc 3 §2's 2s write-coalescing is unimplemented | `firebase_journey_repository.dart`, `journey_store.dart` | S4 |

---

## 4. SPRINTS TO LAUNCH — Aug 29 → Oct 15, 2026

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
- [x] `S0-1` Apple Developer Program enrollment — done; team `PZFFFQ5T9X` (Individual, paid) signs the iOS build with automatic signing
- [ ] `S0-2` ~~App Store Connect~~ → **Play Console: banking & tax / merchant setup** ← still the long pole, still blocks all IAP testing
- [~] `S0-3` Google Play Console ($25) + merchant account *(Play Console exists — products created Sep 2 (S1-4); merchant/banking stays S0-2)*
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
- [x] `S0-13` Enable Cloud Functions API + **upgrade project to Blaze** (B2) *(landed Aug 29 — B2; a gen-2 deploy presupposes Blaze)*
- [x] `S0-14` `firebase functions:secrets:set GEMINI_API_KEY` and `REVENUECAT_WEBHOOK_TOKEN` *(landed — Gemini answers in production since Aug 29; the RevenueCat secrets went into Secret Manager Sep 2, docs/10 §14)*
- [x] `S0-15` Deploy rules + indexes, then functions. Verify `firebase functions:list` returns 9. *(landed Aug 29 — 9 then; 23 functions deployed today, `functions/src/index.ts`)*
- [ ] `S0-16` Confirm Firestore location matches `REGION`; set a **GCP budget alert** (README checklist)

**iOS — currently unbuildable against Firebase (B6)**
- [x] `S0-17` ~~Add `ios/Runner/GoogleService-Info.plist`~~ **Not needed:** `main.dart` initializes with `DefaultFirebaseOptions.ios` (`firebase_options.dart`), so there is no plist to ship
- [x] `S0-18` ~~URL schemes for Google Sign-In~~ **Not needed:** Google is Android-only in the sign-in screen (`_showGoogle`); iOS offers Apple + email
- [x] `S0-19` `Runner.entitlements` — **Sign in with Apple done (Sep 1)**; `CODE_SIGN_ENTITLEMENTS` on Debug/Release/Profile, automatic signing adds the capability to the App ID on build. Push (`aps-environment`) deliberately not added yet: it needs the Push capability on the App ID and an APNs key in Firebase, and a build fails signing until both exist
- [x] `S0-20` Clean iOS build verified Sep 1 on a physical iPhone (iOS 18.6, wireless) via `flutter run --dart-define-from-file=.dart_defines.json`: Apple sign-in, App Check token accepted (pinned debug secret), `syncUserContext` wrote `users/{uid}`. Deployment target 15.0 (Firebase 12 pods)
- [ ] `S0-23` *(iOS submission)* **Revoke the Apple token on account deletion** — App Store 5.1.1(v). `deleteUserData` does not revoke today; the client side is `FirebaseAuth.revokeTokenWithAuthorizationCode`, which needs a fresh authorization code (re-run the Apple sheet at deletion) and the Apple private key configured on the Firebase Apple provider. Not needed for dev-device sign-in
- [~] `S0-24` *(iOS submission)* **App Attest for the release build** — `AppleAppAttestProvider` is already the release provider in `app_check_setup.dart`; register the iOS app's Team ID under App Check in the Firebase console and add the App Attest capability before the first TestFlight build, or every callable fails on release. **Sep 2: this is exactly what the first TestFlight build did** — the coach answered "the server didn't recognise this app" and step two of the Day-1 walkthrough could not complete (docs/10 §17). The app half is done: `com.apple.developer.devicecheck.appattest-environment` is in `Runner.entitlements`. **Open, founder-only:** Firebase console → App Check → iOS app → App Attest with Team ID `PZFFFQ5T9X`, then a new TestFlight build

**Foundation**
- [x] `S0-21` CI running three jobs: Flutter (incl. an l10n-drift check), functions verify, and an emulator job for rules + integration
- [x] `S0-22` Branded app icons both platforms; replace default Flutter icons (B16) *(landed Aug 30 — `flutter_launcher_icons` from `assets/images/cirrus.png`, both platforms)*

**Exit criteria:** `npm run verify` green · 9 functions deployed and listed · iOS builds against Firebase · both store accounts submitted with banking started · name decided · key rotated · CI green.

---

### S1 — MONEY · Sep 7 – Sep 13

**Goal:** make one real dollar arrive. Nothing else in this tracker matters if this doesn't work.

- [x] `S1-1` Add `cloud_functions` + `firebase_app_check` to `pubspec.yaml` (B3) *(landed Aug 29 — B3)*
- [~] `S1-2` Register App Check (Play Integrity + App Attest) — every callable has `enforceAppCheck: true`, so without this **every call is rejected**; without it enforced, `aiCoachChat` is a public Gemini proxy *(release providers wired in `app_check_setup.dart` and debug tokens registered for both apps (B3, B6); the release fingerprints / App Attest registration in the console is unverified (S0-24))*
- [x] `S1-3` Add `purchases_flutter` (RevenueCat) (B4) — Sep 2. One importer: `revenuecat_billing_repository.dart`; everything above speaks `BillingRepository` (fake on `FakeServer` everywhere else)
- [~] `S1-4` Products. **Play (created Sep 2):** subscription `cirrus_premium`, base plans `weekly-299` · `monthly-799` · `yearly-399` (the yearly id as created — permanent, so the catalogue carries it; §7 #16), 7-day trial offer on each. **App Store:** `weekly_299` · `monthly_799` · `yearly_3999` in group "Premium" — still to create (docs/10 §14). RevenueCat: entitlement `cirrus_pro` (§7 #15) with all three Play products attached; offering `default`, packages `$rc_annual` `$rc_monthly` (+ `$rc_weekly` to add)
- [x] `S1-5` **RevenueCat `app_user_id` = Firebase uid** — Sep 2. `EntitlementStore` binds `logIn(uid)` on every session (`_onSessionEstablished`) and, for guests, mints the anonymous uid BEFORE the sheet (`AuthRepository.ensureSessionId`), so a purchase is never filed under an `$RCAnonymousID`. Google/Apple sign-in now LINKS a guest instead of replacing them, so the uid — and the purchase — survive sign-in
- [x] `S1-6` Real purchase in `PaywallScreen._startTrial()` — Sep 2. Purchase first, journey second; cancelled/pending/refused/offline each have their own honest ending; live store prices with the locked USD figures only as a labelled fallback; disclosure + Terms/Privacy/Restore on the paywall
- [x] `S1-7` Real `restorePurchases()` — Sep 2. Paywall link + Settings row; says "nothing to restore" when that is the answer
- [x] `S1-8` **Client-written tier removed** — Sep 2. `profile.tier`, `setTier()` and `isPremium` are gone; the client tier is `entitlementProvider` fed by RevenueCat's customer record (instant after a purchase, cached for offline launches); the server keeps trusting only its mirror. Old journey docs still carrying `tier` decode fine and drop it on the next save
- [x] `S1-9` `rcWebhook` — Sep 2. Constant-time compare, and the event is now a TRIGGER: the handler fetches the subscriber snapshot from RevenueCat (`GET /v1/subscribers`) for every id the event names and mirrors that, so ordering, duplicates, CANCELLATION-vs-EXPIRATION, BILLING_ISSUE grace and TRANSFER (which carries no `app_user_id` at all — the old handler answered it 400) all fall out. Needs the new `REVENUECAT_SECRET_API_KEY` secret. `deleteUserData` now erases the RevenueCat customer too
- [x] `S1-10` Native paywall — the Cirrus paywall IS the paywall (founder pick Sep 2: no RevenueCat Paywalls, no Superwall); when the offering cannot load it shows the locked prices under a caption saying the store shows the exact price
- [ ] `S1-11` Sandbox purchase + restore verified **on both platforms** — blocked on docs/10 §14's dashboard steps (public key, webhook secret, secret key, Play license tester)

**The `ENTITLEMENT_MODE=mirror` flip (added Sep 3 — `docs/12 §4.4`).** Production is still `ungated`, so `tierFor()` returns `premium` for everyone and **every server limit is inert**: every account has an uncapped coach, unlimited panic AI and open posting. **There is nothing to buy, because nothing is withheld.** Flipping the param imposes 5 msgs/day, 1 panic AI session/day and the posting cap on every account at once — it *is* the free/premium split, and no other work in `docs/12` reaches a user until it lands.

**Founder correction Sep 3 2026 — there is no beta cohort.** `S1-12` existed only to protect the "50 free lifetime spots" of docs/06 §3. That cohort was never recruited and will not be; Cirrus ships direct to production. `S1-12` is **descoped**, and the flip is gated only on not wrongly refusing a paying customer.

- [x] ~~`S1-12` **Founder-grant path**~~ — **descoped Sep 3** (no cohort to protect; §7 #29). If a comp is ever needed for a real case — press, a refund, a support escalation — it is a server-written `entitlement` with a far-future `expiresAt` and `source: 'founder_grant'` that `snapshotOf` leaves alone. Build it for that case, not speculatively
- [x] `S1-13` **Purchase→mirror latency — done Sep 3.** New `refreshEntitlement` callable (24th export) shares one write path with `rcWebhook` via `lib/entitlementMirror.ts`; `EntitlementStore` awaits it after a completed purchase and after a restore that found something. It takes no tier from the caller — the uid comes from the verified token and the tier from RevenueCat — so it is safe to expose to any signed-in user. Never throws at the purchase: guarded at both the repository and the call site, because the cost of being wrong is telling someone who just paid that it failed. 8 integration cases + `test/data/entitlement_mirror_test.dart`
- [ ] `S1-14` **Grace periods + dunning on**, verified against a forced Play billing failure. **31% of all Play cancellations are involuntary billing failures** (RevenueCat 2026) vs 14% on the App Store, and 15–20% of that is recoverable with no new users — the highest-ROI Android retention work available. `tierOf()` fails closed on `expiresAt`, so prove the "later of `expires_at` and `ends_at`" rule covers grace before trusting it
- [x] `S1-15` **`ENTITLEMENT_MODE=mirror` — flipped Sep 3** (docs/10 §18). Free accounts now really do get 5 coach messages and 1 post a day, and Premium is a thing that can be bought. **The `config.ts` default moved to `mirror` too** — it used to default to `ungated`, so a missing `.env` failed toward giving the product away; `test/allowance.test.ts` pins that only the exact word `ungated` opens the gates. **Deployed to `alastpuff` Sep 3** — 23 functions updated, `refreshEntitlement` created, all 24 Ready; `ENTITLEMENT_MODE=mirror` confirmed on the live revision (docs/10 §19b). **Still owed: watch `limit_reached` and `entitlement_changed` for 48h**, and `S1-11`/`S1-14` remain open — both are about not wrongly refusing a payer, and both need store-dashboard access

**Exit criteria:** a sandbox purchase on iOS *and* Android flips `users/{uid}.entitlement`, and the app reflects premium within 60s. Restore works from a clean install.

---

### S2 — BRAIN · Sep 14 – Sep 20

**Goal:** Ember becomes real. This is the differentiator no competitor has.

- [x] `S2-1` `coachRepositoryProvider` switches on `backendModeProvider`; add `FirebaseCoachRepository` calling `aiCoachChat` (B5) *(landed Aug 29 — B5)*
- [x] `S2-2` **`CoachReplyCodec` must read the `text` field** — today it drops it and renders `generic1`, discarding every word Ember says (B11) *(landed Aug 29 — B11)*
- [x] `S2-3` Call `syncUserContext` on launch + on locale/tz change, so `users/{uid}` exists and **both crons stop no-opping** (B9) *(landed Aug 29 — B9; the resume re-sync lives in `last_puff_app.dart`)*
- [x] `S2-4` FCM token registration through `syncUserContext.fcmTokens` *(landed Aug 29 through `syncUserContext.fcmTokens` (B7); superseded Aug 30 by the `users/{uid}/devices/{tokenHash}` registry, docs/10 §11.1)*
- [x] `S2-5` **Fix streak parity (B12)** — port the repair-token exception into `streakEngine.ts`; add a parity test mirroring `streak_and_money_test.dart` *(landed Aug 29 — B12; `functions/test/streakEngine.test.ts` parity cases)*
- [~] `S2-6` Token-usage logging on the **streaming** path (today only the non-streaming branch logs) + a cumulative per-user cost ledger *(streaming telemetry landed Aug 29 (docs/10 §5); the per-user cost ledger is still open)*
- [x] `S2-7` Done Aug 29. Panic flow calls `panicSession` on open and on "it passed"; the answer only ever narrows the **AI option**, which becomes the paywall route rather than vanishing. Never awaited by the UI — a craving does not wait on a round-trip. `test/widgets/panic_session_test.dart`
- [x] `S2-8` **Run Doc 4 §9 eval suite — 15/15 required on both models.** Includes prompt-extraction, under-18 redirect, self-harm → 988, and no-dosing-advice cases. Non-negotiable before beta. *(landed Aug 30 — automated `npm run eval:coach`, 19/19 on both pinned models (docs/10 §11.10), re-run 19/19 Aug 31; the founder's feel-pass remains)*
- [x] `S2-9` Done Aug 29 — and the ids were **wrong**: `gemini-3.1-flash` does not exist, so the coach had never answered anybody. Pinned Aug 29 to `gemini-3.5-flash-lite` (free) and `gemini-3.7-flash` (premium), both verified against production; **premium re-pinned to `gemini-3.6-flash` on Aug 30** (§7 #22). `aiCoachChat` logs the live catalogue on a 404, so the next wrong id names its own fix instead of failing silently
- [ ] `S2-10` **Internal track only** — TestFlight + Play internal testing on the founder's own devices, to prove the release build installs and runs from a store artifact. **The 30–50 recruited testers are descoped (§7 #29)**: no cohort, no "50 free lifetime spots", direct to production

**Exit criteria:** a real device gets a real Gemini reply that renders as Ember's own words · evals 15/15 · a store-built artifact installs and runs from the internal track.

---

### S3 — MOAT · Sep 21 – Sep 27

**Goal:** the community goes real. This is the feature Puff Count deleted and our stated moat.

- [x] `S3-1` `communityRepositoryProvider` switches on backend mode; add `FirebaseCommunityRepository` (B5) *(landed Aug 29 — B5)*
- [x] `S3-2` Wire `createPost` callable *(landed Aug 29 — B5)*
- [x] `S3-3` **Write `createReply` (B10)** — rules already deny direct creates citing a callable that was never built — reply read contract already pinned by the rules suite: replies must be written `pending` and flipped by moderation *(landed Aug 29 — B10)*
- [x] `S3-4` Extend `moderatePost` to trigger on replies too *(landed Aug 29 — `moderateReply`, B10)*
- [x] `S3-5` Tighten reply read rule with a `status == 'live'` filter (today any signed-in user reads unmoderated replies) *(landed Aug 29 — pinned by the rules suite)*
- [ ] `S3-6` Validate `alias`/`avatarEmoji`/`dayN` server-side against the real journey; make the 3-post cap **transactional**
- [x] `S3-7` Done Aug 29. `reportCount` increment-only, replies gated on status, and reaction counts moved server-side: clients write only `posts/{id}/reactors/{uid}` and `onReaction` derives the aggregate. **Not** `reactions{uid: emoji}` as docs/05 suggests — that would have made every reactor's uid public on a world-readable post
- [x] `S3-8` Done Aug 31 (day-1 field-test round). Moderation is genuinely fail-closed now: a 4th action `hold` keeps content `pending` + always writes a queue row, and **every** failure — model outage, unparseable verdict, unknown action, any throw (the old rethrow stranded posts pending with no row) — maps to it. `MODERATION_PROMPT` rewritten for the founder's contextual policy (slurs/hate BLOCK; hostile/profane rants HOLD; crisis stays FLAG = visible; self-directed venting ALLOW), the trigger passes the post `tag` so a WIN tag on a rant is itself a signal, and a deterministic `ai/prefilter.ts` slur wordlist blocks before the model so the hard guarantee survives outages (`PROFANITY_ACTION` knob = null per founder choice). Eval gate re-run after the prompt change: 19/19 both models (the suite is noisy — expect re-rolls).
- [x] `S3-9` **Moderation queue readable end to end.** Callables built Aug 29; the **client** (contract, repository, store, screen, Settings entry gated on the `admin` claim) landed the same day. The store is deliberately non-optimistic — a refused decision keeps its row, and a failed load never renders as an empty queue. `test/widgets/moderation_queue_test.dart`. **Still founder-side: granting your account the claim.**
- [ ] `S3-10` Real report / block / delete-own-content paths. **Report is done Aug 31**: new `reportPost` callable mirrors `reportReply` (per-reporter dedupe via `posts/{id}/reporters/{uid}`, auto-hide at 3 → `pending`, always a `moderation` row) — the old client-side raw `reportCount` increment fed a counter no server code read. Client switched to the callable; the rules carve-out is deleted in the repo and **deploys only after the tester is on the new build** (the old build's report button raw-writes and would get PERMISSION_DENIED). Block (viewer-local only) and delete-own-content remain open.
- [ ] `S3-11` SOS: the 60-min pin is **done** and the panic flow now routes into it (composer pre-tagged `sos`). Still open: notifying the last-5 responders and the "23 people had your back" count (Doc 3 §9). The buddy half of this line is dropped with the buddy system
- [ ] `S3-12` Seed the feed — **founder posts only** now the cohort is descoped (§7 #29), via `seedTextId` ids so l10n still resolves. **Consequence to accept or fix:** day-one users land in a near-empty community, and the feed is `docs/08 §2`'s stated retention moat. Either the founder writes enough real posts to make it feel inhabited, or the Community tab opens on an honest empty state rather than a thin one

**Exit criteria:** two real devices see each other's posts and replies · a blocked post never reaches a reader · the founder can review the flag queue.

---

### S4 — LOOP · Sep 28 – Oct 4

**Goal:** close the hook loop and make the funnel visible.

- [x] `S4-1` Push permission + FCM handling; the D4 pre-permission screen stops being a mock (B7) *(landed Aug 29 — B7; `PushService`, the D4 CTA)*
- [x] `S4-2` `flutter_local_notifications` scheduling danger hours on-device — deliberately *not* a server cron (see `functions/src/index.ts` header) *(landed — `ReminderPlanner` + `ReminderCoordinator`, ids 1000–1023; the `periodicallyShow` → `zonedSchedule` fix is docs/10 §7)*
- [x] `S4-3` Enforce Doc 3 §8 caps: max 3 pushes/day, quiet hours 23:00–08:00 *(landed — `ReminderPlanner.maxPerDay = 3`, `leadMinutes = 10`, the quiet-hours rule with its one documented exception)*
- [x] `S4-4` `shared_preferences` so theme/locale/notifications/danger hours **survive restart** (B8) *(landed Aug 29 — B8; `SettingsPersistence` over `shared_preferences`)*
- [x] `S4-5` 🔨 **Analytics complete** — all 16 docs/02 §7 events fire, including `puff_logged`, which the north star (Weekly Active Quitters) cannot be computed without. Per-step events come from the onboarding VM's central choke point; habit events from the store, not the four views that call it. **Amplitude replaces Mixpanel** (founder decision Aug 30) and runs alongside Firebase Analytics through `FanOutAnalytics`; Amplitude also autocaptures sessions and app lifecycle, without which DAU/WAU, session length and retention are not computable. Screen views come from `LpAnalyticsObserver` on the router (go_router hands it the *path pattern*, so no user text can reach the screen dimension) plus an explicit report from `AppShell`, because `StatefulShellRoute` switches tabs without pushing a route.
- [x] `S4-6` Crashlytics — `lib/app/app_errors.dart:26` has been holding the slot *(landed Aug 29 — B7; Crashlytics on both error paths)*
- [~] `S4-7` `onTrialWillEnd` → honest trial-ending push; win-back card 24h after decline ($3.99 founding month) *(`onTrialWillEnd` descoped (§7 #21); the on-device `TrialReminderPlanner` landed Sep 2 (docs/10 §14); the win-back card is built but gated off (`BillingCatalog.foundingOfferEnabled`))*
- [ ] `S4-8` Implement Doc 3 §2's **2-second write coalescing**; every tap currently rewrites the whole journey doc
- [ ] `S4-9` Funnel dashboard saved in **Amplitude** with a **>15% per-screen drop-off alert** (Doc 2 §7). Also outstanding before submission: Play Data Safety and Apple's privacy label must declare a third-party analytics SDK, and the live Privacy Policy should name Amplitude.
- [x] `S4-10` StoreKit `in_app_review` at D3 — today it's a pastiche of the native sheet *(landed — `LpReview` calls `InAppReview.requestReview()`; neither OS reports the outcome, so nothing claims a rating)*
- [x] `S4-11` **Panic arcade** — Sep 2 (landed early; docs/10 §15). Tiles, Blocks and Orbs on one pure-Dart kernel (`lib/domain/logic/games/`), 60-second rounds chained to five with a check-in between, free for everyone, per-game bests on the journey (`gameBests`, legacy `bestGameScore` decoded once), the 1–10 re-ask on the round panel, `game_finished{game,round}` / `game_switched` / `craving_outcome{game,rounds,intensity,intensity_after}`, and `panicSession` storing `intensityAfter` + `game`. The variable-reward and investment stages of the loop, with the craving drop as the reward in the person's own numbers. `test/domain/games/` (72), `test/widgets/game_arena_test.dart`, `blocks_field_test.dart`, `orbs_field_test.dart`, `integration_test/h_panic_games_test.dart`, `functions/test/panicSession.test.ts`

**Exit criteria:** danger-hour push fires 10 min before a real bucket · settings survive restart · the full onboarding funnel is visible in Amplitude.

---

### S5 — HARDEN · Oct 5 – Oct 11 · 🚩 **Beta ends Oct 10**

**Goal:** survive review, and survive users.

- [ ] `S5-1` **Play** store listing (iOS listing moves to the fast-follow) — Doc 6 §4 title/subtitle/keywords; **first screenshot = the dependence-badge moment**
- [ ] `S5-2` Privacy labels: "Data not collected for tracking". We ship no ad SDKs — market it (PRD §6)
- [ ] `S5-3` Age rating 17+/18+; medical disclaimer; "support tool, not medical treatment"
- [~] `S5-4` Privacy policy + terms **live at real URLs**; auto-renew disclosures on the paywall *(`/privacy` + `/terms` live on `alastpuff.web.app` (`lp_links.dart`) and the auto-renew disclosure is on the paywall (S1-6); the policy must still name Amplitude (S4-9), and the pages should move to cirrusquit.com (S5-11))*
- [x] `S5-5` Done Aug 29. `deleteAccount()` calls `deleteUserData`; it is the **one lifecycle command that is not optimistic** — the dialog awaits it and reports failure, because a deletion that silently failed while the UI said it succeeded is a broken promise, not a sync delay. `test/data/account_deletion_test.dart`
- [ ] `S5-6` UGC compliance pack: moderation + report + block + 24h response commitment
- [ ] `S5-7` **Doc 3 §12 acceptance checklist**, all gates — incl. 400 puffs/day × 3 days offline with zero loss, and Comeback ×2 verified at 47h59m / expired at 48h01m
- [ ] `S5-8` **Crash-free ≥ 99.5%.** With no cohort (§7 #29) there is **no pre-launch crash signal** — the first real device population is paying public. Mitigation: hold the Play **staged rollout at 5–10%** for the first 48h and watch Crashlytics before widening. That staged rollout is now the only thing standing where a beta used to
- [ ] `S5-9` Widen test coverage — `paywall_test.dart`, `onboarding_test.dart`, `billing_fake_test.dart`, `premium_gate_test.dart` and `f_firebase_backend_test.dart` exist now; the Firebase repositories still have no coverage beyond the on-device suite
- [ ] `S5-10` **Submit to Google Play**
- [ ] `S5-11` Repoint `lp_links.dart` to `cirrusquit.com/privacy` and `/terms` (the app still links `alastpuff.web.app`, pinned by `paywall_test.dart`), ship it, 301 the Firebase copies to the apex, then retire `hosting/` and the `hosting` block in `firebase.json` — two live copies of legal text will drift
- [ ] `S5-12` Coach copy audit for Quit Buddies leftovers — `prompts.ts` ("text your buddy" in the CRAVING protocol) and `coachReplyParty` ("text me or your buddy") read as generic English but name a removed feature; founder's call, and a prompt change goes through `npm run eval:coach`

**Monetisation redesign (added Sep 3 — `docs/12`, founder decisions §1).** Three gates loosen, one door dies, one is added; the D5 hard paywall is untouched because the evidence supports it. Ordered by expected conversion per hour: `S5-16` first, then `S5-17`, then `S5-15`.

- [x] `S5-16` **`limit_reached{capability, tier, used, limit}`** fired from the coach cap, the community refusals (`permission-denied`, `resource-exhausted`) and the panic narrowing. **The highest-value change on this board per hour of work** — today every *server* wall is silent, so the three highest-intent moments in the product are invisible and "hit a wall" cannot be distinguished from "saw a gate". Everything else here is a guess until it exists. `lib/domain/analytics/lp_events.dart`, `coach_store.dart`, `community_store.dart`, the panic VM · pinned by `test/analytics_test.dart`
- [x] `S5-17` **Add the missing `nudge` door.** A free user with a real `dangerWindow` currently sees *nothing* on Home — no card, no lock (`home_screen.dart:526`). Compact `LpPremiumGate(source: 'nudge')` naming their own honest weekday + hour, advice blurred. Must sit after the mood prompt in Home's priority chain, and the fixture goes on the branch under test — never the wall clock. `test/widgets/premium_gate_test.dart`
- [x] `S5-18` **Paywall measurement:** `plan_selected`, `paywall_dismissed`, `plan_day` on `gate_shown`/`paywall_viewed`, a real `variant` (it is the constant `'d5_default'` today, so docs/02 §6's whole A/B roadmap is unreadable), and tag the untagged **twelfth** door — `Routes.paywall` is in `PushService._allowedRoutes` and reports `source: 'direct'`, indistinguishable from the debug frame map. Rebuild the Amplitude chart before launch, not after
- [x] `S5-19` **Launch-paywall discipline** — plan days {3, 7, 14, 30} only, four showings ever, plus a lifetime cap. It is the one door docs/02 §5 forbids in its own words ("never interstitial spam") and it sits in the worst-converting placement band (0.76–0.89% vs D5's 1.35%). A new persisted field is exactly the shape of B8, so it lands in `SettingsPersistence`'s whole-object save. `lib/domain/logic/launch_paywall_policy.dart`
- [x] `S5-15` **Community: 1 free post/day, any tag; Premium 3/day; SOS refused for no tier and spending its OWN allowance** (`users/{uid}.sosUsage`, `DAILY_SOS_POSTS=5`). Deliberate deviation from "uncapped": a live SOS pins to the top of the feed for an hour, so an unbounded one is a pinning megaphone — 5/day is generous enough that no real crisis meets it, and a spent ordinary allowance can never refuse a call for help. Replying is already free (`createReply.ts` has no tier check), so gating thread-starting is arbitrary — and free users' posts *are* what Premium users pay for. Server cap becomes tier-dependent (`createPost.ts:68` → `FREE_DAILY_POSTS`/`PREMIUM_DAILY_POSTS` params); composer reframes to a remaining-post count. Moderation cost stays bounded at 1/day/account behind the deterministic prefilter. `functions/test/integration/createPost.test.ts`
- [x] `S5-14` **Stats history 7 → 30 days free.** The taper program is 30 days (`P=30`), so a 7-day window cannot show a taper working — and the data is already in the user's own journey doc. Month pill and forecast heatmap stay Premium, so the `history` door survives with a better story. `stats_screen.dart:64–74` + `premiumPitch*` in 5 ARBs
- [x] `S5-13` **Delete the `panic` door.** `aiAvailable == false` routes to the coach with the panic intensity (spending a coach message if any remain), then to the SOS composer — **never the paywall**. Breathing, games, timer and SOS already never block; this closes the last gap in "never paywall anyone mid-crisis". `panic_screens.dart:698` · `test/widgets/panic_session_test.dart`
- [x] `S5-21` **On-device coverage for the new surfaces** — `integration_test/i_monetisation_test.dart`. The widget suite pins each gate on its own; only a device sees the keep-alive shell, a pushed paywall whose `dispose` now does work, and a panic flow that animates forever. It caught nothing new, which is the point: it is the regression net for the four surfaces this sprint moved
- [~] `S5-20` **`premiumPitchHealth` copy ×5** — it said "from two weeks to a year", which is right *under* two weeks and drifts for anyone further along (nothing already reached is ever gated, so 100 days puff-free already owns the three-month node); it names the first node actually locked for that reader now. **And cut both widget claims from the live Play listing (`B21`)** — advertising a non-existent feature *inside* the FREE FOREVER promise is the bait-and-switch clause in Apple 3.1.2(a), not just an ASO problem. **Store change.**

**All eight landed Sep 3 2026** (`docs/12 §5b`). `flutter analyze` clean · `flutter test` **943** · `npm run verify` **205** · `npm run test:integration` **265** · `npm run test:rules` **47** · **on-device 47/47 on a Pixel 8** (Android 17), the whole `integration_test` directory plus a new `i_monetisation_test.dart` (5 cases: the `nudge` door opens and closes back onto Home, Stats' 30-day window and its `history` door, a free account's post-then-door, an SOS still open with the ordinary allowance spent, and the panic flow never reaching a paywall). `S5-20` is half open: the app copy shipped, the **Play listing edit (`B21`) is founder-side**.

Three live bugs were found and fixed on the way, none of them on the plan:
- **`coachCapReached` hardcoded "5"**, so a Premium user who had spent **100** messages was told "that's my 5 free messages" — and offered no upsell, because the CTA is free-only. It interpolates the server's own limit now, with a separate non-selling premium variant.
- **`freePlanFeat4` advertised "1 Panic Button session a day".** The panic *button* has never been limited — `usage.ts` says so outright — only its AI layer. In a cessation app that could stop somebody reopening the one screen built for a crisis.
- **A deploy-time param resolves to 0 when nothing sets it**, and an allowance of 0 is a total outage that looks like a policy (docs/10 §5's coach-limit trap). `allowance()` in `config.ts` now refuses a non-positive value and falls back to `ALLOWANCE_DEFAULTS` — **including on the coach path, which was live and unguarded**. `functions/test/allowance.test.ts`.

A self-review pass over the diff found four more, all in the new code and all fixed: a **lost `paywall_viewed`** (the report is deferred a frame, but the "reported" flag was set synchronously, so a pop inside that frame skipped both paths), **`ref` in `dispose()`** on the same path — the gotcha this repo has scars from, and untested — a **coach wall mislabelled free** when the backend sent no tier, and a **mutating read** in the fake (`_sessionOrGuest()` binds a guest session as a side effect). See `docs/12 §5b`.

#### S5b — the tightening (Sep 3, evening)

The founder ran the build on a device hours after the eight above landed:
*"I feel like we are very generous with users. Everyone will just stick with free only."*
Three of those eight reversed the same day. `docs/12 §5c` is the decision record, `docs/10 §21`
the engineering log.

- [x] `S5-22` **A floor under the composer.** The panic flow opens it pre-tagged `sos`, so
  posting was one tap away with the tag chosen — and `canPost` asked only for non-empty text,
  so `"a"` published *and pinned to the top of the feed for an hour*. `PostQuality`
  (12 chars / 3 words / 2 distinct words / 3 letters / 4 distinct letters), mirrored by
  `postQuality` in `prefilter.ts`, ahead of the allowance so junk costs no slot. Replies get a
  looser version; `createReply.ts` had no validation at all. Bar kept deliberately low —
  `help me please` publishes. `test/domain/post_quality_test.dart`
- [x] `S5-23` **One live SOS at a time.** `claimDailyPost` gained a `cooldownMs` and writes
  `sosUsage.lastAtMs` on the doc it already reads; a second SOS inside the 60-minute pin
  window is refused with `already-exists` (its own code — "come back tomorrow" is wrong for
  something that clears within the hour) and spends no slot
- [x] `S5-24` **Orbs free; Tiles and Blocks Premium.** Orbs is `entries.first` and
  `resolveFor` clamps to it, so nobody *lands* on a lock — not a lapsed subscriber whose
  `lastGame` is Blocks, not a `?g=` link. `Play Orbs` leads the card; `See Premium` is a text
  link. Never mid-round. **`S5-13` is not reversed:** the flow itself stays door-free, and
  `panic_session_test.dart`'s source-scan is extended to pin exactly one door, on the card
- [x] `S5-25` **Three limits tighten.** `freeHistoryDays` 30 → **7** (a real reversal of
  `S5-14`, traded knowingly — Stats is where the product's central question gets answered),
  `sosPosts` 5 → **3**, health free nodes `max(7, …)` → **`max(4, …)`** (still a floor, so
  nothing already reached is ever locked). `premium_gate_test.dart`'s `>= 30` pin is inverted
  **and its reason rewritten**
- [x] `S5-26` **The Free screen sells.** Five ✓ rows and a *Start with Free* button became a
  ten-row Free-vs-Pro table with **every figure read from `LpAllowances`**, Pro as the primary
  button and Free as a text link (still one tap — Apple 3.1.2). The app's **13th door**,
  `source: 'free_plan'`, and the first that measures who reaches Free and reconsiders. Retired
  `freePlanFeat1–5`, two of which hardcoded an allowance in five ARBs each; `paywallFeatPanic`
  stopped selling the free panic button
- [x] `S5-27` **Ember suggests what to say next.** The four quick chips were frozen strings on
  every turn forever. `aiCoachChat` returns 3–4 follow-ups in the **user's** voice from the
  exchange that just happened, riding the `CoachDone` envelope (they cannot stream) and the
  existing `Promise.all` (they cannot delay the first token). Skipped mid-craving, on the cap
  and on every failure path. ~5% of a turn, `COACH_FOLLOWUPS` kills it without a deploy.
  `docs/11 §3`

- [x] `S5-28` **On-device coverage for the four new surfaces** — four cases in
  `i_monetisation` (the arena opens playable for a free account and for a lapsed one, the
  locked pill answers with the card, *Play Orbs* leads, *See Premium* is tagged and closes
  back; the SOS composer through a real IME; the Free table at real size) and two in
  `f_firebase_backend` (the deployed `aiCoachChat` returns chip-sized follow-ups, and none
  mid-craving). **It caught a regression the widget suite could not:** `h_panic_games` reached
  for `TileField` straight after the loop card and landed on Orbs

**Gates:** `flutter analyze` clean · `flutter test` **978** · `npm run verify` **217** ·
`npm run test:integration` **284** · `npm run test:rules` **47** · **on-device 68/68 on a
Pixel 8** (Android 17) — 51 against the fake backend plus the whole 17-case
`f_firebase_backend` suite against **production**. `eval:moderation` not required (no
moderation prompt changed); `eval:coach` not re-gated (`EMBER_SYSTEM_PROMPT` and
`buildCoachInstruction` byte-identical).

**Deployed to `alastpuff` Sep 3 2026**, founder-approved: all 24 functions updated behind a
clean `verify` gate, with `DAILY_SOS_POSTS=5→3` and `COACH_FOLLOWUPS=true`.

One config trap caught by a red test rather than by production: `COACH_FOLLOWUPS` read as
`=== 'true'` would have been **off** on any project whose `.env` never named it, because an
unset deploy-time param resolves to the empty string. It reads `!== 'false'` now — the third
time this repo has been bitten by that shape (`MODEL_*`, the allowance params).

**Exit criteria:** both submissions in review · crash-free ≥ 99.5% · acceptance checklist green.

---

### S6 — SHIP · Oct 12 – Oct 15

**Goal:** launch.

- [ ] `S6-1` Doc 6 §9 launch-week checklist, all 8 items
- [x] `S6-2` **The D3 testimonials no longer invent anyone — fixed Sep 3.** `payoff_steps.dart` renders quote cards only for rows that actually came from the server; with none, the screen shows its title, its ask and no quotes at all. The two bundled ARB quotes are deleted, and the `BETA TESTER` badge is now `REAL REVIEW` (labels the review, not the speaker, so no locale has to gender an unknown person). **Still founder-side:** the `testimonials` collection is empty, so nothing renders there until real consented quotes exist. Original finding follows.
- [ ] ~~`S6-2` 🚨 **The D3 testimonials have no source — this now blocks launch.** `payoff_steps.dart:484` falls back to `obRatingQuote1`/`obRatingQuote2` when the `testimonials` collection is empty, and with no cohort it is **empty forever**. Those two ARB strings are **five-star reviews no human ever said**, rendered on the screen immediately before the paywall. That breaks our own rule (docs/02 §7 "real beta-tester quotes only … never fake personas"), and fabricated testimonials are a store-review risk in their own right. **Three honest ways out, founder's pick:** (a) cut the quote cards from D3 and keep the rest of the screen; (b) hold them until real reviews exist post-launch, then backfill the collection; (c) source real quotes from r/QuitVaping with explicit consent — the `testimonials` rows already carry a consent reference field for exactly this. **What is not an option is shipping (a) as it stands.**~~
- [x] ~~`S6-3` Paywall A/B test #1 armed (7-day vs 3-day trial)~~ **DROPPED Sep 3 (`docs/12 §5`).** RevenueCat 2026 puts trial→paid at **25.5% for ≤4-day trials against 37.4% at 5–9 days**, and Health & Fitness has already converged (54% of the category runs 5–9 days). Running it means serving ≥1,000 people — docs/02 §6's own ship rule — the arm the population data says is ~12 points worse, to answer a question 115,000 apps already answered. **Replaced by the S11 ladder tests, reordered: annual price before weekly.** A/B budget goes where the win rates are — plan duration 58.7%, price 45.5%, visual/copy only 34.6%
- [ ] ~~`S6-4` Reddit thank-you post to the beta cohort~~ — **descoped, no cohort (§7 #29).** The gap it leaves is real: it was the plan for seeding the first App Store reviews, and there is now no organic first-review source. `S6-1`'s launch-day push is what has to carry it
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
| **S11 Scale** | Mar 16 – Apr 15 | Price ladder — **$59.99/yr for new users first, then $3.99/wk**, grandfathering existing (§7 #28); cigarette + pouch modes; B2B pilot | **M6: $44K/mo net sustained** |

**Kill criterion (Doc 6 §8):** if by Dec 1 we've posted 100+ videos with <1K downloads, the content angle is wrong — not the market. Shift weight to the best-performing format. *"January is the judge."*

---

## 6. BACKLOG — proposed additions, hook-mapped

Every candidate must occupy a hook stage. Recommendation: take the first two; the rest are wave-timed.

| Addition | Hook stage | Why it earns its place | Target |
|---|---|---|---|
| **Referral loop** — "quit with a friend, both get a month free" | Investment + External trigger | Downloads are the binding constraint at 17.2K/month. A viral coefficient is the only acquisition lever with no per-install cost. Already PRD V1.1; `LpLinks.invite()` exists as a clipboard stub. | S8 |
| **Web vaping-cost calculator** | Top of funnel | Doc 6 §5 already names it the link magnet. The marketing site is `cirrus-landing` (Astro on Cloudflare Pages, cirrusquit.com — `.github/workflows/cirrus-landing-deploy.yml`), so the calculator goes there; `alastpuff.web.app` still serves the `/privacy` and `/terms` pages the app links to until S5-11 retires it. Zero app risk, pure download upside. | S8 |
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
| 14 | Trial length — PRD §11 and Doc 2 say 3 days; founder decision Sep 1, 2026 (docs/09 issue 4) | **7 days.** Paywall copy, `trialEnding*` copy and the S1-4 store products all say 7. The trial length on screen now comes from the store's offer (`BillingPlan.trialDays`); the fixed copy is the fallback only. A/B #1 (S6-3) now tests 7 vs 3 |
| 15 | RevenueCat entitlement id — the Sep 2 plan said `premium` | **`cirrus_pro`**, the id already in the dashboard (Aug 30). It is a string in two files (`BillingCatalog.entitlementId`, `plans.ts ENTITLEMENT_ID`); the user-facing word stays "Premium" everywhere |
| 16 | Play yearly base-plan id — the plan said `yearly-3999` | **`yearly-399`**, as created in Play Console on Sep 2. Base-plan ids cannot change once activated; the catalogue maps both spellings so a corrected plan later maps too |
| 17 | Trial reminder day — the Sep 1 timeline said Day 5, the push copy says "ends tomorrow" | **The day before the charge** (Day 6 of 7). The on-device reminder fires 24h before `expiresAt` (pulled earlier if that lands in quiet hours), and the timeline now derives its beats from the store's trial length, so copy and schedule cannot disagree. Two days' notice is a one-constant change (`TrialReminderPlanner.lead`) plus the push copy |
| 18 | Panic game length — docs/03 §7 and docs/09 §8 say one 60-second game; the Tetris studies the game leans on dosed **three minutes** | **60-second rounds, chained** (founder decision Sep 2, 2026). Every game runs in rounds; a check-in between them ends on the person's own word; five rounds is the cap; the panel's ring fills toward the studied three. `GameSession` is the one clock |
| 19 | Game engine — the founder asked whether to adopt Flame | **No Flame** (Sep 2). Its `GameWidget` is the `CustomPaint`-off-a-ticker the tile game already is, and its component tree would put game rules behind a Flutter import; the kernel is in-house (`lib/domain/logic/games/`). Flame stays the escape hatch for a game that needs rigid bodies or sprites |
| 20 | Blocks vs Tetris — the studied game is Tetris; its look is protected expression (Tetris Holding v. Xio Interactive, 2012) | **Own expression.** 8×14 board, six 3/4/5-cell pieces drawn as rounded pebbles in palette tones, no ghost, no preview, no garbage, no lock recolour, no game-over (the board breathes). The word never appears in code, copy, docs or the listing |
| 21 | `onTrialWillEnd` (Doc 5 §7) | **Descoped.** RevenueCat sends no such event and neither store does; the reminder is deterministic from the entitlement's expiry, so it is scheduled on-device like the danger hours (`TrialReminderPlanner`) |
| 22 | Premium coach model — S2-9 (Aug 29) pinned `gemini-3.7-flash`; `.env.alastpuff` and `config.ts` say 3.6 | **`gemini-3.6-flash`** (re-pinned Aug 30, docs/10 §11.10). 3.7 cannot stop thinking — `thinkingBudget: 0` is accepted and ignored, `MINIMAL` is rejected, the floor is LOW at a variable 400–2,000 thought tokens — and thoughts spend inside `maxOutputTokens`, so every premium reply truncated mid-word. 3.6 at `thinkingLevel: MINIMAL` thinks zero tokens. `.env.alastpuff` rule 4: a non-lite id must be able to stop thinking |
| 23 | Community posting — docs/01 §10 says free is "Read + react", docs/03 §9 says a flat "cap 3 posts/day", and the shipped build refused every non-SOS post server-side | **An allowance, not a wall, and no longer flat: 1 ordinary post/day free, 3 for Premium, and an SOS refused for neither tier from its OWN counter** (`users/{uid}.sosUsage`, default 5). Founder, Sep 3 2026 — `docs/12 §4.1`, shipped `S5-15`. Not literally "uncapped" for SOS: a live one pins to the top of the feed for an hour, so an unbounded allowance is a pinning megaphone; a spent ordinary allowance can never refuse a call for help, which is the rule that actually mattered. Free users' posts are what Premium users pay for, so gating supply starves demand — and **replying was already free** (`createReply.ts` has no tier check), which made the asymmetry arbitrary. Two free competitors (Escape the Vape, Quash) give community away entirely |
| 24 | Free stats history — docs/01 §10 says 7 days | **30 days** (founder, Sep 3 2026). The taper program is 30 days (`P=30`), so a 7-day window cannot show a taper working, and the data is already in the user's own journey doc. The Month pill and the forecast heatmap stay Premium, so the `history` door survives |
| 25 | "Upgrade prompts … max 1/day" (docs/02 §5) vs eleven doors with no throttle | **Restated, not enforced as written.** A lock card is honest labelling on a screen the user chose to open and always renders. The one *unrequested* prompt is the launch paywall — which is also the "interstitial spam" docs/02 §5 forbids — so it is capped to plan days **{3, 7, 14, 30}**, four showings ever (`S5-19`) |
| 26 | The `panic` door — docs/04 §7 says the panic answer "only ever narrows the AI option, which becomes the paywall route" | **No paywall mid-craving, ever.** A spent panic quota falls through to the coach on the remaining free messages, then to the SOS composer (`S5-13`). Breathing, games, timer and SOS never blocked; this closes the last gap in the founder's own hard constraint |
| 27 | Trial length A/B — docs/02 §6 test 1 (3-day vs 7-day) | **Retired unrun** (`docs/12 §5`). 5–9-day trials convert 37.4% against 25.5% at ≤4 days (RevenueCat 2026), and H&F is 54% on 5–9 days. Testing it would serve ≥1,000 users the known-worse arm |
| 28 | Price ladder order — docs/08 §2 lever 2 leads with "$3.99/wk test" | **Annual price first: $59.99/yr for new users, grandfathering existing.** $39.99/yr sits in Adapty's *low-priced* annual band ($17 install LTV vs $70 for high-priced — a 4.1× spread) and annual holds 61% of H&F revenue at 19.9% Day-380 retention; weekly is the worst-retaining plan we sell (5.5%) |
| 29 | The beta cohort — docs/06 §3's "50 free lifetime spots" for 30–50 recruited r/QuitVaping testers, and everything built on it (`S1-12` founder grant, `S2-10` closed testing, `S3-12` tester-seeded feed, `S5-8` cohort crash-free, `S6-2` tester testimonials, `S6-4` thank-you post) | **Descoped — there is no cohort and never was** (founder, Sep 3 2026). Cirrus ships direct to production. Three consequences, none of them bookkeeping: (a) `S1-12` was the only thing blocking the `ENTITLEMENT_MODE=mirror` flip on a *promise* rather than on correctness — the flip is now gated solely on not refusing a paying customer (`docs/12 §4.4`); (b) **the D3 testimonials lose their source**, so `payoff_steps.dart:484` falls back forever to two invented five-star quotes on the screen before the paywall — `S6-2`, and a launch blocker; (c) there is **no pre-launch crash signal and no organic first-review source** — a staged Play rollout replaces the former, nothing yet replaces the latter |
| 30 | `docs/12 §4.1` (morning of Sep 3) — free Stats history **30 days**, SOS **5/day**, health free nodes **7**, the panic arcade never gated | **All four tightened the same evening** (`docs/12 §5c`, `S5-25`/`S5-24`): **7 days**, **3 SOS/day plus one live at a time**, **4 health nodes**, and **Tiles/Blocks behind Premium with Orbs free**. Founder judgement on the tier as a whole — *"everyone will just stick with free only"* — not a refutation of any single morning argument. The 30-day case in particular stands on its merits and was traded knowingly: the taper runs 30 days, so 7 cannot show one working, and that is precisely why it is the thing Premium sells |
| 31 | `S5-13` "the panic flow never reaches a paywall" vs a Premium panic game | **Both hold, because the flow and the arena are different screens.** `panic_screens.dart` still contains no `paywallFrom` at all; the arena's one door lives on a lock card that a free account can only reach by tapping a padlocked pill, never by opening the arena and never mid-round. `test/widgets/panic_session_test.dart` pins both halves |

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
| **Launching Oct 15 with a solo team** | **High** | The widget slip is the designated release valve. iOS is already the fast-follow (§1); if S2 slips, cut scope, never the review time |
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

### Current gates (Sep 2, 2026)

`flutter analyze` clean · `flutter test` **934** · `npm run verify` **205** · `npm run test:integration` **265** · `npm run test:rules` **47** · `eval:coach` 19/19 on both pinned models · `eval:moderation` 85/85 (docs/10 §13–§15). Every earlier count lives in the log; this line is the current one.

### The $44K tracking line

| Month | Downloads/mo | Active subs | Net MRR |
|---|---|---|---|
| M1 (Nov) | — | — | — |
| M3 (Jan) — the wave | ~17,000 | ~5,500 | **$44K run-rate** |
| M6 (Apr) — the real gate | ~17,000 sustained | **5,549** | **$44,000** |

**North star:** Weekly Active Quitters — users who logged ≥4 days/week.

---

**Session history lives in `docs/10_Build_Log.md`** — dated, append-only; cite as `docs/10 §N`.

**Tier decisions live in `docs/12_Monetisation_Study.md`** (Sep 3, 2026) — the verified door inventory, the sourced conversion evidence, and the free/premium matrix. §7 rows 23–28 above are its resolutions; when this board and `docs/01 §10` / `docs/02 §4–5` disagree on what is free, docs/12 is the reason.

*Built from a full repo audit on Aug 29, 2026. Every ✅ and every blocker in §3 carries its evidence. Anything unverified is marked ❓ and treated as not done.*

