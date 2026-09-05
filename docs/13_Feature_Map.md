# 📄 DOC 13 — FEATURE MAP & MANUAL TEST SCRIPT

**Created:** Sep 4, 2026 · **Status:** LIVE — update it as features land or die · **Depends on:** the code, not the specs.

> **Purpose:** every user-facing feature the app has today, in one list, with what it does and the taps that exercise it. Written from `lib/features/`, the router and the domain layer — not from docs 1–7, which describe things that were since descoped, renamed or rebuilt. When this file and a spec disagree, this file describes what a tester will actually see.
>
> Companion docs: `docs/08` = status and blockers · `docs/10` = dated build history · `docs/09` = the Sep 1 field-test round.

---

## 0. HOW TO RUN THE PASS

**Two backends, one app.** `backendModeProvider` decides who answers.

| Build | Backend | What that means |
|---|---|---|
| `./tool/device.ps1` (Windows) | **real Firebase** | Everything works, including AI. Data persists. The only way to test 🔥 rows. |
| `flutter run` on desktop/web, or any build with `--dart-define=LP_BACKEND=fake` | **FakeServer** | In-memory demo. Fast, no network, **resets on app restart**. AI rows are canned. |
| `./tool/device.ps1 -Test` | — | The on-device E2E suites. |
| `./tool/device.ps1 -Analytics` | real Firebase | Same, but events actually reach Amplitude/Firebase (otherwise silent outside release). |

**Accounts to test with**

- **Fake backend, day-12 Premium persona:** log in with any email (the field pre-fills `maya@quitmail.com`), password **≥ 6 chars**. A password under 6 chars is the "wrong password" path. Restores Maya / @quietfox, day 12 of a 30-day taper, **Premium**.
- **Fake backend, fresh free account:** *Continue with email* → register. New accounts start with **no entitlement** — the only way to see Free gating on the fake backend. Registering `maya@quitmail.com` is refused as already-in-use (deliberate).
- **Real Firebase:** register, or Google (Android) / Apple (iOS). Tier comes from RevenueCat.

**Legend**

- 🔥 = **needs real Firebase** (a Cloud Function answers). On the fake backend the feature renders, but with canned content.
- **Free** = every account · **Pro** = premium-gated (lock + paywall door) · **Admin** = needs the `admin` custom claim.

---

## 1. SESSION & ACCOUNT

| # | Feature | What it does | Manual test |
|---|---|---|---|
| 1 | **Splash / session restore** | The launcher tile (the same rounded art the home screen shows) over a breathing Volt glow, wordmark and tagline beneath, the group centred on the screen; ~1.5s while the backend session is restored. Routes to Home (has journey) or sign-in (none). | Cold-start. The tile, "Cirrus" and the tagline sit stacked in the middle of the screen, never in a corner. Kill and reopen while signed in → lands on Home, never on a stuck splash. |
| 2 | **Launch paywall** | Once per day, free accounts only, pushed over Home after the splash. Never shown while the tier is still unknown. | Free account, cold start → paywall over Home. Restart the same day → it does not return. Premium → never. |
| 3 | **Sign in with Google** (Android) | Native Google sheet → Firebase account. An existing journey restores to Home; a new account goes to onboarding. | Android only. Dismiss the sheet → nothing happens (a dismissal is not an error). |
| 4 | **Sign in with Apple** (iOS/macOS) | Same flow, Apple sheet. Hidden on Android. | iOS only; check the Google button is absent. |
| 5 | **Register with email** | Email + password (min 6), live 3-bar strength meter, then onboarding. | Try `abc` with no `@` → snack. 3-char password → snack. `maya@quitmail.com` on fake → "already in use". |
| 6 | **Log in with email** | Restores the journey. A wrong password shakes the field 2px with kind copy — never a red alarm. | Wrong password → shake + inline message; typing clears it. |
| 7 | **Forgot password** | Sends a reset link, shows an inline ✓ banner, disables *Resend* for 30s with a live countdown. | `/auth/forgot` → Continue → watch 30 → 0. |
| 8 | **Sign out** | Confirmation, then back to sign-in. Cancels every scheduled notification. | Settings → *Sign out*. |
| 9 | **Delete account** 🔥 | Runs `deleteUserData`: journey, server-owned user tree, coach memories, uid↔post map. Community posts are anonymized, not removed, so threads keep no holes. Busy state while it waits. | Settings → Privacy card → *Delete everything* → confirm. Signing in again onboards fresh. |
| 10 | **Legal + support links** | Terms and Privacy in the sign-in footer and Settings; Website; Support opens a mail app **and** prints the address underneath. | Tap each. With no mail client, the address must still be readable. |

