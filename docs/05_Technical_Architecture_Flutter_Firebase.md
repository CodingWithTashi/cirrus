# 📄 DOC 5 — TECHNICAL ARCHITECTURE (Flutter + Firebase)
## Project "LastPuff" ✅ (name locked Aug 17, 2026)
**Version:** 1.1 · **Date:** Aug 17, 2026 · **Depends on:** Docs 1–2 · **Answers:** stack choices, core libraries, data model, backend functions, security, costs, build order
**✅ Founder-locked decisions (Aug 17, 2026):** RevenueCat + Superwall · Gemini (Flash free / Pro premium) via Genkit · Riverpod · TypeScript Cloud Functions · Mixpanel + Firebase Analytics

> **Founder's question answered first:** Design + Docs 1–2 are enough to START (onboarding UI, paywall, auth, home shell). Your developer will get blocked at week 3–4 without **Doc 3** (taper algorithm math, streak/money formulas, relapse logic) and **Doc 4** (AI coach prompts, caps, safety). This Doc 5 closes the stack questions. Build order at the bottom keeps everyone unblocked.

---

## 1. STACK DECISION TABLE (recommendation ⭐ + options)

| Layer | ⭐ Recommendation | Alternatives | Why |
|---|---|---|---|
| App framework | **Flutter (Dart 3), iOS-first release** | Native Swift (what Puff Count used) · React Native | Your skills + one codebase = Android in V2 nearly free (Puff Count has NO Android — open flank). Trade-offs in §3. |
| State management | ✅ **Riverpod (flutter_riverpod v2+)** — founder-confirmed | Bloc | Less boilerplate for a solo/small team, testable, async-first — fits streams from Firestore. Bloc fine if your dev insists. |
| Navigation | **go_router** | auto_route | Simple declarative routes + deep links (panic-button push → panic screen). |
| Auth | **Firebase Auth: Sign in with Apple + Anonymous** | Supabase Auth | Anonymous-first = zero-friction onboarding; link to Apple ID at paywall/backup moment. Apple sign-in is mandatory anyway when offering social login. |
| Database | **Cloud Firestore** (offline persistence ON) | Supabase Postgres | Realtime community feed + offline puff logging out of the box; rules-based security; you know it. |
| Backend logic | **Cloud Functions 2nd gen (TypeScript) + Genkit** | Dart Cloud Functions (early) · Cloud Run | Genkit gives one framework for AI flows, tools, tracing; TS is the mature path (Dart support is preview — revisit at V1.1). |
| AI models | ✅ **Gemini Flash (free tier) / Gemini Pro (premium), server-side via Genkit** — founder-confirmed | Claude, GPT (swappable later via Genkit plugins, no app update needed) | Coach MUST be server-side: system prompt secrecy, per-tier caps, memory injection, safety filters, cost control. Client-side Firebase AI Logic is the wrong tool for the coach (no server-enforced caps). All-Google stack = one billing account, first-class Genkit support, lowest token cost. |
| Subscriptions | ✅ **RevenueCat (purchases_flutter)** — founder-confirmed | Adapty · raw StoreKit2 | Industry backbone (Puff Count used it), free until ~$2.5K/mo tracked revenue then 1%; entitlements, webhooks, charts. |
| Paywall testing | ✅ **Superwall (superwallkit_flutter)** — founder-confirmed | RevenueCat Paywalls (simpler, ~4-variant A/B cap) · Adapty | Puff Count's weapon; remote paywall edits + unlimited experiments without app review. Note: occasional reliability complaints reported — mitigation: hard-code a native fallback paywall if SDK fails to load. If you want ONE vendor to start, RevenueCat Paywalls is acceptable for month 1, add Superwall before scaling ads. |
| Analytics | **Mixpanel (funnels) + Firebase Analytics (free backbone)** | Amplitude · PostHog | Puff Count ran Mixpanel + Amplitude; one product-analytics tool is enough for you. Firebase Analytics feeds Crashlytics/Remote Config audiences free. |
| Attribution (ads) | **Defer to month 3+: AppsFlyer** (what Puff Count used) | Adjust · Apple Ads attribution only | Don't pay for an MMP before you run paid traffic. Apple Search Ads basic attribution is free meanwhile. |
| Crash/quality | **Crashlytics + Sentry (optional)** | — | Crashlytics free; add Sentry if your dev prefers richer traces. |
| Config/flags | **Firebase Remote Config** | LaunchDarkly | Free, targets by audience; kill-switches for AI features. |
| Push | **FCM + flutter_local_notifications** | OneSignal | FCM free; local notifications handle danger-hour schedules offline. |

---

## 2. PUFF COUNT'S STACK → OUR EQUIVALENT (per your ask)

