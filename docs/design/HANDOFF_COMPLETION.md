# Handoff Completion Matrix — all four bundles

**Bundles:** `RUN 1 frame review-handoff` · `RUN 2 frame review-handof` · `RUN 3 frame review-handof` · `LastPuff Run 2 Light handoff`
**Fact:** the four bundles' `project/` folders are byte-identical exports of one Claude Design project (verified by MD5); each README marks a different primary file. Completion below is therefore tracked per design file, frame by frame.

**Legend:** ✅ implemented · ✅* implemented with a deliberate deviation (noted) · 📐 design-system component (built, surfaced in a later phase) · 🔌 out of UI-phase scope (backend / native)

---

## RUN 1 — `LastPuff Run 1.dc.html` (frames 1–24, onboarding + paywall) — priority 1

| # | Frame | Implementation | Status |
|---|---|---|---|
| 1 | A1 Welcome | `features/onboarding/steps/welcome_step.dart` — dimmed `___` counter with slow shimmer tease, social-proof card, CTA bounce | ✅ |
| 2 | A2 Gender | `steps/identity_steps.dart` — option cards, Volt select glow, privacy note, animated progress bar | ✅ |
| 3 | A3 Birth year | keypad with tick haptics, digits roll in (odometer), blinking Volt caret | ✅ |
| 4 | A3b Under-18 | warm resource screen (This is Quitting / My Life My Quit), graceful exit, no funnel back-door | ✅ |
| 5 | A4 Tried before | 2×2 grid, reaction banner slides up 250ms on select | ✅ |
| 6 | B1 Frequency | DAILY / OFTEN / ALWAYS cards | ✅ |
| 7 | B2 Puffs/day | rolling Volt hero number, live badge morph (Light→Moderate→Heavy→Severe per docs/02 thresholds), severe haptic thud, ≈cigarettes line, device-life estimator sheet | ✅* — design mock labels 200 as "Severe"; spec (docs/02 B2) says 151–300 = Heavy; spec wins |
| 8 | B3 Strength | 20/35/50/Not-sure grid, 5% note | ✅ |
| 9 | B4 Spend | rolling yearly shock counter with haptic landing, rotating kicker by amount, month/day chips | ✅ |
| 10 | B5 First puff | four windows + THE SCIENCE card | ✅ |
| 11 | C1 Your why | chips pop into the Your Why card with catch-haptic (IKEA effect) | ✅* — stack-pop instead of full curved-flight overlay; beat and haptic preserved |
| 12 | C2 Worries | chips + AI trains-on-these note | ✅ |
| 13 | C3 Method | taper/cold cards, recommendation chip computed from B2 (≥100/day) | ✅ |
| 14 | C4 Pace | pace pills, curve **morphs 400ms** between paces, Freedom Day dot **pulses Ember**, real dates | ✅ |
| 15 | C5 Building | 3.2s ring, step ticks land with haptics | ✅ |
| 16 | D1 Plan reveal | curve draws in 800ms, **staggered** rolling stat counters, milestone dots, honest-proof block | ✅ |
| 17 | D2 Commitment | hold-to-commit 3s Ember ring, haptic ramp, release rewinds, confetti burst, date card, static specks decor | ✅ |
| 18 | D3 Rating ask | beta-tester quotes (labeled), rate card, "Not now" | ✅ |
| 19 | D4 Notifications | pre-permission with push preview + 3 promise bullets | ✅ |
| 20 | D5 Paywall | yearly pre-selected + BEST VALUE ribbon, founding weekly, trial-reminder toggle ships ON, visible Free path | ✅ |
| 21 | D5b Free plan | positive-only framing, no guilt copy | ✅ |
| 22 | D5c Win-back | one-time founding offer — **fires once** (`winbackShown`), then the regular paywall | ✅ |
| 23 | D5d Trial ending | push mock + user's own 3-day stats + keep/switch | ✅ |
| 24 | Day-1 checklist | 3 tasks, line-through collapse, CTA points at next unchecked | ✅ |

## RUN 2 — `LastPuff Run 2.dc.html` (frames 25–38, auth + core app, Midnight) — priority 2

