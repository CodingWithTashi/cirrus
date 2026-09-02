# 📄 DOC 9 — FIELD TEST · Sep 1 2026 (evening round)

**Created:** Sep 1, 2026 · **Tester:** founder, on device (Android, sideloaded via `./tool/device.ps1`, real Firebase) · **Status:** ✅ CLOSED Sep 1, 2026 — all eight issues landed, one at a time, top to bottom; issue 8's game was rebuilt into the panic arcade on Sep 2 (docs/10 §15).

> **Purpose:** trace the eight UX/logic issues from the Sep 1 evening walkthrough so nothing gets lost between sessions. Each issue keeps its screenshot, what the code does today, the proposed fix, and the acceptance check. Status vocabulary is docs/08's: `✅ done` (evidence cited) · `🔨 in progress` · `⬜ not started` · `❓ needs repro/decision`.
>
> Screenshots were copied from the Desktop into `docs/qa/2026-09-01/` so the paths survive. The founder's message numbered the images 1–6, 8, 9, 10; the files run 1–9. Mapping is by content, below.

---

## 0. BOARD

| # | Issue | Screen | Status | Touches |
|---|---|---|---|---|
| 1 | "We call it Ember" lands on someone who has never met Ember; note card too long | Onboarding D1b coach name | ✅ Sep 1 | `lib/features/onboarding/steps/coach_name_step.dart`, ARB `obCoachName*` ×5 locales, `test/coach_name_test.dart` |
| 2 | "so I can run with her without stopping" hint gives a first user no context; wants 4–5 rotating, marketing-grade placeholders | Onboarding D1c why-words | ✅ Sep 1 | `lib/domain/logic/why_words.dart` (`hintFor`), `lib/features/onboarding/steps/why_words_step.dart`, ARB `obWhyWordsHint{Health,Money,Freedom,Family,Fitness,Appearance}` ×5 |
| 3 | "Rate Cirrus" does nothing | Onboarding D3 rating | ✅ Sep 1 (device check pending) | `lib/core/utils/lp_review.dart` (`ReviewRoute`, `routeFor`), `pubspec.yaml` (+`package_info_plus`), `test/core/lp_review_test.dart` |
| 4 | Features must out-rank pricing; trial 3 → 7 days | Paywall D5 | ✅ Sep 1 (device look pending) | `lib/features/paywall/paywall_screens.dart` (`_TrialTimeline`), ARB `paywall*` + 8 new keys ×5, `trialEndingStatsLabel`, `docs/08` §1/§2/§4/§7 #14, `test/widgets/paywall_test.dart` |
| 5 | Danger-hours slider is unclear: what fires, how many, when? | Stats → Danger hours sheet | ✅ Sep 1 (device look pending) | `lib/features/settings/danger_hours_sheet.dart` (rewritten), `lib/domain/logic/reminder_planner.dart` (`fireTimeFor`, `eligibleStartHours`), `settings_screens.dart` row, ARB `settingsDangerHours*` + 2 new keys ×5, `day1TourHoursBody`, `test/widgets/danger_hours_sheet_test.dart` |
| 6 | Keyboard stays up on tag tap; every post shows "In review"; screen sometimes stuck after Post; moderation must hold only red-flag posts | Community composer + feed, `functions/` | ✅ Sep 1 (functions deployed; client build pending) | `lib/features/community/community_screens.dart`, `lib/data/stores/community_store.dart`, `functions/src/ai/prompts.ts`, `functions/src/ai/prefilter.ts`, `functions/src/handlers/moderatePost.ts` |
| 7 | Breathing ring reads as a pressed button; no visible breathing on first sight | Panic step 1 | ✅ Sep 1 (device-checked; light theme still to eyeball) | `lib/features/panic/breath_pacer.dart` (new), `lib/features/panic/breath_ring.dart` (new), `lib/features/panic/panic_screens.dart` `_BreatheStep`, ARB `panicBreatheInstruction` (new) + `panicBreathe{In,Hold,Out}` ×5, `test/features/panic/breath_pacer_test.dart`, `test/widgets/breathe_ring_test.dart` |
| 8 | Spark-tap game is fine but not gripping; evaluate a stronger distraction game (Piano-Tap style?) | Panic step 3 game | ✅ Sep 1 (device look pending) | `lib/domain/logic/tile_game.dart` (new), `lib/features/panic/tile_field.dart` (new), `lib/features/panic/panic_screens.dart` `TapGameScreen` + `SurvivedScreen` chip, `JourneyState.bestGameScore` + `JourneyCodec`, `JourneyStore.recordGameScore`, `LpEvents.gameFinished`, ARB `game*` + `survivedGame*` ×5, `test/domain/tile_game_test.dart`, `test/widgets/tap_game_test.dart` |

---

## 1. "We call it Ember." — the coach is introduced before the user knows there is one