---

## 2. ONBOARDING — 21 steps, `/onboarding`

| # | Feature | What it does | Manual test |
|---|---|---|---|
| 11 | **Welcome + resume draft** | Step 1. An unexpired draft offers to resume where you stopped, showing how far you got. | Answer 4 questions, kill the app, return → *Resume* with the right count. |
| 12 | **Identity** | Gender, birth year. | — |
| 13 | **Age gate** | Under 18 routes to a dead end. Not skippable. | Enter a year making you 17 → the flow stops. |
| 14 | **Habit quiz** (the 12 counted steps) | Tried before · frequency · puffs/day · nicotine strength · weekly spend · first puff after waking · why (multi) · worries (multi) · method (taper vs cold turkey) · pace (days). Progress reads 1/12…12/12 and Back always works. | Walk all twelve; back out and forward again — answers persist. |
| 15 | **Building screen** | The animated "building your plan" beat. | — |
| 16 | **Plan reveal** | Your Freedom Day, projected saving, puffs the taper removes, and the curve — all engine-computed from your own answers. | Two different quiz runs must give two different reveals. No round marketing numbers. |
| 17 | **Coach name** | Names your coach; defaults to Ember, CTA reads *Keep Ember* until you type. | Type `Koda` → every later screen says Koda, including the Day-1 tour and chat header. |
| 18 | **Why words** | One line in your own words. The placeholder is tailored to a *why* you actually picked (Family > Fitness > Health > Freedom > Money > Appearance). | Pick only Money → the money hint. A hint is never stored as your words. |
| 19 | **Commit** | Press-and-hold commitment beat. | Release early → it does not advance. |
| 20 | **Rating** | Opens the real store review sheet. Does **not** gate on your opinion and never claims a rating was submitted. | On device the OS sheet may or may not appear; the app must claim nothing either way. |
| 21 | **Notifications permission** | The one place the OS permission is asked for. Copy names danger-hour nudges, the trial reminder and milestone celebrations — all three exist. | Deny → the app continues; the Settings toggle reflects reality. |
| 22 | **→ Paywall → Day 1** | Onboarding ends on the paywall (`source=onboarding`), then the Day-1 checklist. | — |

---

## 3. PAYWALL, SUBSCRIPTION & PREMIUM GATES

| # | Feature | What it does | Manual test |
|---|---|---|---|
| 23 | **Paywall (D5)** | Your own plan reveal, then the trial timeline (today → reminder → first charge), then plan cards. **Every price is the store's**; the typed fallbacks appear only when no offering loads, under a caption that says so. The trial-reminder toggle ships ON. | Open from any lock. A period the store does not offer gets **no card** — two cards on the Test Store is correct, not a bug. |
| 24 | **Free plan comparison** (D5b) | Side-by-side Free vs Pro with real numbers (5/day vs 100/day, 7 days vs Forever) read from `LpAllowances`. Pro is the button, Free is a link — one tap away, never hidden. | Paywall → *see what Free gets*. The numbers must match §4 below. |
| 25 | **Purchase** | Opens the store's own sheet. A sheet that closes without the entitlement is **Pending**, not success (Play deferred payments, Ask to Buy). | Sandbox purchase → gates unlock with no restart. |
| 26 | **Restore purchases** | Real restore, on the paywall and in Settings (the Settings row shows only while unsubscribed). Says plainly when there was nothing to restore. | Reinstall → Settings → Restore. |
| 27 | **Manage subscription** | Opens the store's manage page. When the store gives none (family-shared or promo grant) it says where to manage instead of faking a page. | Settings → Subscription while subscribed. |
| 28 | **Trial-ending screen** | Reached from the Subscription row during a trial and from the trial reminder's tap. Shows your own first-week wins; keeping Premium needs no action. | Settings → Subscription (trial). |
| 29 | **Winback / founding offer** | The $3.99 first-month card. **Disabled** until the tagged store offer exists — do not test as live. | Confirm it does **not** appear on Home or in Settings. |
| 30 | **Premium gates** | One blurred `LpPremiumGate` everywhere, each with a paywall door tagged by source: Home nudge · Stats Month + 7-day clamp + forecast heatmap · Health past node 4 · Plan adaptive card · Insight · coach cap · composer allowance · panic Tiles/Blocks. | On a **free** account visit each. Every lock leads to the paywall; none may overflow or hide what is behind it. |

