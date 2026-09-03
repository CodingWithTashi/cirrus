# 📄 DOC 3 — FUNCTIONAL SPEC (Features, Algorithms & Rules)
## Project "LastPuff" ✅ (name locked Aug 17, 2026)
**Version:** 1.0 · **Date:** Aug 17, 2026 · **Depends on:** Docs 1, 2, 5 · **Feeds:** development weeks 3–7
**✅ Founder-locked (hook-optimized):** Adaptive taper · Repair-token streaks · Lock-screen widget in MVP

> **Purpose:** the developer builds every feature from this doc without guessing. Each section = behavior + math + edge cases. The organizing principle, per founder: **maximize hook** — every mechanic below maps to the habit loop (trigger → action → variable reward → investment).

---

## 1. THE HOOK ARCHITECTURE (why each feature exists)

| Loop stage | Our mechanics |
|---|---|
| External trigger | Danger-hour push, buddy nudges, widget on lock screen (seen 80×/day) |
| Internal trigger | The craving itself — Panic Button converts the enemy into an app-open |
| Action (≤1 tap) | Log puff from lock screen; hold Panic Button |
| Variable reward | Streak flame states, surprise milestone confetti, randomized coach praise, "cravings survived" counter, community reactions |
| Investment | Your Why card, logged history, streak equity, repair tokens, buddy bonds, plan customization — each makes leaving costlier |

---

## 2. PUFF LOGGING ENGINE

**Sources (MVP):** in-app hero button · lock-screen widget · home-screen widget. (Siri/Watch = V1.1.)

**Behavior:**
- Tap → optimistic +1 in UI instantly (haptic `light` + ring tick animation) → Firestore `days/{today}.puffCount` via `increment()`.
- **Write batching:** rapid taps within 2s window coalesce into one increment write (cost control, Doc 5 §6).
- **Undo:** 5-second snackbar after each tap ("Logged. Undo?"); undo decrements.
- **Hour bucket:** every log also `hourBuckets.{H}: increment(1)` — fuels danger-hour engine (§8).
- **Offline:** Firestore offline persistence queues everything; widget logs queue via App Group storage and flush on next app/widget process wake.
- **Edit past days:** Stats → long-press a day → stepper (min 0). Edits recompute streak/money for that day forward. History is user-ownable — this was a top Puff Count complaint (locked history, plan resets).
- **"Vape-free day" button:** on Home when count = 0 after 8 p.m., one tap confirms a zero day (prevents "did they log or lapse?" ambiguity for streaks).

**Nicotine estimate:** `mgToday = puffs × factor` where factor = {20 mg/mL: 0.28, 35: 0.49, 50: 0.70} mg/puff. Always display with "≈" and label "estimate."

**Cigarette equivalence (shock stat):** `cigEq = round(puffs / 14)` — shown on Stats and share cards.

---

## 3. ADAPTIVE TAPER ALGORITHM ⭐ (the core IP)

**Inputs:** baseline `B` (onboarding puffs/day, self-corrected by first 3 logged days — see calibration), pace `P` days, day index `d` (1…P), trailing actuals.

**3.1 Base curve (front-loaded exponential — rides fresh-start motivation):**
```
limit(d) = round( B × (1 − d/P)^1.5 )
Final floor override: last 3 days fixed → [5% of B capped at 5, 3, 1] … day P = 0
```
Worked example, B=200, P=30: D1→190 · D7→134 · D15→71 · D21→33 · D27→6 · D28→3 · D29→1 · D30→0.

**3.2 Baseline calibration (days 1–3):** if avg(actual) of first 3 days > B × 1.25, silently reset B = that avg and regenerate curve from d=1 (people underestimate; a plan built on a lie fails). One-time, no shame copy: "We tuned your plan to your real numbers."

**3.3 Nightly adaptive layer (`taperRecalc` cron, per user):**
Let `A = mean(actual/limit)` over trailing 3 days.
- **A ≤ 0.85 (crushing it):** tomorrow = `min( limit(d+1), round(mean(actual) × 0.95) )` — ride momentum; never above curve.
- **0.85 < A ≤ 1.10 (on track):** follow curve.
- **A > 1.10 two consecutive days (struggling):** tomorrow = `max( limit(d+1), round(yesterdayActual × 0.90) )` AND stretch: `freedomDate += 1 day` (total stretch cap: +50% of P). Push copy: "Plan bends, doesn't break — new Freedom Day: Oct 3."
- Hard rules: limit never increases day-over-day (except §5 recovery); limit never < the fixed 3-day floor sequence until its time.