| # | Frame | Implementation | Status |
|---|---|---|---|
| 25 | Splash | `features/auth/splash_screen.dart` — 4s breathing Volt glow, wordmark fade-up, 1.5s auto-advance | ✅ |
| 26 | Sign in | Apple primary, email second-class but visible, why-an-account card | ✅ |
| 27 | Email register | Volt focus ring, live strength meter ("decent password"), no-spam card | ✅ |
| 28 | Email login | "Your streak missed you.", wrong password → 2px field shake + kind copy | ✅ |
| 29 | Forgot password | inline success, resend disabled 30s with countdown | ✅ |
| 30 | HOME / Today | bento grid, glowing ring, rolling counters, coach nudge (swipe-dismiss), LOG PUFF thumb-zone CTA, persistent SOS | ✅* — honest numbers: ring shows the real curve limit (98 at day 12), not the mock's baseline 200; money uses docs/03 math |
| 31 | Log + over-limit | +1 → ring tick + 1.02 card bounce + haptic + 5s undo snackbar; over-limit → Relapse-Red ring, kind copy, Breathe/Coach actions, honest footer; repair-token dim note | ✅ |
| 32 | Panic 1 Breathe | Oxygen ground, 4-7-8 ring with phase haptics, live craving timer, skip-to-why | ✅ |
| 33 | Panic 2 Your why | user's own C1 chips + B4 math, intensity slider, "It passed" exits to celebration | ✅ |
| 34 | Panic 3 Break loop | game / buddy-ping (pre-written) / coach, late-timer copy | ✅ |
| 35 | Craving survived | confetti + rolling total + 8 rotating celebration lines (never twice in a row) + share card | ✅ |
| 36 | AI Coach chat | Ember header, stat-citing scripted replies, inline YOUR WEEK card, chips, typing flame pulse (+ screen-reader label), free-tier counter | ✅ |
| 37 | Plan | morphing curve with glowing today marker, COMING UP milestones, adjust sheet — no reset, no lost history | ✅ |
| 38 | Stats | Day/Week/Month, Ember hard-day bar with kind caption, trigger-hours heatmap → danger window, nicotine trend, personal records, long-press day editor | ✅ |

## RUN 3 — `LastPuff Run 3.dc.html` (frames 39–52) — priority 3

| # | Frame | Implementation | Status |
|---|---|---|---|
| 39 | Health timeline | rolling `lastPuffAt` anchor, Volt line grows to "you are here", honesty source note | ✅* — anchored to last puff (docs/03 §6 rolling rule), not the mock's inconsistent 14h/48h pairing |
| 40 | Money | rolling hero, goal bars, custom goals, goal-funded **confetti**, "math is yours" note | ✅ |
| 41 | Mood check-in | 5-emoji sheet, optional note, mood↔craving unlock meter | ✅ |
| 42 | Weekly AI insight | swipeable story cards, one insight + one move each, ends on next week's plan | ✅ |
| 43 | Community feed | anonymous animal avatars, tag filters, SOS pinned 60min with Oxygen ring, reactions, report/block menu | ✅ |
| 44 | Post composer | tag required, SOS flips Post to Oxygen, persistent kindness line, always-anonymous row | ✅ |
| 45 | SOS rally | "have your back" banner, replies, OP update highlighted Oxygen | ✅ |
| 46 | Buddy / invite | side-by-side flames, combined streak, nudge with **2/day cap**, privacy contract, invite link copy | ✅ |
| 47 | Milestones | pinned next-badge progress, earned glow / locked grayscale grid, "not a leaderboard" | ✅ |
| 48a | Slip — what happened | trigger chips, zero red, teammate tone | ✅ |
| 48b | Slip — adjust | bumped curve reflow, +2 days honest stretch, dimmed-flame card, coach path | ✅ |
| 49 | Profile | Freedom-Day countdown hero, Your Why, lifetime stats, alias/avatar editor | ✅ |
| 50 | Settings | account, subscription lifecycle routes, notifications + inline danger-hours editor, privacy export/delete, Appearance, Language (added), sign out | ✅ |
| 51 | Push set | lock-screen mock reference — in-app renderings exist (D4 danger-hour preview, trial-ending push); OS push delivery is FCM phase | 🔌 |
| 52 | Widgets + states | empty-stats state ✅ · offline pill + error card built as `LpOfflineBanner`/`LpErrorCard` (`core/widgets/lp_misc.dart`) 📐 — surfaced when real IO exists · iOS/Android home-screen widgets = native WidgetKit phase (docs/05 §3) | ✅ / 📐 / 🔌 |