---

## 4. WHAT FREE ACTUALLY GETS — the numbers to verify

| Allowance | Free | Pro |
|---|---|---|
| Coach messages / day | **5** | **100** (marketing may say unlimited; the server enforces 100) |
| Ordinary posts / day | **1** | **3** |
| SOS posts / day | **3**, from its own counter — refused for no tier | 3 |
| Live SOS at a time | 1, pinned for 1 hour | same |
| Stats history | **7 days**, Week range only | 30 days + Month + forecast heatmap |
| Health timeline nodes | **4** — a floor; a node you have reached is never re-locked | all |
| Panic games | **Orbs** | Orbs + Tiles + Blocks |

---

## 5. DAY ONE

| # | Feature | What it does | Manual test |
|---|---|---|---|
| 31 | **Day-1 checklist** | Three setup moves; the CTA always points at the next unchecked one. A row **navigates** — it never ticks itself. | A fresh account lands here after the paywall. |
| 32 | **Day-1 walkthrough** | Holds the rest of the app closed while it teaches three real moves: log one puff on Home, say something to the coach, set your danger hour. The tab bar becomes a single *back to checklist* control. | Do all three. Force-quit mid-tour → you return to the checklist, not a stranded app. Skip is available. |

---

## 6. HOME — `/home`

| # | Feature | What it does | Manual test |
|---|---|---|---|
| 33 | **LOG PUFF** | Pinned in the thumb zone. **One tap = exactly one puff.** Ring tick, 1.02 bounce, light haptic. | Tap 18 times fast → the count rises by exactly 18. |
| 34 | **Press-and-hold log** | The "I had ~30" path: auto-repeat, one puff per tick, the rolling number as live feedback. | Hold, watch it climb, release → one undo snack for the whole burst. |
| 35 | **Quick-log `+`** | The unmarked button in the middle of the tab bar; same rules. Hidden during the Day-1 tour. | Tap and hold it from any tab. |
| 36 | **Undo** | A 5s snack carrying the burst total. | Undo → the count returns exactly. |
| 37 | **Adjust today** | Tap the ring card → stepper sheet (min 0, hold a stepper to run). The way back once the undo snack is gone. | Overshoot with a hold, then correct. |
| 38 | **Over-limit state** | The card folds into the over-limit treatment with honest copy and two actions (panic, coach). | Log past today's limit. |
| 39 | **Repair token** | A streak-saving token absorbs a slip day: the flame dims, it never dies. Derived from history (7 completed holding days = +1, cap 2), never stored-and-trusted. | On the day-12 persona, cross the limit and read the note. |
| 40 | **"Was yesterday vape-free?"** | The morning-after card when a day went unlogged or unconfirmed. Two answers, both yours: confirm, or *I vaped* → the day editor. It never assumes. | Fake backend: skip a day. |
| 41 | **Zero-limit day confirm** | On a 0-limit day the confirm card is up all day; on every other day it waits until 8pm. | Reach day 30 of a taper. |
| 42 | **Mood check-in** | A prompt card after 6pm when no mood is logged → sheet with 5 emoji + optional note. | Home after 18:00 → dismissible card → sheet. |
| 43 | **Craving nudge** (Pro) | Your risky hour, from your own logs, on the screen you open most. Only once a real danger window exists — never a hardcoded hour. | Free account → the same slot shows a paywall door tagged `nudge`. Both branches are dismissible. |
| 44 | **Slip card** | Appears after a slip; opens slip recovery. | — |
| 45 | **Money + cravings bento** | Two live tiles → Money and Milestones. | Tap each. |
| 46 | **Header** | Date/day chip → Plan · avatar → Profile · badge count → Milestones. Never says "Day 31 of 30" — past the end it says maintenance. | Tap all three. |
| 47 | **Quick links** | A row into every lifecycle surface (Plan, Health, Insight, Settings…). | — |
| 48 | **SOS button** | Persistent floating Ember button; it never moves. | Tap → panic takeover. |
| 49 | **Freedom Day state** | Day 30 of 30 renders as its own completion state, not as another 0-limit day. | — |

