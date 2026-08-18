# 📄 DOC 1 — PRODUCT REQUIREMENTS DOCUMENT (PRD)
## Project "LastPuff" ✅ (name locked Aug 17, 2026) — The AI-Powered, Honest Quit-Vaping App
**Version:** 1.0 · **Date:** Aug 16, 2026 · **Owner:** Founder · **Status:** Draft for review

> **How to read this doc:** This is the master document. Anyone reading it should understand the entire product — what we're building, for whom, why it wins, how it makes money, and how we measure success. Docs 2–6 go deeper on each area.

---

## 1. EXECUTIVE SUMMARY

**LastPuff** is an iOS-first subscription app that helps people quit vaping through three pillars: **smart tracking** (puff logging + adaptive taper plan), an **AI Quit Coach** (24/7 craving support and personalized insights), and **community accountability** (buddies, groups, shared streaks).

We are entering a proven market with a decayed leader. Puff Count validated the niche (450K+ downloads, ~$44K/mo peak revenue, grown almost entirely via organic TikTok) but was sold to a portfolio operator, went dormant, removed its only social feature, and is bleeding trust through an aggressive paywall. No one owns "the modern, Gen Z-native, AI + community quit-vaping app." We will.

**Business goal:** $10,000/month net revenue within 6–9 months of launch, timed to peak at the January 2027 "quit wave."

**Model:** Free tier (real, usable forever) + Premium at **$2.99/week · $7.99/month · $39.99/year** — a third of Puff Count's $9/week. Positioning line: *"Cheaper than one disposable a week."* Early users keep this "founding price" forever (urgency + loyalty lever for later price raises).

---

## 2. THE PROBLEM