## Run 2 Light — `LastPuff Run 2 Light.dc.html` (Daylight Ember) — priority 4 (last)

| Item | Status |
|---|---|
| Full Daylight palette as `LpColors.daylight()` (`lib/app/theme/lp_colors.dart`) — audited hex-for-hex against the file: ground `#F6F8F4`, surface `#FFFFFF`, borders `#E3E7EE`/`#E4E6DF`, subtle `#F0F3EC`, ring `#84B400`, accent text `#587E00`, focus `#A5CD1F`, panic `#EAF4F9`, ember text `#CE6A00`, oxygen text `#0787B4`, danger text `#CC4444`, nav `rgba(255,255,255,.97)`, text `#191D27`/`#39404E`/`#68727E`/`#ABB2BD` | ✅ no drift |
| Every screen renders in both themes via semantic tokens (no per-screen theme code) | ✅ |
| Theme switcher: Settings → Appearance (System / Midnight / Daylight) | ✅ |
| CI lock: `test/app_smoke_test.dart` asserts the Daylight and Midnight grounds on Home | ✅ |

---

## Round 2 — "Notes:" annotation sweep (154 details audited)

An exhaustive sweep of every frame's "Notes:" annotation against the code produced a second fidelity round. Fixed:

- **Systemic**: begin-less `Tween(end:)` never animates a first build — `RollingNumber`, `GlowProgressBar`, `BarChart`, `ProgressRing` all gained a real `begin`, restoring every "rolls up on open" hook (reveal stats, money hero, survived 22→23 roll, insight/stats chart draw-ins, profile countdown).
- **PressScale** now overshoots to 1.02 on release (the "1.02 bounce" of every note) instead of only sinking to 0.97.
- Run 1: welcome shimmer tease · birth-year odometer digits · tried-banner 250ms slide-up · severe-tier haptic thud · Why-chip catch-pop + haptic · pace curve 400ms morph + pulsing Ember Freedom dot · staggered reveal counters · commit haptic ramp light→medium→**heavy** + pre-commit specks · option-border fade 150ms · progress bar never animates backwards · under-18 resource CTAs act (copy contact) and Close **exits the app** · "fear of failing" earns a coach note on the Method screen · Day-1 CTA always targets the next unchecked task · win-back = one-time in-app card on Home for Free users (docs/02 §4), burned on open.
- Run 2: login shake (2px, kind copy) · Home **LOG PUFF pinned in the thumb zone** (no longer scrolls away) + ring-card log bounce + honest over-limit footer · panic breathing haptics tick with the ring (silent through the hold) · survived counter rolls previous→new + share copies an anonymous stat line · coach chips **prefill** the composer (protocol routing preserved per locale) + typing bubble announces "Ember is typing…" to screen readers · Stats heatmap **taps into the danger-hours editor** (sheet shared with Settings).
- Run 3: health Volt line grows in · money goal bars spring + goal-funded confetti · community **Mute** + brand/sourcing **auto-hold** with honest copy + one-tap reply flagging · buddy nudge 2/day cap + flame chips scale with streak · milestones next-badge card pinned + badge-unlock confetti · slip curve shows the bump then **visibly reflows** · profile Why card links into the panic reframe.

## Standing deviations (intentional — spec or phase outranks the mock note)