| Puff Count used | Purpose | Our version |
|---|---|---|
| Native iOS (Upwork dev, <$5K MVP) | The app | Flutter (same lean build ethos, plus Android later) |
| Superwall | Paywall A/B, price tests $3.99–$9.99/wk | Same — superwallkit_flutter |
| RevenueCat | Subscription infra, LTV tracking | Same — purchases_flutter |
| Mixpanel + Amplitude | Behavior analytics | Mixpanel only (one is enough) + Firebase Analytics |
| AppsFlyer | TikTok/FB ads attribution | Same, but only when paid ads start (month 3+) |
| 99designs + paper sketches | Design | Claude Design (your v2 prompt) → Figma handoff |
| No AI, no community backend | — | Cloud Functions + Genkit + Firestore feed (our moat) |

---

## 3. FLUTTER TRADE-OFFS — HONEST LIST (and fixes)

1. **Lock-screen/home widgets** ("log a puff without opening the app" — the #1 requested feature we're building): Flutter can't draw iOS widgets. **Fix:** `home_widget` package + a small native **WidgetKit extension in Swift** (~1–2 days of native work). Budget it; don't let the dev skip it.
2. **Live Activities / Dynamic Island** (streak/craving timer): needs native ActivityKit; `live_activities` package bridges. **V1.1, not MVP.**
3. **Apple Watch app**: effectively a separate native mini-app. **V2.** (Watch *notifications* work day one for free.)
4. **App size/startup**: Flutter apps are heavier than Swift; irrelevant at our scale — keep under ~60MB.
5. **The win that outweighs all of it:** one codebase → Android launch in V2 with ~90% code reuse into a market where the original Puff Count never shipped.

---

## 4. CORE LIBRARIES (pub.dev — hand this list to your dev)

**Firebase:** `firebase_core` · `firebase_auth` · `cloud_firestore` · `cloud_functions` · `firebase_messaging` · `firebase_remote_config` · `firebase_crashlytics` · `firebase_analytics` · `firebase_app_check`
**Money:** `purchases_flutter` (RevenueCat) · `superwallkit_flutter`
**State/arch:** `flutter_riverpod` · `go_router` · `freezed` + `json_serializable` (models)
**Dopamine UI:** `fl_chart` (curves, bars, heatmap) · `flutter_animate` (micro-interactions) · `confetti` (milestones) · `rive` (optional: the growing streak flame) · built-in `HapticFeedback`
**OS integration:** `home_widget` (+ Swift WidgetKit target) · `flutter_local_notifications` · `in_app_review` (the D3 rating ask) · `app_links` (deep links) · `quick_actions` (long-press icon → Panic)
**Utils:** `intl` (currency/dates) · `shared_preferences` (flags) · `cached_network_image` (community avatars)
**Rule:** no ad SDKs, no third-party trackers beyond Mixpanel — our "we never sell your data" claim is engineered, not just marketed (also means no ATT prompt = cleaner onboarding).

---

## 5. ARCHITECTURE (one picture)

```
┌────────────── Flutter App (iOS first) ──────────────┐
│ Riverpod state · go_router · Superwall paywalls     │
│ RevenueCat SDK · Mixpanel · local notifications     │
│ home_widget ⇄ Swift WidgetKit extension             │
└───────┬───────────────────────┬─────────────────────┘
        │ Firestore SDK          │ HTTPS callable (App Check)
        ▼                        ▼
┌──── Cloud Firestore ────┐  ┌── Cloud Functions (TS + Genkit) ──┐
│ users, days, plans,     │  │ aiCoach (stream) · panicSession   │
│ cravings, moods, posts, │  │ weeklyInsight (cron) · taperRecalc│
│ buddies, coachThreads   │  │ moderatePost (trigger) · rcWebhook│
│ (offline persistence)   │  │ dangerHourPush (cron) · deleteUser│
└─────────────────────────┘  └───────┬───────────────────────────┘
                                     ▼
                     Gemini API via Genkit (Flash free / Pro premium)
                     RevenueCat webhooks · FCM push
```

---

## 6. FIRESTORE DATA MODEL (cost-smart)

**Key principle: never one document per puff.** A 400-puff/day user would cost a fortune in writes/reads. Log = increment on a daily doc.

```
users/{uid}
  alias, createdAt, tz, gender, birthYear, baseline{puffsPerDay, mgStrength, weeklySpend, firstPuffWindow},
  whyChips[], fearChips[], plan{method, paceDays, startDate, freedomDate, dailyLimitToday},
  streak{current, longest, lastLogDate, repairTokens}, entitlement (mirror of RevenueCat), aiUsage{day, msgCount}

users/{uid}/days/{YYYY-MM-DD}         ← THE workhorse doc
  puffCount (increment), limit, mgTotal, moneySpentAvoided, mood, cravingsSurvived, hourBuckets{0..23: n}

users/{uid}/cravings/{id}             ← panic sessions: startedAt, intensity, outcome, minutes
users/{uid}/coachThreads/{id}/messages/{id}   ← role, text, ts (server-written only)
users/{uid}/insights/{weekId}         ← AI weekly report JSON
posts/{postId}                        ← authorAlias, uid(hidden by rules), tag, text, reactions{}, status(live/flagged)
posts/{postId}/replies/{id}
buddies/{pairId}                      ← uids[2], streaks, lastNudge
config/* (Remote Config mirrors), leaderboards/* (V2)
```

**Rules principles:** users read/write only their own tree; `posts` readable by all signed-in, author-only writes, `uid` field never exposed to clients (Cloud Function stamps alias); coach messages written only by Functions (prevents prompt tampering); App Check enforced on Functions.

---

## 7. CLOUD FUNCTIONS LIST (MVP set)

| Function | Trigger | Job |
|---|---|---|
| `aiCoachChat` | callable (streaming) | Tier check → cap check → inject memory (why, fears, stats) → Genkit → Gemini → store both turns |
| `panicSession` | callable | Serve the 3-step script personalized; log outcome; buddy ping if opted in |
| `taperRecalc` | nightly cron | Recompute tomorrow's limit from trailing 7-day adherence (algorithm in Doc 3) |
| `weeklyInsight` | Sunday cron | Aggregate days/* → Gemini → insight JSON + push |
| `dangerHourPush` | hourly cron | Users whose hourBuckets predict risk this hour → FCM nudge |
| `moderatePost` | Firestore onCreate(posts, replies) | Gemini moderation pass → live/flagged; auto-hide on N reports (App Store UGC requirement: report + block + moderation) |
| `rcWebhook` | HTTPS (RevenueCat) | Mirror entitlement to users/{uid}; analytics events |
| `onTrialWillEnd` | RC webhook event | Honest trial-ending push (Doc 2 §4) |
| `deleteUserData` | callable | Full erasure (privacy promise + App Store account-deletion requirement) |

---

## 8. AI COST CONTROL (implementation of Doc 1 §11)

- Server-enforced caps in `users/{uid}.aiUsage`: free = 5 msgs/day + 1 panic/day; premium = 100 msgs/day soft cap (fair use).
- Model routing: free → Gemini Flash; premium → Gemini Pro (Flash for both is acceptable at launch); `max_tokens ≤ 500`, coach replies are short by design (Doc 4).
- Trim context: last 10 turns + memory card, never full history.
- Budget alarm: daily Function sums token usage → Slack/email alert at $20/day; Remote Config kill-switch downgrades all traffic to Flash.
- Target: < $0.25/user/month blended (Flash pricing + short-reply design; recheck monthly).

---

## 9. ENVIRONMENTS, CI, RELEASE

- Two Firebase projects: `lastpuff-dev`, `lastpuff-prod`; Flutter flavors map to them.
- GitHub + GitHub Actions (or Codemagic) → Fastlane → TestFlight on every main merge.
- Secrets in Google Secret Manager (Gemini API key never in app or repo).
- Crash-free sessions ≥ 99.5% gate before scaling spend.
- App Store prep: 17+/18+ rating, UGC moderation checklist (report/block/hide), account deletion, privacy labels = "Data not collected for tracking" (our differentiator), subscription disclosures.

---

## 10. COST ESTIMATE @ ~10K MAU (order of magnitude)

| Item | $/month |
|---|---|
| Firestore + Functions + FCM (daily-doc model) | $30–80 |
| Gemini API (caps enforced; Flash is very cheap) | $60–200 |
| RevenueCat | $0 until ~$2.5K MTR, then 1% (~$120 at $12K) |
| Superwall | ~$0–99 tier at our scale (check current pricing at signup) |
| Mixpanel | Free tier likely sufficient year 1 |
| Apple dev + misc | $8 + domains |
| **Total** | **≈ $120–500/mo** — well inside $10K revenue target |

---

## 11. BUILD ORDER (8 weeks, maps to docs)

- **Wk 1–2:** Flutter scaffold, flavors, Firebase wiring, Auth (anon+Apple), design system tokens from v2 prompt, onboarding screens A1–C5 (Doc 2)
- **Wk 3:** Plan reveal + commitment + rating + Superwall paywall + RevenueCat products (`weekly_299`, `monthly_799`, `yearly_3999`) — *needs Doc 3 for taper math*
- **Wk 4:** Home + logging + daily-doc engine + streak/money + widget (Swift extension)
- **Wk 5:** AI coach + Panic Button (Functions + Genkit) — *needs Doc 4*
- **Wk 6:** Community feed + moderation + notifications + danger-hour cron
- **Wk 7:** Stats, health timeline, relapse-recovery, mood, polish, dark-mode QA
- **Wk 8:** TestFlight beta (30–50 users from r/QuitVaping + friends), fix, App Store submission

**Definition of MVP-done:** a stranger can go TikTok → download → quiz → trial → log puffs from lock screen → survive a craving with the AI → post in community — without you touching anything.