- Nicotine vapes (especially cheap, high-strength disposables) have created a new addiction wave concentrated in people aged 15–30.
- **The users themselves want out:** 67% of young adult nicotine users planned to quit this new year; 62% want to quit within the year for physical or mental health (Truth Initiative, Jan 2026).
- **They are failing alone:** among daily young e-cigarette users, the share who tried and FAILED to quit jumped from 28% → 53% between 2020 and 2024 (JAMA Network Open). 76% of teen vapers reach for the vape within 30 minutes of waking — genuine dependence.
- Existing help is either **clinical and boring** (government/pharma apps: quitSTART, Nicorette), **generic** (I Am Sober), or **predatory** (Puff Count's total lockout paywall, data-selling under new ownership).
- The moment of failure is always the same: **a craving at a weak moment with no support present.** No app in this niche solves the 2 a.m. craving. That is our wedge.

---

## 3. MARKET SIZE & WHY NOW

| Signal | Data | Source |
|---|---|---|
| US vapers | 4.7M young adults (18–25, highest of any group) + 7.1M adults 26+ + 1.6M students | CDC / CTRI |
| Quit intent | 67% plan to quit (New Year 2026); 62% within the year | Truth Initiative |
| Failed attempts rising | 28% → 53% (2020–2024) among daily young users | JAMA Network Open |
| Category revenue | Quit-smoking apps ~$588M (2023) → $1.34B projected (2032) | Market research |
| Proof of playbook | Puff Count $44K/mo (solo, organic TikTok); QUITTR (porn) $250K MRR in ~5 months with identical mechanics | Founder interviews / AfterMVP |
| Seasonality | Habit apps swing ~2× between January peak and summer trough | Indie founder reports |

**Why now:** (1) the leader is a zombie asset; (2) AI coaching is now cheap enough to run under a $4.99/wk price; (3) disposables got stronger and cheaper post-2024, deepening dependence and demand; (4) January 2027 quit wave is a timed launch window.

---

## 4. TARGET USERS (PERSONAS)

**P1 — "Panic Quitter" (primary) · Jordan, 22, student/service worker**
Vapes 200–400 puffs/day, started at 16. Tried cold turkey 3+ times. Broke, spends ~$25–40/wk on disposables. Lives on TikTok. Triggers: stress, drinking, friends. Needs: instant help at craving moments, proof of progress, not feeling judged. Converts on: shock stats + money saved + "you're not alone."

**P2 — "Health Wake-Up" · Sam, 29, young professional**
Vapes "socially" that became daily. Noticed shortness of breath at the gym. Higher income, will pay for quality. Needs: data, health-recovery timeline, clean design, privacy. Converts on: science credibility + HealthKit integration + annual plan value.

**P3 — "Hiding It" · Alex, 34, parent**
Secret vaper, ashamed, hides it from partner/kids. Needs: total privacy, anonymous community, compassionate relapse handling. Converts on: privacy promise + judgment-free tone. (Secondary but high-retention segment.)

**Explicitly NOT served in v1:** under-18s (17+/18+ age gate — legal + App Store + ethical), cigarette smokers (v2 expansion), cannabis vapers (v2 mode).

---

## 5. COMPETITIVE LANDSCAPE

| App | Price | Strengths | Fatal weaknesses |
|---|---|---|---|
| **Puff Count (original, Rodger Studio)** | ~$9/wk | Brand recognition, sleek tracker, proven ASO | Portfolio-owned zombie; community removed; total-lockout paywall = #1 complaint; now sells ad data; no AI |
| **"Puff Count" clone (MWM)** | $4.99/wk | Copied name; modern quiz onboarding; basic "Ask Puffy" chatbot; mood tracking | Fake stats ("78% quit") = review/App-Store risk; reactive bot, no real coaching; no community; template studio |
| **Quit Vaping (J. Kopp)** | Sub | Feature-rich (buddy system, forum, coach), frequent updates, niche leader by users | Dated design, no AI layer, weak content/marketing engine |
| **Smoke Free / QuitSure** | Freemium | Evidence-based CBT missions, credibility | Smoking-first, older audience, zero TikTok presence |
| **quitSTART / Nicorette (free)** | Free | Trustworthy, free | Clinical, boring, no retention hooks |
| **I Am Sober** | Freemium | Great community/accountability model | Generic all-addictions app; no vaping-specific tools |

**Our gap:** modern Gen Z brand **+ real AI coach + community + honest pricing** in one product. Every competitor has at most one of these.

---

## 6. POSITIONING & BRAND PROMISE

- **One-liner:** *The AI quit coach in your pocket — with real people who get it.*
- **Price position:** ~half of Puff Count. *"Cheaper than one disposable a week."*
- **Honesty position:** Only real, sourced stats (see §9). A free tier that actually works forever. **"We will never sell your data"** — engineered in (no third-party ad SDKs), marketed loudly, directly contrasting Puff Count's current privacy label.
- **Tone:** Best-friend-who-quit energy. Zero medical-pamphlet language. Compassionate on relapse ("a slip is data, not failure").

---

## 7. PRODUCT OVERVIEW — THE THREE PILLARS

1. **TRACK (the habit engine)** — one-tap puff logging (app, lock-screen widget, Apple Watch, Siri), nicotine mg tracking, adaptive taper plan that recalibrates weekly, streaks, money saved (with "what it buys instead"), health-recovery timeline (20 min → 1 yr milestones), mood check-ins.
2. **COACH (the AI differentiator)** — 24/7 AI Quit Coach chat; **Panic Button** (guided 3-minute craving intervention: breathing + CBT reframe + distraction, escalates to buddy ping); craving forecasts ("Friday 10 p.m. is your danger zone — plan ready"); weekly AI insight report in plain English; relapse-recovery mode that adjusts the plan instead of shaming; vape-scanner (photo → auto-set device, nic strength, cost).
3. **TOGETHER (the moat)** — quit buddies with shared streaks, anonymous community feed (wins, SOS posts, milestones), group challenges ("Quitters of January"), buddy alert when someone hits the panic button. *Community is our founder superpower and the hardest thing for portfolio operators to copy.*

---

## 8. FEATURE SCOPE BY PHASE

**MVP (build weeks 1–8, launch month 3):**
Onboarding quiz + paywall (Superwall) · RevenueCat subscriptions · puff logging (tap + lock-screen widget) · adaptive taper plan v1 · streaks · money saved · nicotine tracking · health timeline · AI Coach v1 (chat + Panic Button, usage-capped on free) · mood check-in · basic community feed (post, react, report) · push notifications · relapse-recovery flow · edit past days · privacy-first analytics (Mixpanel/Amplitude, no ad SDKs).

**V1.1 (months 3–5):** Apple Watch app · Siri/Shortcuts logging · craving forecasts · weekly AI insight report · vape scanner · buddy system + panic-button buddy ping · widget upgrades · referral program ("quit with a friend = both get 1 month free").

**V2 (months 6–12):** Android · group challenges · cigarette & nicotine-pouch modes · streak insurance · localization (FR/DE/PT — mirroring Puff Count's proven markets) · B2B pilot (campus health / employers).

**Never:** selling user data · third-party ad SDKs · fake statistics · total-lockout paywall.

---

## 9. HONEST SCIENCE (our stats, with sources — replaces competitors' fake numbers)

- "Quitting attempts fail 92%+ of the time without support — you're not weak, you're under-equipped." (CDC unassisted quit-rate data)
- "A structured quit-vaping program produced 24% abstinence vs 19% going it alone in a randomized trial of 2,588 young adults." (This is Quitting RCT, JMIR)
- "Social accountability raises quit success by roughly 40%." (peer-support cessation literature)
- "Self-monitoring alone measurably reduces consumption." (behavior-change literature; also Puff Count's own user reviews)
- "Most cravings pass in 15–20 minutes — the Panic Button exists for exactly that window." (nicotine craving research)
All in-app claims must trace to this list (full citations in Doc 2 appendix). **No invented percentages, ever.**

---

## 10. FREE vs PREMIUM MATRIX

| Feature | Free (forever) | Premium |
|---|---|---|
| Puff logging + widget | ✅ | ✅ |
| Streaks + money saved | ✅ | ✅ |
| Basic daily limit | ✅ (static) | ✅ Adaptive taper plan |
| Health timeline | ✅ Basic milestones | ✅ Full + HealthKit |
| AI Quit Coach | 5 messages/day | ✅ Unlimited |
| Panic Button | 1 use/day | ✅ Unlimited + buddy ping |
| Craving forecasts + weekly AI report | — | ✅ |
| Community | Read + react | ✅ Post, buddies, groups |
| Mood insights | Log only | ✅ Correlations & trends |
| Stats history | 7 days | ✅ Unlimited |

**Paywall strategy (the hybrid):** keep the high-converting flow (emotional quiz → hard paywall → 3-day trial: Puff Count's switch to this produced 20–25% trial starts; hard paywalls convert ~5× freemium industry-wide) — **but after trial, degrade gracefully to the Free tier above instead of locking users out.** We keep their conversion economics and delete their #1 one-star complaint. Free users stay in the community (word-of-mouth + future converters).

---

## 11. MONETIZATION & PRICING

- **Premium (founder-confirmed):** $2.99/week · $7.99/month · $39.99/year (annual highlighted: "Best value — $0.77/week"). 3-day free trial on all tiers.
- Weekly plans drive ~55% of subscription app revenue industry-wide (RevenueCat SOSA) — weekly is the impulse default; annual is the anchor; monthly catches price-aware users who'd otherwise churn weekly.
- Apple Small Business Program: 15% commission → net ≈ $2.54/wk · $6.79/mo · $33.99/yr.
- **Price ladder plan:** launch at founding price → after traction, test $3.99/wk for new users via Superwall while grandfathering existing subs (marketing: "price goes up — founding members keep $2.99 forever").
- ⚠️ Cannibalization watch: $7.99/mo is 38% cheaper than 4× weekly — monitor tier mix; if monthly dominates and LTV drops, raise monthly to $9.99 in test.
- **AI cost control:** free tier capped (≈5 msgs/day, cheap model); premium routed to a stronger model with a soft fair-use cap; target AI cost < $0.40/user/month (details in Doc 4).

---

## 12. USER JOURNEY (summary — full spec in Doc 2)

1. **TikTok/creator video → App Store page** (ASO: "quit vaping," "puff counter," "stop vaping").
2. **Onboarding quiz (≈14 screens):** identity → habit baseline (puffs/day with live "addiction level" reaction) → spend (seeds money-saved) → goal & pace → motivations & fears → **personalized plan reveal** with real stats → trophy moment → rating ask at peak motivation → paywall with trial.
3. **Day 1–3 (trial):** guided first day, first AI coach conversation, first community post prompt, notification permission with clear value.
4. **Daily loop:** log puffs → watch limit adapt → streak + money tick up → evening mood check-in → AI nudges at forecasted danger hours.
5. **Craving moment:** Panic Button → 3-minute intervention → craving survived → dopamine celebration → optional community share.
6. **Slip:** relapse-recovery mode → plan auto-adjusts → compassionate reframe → streak "repair" mechanic (not total reset).
7. **Quit day & beyond:** maintenance mode, milestone celebrations (24h, 72h, 1wk, 1mo, 1yr), alumni role in community.

---

## 13. SUCCESS METRICS & THE $10K/MONTH MATH

**North star:** Weekly Active Quitters (users who logged ≥4 days/week).

**The funnel to $10K/mo net (~$11.8K gross):**
| Stage | Target | Basis |
|---|---|---|
| Downloads needed (cumulative by month 6–9) | 50–70K | Puff Count did tens of thousands off ONE 8.3M-view video; one viral month can cover this |
| Onboarding completion | ≥70% | Quiz best practices |
| Trial start (hard paywall) | 20–28% | Puff Count hit 20–25% at 3× our price — cheaper converts better |
| Trial → paid | 50–65% | Low price point lifts conversion vs industry 45–60% |
| Active premium needed | ~1,050 blended subs | Blended net ARPU ≈ $9.60/mo (assumes 50% weekly / 25% monthly / 25% annual mix) → ≈ $10.1K net |
| Monthly premium churn | <30% blended | Cheap price + annual mix ≥25% + graceful free fallback reduce churn vs Puff Count |

**Guardrail metrics:** D1 retention ≥45%, D7 ≥25%, D30 ≥12% · Panic Button "craving survived" rate ≥70% · App Store rating ≥4.6 · refund rate <3% · AI cost/user <$0.40/mo · ≥1 organic video >1M views per month.

---

## 14. RISKS & MITIGATIONS

| Risk | Severity | Mitigation |
|---|---|---|
| Paid social rejects nicotine-adjacent ads (TikTok bans the category; Meta only allows FDA/WHO-approved cessation products) | High | Budget goes to creator deals (view-guarantee contracts) + Apple Search Ads + SEO; organic TikTok is the primary engine (proven by Puff Count: 50M organic views, $0 ads at start) |
| Apple review: health claims | Medium | Only sourced claims (§9), "support tool not medical treatment" language, 17+/18+ rating, medical disclaimer |
| AI cost blowout | Medium | Free-tier caps, model routing, monthly cost dashboards |
| January seasonality trough in summer | Medium | Annual-plan push each January; V2 modes (pouches, cigarettes) widen audience |
| Copycats (this niche clones fast) | Medium | Community + brand voice + founder-led content = the three things template studios can't clone |
| Influencer ops eat founder time (STOPPR lesson: 75% of day, 20% margins) | Medium | Systemize month 1: outreach templates, standard $/view guarantee deal, VA by month 4 |
| Solo-founder burnout | High | Fixed content batching days, no-code tools for ops, scope discipline per this PRD |

---

## 15. OPEN DECISIONS (need founder input)

1. **Name.** OPEN — working title "LastPuff." Alternatives: Exhale, Unpuff, AirBack, Vapeless, Breathr, ClearLung. Criteria: .com available, App Store search overlap with "puff"/"vape," TikTok handle free. (Founder: decide before Doc 7 / design phase.)
2. **Community scope at MVP:** DEFAULT SET → light anonymous feed + reporting at MVP (founder can override; it's our moat, start day one).
3. **Pricing:** ✅ RESOLVED by founder — $2.99/wk · $7.99/mo · $39.99/yr (see §11).
4. **Platform:** DEFAULT SET → iOS-first native; Android in V2 (founder can override).

---

## 16. DOCUMENT MAP

| # | Doc | Status |
|---|---|---|
| 1 | Product Requirements (this doc) | ✅ v1.0 |
| 2 | Onboarding, Paywall & Monetization Spec | Next |
| 3 | Functional Spec (features & algorithms) | Queued |
| 4 | AI Coach Spec (prompts, safety, cost) | Queued |
| 5 | Technical Architecture | Queued |
| 6 | Marketing & Launch Playbook | Queued |
| +7 | Brand & Design Brief (incl. the design prompt you requested) | Queued |

---

## APPENDIX — RESEARCH SOURCES
CDC E-Cigarette Use Among Adults/Youth · Truth Initiative (Jan 2026 survey) · JAMA Network Open (youth quit-failure trend) · This is Quitting RCT (2,588 young adults) · RevenueCat State of Subscription Apps · Puff Count: App Store listing, puffcount.com FAQ, AfterMVP growth playbook, Starter Story interview, Marlvel intel report, Flippa sale listing · QUITTR founder interviews (LA Weekly, Startup Spells) · STOPPR founder postmortem (Indie Hackers) · MWM "Puff Count" clone onboarding (founder's screenshot audit, Aug 2026).