---

## 7. STATS — `/stats`

| # | Feature | What it does | Manual test |
|---|---|---|---|
| 50 | **Range Day / Week / Month** | Month is Pro; free is clamped to Week and tapping Month opens the paywall (`source=history`). | Free → tap Month. Premium → it switches. |
| 51 | **Week bars** | A **calendar-day** window, not "the last N logged days", with the hard day in Ember and a kind caption. | Skip a day → the chart must not slide into last week. |
| 52 | **Edit a past day** | Long-press any bar → stepper sheet. History is user-ownable. | Long-press, change a value → streak and money re-derive. |
| 53 | **Trigger-hour heatmap** | Your puffs by hour; tapping it opens the danger-hours editor. | Tap the heatmap. |
| 54 | **Forecast heatmap** (Pro) | The predicted-risk layer. | Free → blurred, with the door. |
| 55 | **Nicotine trend** | ≈ mg/day, engine-computed. | — |
| 56 | **Personal records** | Longest gap (h), best day, cravings beaten. Personal bests only, never a leaderboard. | — |
| 57 | **Empty state** | An honest "nothing logged yet" rather than invented bars. | Fresh account → Stats. |

---

## 8. PLAN · MONEY · HEALTH · MILESTONES · INSIGHT

| # | Feature | What it does | Manual test |
|---|---|---|---|
| 58 | **Plan curve** (`/plan`) | The live taper curve with a today marker and coming milestones. | Home header chip → Plan. |
| 59 | **Adjust plan** | Change method (taper / cold turkey) and pace **without resetting** progress. | 30 → 21 days: the streak and history survive. |
| 60 | **Adaptive card** (Pro) 🔥 | The nightly `taperRecalc` made visible — why tomorrow's number moved. Framed as the plan adapting, never as you failing. | Free → gated. |
| 61 | **Money** (`/money`) | Rolling savings hero and a "the math is yours" breakdown. | Log puffs → the number moves. |
| 62 | **Savings goals** | Add and edit your own goal with a target. Crossing 100% on screen fires confetti. | Add a $1 goal and cross it. Nothing is ever pre-invented for you. |
| 63 | **Health timeline** (`/health`) | Recovery milestones anchored to your **rolling last puff**, not to Freedom Day. | Log a puff → the anchor moves and earlier nodes re-arm. |
| 64 | **Health gate** (Pro) | Free sees at least 4 nodes; a node you have already reached is never locked, however far along you are. | Free account on day 12 → reached nodes stay open. |
| 65 | **Milestones** (`/milestones`) | 17 badges — earned glow, locked grayscale, next-badge progress pinned on top, confetti on an unlock you are watching. | Earn `firstLog` on a fresh account. |
| 66 | **Weekly insight** (`/insight`, Pro) 🔥 | Swipeable story cards: the report `weeklyInsight` wrote **for you**, over charts drawn from your own logs. With no report it says so — it never fills the space with invented findings. | On the fake backend the pending state is the correct result. |

---

## 9. COACH — `/coach`

| # | Feature | What it does | Manual test |
|---|---|---|---|
| 67 | **Chat with Ember** 🔥 | Streaming replies that cite your own data, under whatever name you gave the coach. | Ask "why is today hard?" → the reply should quote real numbers. |
| 68 | **Follow-up chips** 🔥 | 3–4 things **you** might say next, written fresh each turn. The fake backend always shows the four static openers — which is also the honest production fallback (older backend, restored transcript, cap, mid-craving turns). | Real Firebase only. Four static chips on fake is not a bug. |
| 69 | **Week card** | An inline YOUR WEEK stat card on the same calendar window Stats uses. Hidden until two days have puffs — one point is not a trend. | Fresh account → no week card. |
| 70 | **Free cap** | 5 messages/day, then an in-thread cap CTA to the paywall. Server-enforced. | Free account → send 6. |
| 71 | **Panic mode** | Arriving from the panic flow (`?panic=8`) puts Ember in a short, directive voice for the next message. | Panic → *talk to Ember* → the reply reads visibly different. |
| 72 | **Connection failure** | Fails in-thread with a retry, and **refunds** the free message. | Airplane mode → send. |
| 73 | **Rename the coach** | Settings only — never the chat header, which is one mis-tap from a rename mid-craving. Stored transcripts and memories are deliberately not rewritten. | Rename → the greeting and next reply follow; history keeps the old name. |
| 74 | **Memories** (`/coach/memories`) 🔥 | Two sections: *what it always knows* (your own journey data, not forgettable) and *things you've told it* (chat-extracted, each with Forget). | Tell Ember something personal → it appears → forget it. |