**3.4 Cold-turkey mode:** limit = 0 from chosen quit date; optional 3-day "awareness runway" before (log-only, no limits). All streak/panic/coach features identical.

**Hook rationale:** achievable limits → daily wins → logging habit. Impossible limits → churn (documented Puff Count 1-star pattern).

---

## 4. MONEY ENGINE

- `costPerPuff = weeklySpend / (7 × B)` (recompute if user edits spend or B recalibrates).
- `savedToday = max(0, B − actualToday) × costPerPuff`; lifetime = Σ savedDay. Counter rolls on Home (odometer).
- Projection on Plan screen: `projectedAtFreedom = Σ over remaining days of (B − limit(d)) × costPerPuff`.
- **"What it buys" ladder (variable reward):** $25 pizza night → $80 sneakers → $129 AirPods → $250 flight → $450 PS5 → $1,300 "your yearly vape money." Card unlocks + confetti at each threshold; user can set a custom savings goal with progress bar.

---

## 5. STREAKS & REPAIR TOKENS ⭐

**Definition — ONE streak:** *Freedom Streak* = consecutive days ending at-or-under that day's limit, with the day confirmed (≥1 log OR "vape-free day" tap).

**States (Rive flame):** Spark (1–2d) → Flicker (3–6) → Flame (7–13) → Blaze (14–29) → Inferno (30+). Visual growth = investment users won't abandon.

**Repair tokens:**
- Earn 1 per 7 consecutive streak-days. Wallet cap: 2. Shown as 🔥🛡️ chips.
- **Over-limit day:** auto-consume a token → streak number survives, flame renders "dimmed" for 24h ("your 12 days still count — flame dims, doesn't die").
- **Unconfirmed day (no logs, no vape-free tap):** grace till next-day noon reminder; then consumes a token; no token → break.
- **No token + over limit → streak breaks:** `longestStreak` is permanent and displayed forever; **Comeback ×2** activates — for 48h, streak-days count double toward the next flame state (loss aversion → immediate re-engagement instead of rage-quit).
- **Recovery mode** (from Doc 2): on a big relapse (> limit × 2), offer plan flatten: insert 2 plateau days at yesterday's actual, shift freedomDate, coach opens a check-in. Never a lecture.

---

## 6. HEALTH RECOVERY TIMELINE

Time anchored to `lastPuffAt` (rolling — resets on any logged puff after a zero streak begins; for taper phase, anchored to Freedom Day).
20 min: heart rate settles · 8 h: oxygen normalizing · 24 h: nicotine dropping fast · 72 h: nicotine ~gone, cravings peak — Panic Button promoted · 1 wk: taste & smell sharpen · 2 wk: circulation up · 1 mo: lung function improving · 3 mo: cough fading · 6 mo: stress baseline down · 1 yr: massive risk reduction.
Copy note: adapted from smoking-cessation literature; all cards labeled "based on smoking research — vaping evidence still emerging" (honesty rule + App Review safety). Each unlock = push + confetti + share card.

---

## 7. PANIC BUTTON — SESSION LOGIC

- Entry: Home button, widget long-press, push deep link, or coach chip. Full-screen takeover ≤ 400 ms (pre-warmed route).
- **Step 1 Breathe (60–120s):** Oxygen ring 4-7-8; intensity slider (1–10) captured on entry.
- **Step 2 Your Why:** injects onboarding whyChips + live stats ("$312 saved · 23 cravings beaten").
- **Step 3 Break the loop:** 60-sec tap game · Text buddy (pre-filled) · Open coach.
- Exit slider again → `outcome = survived | slipped`; either way, warm copy. `cravingsSurvived` increments with randomized celebration line (variable reward — 12 copy variants, never the same twice in a row).
- Session doc written to `cravings/` (Doc 5 §6): fuels danger-hours + weekly insight.
- If `buddyPingOptIn`: buddy gets push "Alex hit a rough moment — send a 🔥?" (one-tap reaction, no chat required).

---

## 8. NOTIFICATIONS ENGINE (danger hours)

- **Danger hours:** top-2 hour buckets from trailing 14 days (need ≥3 days of data; before that, use onboarding `firstPuffWindow` morning slot). Recompute nightly.
- Push fires 10 min before each danger hour, max 1 per hour block: "Heads up — 10 p.m. is usually your spike. Plan's ready 💪."
- **Caps & quiet:** max 3 pushes/day total; quiet hours default 23:00–08:00 (danger-hour pushes exempt only if the danger hour itself is in that window); all editable in Settings.
- Other types: streak milestone (on unlock), limit-near ("5 puffs left today — you've got this"), unconfirmed-day noon reminder, buddy events, trial-ending (honest, Doc 2), weekly insight ready.
- Permission not granted: features degrade gracefully; re-ask ONLY after first survived craving ("want backup next time?").