1. **Honest numbers** — the mocks' `$47`/`$312`/`52 of 200` figures are not reproducible under the app's own money/taper math (docs/03); every number on screen is engine-computed. "No invented numbers" outranks mock fidelity.
2. **Severe badge threshold** — follows docs/02 (301+ = Severe), not the Run 1 mock's 200→red.
3. **Health anchor** — rolling last-puff anchor per docs/03 §6, resolving the mock's internal inconsistency.
4. **A4 reaction copy** — one shared reframe for any answer above "Never", exactly as docs/02 A4 specifies (the mock note's "personalized per answer" has no spec copy to draw on).
5. **SOS pin window** — 60 minutes per docs/03 §9 (the frame-43 note says 30; spec wins).
6. **"Only place Oxygen is used"** (frame 32 note) — contradicted by the design's own Run 2/3 frames (SOS, coach, insight all use Oxygen); the palette follows the frames, not the note.
7. **Curve morph easing** — 400ms emphasized ease rather than a literal spring (overshoot on a 0..1-clamped curve reads as a glitch).
8. **Backend/native-phase notes** — Face ID auto-login (`local_auth`), panic intensity feeding the coach memory card + weekly report, slip triggers feeding the heatmap, live SOS viewer counts, real buddy pushes, StoreKit rating, SMS/web deep links (`url_launcher`): all deferred to the Firebase/integration phase per docs/04–05; the UI seams exist.


---

## Round 3 — live emulator verification, every frame, both themes (Aug 17–18, 2026)

All 52 frames were walked **screen-by-screen on an Android emulator** (Pixel-class, 1080×2400), first end-to-end in **Midnight (dark)**, then end-to-end in **Daylight (light)** — organic navigation where the product offers it (onboarding funnel, login, panic loop, tabs, quick links, profile/settings) and the Frame Map (Settings → "All 52 design frames") for preview-only states. Every screen was screenshot-compared against its design frame. Result: **52/52 match in both themes** after the fixes below.

Defects found by the walk and fixed (all covered by `flutter analyze` 0 issues · `flutter test` 20/20 green):

1. **Stats hard-day caption rendered "— —."** when the hardest day had no mood note — added a no-reason fallback caption (statsHardDayCaptionPlain, all 5 locales) and seeded the demo Tuesday with the design's "party night" note.
2. **Insight charts crashed** ((num,num)=>num vs (int,int)=>int reduce covariance) and cascaded into a full-page overflow — BarChart now folds with an explicit double accumulator; all four insight pages render in both themes.
3. **Under-18 "Close" killed the app from the Frame Map** — now pops back when the route was pushed; still exits at the real onboarding dead-end.
4. **Backing out of the first onboarding step wiped the navigation stack** (go('/auth')) — same pop-when-pushed treatment; Frame-Map previews return to the map.
5. **Panic Mode could open under a lingering "Logged 1 puff / Undo" snack** that swallowed the step controls — PanicFlow clears snackbars on entry (the takeover owns the screen).
6. **Post composer overflowed 3.4px with the keyboard up** — body now scrolls under a min-height constraint; the kindness card stays pinned whenever there is room.
7. **An unconfirmed in-progress today zeroed the streak** (day-2 morning showed 🔥 0 after a clean day 1) — StreakEngine.currentStreak now anchors to yesterday until today is confirmed; a slip **dims** the flame instead of killing it (docs/02), locked by a new unit test.

Verification evidence: ~90 numbered screenshots (d*/l* series) in the session scratchpad, one per frame per theme, plus interaction checks (nudge cap, coach chip routing + week card, danger-hours save reflected in Settings, share-copy, mood investment meter, game scoring, forgot-password cooldown, winback burn-once, honest date/limit rollover across midnight).

---

## Round 4 — pre-commit code review (DRY / SOLID / best practices, Aug 18, 2026)

Full-codebase review (all 67 hand-written Dart files). Architecture held up: pure-Dart domain engines, repository-interface seam, Riverpod Notifier MVVM, token-only styling, zero hardcoded UI strings in views. 19 findings fixed, `flutter analyze` 0 · `flutter test` 20/20 · debug APK builds:

**Correctness/UX** — Adjust-plan sheet preselected a hardcoded 30-day pace instead of the user's actual runway · selected SOS/oxygen chips used raw Oxygen as text (light-theme contrast) — LpChip now maps every accent to its text token · login's wrong-password error clears while retyping · register's invalid-email used a raw SnackBar bypassing showLpSnack's replace contract · Welcome's "Restore purchase" was a dead link · Insight's ✕ got a 40×40 tap target.

**DRY** — celebrate-on-new-milestone confetti (was duplicated in Milestones + Money) extracted to `NewIdConfetti` · OS push-preview bubble (duplicated in D4 + trial-ending) extracted to `PushPreviewCard` · all paywall prices centralized in `LpPricing` (the StoreKit seam) · invite URL centralized in `LpLinks` and removed from all 5 ARBs (URLs aren't translations) · buddy's magic `2` now reads `CommunityStore.nudgeDailyCap` · settings' chevron-in-translation hack removed (glyph belongs to the row template) + one language map for row and picker · JourneyStore's day-limit computation deduped into `_limitOn` · dead `tab(index:)` param and unused `ConfettiBurst.play` removed.

**SOLID/design system** — cravings-fade day (70% rule) and projected-puffs-avoided moved from views into `TaperEngine` · new `caution`/`cautionText` theme tokens replace the one raw hex in a feature file (moderate-dependence badge; also fixes its light-theme contrast) · seeded goal names ("Tokyo flight", "New kicks") now resolve through l10n like seed posts · goal/alias sheet controllers disposed via `whenComplete` · deliberate non-token colors (Apple HIG button, iOS rating-sheet blue) annotated as intentional.

## Round 5 — data-layer verification fixes (Aug 18, 2026)

Two defects surfaced while emulator-verifying the API-shaped data layer, both fixed and regression-tested (`test/widgets/ui_regressions_test.dart`), verified live on emulator-5554:

**Auth forms overflowed under the keyboard** — Register (36px) and, on smaller viewports, Login/Forgot. All three now wrap their Column in `_AuthScrollView` (scroll under a min-height with `IntrinsicHeight` so the Spacer-pinned footer stays put) — the same idiom the community composer already used.

**Action snack bars never auto-dismissed** — when the platform reports accessible navigation (which some environments report spuriously), the framework deliberately skips its timeout for snack bars that carry an action, so "Logged 1 puff · Undo" sat on screen forever, covering the LOG PUFF CTA. `showLpSnack` now bounds every snack's lifetime itself: a fallback timer closes whatever is still showing at `duration + 250ms`, cancelled the moment the snack closes by any other path (timeout, swipe, replacement). Do not remove this timer — the framework's own timeout is not guaranteed to run.

## Round 6 — app-level error handling (Aug 18, 2026)

Friendly, on-brand error surfaces across the whole app; verified live on emulator-5554 with airplane mode, regression-tested in `test/widgets/error_handling_test.dart` (46/46 green):

**Connectivity** — `ConnectivityStore` (data/network/connectivity.dart) polls a dependency-free DNS probe every 5s; the FakeServer reads it *synchronously* and throws `NoConnectionException` before applying anything, so offline behaves exactly like a real unreachable backend. Tests disable polling via `connectivityPollIntervalProvider: null` (see `test/helpers.dart` — every app-pumping test must use `fastBackendOverrides()`).

**Surfaces** — app-level offline strip (caution-token pill overlaid via MaterialApp.builder, slides away on reconnect); `showLpErrorDialog` (offline: "No wifi, no worries" / generic: "Well, that glitched", with "Run it back" retry) on every awaited lifecycle CTA (login, register, Apple, paywall completion); `LpErrorState` for content areas (community feed failed → "The feed ghosted us" + retry); go_router `errorBuilder` → `RouteNotFoundScreen` ("This page doesn't exist" → "Take me home"); Ember owns a lost connection in-thread (`CoachTemplate.connectionLost`, free message refunded); `LpCrashScreen` replaces the red error box (locale via platform dispatcher — the one sanctioned non-ARB copy, because Localizations may be what crashed); `LpErrors.install()` in main routes uncaught async errors to a throttled "something glitched backstage" snack instead of crashing.

**Local-first stance** — mutations never surface wire failures: `_commit` and all community write-behinds `.ignore()` errors (the banner already tells the story; a real sync/retry queue slots in there later). `restoreSession` failing at launch lands on sign-in, never a stuck splash. Added the INTERNET permission to the main AndroidManifest (release builds need it for the probe + the future backend).