---

## 10. COMMUNITY — `/community`

| # | Feature | What it does | Manual test |
|---|---|---|---|
| 75 | **Anonymous feed** | Posts with alias and day count. Live SOS posts pin to the top for an hour with an Oxygen ring. | Scroll; retry after an error. |
| 76 | **Tag filter** | win · sos · day1 · milestone · vent. | Tap each chip. |
| 77 | **Composer** (`/community/compose`) | Tag required, always anonymous, day count auto-attached. | Post something over 12 characters. |
| 78 | **Quality floor** | 12 chars, 3 words, 2 distinct words, 3 letters, 4 distinct letters — checked **before** any allowance is spent, so junk never costs a slot. Deliberately low: `help me please` publishes. | `a` → refused, no slot spent. `help me please` → publishes. |
| 79 | **Post allowance** | 1/day free, 3/day Pro. The blocker appears **under your text with the words still there to edit**, and only carries a paywall door when a subscription would genuinely have let this post through. | Free → post twice. |
| 80 | **SOS post** | Own counter (3/day), refused for no tier. A second SOS while yours is still pinned says *yours is still up there* — never "come back tomorrow" — and spends no slot. | Post an SOS, then try another inside the hour. |
| 81 | **Post status** 🔥 | Four honest states for your own post: `pending` (spinner, seconds), `held` (a human is looking), `blocked`, `failed` (retry on the row). Retry is safe — posting is idempotent on the client id. | Airplane mode → post → *failed* → retry online. |
| 82 | **Post detail + replies** | Open a post, reply, and see the backup count — real replies plus reactions; zero renders nothing. | Reply with `thanks`; replies have a much looser floor (6 chars, no word minimum). |
| 83 | **Reactions** | Emoji pills, one per person, your own outlined. | Tap twice → toggles off. |
| 84 | **Report / mute / block** | Per-post menu; three reports auto-hide a post. Your own posts show no menu. | Report one post, then check a *different* post is unaffected. |
| 85 | **Moderation queue** (`/moderation`, Admin) 🔥 | The founder's review queue. No decision looks applied until the server confirms it. | Only visible with the `admin` claim; the Settings row is absent otherwise. |

---

## 11. PANIC — `/panic`

| # | Feature | What it does | Manual test |
|---|---|---|---|
| 86 | **Takeover** | Full-screen 250ms fade onto the Oxygen ground. Clears any snackbar on entry. | SOS from Home. |
| 87 | **Step 1 — breathing** | A 4-7-8 pacer: the instruction is on screen from the first frame, the orb rests at 40% so the first inhale is visible, a pointer laps the track through the hold, haptics match. | Watch a full cycle — it must not read as a pressed button. |
| 88 | **Craving timer** | A live mm:ss pill — "peaks ~15 min". | — |
| 89 | **Step 2 — your why + intensity** | Your own why words plus a 1–10 intensity slider, which rides along to the coach. | Set 9, then take the coach door. |
| 90 | **Step 3 — break the loop** | Three doors: **game**, **SOS post** (composer pre-tagged `sos`), **coach**. The coach door **never** becomes a paywall mid-craving. | Free account past its cap → the coach door still opens the coach. |
| 91 | **"It passed"** | On every step; ends the session as survived. | — |
| 92 | **Game arena** (`/panic/game`) | 60-second rounds chained up to five, games swapped in place by the pills. No game-over — a round ends on "still craving, 60 more" or "it passed". An abandoned round is recorded nowhere. | Play a round to the line, then chain another. |
| 93 | **Orbs** (Free) | The free game, and always the landing game: a stored or deep-linked locked game is clamped to it, so nobody meets a lock mid-craving. | Free account → open the arena → Orbs. |
| 94 | **Tiles / Blocks** (Pro) | Two more games. A locked pill shows a card that leads with **Play Orbs**; *See Premium* is the secondary text link. The lock never appears mid-round. | Free → tap Tiles. |
| 95 | **Personal bests** | Per game, recorded only when a round ran to the end. | Beat a best; then abandon a round → nothing recorded. |
| 96 | **Survived screen** | Confetti, rolling craving counter, the game result, and *share the W* (copies to the clipboard). | Tap share → the snack confirms the copy. |