---

## 9. COMMUNITY RULES (MVP light feed)

- **Identity:** auto-generated alias (adjective+noun+num, e.g., SteadyFalcon42), editable once; real uid never exposed client-side (Doc 5 rules).
- **Posting:** text ≤ 500 chars, one tag required (🏆 Win · 🆘 SOS · Day 1 · Milestone · Vent), cap 3 posts/day, replies ≤ 300 chars.
- **Feed sort:** reverse-chron; active 🆘 posts pinned to top for 60 min.
- **SOS flow:** posting SOS auto-notifies user's buddy + last 5 people they interacted with; reply composer opens with kindness prompt; after 60 min author gets "23 people had your back."
- **Moderation pipeline:** every post/reply → `moderatePost` Function → Gemini classification (allow / flag / block) against policy: no vape brand praise or sourcing, no minors content, no self-harm encouragement (self-harm *disclosure* → allow + auto-reply with resources), no harassment, no medical claims. Blocked = never visible; flagged = visible + queued for founder review (daily).
- **User tools (App Store mandatory):** report (3 reports auto-hide pending review), block user (mutual invisibility), delete own content.
- **Empty-feed cold start:** seed with the founder's own quit-journey posts; "Day 1" auto-prompt nudges every new user to post once (investment + content flywheel). *(Revised Sep 3 2026 — the "+ beta testers" half of this is descoped with the cohort, `docs/08 §7 #29`. Founder posts are now the only seed, so day-one users land in a thinner feed than this section assumes: `S3-12`.)*

---

## 10. LOCK-SCREEN & HOME WIDGETS ⭐ (MVP)

- **Lock screen (circular):** today count / limit ring. **(rectangular):** count, limit, streak flame.
- **Home (small):** ring + count + flame. **(medium):** + money saved + Panic shortcut.
- **Interactive logging:** iOS 17+ App Intent button logs directly from widget (no app open). iOS 16: tap deep-links to instant-log screen.
- **Data path:** Flutter → `home_widget` → App Group `UserDefaults` (count, limit, streak, money) → WidgetKit timeline refresh on each log + at midnight rollover. Budget: WidgetKit refresh limits respected (batch, don't spam reloadTimelines).
- QA: widget shows correct data after offline logging, timezone change, and day rollover.

---

## 11. EDGE CASES & RULES OF TRUTH

- **Day boundary:** local-midnight per `users.tz`; tz change mid-day → current day keeps original tz, next day uses new (no double/short days).
- **Rapid taps:** UI counts all; writes coalesce; undo removes last logical tap.
- **Plan edits:** editing pace/method regenerates curve from *today* with current actuals as baseline; past days immutable by plan changes; freedomDate recomputed; zero history loss (anti-Puff-Count guarantee).
- **Clock tampering:** server timestamps authoritative for streak grants.
- **Account deletion:** `deleteUserData` wipes tree + community posts anonymize to "[departed quitter]" (thread integrity, privacy honored).
- **Restore/new device:** RevenueCat `restorePurchases` + Firestore = full state return; widget re-syncs on first open.
- **Entitlement flip mid-session:** Riverpod listens to RC customerInfo stream; caps apply within 60s.

---

## 12. ACCEPTANCE CHECKLIST (QA gates per feature)

- [ ] Log 400 puffs/day for 3 days offline → exactly N writes ≤ N/expected batch, zero loss on sync
- [ ] B=200/P=30 curve matches §3.1 table exactly; adaptive rules fire on seeded fixtures (A=0.8, 1.0, 1.2 cases)
- [ ] Streak survives one over-limit day with token; breaks without; Comeback ×2 window verified at 47h59m and expired at 48h01m
- [ ] Panic session end-to-end ≤ 3 taps from lock screen; outcome stored; buddy push delivered
- [ ] Danger-hour push arrives 10 min pre-bucket; never exceeds 3/day cap
- [ ] SOS post pins, notifies, unpins at 60 min; 3 reports auto-hide; blocked user invisible both ways
- [ ] Widget logs while app force-quit (iOS 17 intent) and reflects midnight rollover
- [ ] Plan edit mid-journey: history intact, curve regenerates from today, freedomDate correct
