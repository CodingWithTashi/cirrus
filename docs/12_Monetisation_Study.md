# 📄 DOC 12 — MONETISATION STUDY
## Project "LastPuff" / store name "Cirrus" — the free/premium split, the gates, and the paywall

**Version:** 1.1 · **Created:** Sep 3, 2026 · **Revised:** Sep 3, 2026 (§5c — the tightening) · **Depends on:** Docs 1–7, `docs/08` (board), `docs/11` (AI flow) · **Status:** LIVE — the study of record for tier decisions.

> **Purpose:** an evidence-first redesign of what is free, what is paid, where the doors sit, and how any of it is measured. Phase 1 is a **verification pass against the code**, because the specs and the shipped build already disagree. Phase 2 is external evidence, every figure carrying a source and a date. Phase 3 is the resolution. The sequenced work lives on `docs/08 §4`.
>
> **When this file and `docs/01 §10` / `docs/02 §4–5` disagree, this file wins** — and `docs/08 §7` carries the register rows.

---

## 0. THE HEADLINE

**Three gates loosen, one door dies, one door is added, and the paywall's visual design is deliberately left alone.**

A tighter wall is not automatically better. The published data says our *structure* — a hard paywall at D5 followed by a real free tier — is already the right one, and that our **instrumentation** and **gate placement** are what is wrong. The single most valuable change on this list is an analytics event, not a wall.

### ⚠️ The finding that outranks the rest

`ENTITLEMENT_MODE=ungated` (`functions/.env.alastpuff`) makes `tierFor()` return `'premium'` for every caller and skip the Firestore read entirely. **Every server-enforced limit is inert in production right now** — every account has an uncapped coach, unlimited panic AI and open community posting. There is no Premium to buy, because there is no Free to leave.

Flipping one config value to `mirror` imposes 5 coach messages/day, 1 panic AI session/day and the posting cap on every account at once. That flip **is** the free/premium split; until it happens, none of the work in this study is reachable by a user.

**Founder correction, Sep 3 2026 — there is no beta cohort.** The earlier version of this section treated the flip as blocked on a founder-grant path, because `docs/06 §3` promised "50 free lifetime spots" to a recruited tester group. **That cohort was never recruited and will not be: Cirrus ships direct to production.** Nobody holds a promise the flip would break, so the grant path is descoped (`S1-12`) and the flip is gated only on the four remaining preconditions in §4.4 — all of which are about not wrongly refusing a *paying* customer.

---

## 1. FOUNDER DECISIONS — Sep 3, 2026

| Decision | Call |
|---|---|
| **Community posting** | **1 free post/day, any tag.** Premium keeps 3/day. SOS is refused for no tier — implemented with its **own** allowance rather than none at all (see §5b): a live SOS pins to the feed for an hour, so "uncapped" is a pinning megaphone. |
| **Free Stats history** | **30 days**, up from 7. Month pill and forecast heatmap stay Premium. |
| **The `panic` door** | **Deleted.** A spent panic quota falls through to the coach on the remaining free messages, then to the SOS composer. Never the paywall. |
| **Launch paywall** | **Milestone plan days {3, 7, 14, 30} only** — four showings ever, with a lifetime cap and a dismissal event. |

Net: the door count stays at eleven (one deleted, one added), three gates loosen, and the D5 hard paywall — the structure the evidence actually supports — is untouched.

---

## 2. PHASE 1 — WHAT ACTUALLY SHIPPED (the audit, before the change)

Verified against the working tree on Sep 3, 2026, **before any of §4 was implemented**. Every row carries a path.

> Read this section as the "before" picture — it is the evidence §4's decisions were made from, and it is deliberately not updated as the code moves. **§5b records what actually changed**, and the line numbers below drift with the first edit. Where the two disagree, §5b is the current state.

### 2.1 The eleven tagged doors

The code agrees with itself: `lib/core/widgets/lp_premium_gate.dart:83` says *"all eleven of them"*.

**Four `LpPremiumGate` gates:**

| # | file:line | `source` | What sits behind it |
|---|---|---|---|
| 1 | `lib/features/health/health_screen.dart:105` | `health` | Timeline nodes past `freeNodes`, `lockAlignment: topCenter` |
| 2 | `lib/features/insight/insight_screen.dart:127` | `insight` | The weekly-report pager, or the pending card |
| 3 | `lib/features/plan/plan_screen.dart:125` | `plan` | **Nothing** — `child` is null, so the lock card renders alone (the server computes no advice for a free account, and there is no mock-up to blur) |
| 4 | `lib/features/stats/stats_screen.dart:364` | `forecast` | The trigger-hours forecast heatmap |

**Seven direct `Routes.paywallFrom(...)` doors:**

| # | file:line | `source` | Trigger |
|---|---|---|---|
| 5 | `lib/features/auth/splash_screen.dart:73` | `launch` | The once-a-day launch paywall (`LaunchPaywallPolicy`) |
| 6 | `lib/features/coach/coach_screen.dart:315` | `coach_cap` | CTA under the `capReached` bubble |
| 7 | `lib/features/community/community_screens.dart:681` | `compose` | Composer, non-SOS tagged post |
| 8 | `lib/features/onboarding/steps/payoff_steps.dart:651,661` | `onboarding` | D5 (two call sites, one door) |
| 9 | `lib/features/panic/panic_screens.dart:698` | `panic` | The AI option **during a craving**, when `aiAvailable == false` |
| 10 | `lib/features/settings/settings_screens.dart:142` | `settings` | Subscription row while the entitlement is not active |
| 11 | `lib/features/stats/stats_screen.dart:93` | `history` | Month pill tapped while free |

### 2.2 …and a twelfth, untagged one

`Routes.paywall` — **bare, no `?source=`** — is in `PushService`'s `_allowedRoutes` (`lib/app/last_puff_app.dart:243`), so a push notification can land someone on the paywall. The route builder defaults `source` to `'direct'` (`app_router.dart:191`, `paywall_screens.dart:41`), so a push-driven paywall view is **indistinguishable from the debug frame map's**. `lp_events.dart:70` already documents a `push` source that nothing in the app passes.