---

## 12. SLIP · PROFILE · SETTINGS

| # | Feature | What it does | Manual test |
|---|---|---|---|
| 97 | **Slip recovery** (`/slip`) | Pick what triggered it (party · stress · boredom · drinking · friends · just happened), then land on Home or the coach. Teammate-reviewing-film tone; **no streak-zero moment is ever shown**. | Home slip card → walk it. |
| 98 | **Profile** (`/profile`) | Countdown hero, Your Why, lifetime stats, links to Milestones / Insight / Settings / panic. | — |
| 99 | **Edit profile** | Your alias and avatar emoji. | Change both → the Home avatar and every post byline follow. |
| 100 | **Notifications toggle** | The master switch; off cancels everything scheduled. | Toggle off → no nudges arrive. |
| 101 | **Danger hours** | One question, one answer: pick the risky hour from labelled chips (only hours passing the quiet-hours rule are offered) and it prints the exact fire time — **one** push, 10 minutes before, every day. | Settings' inline row, or the Stats heatmap. Pick 9 PM → it says 8:50 PM. |
| 102 | **Appearance** | The mode: dark · light · match system. Orthogonal to the theme below, so "match system" keeps working whichever family you wear. | Switch → every screen re-themes; check the panic flow and paywall. |
| 102b | **Theme** (Premium) | The palette family: **Ember** (free, the original) · **Hearth** (warm amber on charcoal/linen) · **Tide** (teal on indigo/arctic). Each has its own dark and light. Locked families stay visible and tappable with real swatches; tapping one opens the lock card, never the theme. | Free account → Settings → Theme: three cards, two locked. Tap Hearth → paywall tagged `theme`, app still Ember. Buy → the cards unlock in place. Pick Hearth → walk Home/Stats/Coach/panic in both modes. Kill and relaunch → it survives. |
| 103 | **Language** | en · es · fr · de · pt. | Switch to pt → no English leaks and no sentence with a hole where a value should be. |
| 104 | **App version footer** | The real package version. | — |

---

## 13. NOTIFICATIONS — on-device, inexact by design

| # | Feature | What it does | Manual test |
|---|---|---|---|
| 105 | **Danger-hour nudge** | One local push, 10 minutes before your chosen hour, daily, never inside quiet hours. Free for everyone. Inexact — it may run late, never early. | Set the hour a few minutes out, background the app, wait. |
| 106 | **Trial-ending reminder** | The day before the first charge. Scheduled on-device because no store sends this event. | Start a sandbox trial. |
| 107 | **Milestone celebration** | Five moments across a 30-day plan (badges at 3, 7, 14 and 30 days, plus Freedom Day), at 08:00. Only ever celebrates a badge **already earned** — it cannot congratulate a streak that might still break tonight. | Drive the device clock. |
| 108 | **Tap routing** | Every reminder carries its kind: trial → trial-ending (or Settings once it is over), danger-hour → Home. Works from cold start, after the splash has chosen the first screen. | Kill the app, tap a notification. |

---

## 14. ANDROID HOME-SCREEN WIDGET

