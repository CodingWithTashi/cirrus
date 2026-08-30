# 📄 DOC 2 — ONBOARDING, PAYWALL & MONETIZATION SPEC
## Project "LastPuff" ✅ (name locked Aug 17, 2026)
**Version:** 1.0 · **Date:** Aug 16, 2026 · **Depends on:** Doc 1 (PRD) · **Feeds:** Doc 3 (Functional), Doc 5 (Tech), Doc 7 (Design)

> **Purpose:** A developer + designer can build the entire first-session experience from this document alone: every screen, every copy line, every animation trigger, every price, every A/B test. This flow is modeled on what converts (Puff Count 20–25% trial starts; QUITTR's "sales-call" quiz; the MWM clone's dopamine loop from the founder's screenshot audit) — **upgraded with honest science and stronger reward mechanics.**

---

## 1. DESIGN PRINCIPLES (non-negotiable)

1. **Every tap gets a reaction.** Instant visual/haptic feedback on every answer — badge, color shift, counter tick, curve morph. No dead screens.
2. **Investment ladder.** Easy identity questions → habit confession → dreams/fears → personalized payoff. Each screen states WHY we ask ("calibrates your plan").
3. **Honest numbers only.** Every statistic on screen traces to §8. No invented percentages (the MWM clone's fake "78% quit" is a lawsuit/review-bomb waiting to happen — their weakness, our credibility).
4. **Shame-free voice.** Never "addict," never guilt. "Heavy dependence" not "heavy addiction." The tone: a friend who quit, not a doctor.
5. **One question per screen.** Progress bar always visible. Back arrow always works. Target: full quiz ≤ 2.5 minutes.
6. **18+ gate enforced** at birth-year screen (App Store + ethics; under-18 → resource referral screen, session ends).

---

## 2. FLOW MAP

```
PHASE A: HOOK          A1 Welcome → A2 Gender → A3 Birth year (age gate) → A4 Quit attempts
PHASE B: HABIT AUDIT   B1 Frequency → B2 Puffs/day (live badge) → B3 Nic strength → B4 Spend (live yearly shock) → B5 First puff of day
PHASE C: DREAM & PLAN  C1 Why quit (multi) → C2 Fears (multi) → C3 Method → C4 Pace (live curve) → C5 Plan-building animation
PHASE D: PAYOFF        D1 Plan reveal → D2 Commitment (hold-to-commit) → D3 Rating ask → D4 Notifications → D5 PAYWALL → D6a Trial start / D6b Free fallback
```
19 screens · ≤2.5 min · progress bar shows Phase A–C as 0→100%.

---

## 3. SCREEN-BY-SCREEN SPEC

### A1 — Welcome / Hook
- **Headline:** "How dependent are you, really?"
- **Sub:** "2-minute check-up. Brutally honest results. A plan built for you."
- Social proof strip (real, updates from backend): "Join 1,240 people who started this week" (hide until true).
- CTA: **Start my check-up** · tiny link: "Restore purchase"
- *Mechanic:* curiosity gap — frame the quiz as a diagnostic, not a signup.

### A2 — Gender
- "Choose your gender" / sub: "Calibrates your plan — nicotine metabolism differs." (True: supported by cessation literature.)
- Options: Male · Female · Other/prefer not to say.

### A3 — Birth year ⚠️ AGE GATE
- "When were you born?" / sub: "Your plan adapts to your age."
- **If age < 18:** route to full-screen "We can't help you here — but this can" → link to free This is Quitting text program (Truth Initiative) → END SESSION. No data stored. (App Store compliance + genuinely right.)

### A4 — Tried quitting before?
- Options: Never · Once · 2–5 times · More than 5.
- **Reaction copy (any answer >Never):** "Good. Most people need multiple attempts before it sticks — each one taught your brain something. This time you'll have backup." *(honest reframe, no fake stat)*

### B1 — How often do you vape?
- DAILY (routine moments) · OFTEN (throughout the day, no pattern) · ALWAYS (constantly, barely any gap) — plain-English descriptions as in clone, kept.

### B2 — Puffs per day 🎰 (signature dopamine screen)
- Numeric input, huge type. **Live badge animates as they type:**
  - 1–50 → 🟢 "Light habit"
  - 51–150 → 🟡 "Moderate dependence"
  - 151–300 → 🟠 "Heavy dependence"
  - 301+ → 🔴 "Severe dependence" (+ soft haptic thud)
- Below badge, live equivalence line: "≈ {n/14} cigarettes worth of puffs" (research heuristic ~14 puffs ≈ 1 cigarette; cite in §8).
- Sub: "Estimate is fine — the plan self-adjusts in your first week."
- *Note:* "Don't know?" link → mini-helper: "1 disposable ≈ X puffs — how many do you finish a week?" → auto-calculates.

### B3 — Nicotine strength
- Picker: 20 mg/2% · 35 mg/3.5% · 50 mg/5% · Not sure (defaults 50 — most disposables).
- Sub: "Most disposables are 5% — that's the strong stuff."
- v1.1 teaser chip: "📷 Scan your vape later — we'll auto-detect."

### B4 — Weekly spend 💸 (shock counter)
- Currency-aware input. As they type, a counter **animates upward** to the yearly figure: "$25/week → **$1,300 a year**" with a one-line kicker rotating by amount: "That's a flight to Tokyo. Every year."
- Data seeds the money-saved engine (Doc 3 §4).

### B5 — First puff of the day 🧪 (the science question)
- "How soon after waking do you reach for it?" — Within 5 min · 5–30 min · 30–60 min · 1 hr+
- *Why:* adapted Fagerström dependence item — the single strongest dependence predictor; also sets morning-notification timing.
- Reaction if ≤30 min: "That's your brain's nicotine clock talking — 76% of young vapers are in the same spot. The plan starts by pushing this later." *(sourced: Truth Initiative)*

### C1 — Why do you want to quit? (multi-select)
- ❤️ Health · 💰 Money · 🔓 Freedom/control · 👶 Family · 🏃 Fitness · ✨ Skin & appearance
- Each tap adds a chip to a visible **"Your Why" card** building at bottom of screen (they watch their reasons stack up — IKEA effect).

### C2 — What worries you most? (multi-select)
- Cravings & withdrawal · Stress · Social pressure · Fear of failing again · Weight gain · Losing "my little breaks"
- Sub: "Your AI coach trains on your specific fears." *(true — these seed the coach's memory, Doc 4)*

### C3 — Method
- 📉 **Taper down** ("reduce daily — gentler on your brain") · 🔥 **Cold turkey** ("full stop on a chosen day — faster, harder")
- Honest guidance line under each; both fully supported.

### C4 — Pace (live curve)
- 14 · 21 · **30 (pre-highlighted: "Most chosen")** · 60 · 90 days.
- **A taper curve on-screen morphs live** as they tap options, showing their start number → 0 with their real dates. Their data, their curve — this is the moment it becomes *theirs*.

### C5 — Plan-building animation (3 seconds, labor illusion)
- Progress ticks: "Analyzing 200 puffs/day…" → "Mapping your 4 trigger fears…" → "Calibrating your 30-day curve…" → "Reserving your coach…"

### D1 — PLAN REVEAL (the payoff)
- Personalized dashboard preview: their curve with milestone dots (Day 3: "worst cravings peak — Panic Button ready" · Day 7: taste/smell returning · Quit Day flagged with 🏆) + money-saved projection at quit day + first health milestones.
- **The honest proof block (replaces clone's fake 78%):**
  > "In a randomized trial of 2,588 young adults, a structured quit program hit **24% abstinence vs 19%** going it alone. Tracking + support + a plan is the difference." *(This is Quitting RCT)*
  > "Self-monitoring alone measurably cuts consumption — awareness is step one." *(behavior-change literature)*
- CTA: "Lock in my plan"

### D2 — Commitment moment 🏆 (upgraded trophy)
- "**Hold to commit**" button — 3-second press with expanding ring + haptic build + confetti burst.
- Stamps: "🏆 Freedom Day: **Sep 15, 2026** · Committed Aug 16, 2026."
- Privacy card beneath (real, engineered claim): "🔒 We never sell your data. No ad trackers in this app. Ever."

### D3 — Rating ask ⭐ (their genius placement, our honest copy)
- Trigger native StoreKit review prompt at THIS peak-motivation moment (before paywall, before anything can annoy).
- Lead-in screen copy: "One quitter's review helps the next one find us. 10 seconds, huge karma." **No fake statistic.**
- Show real beta-tester quotes only, labeled "Beta tester" until we have live reviews. Never stock-photo fake personas (clone's "Sarah, 29" = review-bomb risk).

### D4 — Notification permission
- Pre-permission screen: "Your coach texts you BEFORE your danger hours — not spam, backup." Preview bubble: "Fri 9:54 PM — heads up, Friday nights are your spike. Plan's ready. 💪"
- Then native iOS prompt. If declined → respect it, re-ask contextually after first Panic Button use.

### D5 — PAYWALL (see §4)

### D6a — Trial started → Day-1 guided setup (first log, meet coach, first community peek)
### D6b — Declined → Free fallback (see §5) — NEVER a dead end.

---

## 4. PAYWALL SPEC

**Layout (single screen, scrollable):**
1. Header: "Your plan is ready. Try everything free for 3 days."
2. Feature checklist (✓ AI Coach unlimited · ✓ Panic Button + buddy ping · ✓ Adaptive taper plan · ✓ Craving forecasts · ✓ Full community · ✓ Weekly insight reports)
3. **Plan cards:**
   - **YEARLY — $39.99/yr → "$0.77/week · SAVE 74%" — pre-selected, "BEST VALUE" ribbon**
   - MONTHLY — $7.99/mo
   - WEEKLY — $2.99/wk → "Founding price — locked forever"
4. Trust row: "🔔 We'll remind you before your trial ends" (toggle, ON by default — Blinkist pattern; slashes refunds & 1-stars) · "Cancel anytime in 10 seconds" · 🔒 privacy line.
5. Price-anchor line: "Less than one disposable a week."
6. CTA: **Start my free 3 days** · below: "Continue with Free plan →" (small but real — this is our anti-Puff-Count move).

**Compliance:** full auto-renew disclosure text; restore purchases link; terms/privacy links.

**Decline flow:** tap "Continue with Free" → confirmation of what Free includes (positive framing, no guilt screen) → home. **Win-back:** 24h later, one push + one in-app card: "Founding offer: first month $3.99" (50% off monthly, one-time).

---

## 5. FREE FALLBACK EXPERIENCE (the anti-lockout)

Free forever: puff logging + widget · streaks · money saved · static daily limit · basic health milestones · community read/react · AI coach 5 msgs/day · Panic Button 1/day · 7-day history.
Upgrade prompts: contextual only (hitting a cap), never interstitial spam, max 1/day. Every cap screen shows exactly what Premium adds at that moment.

---

## 6. SUPERWALL A/B ROADMAP (in priority order)

| Test | Variants | Success metric |
|---|---|---|
| 1. Trial length | 3-day vs 7-day | trial→paid × D30 retention |
| 2. Pre-selected plan | Yearly vs Weekly default | blended LTV |
| 3. Weekly price (new users only) | $2.99 vs $3.99 | LTV (grandfather existing) |
| 4. Monthly tier presence | 3 tiers vs weekly+yearly only | blended LTV, cannibalization check |
| 5. Paywall placement | after D2 commit vs after D4 notifications | trial start rate |
| 6. Reveal proof block | RCT stat vs money-saved emphasis | trial start rate |
| Ship rule | ≥1,000 users per arm, one test at a time | — |

---

## 7. FLOW EVENT TRACKING (Mixpanel/Amplitude)

`onboarding_start` · `screen_completed {screen_id, ms}` · `age_gate_blocked` · `puffs_entered {value, badge}` · `spend_entered {weekly, yearly_shown}` · `why_selected {chips}` · `fears_selected {chips}` · `method_chosen` · `pace_chosen` · `plan_revealed` · `commit_held` · `rating_prompt_shown / completed` · `notif_prompt {granted}` · `paywall_viewed {variant}` · `trial_started {tier}` · `free_continued` · `winback_shown / converted` · funnel alert if any screen drop-off >15%.

---

## 8. HONEST-STATS APPENDIX (every on-screen number, sourced)

| On-screen claim | Exact source |
|---|---|
| "24% vs 19% abstinence in a randomized trial of 2,588 young adults" | *This is Quitting* RCT, Truth Initiative / JMIR (intention-to-treat: 24.1% vs 18.6%) |
| "76% of young vapers reach for it within 30 min of waking" | Truth Initiative teen-vaper survey |
| "Failed quit attempts among daily young users rose 28% → 53% (2020–2024)" | JAMA Network Open |
| "Most cravings pass in 15–20 minutes" | Nicotine craving literature (used in Panic Button, Doc 4) |
| "Social accountability raises quit success ~40%" | Peer-support cessation literature |
| "≈14 puffs ≈ 1 cigarette" | Research heuristic; present as "≈", never exact |
| Money figures | User's own input × 52, real arithmetic only |
| "≈{mg} mg of nicotine a day" (B3 fact) | `DependenceEngine.nicotineMg` — the user's own puff count × the absorbed mg/puff for their stated strength (docs/03 §2). Their arithmetic, not a claim. Always shown with "≈" |
| Spend-comparison item prices (B4, D1) | `lib/domain/logic/spend_comparisons.dart` header table — rounded US median bands, one line of provenance per item, reviewed 2026-08-30. **Never rendered**: a price is only ever a divisor, so the screen shows the user's own money and our noun |
| Banned forever | "78% of members quit," "2× faster," "27% more likely" — any uncited number |

**Where each approved row is spent.** A fact may only appear on screen if it is
in this table, and adding one here is part of the same change that renders it.

| Row | Rendered by |
|---|---|
| 24% vs 19% RCT | `obRevealProof` — D1 plan reveal |
| 76% within 30 min | `obFirstPuffScience` — B5, via `StepFact` |
| 28% → 53% failed attempts | `obFactTried` — A4, only when they have tried before |
| Cravings pass in 15–20 min | `obFactWorryCravings` — C2, when they name cravings |
| Peer support ~40% | `obFactWorrySocial` — C2, when they name social pressure |
| ≈14 puffs ≈ 1 cigarette | `obPuffsCigEquiv` — B2 live equivalence |
| Nicotine mg | `obFactStrength` — B3, via `StepFact` |

Steps with no row left to spend say nothing. That is the design, not a gap:
`ObTailoring.fact` is exhaustive over all 19 `ObStep`s, so a new screen forces
a deliberate "there is nothing honest to put here" rather than an invented
statistic.

---

## 9. HANDOFF CHECKLIST
- [ ] Designer: screens A1–D6 in Figma per Doc 7 design system
- [ ] Dev: Superwall config with §4 tiers + §6 test 1 armed
- [ ] Dev: RevenueCat products: `weekly_299`, `monthly_799`, `yearly_3999`
- [ ] Copy review: every stat matches §8
- [ ] Legal: auto-renew disclosures, privacy policy URL live