### 2.3 The shipped matrix, and where each limit is enforced

| Capability | Free | Premium | Enforced |
|---|---|---|---|
| Coach messages | **5/day** | **100/day** | **Server** — `aiCoachChat` → `claimCoachMessage` (transactional). `FREE_DAILY_COACH_MESSAGES=5`, `PREMIUM_DAILY_COACH_MESSAGES=100` in `.env.alastpuff`. The client's `CoachStore.freeDailyCap = 5` is a first guess only, overwritten by the server's `messagesLeft` |
| Panic breathing, timer, arcade | unlimited | unlimited | **never gated** — `usage.ts`: *"We do not paywall someone mid-crisis"* |
| Panic AI option | **1 session/day** | unlimited | **Server** — `panicSession.ts:75`; `FREE_DAILY_PANIC_SESSIONS = 1` is a hardcoded const, **not** a tunable param |
| Stats history | trailing **7 days** (`historyFloor = dayStart(now) − 6`) | full journey | **Client only** — `stats_screen.dart:64–74` |
| Stats Month pill | opens the paywall | allowed | **Client only** — `stats_screen.dart:46, 93` |
| Forecast heatmap | gated | shown | **Client only** |
| Health timeline | `math.max(7, hereIndex + 1)` nodes | all | **Client only** — and it **never locks a node already reached** |
| Adaptive taper | none | nightly | **Server** — `taperRecalc.ts:90` |
| Weekly insight | none | generated | **Server** — `weeklyInsight.ts:67` (via `tierOf` on the doc already in hand) |
| Community read + react | yes | yes | rules; no tier |
| Community **reply** | yes | yes | **not gated at all** — `createReply.ts` contains no `tierFor` call |
| Community **post** | SOS only | any tag | **Server** `createPost.ts:68` (`permission-denied`) + client mirror at `community_screens.dart:505` |
| Daily post cap | 3/day | 3/day | **Server** `claimDailyPost`; `DAILY_POST_CAP = 3` — identical for both tiers |
| Home coach nudge | hidden entirely | shown | **Client only** — `home_screen.dart:526` |
| Logging, streaks, money, reminders, repair tokens, report/block | free | free | not gated |

### 2.4 Three corrections to the spec

1. **Replying is free while posting is paid.** `createReply.ts` has no tier check. Nothing documents that asymmetry, and it is the strongest argument for §3's posting change: a free user can already write unlimited paragraphs under someone else's post but cannot start a thread.
2. **The health gate never locks a node the user has reached.** `freeNodes = math.max(7, hereIndex + 1)` means the gate only ever hides the *future*. That is better than `docs/01 §10`'s "basic milestones" and should not be regressed.
3. **The composer has no untagged-post hole.** `premiumBlocked` gates on `_tag != null && _tag != PostTag.sos`, and `canPost` independently requires a tag (`community_screens.dart:516`) — so client and server agree exactly on every postable case.

### 2.5 What a client could grant itself

Five limits are client-only: history window, Month pill, forecast, health nodes 8+, Home nudge.

All five are **presentation over data already legitimately in the user's own `journeys/{uid}` document**, and all five cost the server nothing. The limits that carry real marginal cost — model tokens, taper compute, insight compute, posting and its moderation — are already server-side. Moving the five would cost a read per render and buy nothing.

**`firestore.rules` contains no tier logic whatsoever** (grep-verified; the only tier-shaped text is the ownership rationale at lines 9 and 13–14). The rules layer never enforces entitlement, by design — the callables do.

### 2.6 What the funnel can measure

**Working today:** `gate_shown{source}` → `gate_tapped{source}` → `paywall_viewed{variant, source}` → `trial_started{tier}` → `purchase_completed{plan,trial}` / `purchase_cancelled{plan}` / `purchase_failed{code}` / `restore_completed{found}` / `entitlement_changed{tier}`; plus `free_continued` and `winback_shown` / `winback_converted` (the win-back card is built but `BillingCatalog.foundingOfferEnabled = false`).

**Seven blind spots, in order of cost:**

| # | Blind spot | Consequence |
|---|---|---|
| 1 | **Every server wall is silent.** The coach `capReached` template, `createPost`'s `permission-denied` and `resource-exhausted`, and `panicSession`'s `aiAvailable: false` fire no analytics | "Hit a wall" and "saw a gate" are different events and only the second exists. The three highest-intent moments in the product are invisible |
| 2 | **`variant` is the constant `'d5_default'`** (`paywall_screens.dart:66`) | `docs/02 §6`'s entire A/B roadmap is unreadable as instrumented |
| 3 | **No `paywall_dismissed`** — `purchase_cancelled` only fires if the store sheet opened | Abandoning the paywall itself is invisible |
| 4 | **No `plan_selected`** | Which card people consider versus buy is unknown |
| 5 | **No plan-day dimension** on `gate_shown` / `paywall_viewed` | A day-3 gate and a day-40 gate are the same row |
| 6 | **`docs/02 §5`'s "max 1 prompt/day" is unenforced and unmeasurable.** Only `launch` is throttled (`launchPaywallShownDay`) | Nothing counts how many doors a free user met in one session |
| 7 | Analytics is `kReleaseMode`-only | None of this is observable from a dev device without `--dart-define=LP_ANALYTICS=on` |

**The caveat we keep, verbatim from the code** (`lp_premium_gate.dart:80–84`): `gate_shown` counts *"this gate built"*, **not** *"this gate entered the viewport"*. Three of the four gates sit in scrolling columns, so their denominators are inflated by an unknown amount. **Compare a door to itself over time; never compare the `gate_tapped/gate_shown` *level* across doors of different placement.** True visibility would need a detector on each gate — not worth it before launch.

Everything above is first-party. There is no advertising ID (`B19`) and no MMP, and nothing in the measurement plan needs one.