| # | Feature | What it does | Manual test |
|---|---|---|---|
| 109 | **Cirrus widget** | Resizable 2x2 → 4x2: day number on top, today's count below, with `+` and `−`. Localized and themed, and it refuses to draw a limit it cannot know (past the plan window). | Long-press the home screen → Widgets → Cirrus. |
| 110 | **Log with the app dead** | A tap appends to an outbox; the app drains it through the same `logPuff` the in-app button uses, so there is one implementation of the counting maths. | Kill the process with `am kill` (**not** force-stop, which makes Android drop every broadcast), tap `+` three times, open the app → exactly 3 more puffs. |
| 111 | **`−` clamp** | Refuses below zero and writes no event. | Tap `−` at 0. |
| 112 | **Midnight rollover** | Day number and count roll over with the app closed, and the limit follows the taper curve. | Drive the clock forward with the app closed. |
| 113 | **Convergence** | The widget and the app never settle on different numbers, offline included. The count is recomputed from the clock at tap time, never read off the pixels — a tap on a stale widget still files today's puff on today. | Airplane mode → 3 taps → open the app → both agree. Cold restart → still agree. |
| 113b | **No session, no numbers** | Signed out, freshly installed, account deleted, or a launch that restores no session: the widget shows **"Start your plan / Tap to open Cirrus"** and nothing else. No count, no day number, no working `+`/`−`. The mirror carries no numeric keys at all in this state, and a tap is refused natively. | Sign out with the widget on the home screen → it flips to the message. Tap `+` → nothing happens, nothing queues. |
| 114 | **iOS widget** | **Not shipped.** The Swift is written (`ios/CirrusWidget/`) but the Xcode target does not exist — `docs/08` B22. | Do not test on iOS. |

---

## 15. CROSS-CUTTING

| # | Feature | What it does | Manual test |
|---|---|---|---|
| 115 | **Offline banner** | An app-level pill whenever the DNS probe fails. Optimistic writes keep working behind it — a background save never raises a dialog. | Airplane mode → log puffs: the count still moves and the banner explains why. |
| 116 | **Error dialogs** | Awaited lifecycle actions (sign-in, register, purchase, delete) fail into a dialog with a working **Retry**, with offline copy when offline. | Airplane mode → log in. |
| 117 | **Failed content areas** | The feed and other content areas fail to a retry state, not a blank screen. | Airplane mode → Community → *Retry*. |
| 118 | **Route not found** | A bad deep link lands on a friendly dead end with a way home. | Open `/nonsense`. |
| 119 | **Crash screen** | Replaces Flutter's red error box; renders even in a broken tree. | — |
| 120 | **Analytics** | Fires from **release builds only**, or with `-Analytics`, so dev runs never pollute the funnel. Screen names are route *patterns*, never user text. | `./tool/device.ps1 -Analytics`, then check Amplitude. |

---

## 16. DELIBERATELY ABSENT — do not file these as bugs

| Thing | Why |
|---|---|
| **Quit Buddies / buddy ping** | Descoped Aug 2026. It rendered an invented friend and pinged nobody. Its stage in the hook is now the community SOS. |
| **Export my data** | Removed. It showed a success snack and exported nothing; it returns when it writes a real file (`docs/08` S5). |
| **Frame Map** | Deleted Sep 3 2026 — debug-gated in Settings, but its routes shipped in every release binary. |
| **Founding-offer / winback card** | Gated off until the tagged $3.99 store offer exists. |
| **Star-rating gate** | Neither store permits asking for an opinion before the system prompt. The five-star row on D3 belongs to the testimonial, not to the user. |
| **Rating confirmation** | Neither OS reports whether its sheet appeared, so nothing may claim a rating was submitted. |
| **iOS widget** | Authored, unbuilt (B22). |

---

## 17. FASTEST FULL PASS — ~25 min, real Firebase, Android

1. `./tool/device.ps1` → splash → **register** a fresh email.
2. Onboarding: all 21 steps, rename the coach to `Koda`, deny notifications → paywall → *see what Free gets* → back → continue on Free.
3. Day-1 checklist: complete all three tour steps.
4. Home: LOG PUFF ×5, undo, hold to ~20, correct via the ring sheet, then log past the limit.
5. Free gates: Stats Month · Health node 8 · Insight · Plan adaptive · Home nudge — each must open the paywall.
6. Coach: send 6 messages → cap CTA. Say something personal → check `/coach/memories`.
7. Community: post `a` (refused), post something real, post a second (allowance), post an SOS, react, reply, report.
8. Panic: SOS → breathe → intensity 9 → one full Orbs round → chain → *it passed* → share.
9. Widget: add it, kill the process, `+ + + −`, reopen, verify the count.
10. Settings: danger hour 10 minutes out → background → wait for the push. Then language `pt`, appearance light, theme Tide. Sign out.

---

## 18. CHANGE LOG

| Date | Change |
|---|---|
| Sep 4, 2026 | Created — 120 features mapped from `lib/features/`, the router and the domain layer at commit `9ddb382`. |