**Screenshot:** `docs/qa/2026-09-01/01_coach_intro.png` (founder's Image #1)

**What you saw.** Title "We call it Ember." on a screen where the user has never heard the word. The note card is four sentences ("We went with Ember because it needed one…") and reads long. Ask: lead with *meet your coach*, then say "we call it Ember", cut the card down, and write it as a hook, not an explanation.

**What the code does.** `CoachNameStep` renders `obCoachNameTitle` ("We call it {name}."), `obCoachNameSubtitle`, and `LpNoteCard(obCoachNameAsk)` — the long card. CTA is "Keep {name}" until something is typed. All five locales carry the same keys; `test/coach_name_test.dart` renders every `{name}`-bearing key × 5 locales × 3 probe names, and `test/l10n_parity_test.dart` pins that every locale interpolates exactly what English does.

**Proposed fix (copy only, no layout change).**

| Slot | Was | Shipped (founder's pick, Sep 1) |
|---|---|---|
| Title | We call it Ember. | **Meet your coach.** |
| Subtitle | Your coach. Quit two years ago, remembers exactly how it felt, and has already read your plan. | unchanged (founder kept it) |
| Card | 4 sentences | **We call it Ember.** It answers to anything — pick the name you'd text at 2am. |
| Field / chips / CTA | unchanged | unchanged ("Keep Ember") |

Hook logic: title = attention (a person is being introduced), subtitle = credibility in three beats, card = the only action, framed as the user's choice. Everything else on the screen already earns its place.

**Steps.** Edit the three keys in all five ARBs via a JSON round-trip (never line surgery — see CLAUDE.md gotcha). If `obCoachNameTitle` stops carrying `{name}`, remove it from the name-bearing list in `test/coach_name_test.dart` and drop its `@` placeholder block. `flutter gen-l10n`, `flutter test test/coach_name_test.dart test/l10n_parity_test.dart`.

**Landed Sep 1.** Title and card rewritten in all five ARBs via JSON round-trip; the title no longer carries `{name}`, so its `@` block is gone, it is a getter in the generated code, and it left the name-bearing list in `test/coach_name_test.dart`. Evidence: `flutter test test/coach_name_test.dart test/l10n_parity_test.dart test/widgets/onboarding_tailoring_test.dart` → 27 passed; `flutter analyze` clean.

---

## 2. "Tell Koda one thing." — the hint gives a first user nothing to anchor on

**Screenshot:** `docs/qa/2026-09-01/02_why_words.png` (Image #2)

**What you saw.** The field's placeholder is "so I can run with her without stopping". Without context, a first user does not know who "her" is or what kind of answer is wanted. Ask: keep it marketing-heavy and human, and rotate 4–5 placeholders so different users see different ones.

**What the code does.** `WhyWordsStep` passes a single `obWhyWordsHint` to `LpField`. Title ("Tell {name} one thing.") and subtitle ("Why now? Not the health-class answer — the real one.") are good and stay. The hint is display-only: nothing is stored unless the user types, so a hint can never leak into the journey as the user's own words (this matters — see the "never invent data that renders as the user's own" gotcha; a *hint* is fine, a pre-filled value is not).

**Shipped (founder's pick, Sep 1): tailored, not random.** Two screens earlier the funnel asked "Why do you want out?" (Health / Money / Freedom / Family / Fitness / Appearance, at least one required), so the placeholder now echoes a why the user actually picked — different users see different lines, every line is about them, and nothing random has to be stored. With several whys picked a fixed precedence decides (Family > Fitness > Health > Freedom > Money > Appearance: most personal first); nothing picked (the Frame Map preview) falls back to Fitness, the line that shipped first.

| Why | Placeholder |
|---|---|
| Health | so I stop sounding like a kettle on the stairs |
| Money | I want my money back. And my mornings. |
| Freedom | because I'm done with the 11pm gas-station run |
| Family | my kid found it in my jacket. Never again. |
| Fitness | so I can run with her without stopping |
| Appearance | I want the un-tired version of my face back |

The rule is pure Dart (`WhyWords.hintFor` + `hintPrecedence` in `lib/domain/logic/why_words.dart`); the view maps the chip to its ARB key. The hint is display-only, so it can never be stored as the user's own words.

**Landed Sep 1.** Six keys replace `obWhyWordsHint` in all five ARBs (JSON round-trip, es/fr/de/pt written gender-neutral where the English was). Evidence: `test/domain/why_words_test.dart` `hintFor` group (5 cases, incl. "precedence names every why exactly once" so a new chip cannot silently fall through) and `test/widgets/onboarding_tailoring_test.dart` "the why-words placeholder is theirs" (2 cases); `flutter analyze` clean.

---

## 3. "Rate Cirrus" does nothing

**Screenshot:** `docs/qa/2026-09-01/03_rate_cirrus.png` (Image #3)

**What you saw.** Tapping the CTA advances the funnel and nothing else happens.

**Root cause (confirmed in code).** `payoff_steps.dart:546` shows the button only when `LpReview.isAvailable()` is true, then calls `InAppReview.requestReview()`. On Android `isAvailable()` answers "is the Play Store installed" — true on every phone — but Play's in-app review shows *nothing* for an app that was not installed from Play, which is every `./tool/device.ps1` build. The button is live, and silent, by design of the Play API. The same silence happens on a real install once the undocumented per-user quota is spent.

**Proposed fix.** Decide the fallback by *how the app was installed*, which the OS does report:

- Add `package_info_plus` (not in `pubspec.yaml` today) and read `PackageInfo.installerStore`. `com.android.vending` = installed from Play → `requestReview()` (the real sheet, quota permitting) — and nothing else, since two prompts would be worse than one.
- Anything else (sideloaded, an internal-test APK, desktop) → `InAppReview.openStoreListing()` / `url_launcher` to the Play listing `https://play.google.com/store/apps/details?id=com.quitvape.last_puff`. That page is a placeholder until the listing exists (founder OK'd a dummy link for now); it is still an honest action the user can see happen.
- Keep the non-negotiables from `lp_review.dart`: no star picker, no sentiment routing, no "thanks for rating" — neither store reports what happened.

**Landed Sep 1.** `LpReview` now decides a `ReviewRoute` — `sheet`, `listing` or `none` — from a pure `routeFor(platform, sheetAvailable, installerStore)`, with the plugin calls around it. Android: installer `com.android.vending` → `requestReview()`; anything else (adb, the system installer, a third-party store, unknown) → `openStoreListing()`, which opens the Play app on the app's own package name, so there is no placeholder URL to remember to swap once the listing exists (it shows "item not found" until then — the founder's accepted dummy). iOS/macOS always take the sheet (StoreKit prompts in dev builds too). `isAvailable()` now means "the CTA has somewhere to go", so the widget did not change beyond its comments. Dependency `package_info_plus ^10.2.1` added. Evidence: `test/core/lp_review_test.dart` (4 cases: none everywhere without a sheet; Play → sheet; five non-Play installers → listing; iOS/macOS → sheet); tailoring suite green; `flutter analyze` clean.

**Still to verify on device** (`./tool/device.ps1`): tapping Rate Cirrus opens the Play app. On a Play-installed build the sheet should appear instead — check after the first internal-test upload.

---

## 4. Paywall — features must be the hero, and the trial goes to 7 days

**Screenshot:** `docs/qa/2026-09-01/04_paywall.png` (Image #4)

**What you saw.** Six 13-px check-rows in a 2×3 grid, one of them truncated ("Panic Button + communit…"), sitting above three large price cards. The eye lands on $39.99 before it lands on what it buys. Ask: make the features visibly more prominent than the pricing, look for any other lift on this screen, and change the 3-day trial to one week.

**What the code does.** `PaywallScreen` builds the feature rows at `LpType.body13` inside `Expanded` halves (hence the ellipsis), then three `planCard`s, the reminder toggle, and the CTA "Start my free 3 days". The trial length exists only as copy: ARB `paywallSubtitle`, `paywallCta`, `trialEndingStatsLabel` ("YOUR 3 DAYS SO FAR"), `trialEndingPush`/`trialEndingBody` ("ends tomorrow"), and the `docs/08` §1 pricing row ("3-day trial, founder-locked"). Nothing in `lib/domain`, `lib/data` or `functions/` computes a trial end date — the real period will be the Play base-plan offer (and RevenueCat's entitlement), so the app only has to *say* the right number and schedule the reminder on the right day.

**Proposed fix.**

*Layout.* Feature block becomes the hero: full-width rows, an icon per row, benefit-first copy ("AI coach that remembers your why", "Panic button — 60-second craving killer", "Community that answers an SOS", "Plan that adapts to your slips", "Craving forecasts for your danger hours", "Weekly report in your own numbers"), no truncation. Plans collapse to a compact selector (three slim rows or a segmented control) with the price on the right; "BEST VALUE" and "Founding price — locked forever" stay. The CTA carries the trial ("Start my free week"), the price detail moves under it in caption ("then $39.99/yr · cancel anytime").

*The one proven lift worth adding.* A three-step trial timeline above the CTA — **Today** full access unlocked · **Day 5** we remind you · **Day 7** first charge, cancel before and pay nothing. This is the pattern Blinkist published as raising trial starts and cutting refunds; it also makes the reminder toggle self-explanatory. The copy must stay true: the reminder is a local notification we control, the charge date is the store's.

*Trial length.* 3 → 7 everywhere: the four ARB keys above ×5 locales, the reminder scheduled for day 5/6 rather than day 2, `docs/08` §1 pricing row and §2 funnel assumptions (the 57.5 % trial→paid rate was a 3-day figure — flag it as re-baselined, do not invent a new rate), and later the Play offer config. The `TrialEndingScreen` "YOUR 3 DAYS SO FAR" label becomes "YOUR WEEK SO FAR".

**Shipped (founder's picks, Sep 1): layout A, three-step timeline, six feature lines, CTA "Start my free week".**

- Features are the hero: six full-width rows, a volt icon tile each, `body14`, no ellipsis. Copy: Unlimited AI coach that remembers your why · Panic button: a 60-second craving killer · Community that answers your SOS · A plan that adapts when you slip · Craving forecasts for your danger hours · Weekly report in your own numbers.
- Timeline strip (`_TrialTimeline`): Today "Everything unlocked" · Day 5 "We remind you" · Day 7 "First charge {price}. Cancel before, pay nothing." — the price follows the selected plan with its period (`paywallPerYear/Month/Week`), from `LpPricing`. Copy about the offer, same footing as the CTA; the Day-5 push itself is S4-7.
- Plans are slimmer rows (padding 11, name 15, price 18); BEST VALUE and the founding-price line stay. Reminder toggle unchanged.
- The page scrolls; "Cancel anytime · Less than one disposable a week", the CTA and "Continue with Free plan →" are pinned at the bottom, so a short phone never overflows and the free path is always visible.
- Trial length: `paywallSubtitle` "Try everything free for 7 days.", `paywallCta` "Start my free week", `trialEndingStatsLabel` "YOUR WEEK SO FAR", all five locales. Nothing in `lib/domain`, `lib/data` or `functions/` computes a trial end, so copy was the whole change on the app side; the Play offer (S1-4) is where the real 7 days will be set.
- `docs/08`: §1 pricing row, §2 funnel note (57.5 % trial→paid was a 3-day figure — re-baseline from Play data), S1-4, S6-3 (A/B now 7 vs 3), and **§7 register row 14** recording the founder decision over PRD §11.

**Landed Sep 1.** Evidence: `test/widgets/paywall_test.dart` "the seven-day trial" — the timeline quotes the yearly price by default and the monthly price after tapping MONTHLY; every locale says 7 and none of the three trial strings still says 3. `screen_layout_test` (paywall at all sizes/themes), `l10n_parity_test`, `copy_honesty_test` green; `flutter analyze` clean.

**Still to look at on device:** the visual order features → timeline → plans → pinned CTA on a 360-dp phone, and the timeline's dot track at that width.

---

## 5. Danger hours — the slider does not say what will happen

**Screenshot:** `docs/qa/2026-09-01/05_danger_hours.png` (Image #5)

**What you saw.** Headline "9 PM – 12 AM", a slider, "Max 3 pushes a day, quiet hours respected", quiet hours 11 PM – 8 AM. It is not clear what gets sent, how many, or when.

**What the code actually does (confirmed).** `reminder_coordinator.dart:47-52`: when a custom window is saved, the planner schedules **exactly one** local notification per day, **10 minutes before the start hour** (8:50 PM for the screenshot), zoned to the next calendar day. The end hour is never used for scheduling — the slider only moves the start; the span is whatever was set at onboarding (3 h by default) and the sheet clamps it 1–6. "Max 3 pushes a day" describes the *detected* mode (trigger-hour buckets from the puff log) and is wrong for this sheet. Quiet hours (23:00–08:00) suppress the slot entirely, so a window starting at 11 PM or later silently gets **no** nudge — the sheet lets you pick 11 PM, 12 AM, 1 AM and 2 AM without saying so.

**Shipped Sep 1 (founder delegated the design call: "best for the user").** The consumer map decided it: the custom window feeds exactly one thing, a single daily push at start − 10 min. The "danger window" on Home, Stats, Panic and in the coach's card is the *detected* one from the puff log, and the custom end hour was read by nothing but the Settings row. So:

- **One question, not a label.** Title "When do cravings hit hardest?" (the Day-1 tour already asks "When do you cave?"); note "Pick the hour it usually starts. We nudge you 10 minutes before it — one push a day, nothing more." The "max 3 pushes" line is gone — it described the detected mode.
- **Hour chips, not a slider.** The choice is discrete; a slider hides the option set and needs a drag to land on a value, and the old one had no labels on the track (NN/g and Material 3 both reserve sliders for ranges where the exact value does not matter). Chips show every option at once, one tap.
- **Only hours that will fire.** The chip list is `ReminderPlanner.eligibleStartHours`, derived from the same quiet-hours rule the scheduler applies: 9 AM → 11 PM under the default 11 PM – 8 AM. The old slider let you save midnight–2 AM and the nudge was silently dropped. A saved start that now falls outside the list (0–2 from the old slider) opens on the nearest hour on the clock face (midnight → 11 PM), never on nothing.
- **The promise, live.** A card under the chips prints "One nudge at **8:50 PM**, every day." for the hour under the thumb (`ReminderPlanner.fireTimeFor`, formatted with minutes), and "Never between 11 PM – 8 AM — quiet hours." A concrete time is an implementation intention — the form of plan people follow through on — and stating "one, at this time" is what stops a reminder reading as spam before it has fired once. With notifications off the card says so instead of promising a push.
- **End hour dropped from view.** Settings row shows "9 PM · edit ›" instead of a range nothing reads; the model keeps `dangerEndHour = start + 3` so nothing else changes. Sheet is `isScrollControlled` and scrolls, so the chip rows never clip on a short phone. Day-1 tour lock/complete behaviour untouched; tour body copy now says "hour", not "window".

**Landed Sep 1.** Evidence: `test/domain/reminder_planner_test.dart` "the Settings sheet promises only what will fire" (4 cases, incl. every offered hour schedules and no other hour does); `test/widgets/danger_hours_sheet_test.dart` (3 cases: only 9 AM–11 PM offered; default opens as 8:50 PM, tapping 10 PM reads 9:50 PM, Save stores 22 + custom and the row shows "10 PM"; a stored midnight opens on 11 PM). Reminder, persistence, parity and layout suites green; `flutter analyze` clean.

**Still to look at on device:** the chip rows at 360 dp (four rows) and the sheet height on a short phone.

---

## 6. Community — keyboard, "In review" on every post, stuck screen, red-flag-only moderation

**Screenshots:** `docs/qa/2026-09-01/06a_composer_keyboard.png` (Image #6) · `docs/qa/2026-09-01/06b_feed_in_review.png` (Image #7, referenced as #8 in the message)

### 6a. Keyboard stays open after picking a tag
`community_screens.dart:637` — the tag chip's `onTap` is `setState(() => _tag = tag)` and nothing releases focus. Fix: `FocusManager.instance.primaryFocus?.unfocus()` in that handler. One line; add to the composer widget test.

### 6b. Every post says "In review — only you can see this for now"
Two things are stacked here.

*Every post is born pending.* `createPost.ts` writes `status: 'pending'`; the Firestore trigger `moderatePost` (deployed — checked with `firebase functions:list` this session) classifies it and flips it `live`, typically within a few seconds, longer on a cold start. The client mirror `users/{uid}/posts/{id}` follows the server, and the feed renders `pending` as "In review". So **every** post shows that line for the first seconds even when it publishes cleanly. The status cannot distinguish "not classified yet" from "held by moderation" — `VERDICT_STATUS.hold` maps to the same `pending`.

*This particular post was held on purpose.* "fuck this app" is exactly the case the Aug 31 founder decision (memory `lastpuff-moderation-policy`) routes to `hold`: hostile rant → invisible + founder queue. The prefilter's `PROFANITY_ACTION` is already `null` (profanity alone does not trip it); the model prompt is what held it.

**New policy (founder, Sep 1):** only red flags are reviewed. Slurs/hate → `block` (prefilter, no model call). Harassment aimed at a person, self-harm, brand names / where-to-buy → `hold`/`flag` per the existing prompt. **Plain profanity, including anger at the app, publishes.**

Proposed fix, in order:
1. `functions/src/ai/prompts.ts` `MODERATION_PROMPT`: profanity is never a reason on its own; hostility counts only when its target is a person or group. Update `functions/evals/moderation` cases ("fuck this app" → allow) and re-run `GEMINI_API_KEY=… npm run eval:moderation` — the gate for any prompt change.
2. Split the state so the client can be honest: mirror writes `held` when the verdict is `hold` (public post stays `pending`, so `firestore.rules` and the collection-group rule are untouched). Client: `pending` → "Posting…" (small spinner, no banner), `held` → "In review", `blocked` → "Not published — community rules". `PostStatus` enum + `PostCodec` + `test/data/dto_roundtrip_test.dart` (any new enum value goes through the codec test).
3. Fail-closed stays: a model outage still holds — that is an App Store requirement, not a preference. The "Posting…" state makes a slow classify look like latency, not a verdict.
4. Deploy order: `npm run verify` → `firebase deploy --only functions` → client build. Nothing else changes in rules.

The slur/racial floor the founder asked for **already exists**: `functions/src/ai/prefilter.ts` (word-boundary, diacritic- and leet-normalized, blocks before any model call) plus the model as contextual backstop. Extend the `SLURS` list there if a term is missing; every entry must be unambiguous in all five locales.

### 6c. Screen sometimes stuck after Post
❓ needs repro. The composer's Post handler is synchronous: `addPost` (optimistic insert) → haptic → `context.pop()` → `showLpSnack`. Candidates, in order of suspicion: the snack is shown through the composer's own `context` *after* it was popped; the `createPost` callable cold-starting 5–10 s while the feed sits on the optimistic pending row (looks stuck, is not); an App Check / `unauthenticated` refusal leaving the post pending forever with no banner (the `_syncPost` catch swallows it). Repro on device with the console open; if the second candidate, 6b's "Posting…" state is the fix.

**Landed Sep 1 (code; deploy is the next step — functions first, then the client).**

*Server (`functions/`).*
- **Policy**: `MODERATION_PROMPT` now says it outright — only words aimed at PEOPLE are ever a reason to hide a post; anger at the app, the product, the company, the cravings or one's own quit is feedback. BLOCK unchanged (slurs, hate, harassment, threats, minors, harm, sourcing, spam). HOLD is people-targeted hostility or mocking someone's quit. FLAG unchanged (crisis stays visible). `tools/moderationEval.ts`: "fuck this app" → allow, plus two new cases (hostile product feedback → allow; "you're all pathetic" → hold).
- **Two status vocabularies.** The post keeps `pending`/`live`/`blocked` (rules read only `live`). The author's mirror `users/{uid}/posts/{id}` gains `held` (`MIRROR_STATUS` beside `VERDICT_STATUS`): `pending` now means "still classifying", `held` means "a human must look". No rules change.
- **Self-healing holds.** `classify` marks the two holds the pipeline itself causes (model unreachable, unparseable answer) `retryable: true`; both triggers write it onto the queue row; new `remoderateHeld` cron (every 15 min, batch 50, gives up after three consecutive still-down answers) re-asks the same classifier and applies the answer — clean → live + row closed as `reviewedBy: remoderate`; anything else → real verdict, row stays for the founder; subject gone or already decided → row dropped from selection. A hold the model chose is never re-rolled. Query is two equality filters, no composite index.
- Evidence: `npm run verify` green (161 unit); `npm run test:integration` green (235, incl. new `remoderate.test.ts` ×9 and the mirror `held` case in `triggers.test.ts`); README rows for `moderatePost` and `remoderateHeld`; CLAUDE.md community paragraph.

*Client (`lib/`).*
- `PostStatus` gains `held` (wire, mirror only) and `failed` (local only — the network never carried it). `FirebaseCommunityRepository` maps `held`; the fake backend now answers `held` for a rule-violating post instead of `pending`.
- Feed row under the author's own post (`_OwnPostStatus`): `pending` → spinner + "Posting…"; `held` → "In review — only you can see this for now"; `blocked` → "Not published…"; `failed` → "Didn't send — tap to retry", and the tap calls `CommunityStore.retryPost`. A send that throws (offline, App Check refusal) now lands in `failed` instead of "Posting…" forever — the honest version of the stuck screen (6c).
- Composer: choosing a tag releases the keyboard (6a).
- Evidence: `test/data/community_post_status_test.dart` (4: clean → pending → live; rule-breaker → held; offline → failed → retry → live; retry only for failed), `test/widgets/composer_test.dart`, `dto_roundtrip_test.dart` "every status survives the wire"; full suite 626 green; analyze clean.

**Eval gate**: `npm run eval:moderation` → **57/57** rolls on `gemini-3.5-flash-lite` (19 cases × 3, first run, no re-rolls). "fuck this app" and the hostile-feedback case allow on every roll; "you're all pathetic", the community-targeted rant and the WIN-tag rant hold on every roll. Transcript: `functions/evals/moderation-2026-09-02T00-37-15-949Z-gemini-3.5-flash-lite.json`.

**Follow-up, Sep 1 late (founder re-test: "creating post sometimes stuck in same screen even after created; reject should happen before posting").**

- **Stuck composer — root cause found and pinned.** The Post handler called `addPost` (which awards the `firstPost` badge → journey mutation → router `refreshListenable`) *before* `context.pop()`; the refresh recomputed the match list from the still-current location and the pop was undone — the exact `leavePaywall` gotcha, so it hit every account's FIRST post and never the second (the badge is only awarded once). Now: pop first, then mutate. `test/widgets/composer_test.dart` "posting leaves the composer — even the first post, which earns a badge" reproduces it against the seeded journey (which has no `firstPost`).
- **Refused before posting, on both sides.** `CommunityRules.check` (domain) refuses slurs — the same list and matching as `prefilter.ts`, and `test/domain/community_rules_test.dart` reads the TypeScript file and fails if the lists differ — and brand/sourcing text. The composer shows the reason under the text box as they type and keeps Post off; nothing is sent, the words stay to edit. The daily cap (3) is checked the same way before the fourth post. Server: `createPost`/`createReply` run the prefilter at the door and answer `invalid-argument`, so a slur never lands in Firestore and never claims a cap slot (integration cases added); the client maps `invalid-argument`/`resource-exhausted` from `createPost` to `ContentRefusedException` → the post reads "Not published" with no retry, distinct from a network failure. The fake backend refuses the same text. The old "Held for review — brand names…" snack is gone (unreachable).
- Evidence: Flutter 638 green (composer ×5, rules ×8, status ×4); functions verify 161; integration 239; **second deploy Sep 1: `createPost`, `createReply` updated.**

**Review round, Sep 1 late (`/code-review high` before commit) — nine findings fixed, one left to the founder.**

1. `reportPost`'s three-report auto-hide still mirrored `pending`, which the new client renders as an endless "Posting…" spinner → mirrors `held`. (`callables.test.ts` updated.)
2. The client closed the status watch on `held`, so the sweeper's later "live" never reached the author in-session → `pending` and `held` both keep the watch open (`watchPostStatus`, `_setStatus`), and held posts loaded at startup get a watch too (`_watchUnsettled`). Pinned by `test/data/community_status_stream_test.dart` (3 cases, stub repository).
3. `resolveModeration` left `retryable` set and a report re-opens rows, so the cron could re-classify past a founder's decision → resolve and both report handlers clear `retryable`. (`remoderate.test.ts` case.)
4. The client normalizer folded a short table while the server NFD-strips → fold table covers the Latin letters NFD decomposes, plus a combining-mark strip for decomposed input. (Tests for decomposed and Extended-B carons.)
5. Sourcing was substring-matched and now hard-blocked ("unplug for a while", "threw my juul in the bin") → whole-phrase matching for where-to-buy/for-sale; **brand names are no longer a client refusal** (tone is the model's call; the fake still holds them via `mentionsBrand`). Copy for the sourcing line updated ×5.
6. A cap refusal read as "didn't clear the community rules" → `ContentRefusedException` carries a reason; `resource-exhausted` becomes local `PostStatus.capped` with its own line ("Not posted — that's 3 today…") ×5.
7. Retry could duplicate a post whose response was lost → `createPost` is idempotent on the app's `clientId` (doc id = sha256(uid:clientId)[:20]; an existing doc returns without a second cap claim). The fake is idempotent on the id too. (3 integration cases.)
8. Door-refused posts counted toward the client cap → `myPostsToday` excludes them (`_refusedAtDoor`), failed and capped.
9. The sweeper had no attempt cap → `MAX_ATTEMPTS = 8` (two hours of ticks), then the row is left to the founder with `retryGaveUpAt`. (2 integration cases.)
10. **Left to the founder:** `purchases_flutter ^10.10.1` in `pubspec.yaml` is referenced nowhere yet (it was added outside this session); it compiles the RevenueCat SDK into every build for nothing until S1-6 lands.

Evidence: Flutter full suite green, analyze clean; functions verify 161; integration 244; **third deploy Sep 1:** `createPost`, `reportPost`, `reportReply`, `resolveModeration`, `remoderateHeld`.

**Deployed Sep 1 (founder's go).** `npm run deploy` → verify green → `firebase deploy --only functions` on `alastpuff`: 22 functions updated, `remoderateHeld` created (every 15 min, us-central1). Rules and indexes unchanged. **Next:** rebuild the app (`./tool/device.ps1`), post "fuck this app" — expect "Posting…" for a few seconds, then nothing (live); post a brand name — expect "In review"; toggle airplane mode and post — expect "Didn't send — tap to retry".

---

## 7. Breathing ring reads as a pressed button

**Screenshot:** `docs/qa/2026-09-01/07_breathe_ring.png` (Image #8, referenced as #9)

**What you saw.** A big teal circle with "In…" and a small "3" — it looks like a button someone is holding down. Nothing tells the user to breathe, and the motion is not visible on first sight.

**What the code does.** `_BreatheStep` scales a 240-px ring from 0.8 → 1.0 across the 4-second inhale, holds, then 1.0 → 0.8 across the 8-second exhale. Twenty percent over four seconds is below what the eye registers as motion at a glance; the label is a single word ("In…", "Hold", "Out") and the countdown is 13-px secondary text. There is no progress cue and no instruction line.

**Proposed fix.**
- Instruction above the ring, visible from frame one: "Breathe with the circle."
- Phase labels become verbs: "Breathe in" / "Hold" / "Breathe out"; countdown grows to the number style (28–34 px).
- Scale range widens to ~0.55 → 1.0 so the inhale is unmistakable within the first second; keep `easeInOut`.
- A progress arc drawn around the ring (`CustomPainter`, sweep = phase progress) so the eye has something moving even during the 7-second hold.
- The first inhale starts at scale 0.55 on the first frame (it already runs from `initState`, so this is a numbers change, not a lifecycle one).
- Keep haptics, the craving timer, and "Skip to my why" as they are; keep the 4-7-8 pattern text.

**Acceptance.** On device, the ring is visibly growing within one second of the screen appearing, and the screen tells the user what to do before they read anything else. `test/screen_layout_test.dart` still green (Stack, not IntrinsicHeight, around any animated sizing).

**What landed (Sep 1).** The mechanics are borrowed from the three references that get this right, and layered so something is always visibly moving:

- **Instruction from frame one.** "Breathe with the circle." above the ring in body-15 primary (new key `panicBreatheInstruction`, five locales). Founder-approved copy; the note line at the top and the pattern line below are unchanged.
- **Verb labels caption the ring from below.** "Breathe in" / "Hold" / "Breathe out" at 28 px display in Oxygen (Apple Watch Breathe and Calm both use the verb form); the ellipsis went. es *Inhala/Mantén/Exhala* · fr *Inspire/Retiens/Expire* · de *Einatmen/Halten/Ausatmen* · pt *Inspira/Sustém/Expira*. Countdown 34 px `LpType.number` in primary text under the verb; the verb crossfades on the phase beat. **The orb itself is empty.** The first device build put both inside the orb (the founder's first pick from the previews) and the founder called it "weird and absurd" on sight — rightly: a resting orb is narrower than any 28-px verb, so the rim sliced through "Breathe out", and a grey count on teal read as a disabled control. A circle with a label in it is a button by convention; an unlabelled orb cannot be. Apple and Headspace both keep the shape empty and caption it.
- **The orb rests at 0.4 and fills to 1.0** (Headspace's published 40 → 100 %; Apple's petals collapse to 0.15 but carry no text), on a sine ease — the sinusoidal pacer the HRV-biofeedback literature uses. The cubic ease-in-out was tried first and sits nearly still for its first half-second, which is exactly when a frightened user decides whether the thing moves at all. Fill opacity rises with the inhale (the paced-breathing stimulus in the Frontiers 2022 guided-breathing study: bigger *and* darker in, smaller *and* lighter out).
- **A thin outer track marks "full"**, with tick marks at the three phase boundaries, and **a pointer laps it once per breath** with the elapsed arc trailing behind it (Calm's bubble runs its pointer the same way) — so the seven-second hold still has motion in it. Through the hold the glow swells on a two-second pulse (Headspace's "gentle pulsing glow"); full lungs never read as a frozen button.
- **One painter, no per-frame rebuilds.** The orb, track, ticks, arc and pointer are one `CustomPainter` driven straight off the controller via `repaint:`, so the widget tree is out of the 60 fps loop; the verb and count rebuild once a second via `setState`. The middle of the screen is an `Expanded` + `LayoutBuilder` that sizes the ring to what the header, caption and footer leave (160–272 px) — a small phone gets a smaller ring, never an overflow. No `IntrinsicHeight` anywhere near it.
- **Unchanged, as asked:** haptics (light at each phase change, a selection tick each second while inhaling/exhaling, silence through the hold), the craving timer pill, the pattern line, "Skip to my why".

**Evidence.** `BreathPacer` unit tests (frame one is empty lungs counting from 4; the orb has grown by more than a fifth one second in; only grows through the inhale, only shrinks through the exhale; countdown never 0; the pointer wraps cleanly at the cycle boundary) and `breathe_ring_test.dart` on the real `PanicFlow` (instruction + verb + "4" on the first frame before any animation runs; label/countdown turnover at 4 s, 11 s, 19 s; haptic channel recorded — three ticks through the inhale, none through the hold; lays out at 360×640 in both themes). `flutter analyze` clean · `flutter test` 658 green (645 + 13).

**Device look (Sep 1, founder's phone, real backend).** Frames captured on-device at ~0.8 s / 2.1 s / 3.5 s (inhale), 4.8 s and 7.2 s (hold), 11.3 s and 15.3 s (exhale), 19.3 s (next inhale): the orb is small with the pointer at twelve on the first frame, visibly larger by the second capture, full and glowing through the hold with the pointer creeping, and back to small by the end of the exhale. The verb, the count and the haptic turn over together. Still to eyeball: the light theme once — the pointer and arc use the text-contrast Oxygen so they should stay visible on the pale panic ground.

---

## 8. The spark game — good enough, not gripping

**Screenshot:** `docs/qa/2026-09-01/08_tap_game.png` (Image #9, referenced as #10)

**What you saw.** One spark; tap it and it jumps. Fine, but not something that pulls attention away from a craving. Founder floated a Piano-Tap game, explicitly only if research says it is worth it.

**What the code does.** `TapGameScreen`: one spark, relocates only when tapped, 60-second timer, score, then `survive()` → survived screen. No urgency (nothing happens if you stop tapping), no variable reward, no best-score memory.

**What the evidence says.** The mechanism the panic flow is leaning on is *elaborated intrusion*: a craving is mostly vivid sensory imagery, and a task that loads the same visuospatial working memory shrinks it. That is the finding behind the Tetris studies (Skorka-Brown, Andrade & May — three minutes of Tetris cut self-reported craving strength by roughly a fifth, across nicotine, food and other targets, and it kept working over a week of use). What matters is not the game but the properties: **continuous visuospatial demand, a rhythm, immediate feedback, and difficulty that ramps** so attention cannot drift. A single spark that waits for you has none of the first three.

**Recommendation — build the Piano-Tap variant, with three rules.**
- Four lanes, tiles fall, tap the lit lane before it passes; speed ramps every ten seconds. Continuous demand, rhythm, ramp — all three properties, and it is the format Gen Z already knows.
- **No game-over.** Panic mode must never punish someone mid-craving. A miss shakes the tile and costs the combo, the clock keeps running, 60 seconds always ends on the survived screen.
- Variable reward + investment: streak/combo counter, a personal best stored in the journey (engine-derived, never invented), and the best shown on the survived screen and in the coach's week card. That is the hook-loop stage the current game lacks.

Cheaper alternative if we want to spend the time elsewhere: keep sparks but spawn them on a timer with a 1.2-second decay and two on screen at once — gives urgency, still no rhythm. Weaker on the evidence, one-evening build.

**Decision (Sep 1).** Piano-Tap — and two corrections from the founder mid-build that shaped everything after them. First: *the goal is not the game, it is helping a vape addict through the craving* — so the copy leads with why tapping helps, the score stays quiet, and the sixty seconds end on a question rather than a claim. Second, from playing the first build on the phone: *a fast tapper had to wait for the next tile, the board should scroll as fast as you tap, the target is the bottom gap like Piano Tiles, and it should get tougher as the player finds it easier.* The first build was Piano Tiles Arcade (auto-scroll, tap the tile wherever it is); what shipped is Piano Tiles Classic with an adaptive clock.

**What landed (Sep 1).**

- **Mechanics (`lib/domain/logic/tile_game.dart`, pure Dart).** Four full-bleed lanes, a board of five dealt rows (four on screen, one buffered), one tile per row, never the same lane three rows running. **The bottom row is the target.** A tap in its lane is a hit and brings the next row down *at once* — the board goes exactly as fast as the thumbs do, nobody ever waits for a tile, and the board is full from the first frame. **Only the target moves on its own:** it sinks from its home (2.75 rows down) to the miss line (half under the bottom edge) over a *window* that is a fixed multiple (×1.5) of the player's own recent pace — intervals over the last three seconds, so seven taps in three seconds reads as two a second, not 7/3. Two taps a second → 0.75 s per tile; four → the 0.5 s floor; nothing in the last three seconds → the ceiling, 2.4 s at the start of the minute easing to 1.6 s at its end (the one time-based ramp left). The window is fixed when a tile lands, so its sink is a straight line the eye can read. Steady play never loses a tile; a hesitation half again as long as the beat does — which is the mechanism: attention cannot drift to the craving without a tile paying for it, and a tired thumb is never punished, because a pause immediately loosens the next window. A tap with nothing to hit (wrong lane) is a miss; a bounce within 120 ms of a hit in the same lane is ignored, never a hit — **one tap is one hit, always** (QA H1's rule, pinned). **A miss costs the combo and nothing else** — no game-over, the clock runs on, the board never punishes by scrolling faster than you asked. Steps of at most 100 ms, so backgrounding pauses the game.
- **The screen (`lib/features/panic/tile_field.dart`, a painter off a per-frame `Listenable`, no rebuild in the 60 fps loop).** Piano-key hairline dividers, volt slab tiles (`voltStrong`, so the daylight theme gets the stronger green), the target under a soft glow, the whole board easing down one row in 90 ms after every hit so a tap reads as scrolling rather than teleporting (the engine's positions are final the moment the tap lands — the slide never delays an input), the hit tile flashing oxygen and popping out, a lost tile freezing at the miss line to shake ember, the tapped lane washing oxygen/ember for 150 ms, and the combo as a faint 120 px ghost number behind the lanes from 3+ (Piano Tiles 2). Header: timer + tile count only. Haptics: light per hit, medium per miss, celebrate when a run passes a best that already existed.
- **The craving, not the game.** Title "Crowd the craving out." and a subtitle that says why ("A craving is mostly a picture in your head. Tap the falling tiles for 60 seconds and it gets less room to grow." — the size of claim the Tetris evidence supports). At sixty seconds the tiles stop and the why step's two choices appear: **"Still craving — 60 more seconds"** (primary, a fresh run, the craving timer keeps counting) and **"It passed 🎉 I'm good"** (the exit). A "+1 craving beaten" is only ever theirs to say. New string "60 seconds done." heads that panel.
- **The best.** `JourneyState.bestGameScore` (null = never played, through the codec and the round-trip test; a journey written before the field decodes to null). `JourneyStore.recordGameScore` records a run at its end, only if it beats the best; zero never becomes a best (`TileGame.beats`), so the honest empty state holds until someone has caught something. Never seeded: the demo journey has no best. Shown quietly: no target in the header, a "new best" caption only when a run passes a best that already existed (the first run has nothing to pass), and on the end panel + survived card a chip row — volt "🎹 112 tiles · NEW BEST" when the run set it, secondary "🎹 112 tiles · best 130" otherwise. The survived screen receives the run through the route's query string (`GameOutcome`), which is what survives `survive()` invalidating the panic session. Leave-first-then-mutate on the exit.
- **Analytics.** `game_finished {score, best_combo, misses}` in the `LpEvents` vocabulary (pinned in `analytics_test.dart`) — what the pace factor and the window floor get tuned on.
- **Tests.** `test/domain/tile_game_test.dart` (18: the board opens full and never waits, a hit advances at once, twenty hits in no time, the target sinks and is lost at the end of its window, no triples, the pause clamp, the finish, the countdown, the window's floor/ceiling/pace rule, tighter-then-wider with the player, a steady player never loses a tile, a hesitation half again as long as the beat does, wrong lane costs only the combo, bounce grace, two hits for two rows in a lane, `beats`), `test/widgets/tap_game_test.dart` (9, on the real router: one hit per tap, a burst of taps in one lane is never more hits than rows there, wrong lane costs only the combo, sixty seconds end on the choice with the run recorded and no craving claimed, "it passed" carries the run to the survived screen, "still craving" restarts and a lower run says "best N", no best named before one exists, passing an existing best says so once, the survived screen without a game shows no game line), codec round-trip + pre-field decode.
- **Follow-up (not this issue):** surface the game bests in the coach's week card — `functions/src/domain/journeyCodec.ts` would decode `gameBests` and `functions/src/ai/memoryCard.ts` quote it. Server-side, separate change.

**Addendum (Sep 2).** This game became one of three. The clock moved out of `TileGame` into `GameSession` (60-second rounds chained to five, docs/08 §7 row 18), the engine moved to `lib/domain/logic/games/`, `bestGameScore` became `gameBests[tiles]` (old documents decode once), and the screen became the game-agnostic arena in `lib/features/panic/game_arena_screen.dart` with Blocks and Orbs beside it. Every rule and every number above is unchanged; the tests moved with the code (`test/domain/games/`, `test/widgets/game_arena_test.dart`). The record of the whole change is docs/10 §15.

**Eyeball on device.** The board is full at the first frame and the first tap moves it; tapping fast scrolls fast with no wait; the target's glow and sink read as "this one is slipping" without the tiles above moving; whether ×1.5 of your own beat feels fair when you hesitate (a miss should feel like *you* drifted, not like the game sped up); the ember shake reads as "that one got away", not as punishment; the ghost number at 16 % is visible under real tiles but never louder than them; the end panel's primary is "60 more", not "it passed"; the survived chip under the 22 → 23 roll; light theme for all of it.

---

## 9. ORDER OF ATTACK

Copy-only first (fast, no risk), then logic, then the two design pieces that need a decision:

1. Issue 1 → 2 (ARB round-trip, two tests)
2. Issue 6a (one line) → 6b (prompt + eval + `held` status + deploy) → 6c (repro with the new state in place)
3. Issue 3 (installer check + listing link)
4. Issue 5 (danger-hours sheet rewrite)
5. Issue 7 (breathing ring)
6. Issue 4 (paywall layout + 7-day trial — needs the docs/08 register row)
7. Issue 8 (after the decision)

## 10. LOG

| Date | Issue | What landed | Evidence |
|---|---|---|---|
| Sep 1 | — | Tracker created; screenshots copied to `docs/qa/2026-09-01/`; `moderatePost` confirmed deployed on `alastpuff` | this file |
| Sep 1 | 1 | Coach intro copy: "Meet your coach." + one-line card, all five locales; title dropped `{name}` | `git diff lib/l10n lib/features/onboarding/steps/coach_name_step.dart test/coach_name_test.dart`; 27 tests green |
| Sep 1 | 2 | Why-words placeholder keyed to a why the user picked (6 lines × 5 locales, precedence rule in domain) | `WhyWords.hintFor`; 7 new tests; full suite green |
| Sep 1 | 3 | Rate Cirrus routes by installer: Play → sheet, anything else → Play listing | `LpReview.routeFor`; `test/core/lp_review_test.dart`; device tap still to confirm |
| Sep 1 | 4 | Paywall: feature hero + trial timeline + slim plans + pinned CTA; trial 3 → 7 days in copy, docs/08 register #14 | `paywall_test.dart` "the seven-day trial"; full suite green |
| Sep 1 | 5 | Danger-hours sheet: one question, hour chips from the planner's quiet-hours rule, live "One nudge at 8:50 PM" sentence; end hour dropped from view | `reminder_planner_test.dart` + `danger_hours_sheet_test.dart`; full suite green |
| Sep 1 | 6 | Moderation policy (people-targeted only), `held` mirror state, `remoderateHeld` sweeper, client posting/held/failed + retry, composer keyboard | verify 161 · integration 235 · flutter 626 · eval 57/57; functions deployed to `alastpuff` Sep 1 |
| Sep 1 | 6 (re-test) | Stuck composer: pop-before-mutate (first-post badge undid the pop); slurs/brands/cap refused in the composer and at the server door | flutter 638 · integration 239; `createPost`/`createReply` redeployed |
| Sep 1 | 6 (review) | `held` stream stays open; report auto-hide mirrors `held`; resolve/report clear `retryable`; sweeper attempt cap; idempotent `createPost`; sourcing phrases only; capped state | integration 244; full Flutter suite green; functions redeployed |
| Sep 1 | 7 | Breathing ring: instruction from frame one, verb labels, orb 0.4 → 1.0 on a sine ease with opacity rising, outer track + phase ticks + a pointer lapping once per breath, glow pulse through the hold; `repaint:`-driven painter; ring sized by layout (160–272) | `breath_pacer_test.dart` (8) + `breathe_ring_test.dart` (5); analyze clean; flutter 658 green; on-device frames captured |
| Sep 1 | 7 (device) | Founder saw the first build on device: verb + count inside the orb read "weird and absurd" (rim through the words, grey count on teal). Orb emptied; verb + count now caption the ring from below, count in primary white, verb crossfades | device frames across one breath; suite re-run green |
| Sep 1 | 8 | Piano-Tap game replaces the spark. First build (Piano Tiles Arcade: auto-scroll 1.5 → 3.0 tiles/s, tap the tile wherever it is) played on the phone by the founder — a fast tapper waited for the next tile. Rebuilt as Piano Tiles Classic with an adaptive clock: bottom row is the target, a hit brings the next row down at once, the target sinks over ×1.5 of the player's own pace (0.5 s floor, 2.4 → 1.6 s ceiling), one tap = one hit, a miss costs the combo only (ember shake at the miss line), ghost combo behind the lanes; 60 s end on "still craving — 60 more" / "it passed" (never a claim); `bestGameScore` on the journey through the codec, quiet "new best", survived chip; craving-first copy ×5 locales; `game_finished` event | `tile_game_test.dart` (18) + `tap_game_test.dart` (9) + codec (2); analyze clean; flutter 687 green; device frames in `docs/qa/2026-09-01/08_after/` |