---

## 3. PHASE 2 — EVIDENCE

Every figure carries a source and a date. Anything unsourced is marked a judgement call. The **no-invented-numbers** rule applies to analysis exactly as it applies to the app.

### 3.1 Hard vs soft paywall — both published numbers are true

| Source | Denominator | Finding |
|---|---|---|
| **RevenueCat, State of Subscription Apps 2026** (pub. Mar 19 2026; 115,000+ apps, $16B revenue, 1B+ transactions) | **every download** | Hard paywall **10.7%** vs freemium **2.1%** (~5×). Hard-paywall floor 4.2%; top decile 38.7%. Revenue per install at D60 **$3.09 vs $0.38** (8×). 12-month retention **27% vs 28%** — *"statistically negligible"* |
| **Adapty, 2026 paywall report** (pub. Mar 13 2026) and **H&F benchmarks** (pub. Mar 27 2026; 16,000+ apps, $3B) | **paywall views** | Hard paywalls produce **21% higher 1-year LTV** (median $41.9 vs $20.0), while soft paywalls **convert ~50% better per paywall view** (4.85% vs 3.34% in secondary reporting of the same dataset) |

**The resolution:** same reality, two denominators. Per *download* hard wins, because it filters tyre-kickers at install. Per *paywall view* soft wins. Hard wins on LTV per install; soft wins on subscriber count.

**Cirrus is not choosing between them.** It already runs hard-at-D5 plus a real free tier after decline, which is exactly the `docs/01 §10` hybrid and the only structure the anti-lockout constraint permits. **The evidence does not say move the D5 wall.**

### 3.2 Trial length — 7 days is right

- Trial→paid by length (RevenueCat 2026): **≤4 days 25.5%** · **5–9 days 37.4%** · **17–32 days 42.5%**. Longer trials convert ~70% better.
- Health & Fitness has already converged: **54% of the category runs 5–9 days**. Category trial→paid **37.7%** (RevenueCat) / **42.2%** (Adapty).
- **55.4% of 3-day trial cancellations happen on Day 0**; 84% by Day 1 (RevenueCat 2026). A 3-day trial is decided before the product has done anything.
- Adapty: weekly-plan LTV **$7.40 without a trial vs $54.50 with a 3-day trial** — the trial itself is the lever; lengthening it is the cheap follow-on.

### 3.3 Where the money actually is

- **A/B win rates** — share of tests that lifted LTV (Adapty 2026): localisation **62.3%** · trial structure **59.6%** · plan duration **58.7%** · number of plans **57.1%** · price **45.5%** · **visual/copy only 34.6%**. → *Redesigning how the paywall looks is the worst-value work available.*
- **Placement** (Adapty 2026): onboarding paywall **with a trial** converts **1.35%**, the best of any placement. In-app with trial 0.89%; onboarding without trial 0.82%; in-app without trial **0.76%**. → *D5 is the best slot we have; `launch` sits in the worst band.*
- **Annual is the H&F engine:** 61% of category revenue, up from 51% in 2023 (Adapty). Day-380 retention: annual **19.9%** · monthly **14.2%** · weekly **5.5%**. High-priced annual plans return **$70 install LTV vs $17** for low-priced ones — a **4.1× spread**.
- **H&F is the best category to be in:** the highest install LTV of any App Store category ($1.21 global median; D14 RPI **$0.48**, ~6× Gaming's $0.08). North America D35 download→paid **2.8%**, D30 download→trial **7.1%** (top quartile >15%).
- **Android's biggest leak is involuntary:** **31% of all Play cancellations are billing failures** (up from 28.2% in 2025) against 14% on the App Store. RevenueCat names dunning + grace periods the highest-ROI Android action, recovering **15–20% of lost revenue with no new users.** Cirrus is Android-first.
- **Lifetime is not a business:** lifetime/other is **<5% of revenue in every region** (RevenueCat 2026), though 35% of apps now mix consumables or lifetime alongside subscriptions.

### 3.4 What gates well in behaviour-change apps

- **JMIR scoping review**, *When and Why Adults Abandon Lifestyle Behavior and Mental Health Mobile Apps* (PMC11694054): a median **70% discontinue within the first 100 days**, sharpest right after acquisition; 22 reasons across 6 categories, of which *"time and financial costs"* is **one category among six** — technical and functional issues, poor UX and content gaps sit alongside it. **Cost is a contributor, not the dominant driver.**
- **JMIR**, *Smartphone Apps for Vaping Cessation: Quality Assessment and Content Analysis* (PMC9002586): *"Some apps included valuable features such as a designated quit plan page that were available only with paid subscriptions ranging from US $5.99 to US $27.99."*

> ⚠️ **Caveat — read before quoting either.** PMC blocks automated fetch, so both figures come from search-surfaced summaries rather than the full text. **Verify against the PDFs before either number appears anywhere user-facing.** Treat as directional evidence only.

### 3.5 Competitor teardown — paywall and gating

Prices as observed Sep 3, 2026.

| App | Price | Trial | Free | Paid | What it teaches |
|---|---|---|---|---|---|
| **Puff Count** (Rodger Studio, iOS only) | $4.99/wk · $9.99/mo; IAP list spans **$3.99–$89.99/yr**. **4.3★, ~2,600 ratings** | 3 days | "core tracking" | *"Some features within the app require an additional subscription"* | Reviewers report a paywall immediately after setup and being unable to continue once the trial ends; the dominant theme is that a quit-vaping app **costs more than the habit**. **But the rating holds at 4.3** — the lockout is a *churn and sentiment* problem, not a rating collapse. It validates the anti-lockout position **and** proves a hard wall is commercially survivable |
| **Kwit** | $6.49/wk · $20.99/mo · $48.99/3mo · $84.99/6mo · $127.99/yr · **$169.99 lifetime** | — | "as complete as possible", ad-free | premium features | The only lifetime tier in the set, priced as a deterrent. **Six durations** is far past the 2–4 the plan-count evidence favours |
| **Smoke Free** (David Crane; prescribed on the German health system) | Pro $6.99–$29.99, up to $209.99 | — | daily Missions **+ an AI quit coach, free** | more craving help, expert-advised plan, 24/7 advisors | **The competitive correction that matters: a free AI coach is now table stakes.** Its free tier is more generous than ours on the exact axis we call the differentiator |
| **nicoff** | weekly or yearly | 3 days, all Pro | trial only | everything | Direct hard-paywall competitor on a 3-day trial |
| **Quash** (PHE Canada, nonprofit) | **free** | — | everything | — | Free, and targets ages 14–30 — our demographic. Anything we charge for that Quash gives away is a review-comparison risk |
| **Escape the Vape** | **free**, iOS + Android | — | tracking, savings, cravings, **community** | — | A free community on both stores. **Our community-posting gate is the one most directly undercut** |
| **I Am Sober** | ~$9.99/mo or **$39.99/yr** (list $119.88) | **7 days** | counter + daily pledge | extended stats, **longer history**, community, partner features | The nearest neighbour: same trial length, same annual price, and it gates history and community exactly as we do |

### 3.6 Policy — no store rule blocks any gate we have

- **Apple 3.1.2(a):** *"you must provide ongoing value to the customer, and the subscription period must last at least seven days"*; subscriptions *"should allow a user to get what they've paid for without performing additional tasks"*; and apps that *"trick users into purchasing a subscription under false pretenses or engage in bait-and-switch"* are removed.
- **Apple 1.4.1:** medical-adjacent apps are reviewed with greater scrutiny and must remind users to check with a doctor. **1.4.3:** apps that *encourage* consumption of tobacco or vape products are banned — cessation is the opposite, but the age gate and the disclaimer stay load-bearing.
- **Apple 5.1.3:** health and fitness data may not be used for advertising or use-based data mining. Already satisfied — no ad SDKs, and `AD_ID` removed (`B19`).
- **Ratings:** *"Apps must not force users to rate the app, review the app, download other apps, or other similar actions in order to access functionality, content, or use of the app."* The **text** is confirmed; the section number has moved between revisions, so **cite the language, not "1.1.7"**.
- **Google Play, Health Content and Services:** the Health apps declaration form is mandatory; a non-medical-device health app must carry *"not a medical device and does not diagnose, treat, cure, or prevent any medical condition"* and must remind users to consult a healthcare professional. **No language restricts charging for health features.**

> **The one live policy exposure is `B21`, and it is a monetisation issue, not an ASO one.** The published Play description advertises a home-screen widget twice — once inside *"FREE FOREVER: Puff counter, widget, streaks…"*. There is no widget (`B14`). Advertising a non-existent feature **inside the free-tier promise** is the bait-and-switch clause above.

---

## 4. PHASE 3 — THE RESOLUTION

### 4.1 Revised free/premium matrix — changes only

| Line | Today | Decided | Rationale | Expected effect |
|---|---|---|---|---|
| **Community posting** | SOS only; 3/day cap for Premium | **1 post/day any tag free; SOS always free and uncapped; 3/day Premium** | Posting is the stated moat, and a moat you cannot enter is a read-only forum. Free users' posts **are** what Premium users pay for, so gating supply starves demand. Replying is already free, making the asymmetry arbitrary. Two free competitors (Escape the Vape, Quash) give community away | Trial-start ↓ slightly at `compose`; **retention ↑** — lever #1 in `docs/08 §2` |
| **Stats history** | trailing 7 days | **trailing 30 days** | The taper program is 30 days (`P=30`). A 7-day window cannot show a taper working, so free users cannot see their own plan's arc — and the data is already in their own document | Trial-start ~flat; **D7/D30 ↑**; removes the worst honesty optic |
| **Stats Month pill + forecast** | Premium | **unchanged** | Different *views*, not a data window. Keeps the `history` door with a better story: *"you have the month; Premium has the whole quit"* | — |
| **Panic AI option** | 1/day, then **paywall** | **1 panic-recorded session/day, then fall through to the coach on the remaining free allowance; when that is spent too, offer SOS — never the paywall** | Selling mid-craving is the worst moment for both parties: the least considered purchase and the likeliest one-star naming the exact thing we position against. Breathing, games, timer and SOS already never block; this closes the last gap | Trial-start ↓ at `panic` (small); **review risk ↓ materially** |
| **Health timeline** | `max(7, hereIndex+1)` nodes | **unchanged**, copy fixed | Already never locks a node reached — better than spec. But `premiumPitchHealth` ("from two weeks to a year") under-describes what a day-3 user already has | — |
| **Coach cap** | 5 free / 100 Premium | **unchanged** | `docs/04 §7`, and the `<$0.25` blended AI-cost guardrail depends on it. Smoke Free's free coach is real pressure — but **5/day *is* a free coach** | — |
| **Home coach nudge** | hidden entirely for free | **compact gate, `source: 'nudge'`** | The best contextual moment in the app — we know their danger hour **from their own logs** — and we currently render nothing at all. Name the honest weekday and hour; blur only the advice | **Trial-start ↑** — a new door where none existed |
| Logging, streaks, money, arcade, reminders, replies, report/block | free | **unchanged** | The free tier is real and forever | — |

### 4.2 Gate-by-gate — placement and copy

| Door | Verdict |
|---|---|
| `onboarding` (D5) | **Keep exactly as is.** The best-converting placement in the evidence (1.35% with a trial). Do not move it |
| `coach_cap` | **Keep — the strongest door in the app.** Someone who has spent five messages has proven intent. Add the count to the copy ("that's your five for today"): the only door where the value already delivered is provable from the user's own history |
| `insight` | Keep. The honest tease — headline visible, body blurred — already matches `docs/04 §5` |
| `health` | Keep; fix the pitch copy in 5 locales |
| `forecast` | Keep |
| `history` | Keep, restated for a 30-day free window |
| `plan` | Keep. Lowest-priority improvement: it converts best right after a slip and carries no slip context today |
| `settings` | Keep. Not a prompt — the user went looking |
| `compose` | **Reframe** from "posting is Premium" to a remaining-post count |
| `nudge` | **Missing — add** |
| `panic` | **Delete.** The only door removed outright |
| `launch` | **Keep, but discipline it.** It is the one door `docs/02 §5` forbids in its own words (*"never interstitial spam"*), it sits in the worst-converting placement band (0.76–0.89%), and once-a-day forever is a slow-burn one-star generator. Restrict to plan days **{3, 7, 14, 30}** — four showings ever — and instrument dismissal so it is judged rather than assumed |
| push → paywall (untagged) | **Tag it `push`** (`lp_events.dart:70` already expects it) or remove `Routes.paywall` from `_allowedRoutes`. Untagged, it pollutes `direct` with the debug frame map |

### 4.3 Trial length and the price ladder

- **Keep the 7-day trial.** 5–9-day trials convert **37.4%** against **25.5%** at ≤4 days; H&F is 54% on 5–9 days; I Am Sober — same annual price — uses 7.
- **Keep all three prices at launch.** They are locked, created in Play, and changing store products six weeks out is risk with no data behind it.
- **Keep yearly pre-selected.** Plan duration wins 58.7% of A/B tests, and annual holds 61% of H&F revenue at 19.9% Day-380 retention against weekly's 5.5%.
- **Reorder the S11 ladder tests: annual price before weekly price.** `docs/08 §2` lever 2 targets $3.99/wk. But **$39.99/yr sits squarely in Adapty's low-priced annual band** ($17 install LTV vs $70 for high-priced — a 4.1× spread), and weekly is the **worst-retaining plan we sell**. Test **$59.99/yr for new users, grandfathering existing subscribers**, before touching weekly.
- **No lifetime tier.** <5% of revenue in every region, and it converts the recurring revenue the $44K target is made of into one-time cash. Kwit's $169.99 is priced as a deterrent, not a product.
- **No in-app-only tier.** It splits the entitlement into two states the mirror must track and doubles the enforcement surface, with no evidence that a partial tier converts better. **The free tier already *is* the in-app-only tier.**

### 4.4 Server versus client enforcement

**Stays client-side, deliberately:** history window, Month pill, forecast heatmap, health nodes, Home nudge. All are presentation over the user's own document; server enforcement would cost a read per render and buy nothing, because the data is legitimately on the device already.

**Stays or becomes server-side:** coach cap, panic-AI count, posting cap, taper recalc, weekly insight — everything carrying real marginal cost.

**Four things that must be true before `ENTITLEMENT_MODE=mirror`** (revised Sep 3 2026):

Every one of them is about the same failure: **the flip must never refuse a customer who has paid.** The reverse failure — a free account keeping something it should have lost — costs nothing but a day's margin and self-corrects on the next call.

1. **`S1-11` passes** — a real sandbox purchase flips `users/{uid}.entitlement`. If the mirror is wrong, `mirror` mode makes paying users free. The Test Store proved the path end to end on Sep 2 (`docs/10 §14`); Play and App Store sandbox are what remain.
2. **Purchase→mirror latency is handled.** A purchase makes the client premium instantly (`EntitlementStore`) while `users/{uid}` lags a webhook round-trip, so a freshly-paying user can be refused by `createPost` or metered by `aiCoachChat`. **This is a real, reachable bug the moment `mirror` lands** — and the one precondition that is pure code, owing nothing to a store dashboard.
3. **Grace periods and dunning are on and verified** against a forced Play billing failure. 31% of Play cancellations are involuntary; `tierOf()` fails closed on `expiresAt`, and the mirror's "later of `expires_at` and `ends_at`" rule is what covers grace — **prove it before trusting it.**
4. **A refusal event exists on every server wall**, or the flip is unobservable. ✅ **Satisfied Sep 3** by `S5-16` — `limit_reached{capability, tier, used, limit}` fires on every wall, client and server.

> **Descoped Sep 3 2026 — the founder-grant path (`S1-12`).** It existed only to protect the "50 free lifetime spots" of `docs/06 §3`. **There is no beta cohort — Cirrus ships direct to production**, so there is no promise to keep and nothing the flip revokes. If a comp is ever needed (press, a refund, a support case), the mechanism is a server-written `entitlement` with a far-future `expiresAt` and `source: 'founder_grant'` that `snapshotOf` leaves alone — build it then, for a real case, not speculatively.

### 4.5 Measurement plan

| Question | Answered by | Status |
|---|---|---|
| Which door earns trial starts? | `gate_shown` → `gate_tapped` → `paywall_viewed` → `trial_started`, per `source` | ✅ works |
| Which door is seen and ignored? | `gate_tapped ÷ gate_shown` per source | ✅ works, with the built-vs-seen caveat |
| Which wall do people actually hit? | `limit_reached{capability, tier, used, limit}` | ✅ shipped — from the coach cap, `createPost`'s refusal and cap, and `panicSession aiAvailable:false` |
| Does paywall layout matter? | `paywall_viewed{variant}` | ✅ shipped — it varies now: `d5_default` (live store prices), `d5_fallback` (typed fallbacks under the "prices unavailable" caption) and `d5_loading` (closed before the store ever answered). A spike in the third is a slow store, which is a conversion problem with a completely different fix |
| Paywall abandoned, or the store sheet? | `paywall_dismissed{source, plan}` | ✅ shipped — and deliberately NOT suppressed by opening the sheet: `purchase_cancelled` then `paywall_dismissed` is what separates "tried and thought better of it" from "never engaged" |
| Which plan is considered vs bought? | `plan_selected{period, source}` | ✅ shipped |
| Is `launch` a nag? | `paywall_dismissed{source:'launch'}` + `settings.launchPaywallShownCount` | ✅ shipped |
| Does a day-3 gate differ from a day-40 one? | `plan_day` on `gate_shown` and `paywall_viewed` | ✅ shipped |

**Per-door ratios to watch:** `gate_tapped/gate_shown` (copy quality) · `trial_started/paywall_viewed` (door intent quality) · `purchase_completed/trial_started` (sheet friction) · `limit_reached → gate_tapped` within 24h (wall→door coupling).

**And the caveat, once more, because it changes how the dashboard is read:** `gate_shown` counts *built*, not *seen*. Compare a door to itself over time; never rank doors of different placement by the level of that ratio.

---

## 5. THE THREE HIGHEST-VALUE CHANGES, AND THE ONE NOT TO MAKE

Ranked by expected conversion per hour of work.

| Rank | Change | Est. | Why it wins |
|---|---|---|---|
| **1** | **`limit_reached` event** (`S5-16`) | ~2h | The only change that makes the **server** walls visible, and those are the three highest-intent moments in the product. Every other item on this list is a guess until it exists; with it, `S7`'s funnel work has a target |
| **2** | **The `nudge` door** (`S5-17`) | ~3h | Adds a door where there is currently **nothing** — free users with a real danger window see no card and no lock — at the app's best contextual moment, on its most-visited screen |
| **3** | **Free posting, 1/day** (`S5-15`) | ~6h | The only change here that plausibly moves **retention** rather than conversion, and churn 30%→20% is lever #1 in `docs/08 §2` (it cuts required downloads by roughly a third). It also defuses the one gate two free competitors directly undercut |

### ⛔ The one not to make: `S6-3` as written — the 7-vs-3 trial A/B

RevenueCat 2026 puts trial→paid at **25.5% for ≤4-day trials against 37.4% for 5–9 days**, and Health & Fitness has already converged on 5–9 days (54% of the category). Running the test means deliberately serving **≥1,000 people — `docs/02 §6`'s own ship rule — the arm the population data says is ~12 points worse**, to learn something 115,000 apps have already answered.

Spend that A/B budget where the win rates are: **plan duration (58.7%) and annual price (45.5%)**, starting with $59.99/yr for new users. See §4.3.

---

## 5b. WHAT SHIPPED — Sep 3, 2026

All eight client steps landed the same day the study was written. Gates: `flutter analyze` clean · `flutter test` **943** · `npm run verify` **205** · `npm run test:integration` **265** · `npm run test:rules` **47** · **on-device 47/47 on a Pixel 8** (Android 17, `LP_BACKEND=fake`) — the whole existing `integration_test` directory plus a new `i_monetisation_test.dart`, run again against the final code.

The new on-device suite is the regression net for the four surfaces this sprint moved: the `nudge` door opens *and closes back onto Home*, Stats states its 30-day window and Month opens the `history` door, a free account posts once and meets the door on the second, an SOS stays open with the ordinary allowance spent, and the panic flow never reaches a paywall. Those need a device because the gates live in a keep-alive `StatefulShellRoute`, the paywall is a pushed route whose `dispose` now emits an event, and the panic flow animates forever — three things that have each already broken a green widget test in this repo.

| Step | Landed | Notes beyond the plan |
|---|---|---|
| `S5-16` | ✅ | `limit_reached{capability, tier, used, limit}` + `LpLimit`. **Found and fixed two live bugs on the way:** `coachCapReached` hardcoded "5", so a Premium user who spent **100** messages was told "that's my 5 free messages" *and* offered no upsell (the CTA is free-only) — it interpolates the server's own limit now and has a separate, non-selling premium variant; and the fake coach answered a cap with the generic reply card, whose `limit` is the day's **puff** allowance, so the bubble quoted the taper curve at someone out of messages |
| `S5-17` | ✅ | The `nudge` door. The pitch sells the **forecast**, never the reminder — `ReminderPlanner` has no tier check, so danger-hour nudges are already free and promising them would be selling the reader something they have |
| `S5-15` | ✅ | Free 1 post/day, Premium 3, **SOS on its own counter** (`users/{uid}.sosUsage`). Deviation from the plan, deliberately: "uncapped SOS" would have been an unbounded pinning megaphone, since a live SOS pins to the top of the feed for an hour. `DAILY_SOS_POSTS=5` is generous enough that no real crisis meets it. Also fixed `freePlanFeat4`, which advertised "1 Panic Button session a day" — the panic **button** has never been limited, only its AI layer, and in a cessation app that could stop somebody reopening the one screen built for a crisis |
| `S5-14` | ✅ | Free history 7 → 30 days; `premiumFreeHistoryNote` interpolates the constant instead of hardcoding "7" |
| `S5-13` | ✅ | The `panic` door is gone. **Plus the loophole it would otherwise have opened:** routing to the coach instead only moves the mid-craving purchase decision one screen along, so the coach's cap CTA is suppressed for anyone who arrived from a craving. The words still explain; the button waits. Held as a **timestamp with a 20-minute window**, not a flag — the coach tab is keep-alive, so switching to it from the bottom bar pushes no route, `didUpdateWidget` never fires, and a flag would have hidden the strongest door in the app for the rest of the session. It expires on the app's own model of a craving (docs/03 §7: most pass in 15–20 minutes) |
| `S5-18` | ✅ | `plan_selected`, `paywall_dismissed`, `plan_day` on `gate_shown`/`paywall_viewed`, and a `variant` that finally varies — `d5_default`, `d5_fallback` (typed prices under the "prices unavailable" caption, a materially different offer) and `d5_loading` (closed before the store ever answered, which would otherwise have been a **lost** view understating every door's denominator). `taggedPushRoute` closes the twelfth, untagged door |
| `S5-19` | ✅ | Launch paywall restricted to plan days {3, 7, 14, 30} with a lifetime cap of 4, persisted through `SettingsPersistence` |
| `S5-20` | ✅ (app half) | `premiumPitchHealth` now names the first node **actually** locked for this reader. The original claim in §4.1 was too strong: "from two weeks to a year" is correct under two weeks and only drifts for someone further along, who already sees more nodes free. **The Play listing half (`B21`) is founder-side and still open.** |

**One safety fix that was not in the plan and matters more than most of it.** Making the post allowances deploy-time params exposed the trap CLAUDE.md documents: a param resolves to **0** when nothing supplies a value, and an allowance of 0 is not a small allowance — it is a total outage wearing the costume of a policy. A coach limit of 0 answers every user `capReached` before the model is called; a post limit of 0 refuses every post in the app. `allowance()` in `functions/src/config.ts` now refuses to believe a non-positive value and falls back to `ALLOWANCE_DEFAULTS`, and **the coach params go through it too** — that path was live and unguarded. `functions/test/allowance.test.ts` pins it.

**A self-review pass over the diff found four more, all in the new code and all fixed** (Sep 3 2026):

- **A lost `paywall_viewed`.** The send is deferred a frame so `build` stays side-effect free, but the "already reported" flag was set *synchronously* — so a pop inside that frame left the view scheduled, unsent, and skipped by the dispose fallback too. Now a `_pendingVariant` / `_viewSent` pair, with an idempotent `_sendView()` both paths call.
- **`ref` in `dispose()`** — the gotcha this repo already has scars from. The dispose fallback called a helper that read `quitStoreProvider`; it would have thrown on any paywall closed before the store answered, and no test covered that path. `planDay` is captured in `initState` now, next to the sink.
- **A mislabelled coach wall.** `CoachReply.isFreeTier` is null when the backend did not say, and `isFreeTier == false` read that as *free* — filing a subscriber who had just spent a hundred messages under the free tier's wall. It falls back to the client's own tier instead.
- **A mutating read in the fake.** `_myPostsToday` counted through `_sessionOrGuest()`, which binds a guest session as a side effect (`??=`). Counting now goes through a read-only `_readerId`.

Two structural changes came out of the same pass: `claimDailyPost`'s bucket is **required** (a default would let a future caller quietly spend the wrong allowance), and every allowance is read through `readAllowance.*`, which binds each param to its own default so a call site cannot pair one allowance's param with another's fallback. `SettingsPersistence`'s round-trip test now asserts the full field list of `SettingsState`, so B8's "saved on write, forgotten on read" hole cannot reopen.

**Client/server parity** is `LpAllowances` (`lib/domain/logic/allowances.dart`) ↔ `ALLOWANCE_DEFAULTS`, with the same literals asserted on both sides (`test/domain/allowances_test.dart`, `functions/test/allowance.test.ts`). The client copy is a hint for what to render before the wire speaks; the server's answer always wins.

---

## 5c. THE TIGHTENING — Sep 3, 2026 (evening)

**§4.1 and §5b describe the morning. This describes the same day's evening, and where the two
disagree, this section wins.**

The founder ran the build on a device after §5b landed and reported four things, of which
three were the same finding: *"I feel like we are very generous with users. Everyone will
just stick with free only."* That is a judgement about the whole tier, not about any one gate,
and it is the founder's to make — so three decisions taken that morning were **reversed the
same day**, knowingly and with their original arguments on the record.

### What reversed, and what was traded away

| Line | Morning (§4.1) | Evening | What the reversal costs |
|---|---|---|---|
| **Free Stats history** | 30 days (`S5-14`) | **7 days** | The morning's argument was real and is not refuted: the taper program runs 30 days (`P=30`), so a 7-day window cannot show a taper working, on data already in the user's own document. It is traded deliberately — **Stats is where the product's central question gets answered, and a free tier that answers it in full has nothing left to sell.** The Month pill and the forecast heatmap stay Premium alongside it |
| **SOS posts** | 5/day, own counter (`S5-15`) | **3/day, plus one live SOS at a time** | Little. Five was chosen as "generous enough that no real crisis meets it" and three still is. The real change is the **60-minute cooldown**, which matches the feed's own pin window: a second SOS while yours is still pinned is not a second call for help, it is the same person occupying the top of the feed twice — the "pinning megaphone" the separate allowance was created to prevent and did not |
| **Health timeline** | `max(7, hereIndex+1)` nodes | **`max(4, hereIndex+1)`** | Nothing structural. It is still a **floor, never a ceiling**, so §2.4's correction holds exactly: a node the reader has already reached is never locked. Four is the first 24 hours — the stretch a day-1 quitter is living through — and everything past it is the long arc, which is what Premium is for |
| **Panic arcade** | free and unbounded | **Orbs free; Tiles and Blocks Premium** | See below. This is the one that touches §4.2 |

### The panic door, and why this is not a reversal of §4.2

`S5-13` deleted the panic paywall door because *"selling mid-craving is the worst moment for
both parties: the least considered purchase and the likeliest one-star naming the exact thing
this product positions against."* That reasoning is intact and the flow itself is untouched —
breathing, the why step, the three loop-breakers, the coach and the SOS composer are all still
completely free and carry no door at all.

What changed is inside the **arena**, and three things keep it on the right side of that line:

1. **Orbs is `GameCatalog.entries.first`, and `resolveFor` clamps to it.** A free account's
   default game is a free one — including a lapsed subscriber whose stored `lastGame` is
   Blocks, and including a `?g=blocks` deep link. **Nobody LANDS on a lock.** The card is
   reached only by deliberately tapping a pill marked with a padlock, which is a question the
   user asked rather than an offer put in their way.
2. **The card leads with `Play Orbs`,** a filled button that starts a free board in one tap.
   `See Premium` is a text link beside it. Somebody mid-craving came for a board, and they get
   one without reading a price.
3. **It is never shown mid-round.** `_switchTo` stops the ticker before the card takes the
   field's slot, and the round panel, the paused veil and the switcher are all pinned
   door-free by `test/widgets/panic_session_test.dart`.

That test was **extended rather than deleted**: `panic_screens.dart` must still contain no
`paywallFrom` at all, and the arena is allowed exactly one, on the lock card.

### The composer's missing floor

A separate finding from the same device pass, and the reason the SOS work was reachable at
all: the panic flow opens the composer **pre-tagged `sos`**, so publishing was one tap away
with the tag already chosen — and `canPost` required only `text.trim().isNotEmpty`. **`"a"`
published, and because a live SOS pins to the top of the feed for an hour, it pinned.**

`PostQuality` (`lib/domain/logic/community_rules.dart`, mirrored by `postQuality` in
`functions/src/ai/prefilter.ts`) is the floor: 12 characters, 3 words, 2 distinct words, 3
letters and 4 distinct letters for a post; a much looser bar for a reply, which had no
validation of any kind beyond a length cap. It runs **before any allowance is claimed**, like
the slur check, so junk never costs its author a slot — and the client refuses first so the
words are still in the box to edit, rather than "not published" after the composer has closed
(`docs/09` issue 6).

The bar is deliberately low. `help me please`, `i want to vape` and `i cant i cant i cant` all
publish. **A gate that turns away a real cry for help costs far more than the noise it
filters**, which is the whole reason the numbers are where they are rather than higher.

### The Free screen

`FreePlanScreen` was five ✓ rows and one button, and that button was *Start with Free*: a
person who reached it was shown nothing they did not already have and given no reason ever to
leave. Premium was one grey line of reassurance at the bottom.

It is now a **Free-vs-Pro comparison table** — ten rows, every figure read from `LpAllowances`
rather than typed — with **Pro as the primary button and Free demoted to a text link**. The
free path stays plainly visible and one tap away, which is what Apple 3.1.2 and Play actually
require; it is the same shape the D5 paywall already uses in reverse. No guilt copy: the rows
state facts, and the Free column is simply shorter, which is true.

It is also the app's **thirteenth door** and the first that measures the people who reach Free
and reconsider — `gate_shown`/`gate_tapped` with `source: 'free_plan'`.

Two copy fixes fell out of it. `freePlanFeat3` hardcoded "5 coach messages a day" and
`freePlanFeat5` hardcoded "one post a day", in five ARB files each; both are now interpolated
from the constants the app enforces. And `paywallFeatPanic` sold "Panic button: a 60-second
craving killer" — the panic button has always been free and is staying free, so the line now
names what Premium actually adds: all three arena games.

### The coach's chips

Not a monetisation change, but it landed in the same pass and it is the founder's answer to
"we still have a lot of room to improve" on retention. The quick chips under the thread were
four frozen strings rendered identically on every turn forever. Right for a cold open, useless
as a reply. `aiCoachChat` now returns 3–4 follow-ups written in the **user's own voice** from
the exchange that just happened, and the app shows those in place of the openers. See
`docs/11 §3` for the pipeline and its cost (~5% of a turn, with a kill switch).

### Gates

`flutter analyze` clean · `flutter test` **978** · `npm run verify` **217** ·
`npm run test:integration` **284** · `npm run test:rules` **47** · **on-device 68/68 on a
Pixel 8** (Android 17), 51 against the fake backend and the 17-case `f_firebase_backend`
suite against **production**. `eval:moderation` was not required (no moderation prompt
changed) and `eval:coach` is not re-gated — `EMBER_SYSTEM_PROMPT` and
`buildCoachInstruction` are byte-identical, and the follow-up prompt is its own separate call.

**Shipped to production Sep 3 2026** (founder-approved): all 24 functions redeployed behind a
clean gate, `DAILY_SOS_POSTS=5→3`, `COACH_FOLLOWUPS=true`. The follow-up chips are verified
against the deployed `aiCoachChat`, not just against a stub — the fake coach returns none by
design, so that surface has no other harness. See `docs/10 §21.7`.

---

## 6. REGISTER — what this study overrides

These rows belong in `docs/08 §7`.

| Spec text | Superseded by |
|---|---|
| `docs/01 §10` "Community: Read + react" (free) | **1 post/day any tag, SOS uncapped** (§4.1) |
| `docs/01 §10` "Stats history: 7 days" (free) | ~~30 days (§4.1)~~ → **back to 7 days** (§5c, same day) |
| §4.1 "SOS refused for no tier", 5/day | **3/day, plus one live SOS at a time** (§5c) |
| §4.1 / §5b free health nodes `max(7, hereIndex+1)` | **`max(4, hereIndex+1)`** — still a floor (§5c) |
| §4.1 "the panic arcade is never gated" | **Orbs free; Tiles and Blocks Premium** — the flow itself stays door-free (§5c) |
| `docs/02 §4` "Try everything free for 3 days" and `docs/02 §6` test 1 | **7 days**, already resolved as `docs/08 §7 #14`; §3.2 is the evidence, and §5 retires the 7-vs-3 test |
| `docs/02 §5` "Upgrade prompts … max 1/day" | Only `launch` was ever throttled. Restated: **lock cards are honest labelling and always render; the unrequested full-screen paywall is capped to plan days {3, 7, 14, 30}** (§4.2) |
| `docs/02 §4` feature checklist "Panic Button + buddy ping" | Buddy is descoped (`docs/08 §7 #13`); the panic **AI** never routes to the paywall (§4.1) |
| `docs/08 §2` lever 2 ("$3.99/wk test") | **Annual price first** — $59.99/yr for new users (§4.3) |
| `docs/06 §3` "50 free lifetime spots" + the recruited beta cohort | **Descoped Sep 3 2026 (founder).** No cohort was recruited and none will be; Cirrus ships direct to production. Everything downstream of it goes too — `S1-12` (founder grant), `S2-10` (closed testing), `S3-12` (tester-seeded feed), `S5-8` (cohort crash-free), `S6-2` (tester testimonials), `S6-4` (thank-you post) |

---

*Built from a code verification pass on Sep 3, 2026. Phase 1 cites a path for every claim; Phase 2 cites a source and a date for every figure. The two PMC figures in §3.4 carry an explicit unverified caveat and must not be quoted user-facing until checked against the papers.*
