# LastPuff Cloud Functions

TypeScript backend for LastPuff. There is **no separate Node server** — these
are Firebase Cloud Functions (2nd gen), which run on Cloud Run under the hood.

## Why any server code exists at all

Nine things cannot live in the Flutter app. Each fails hard if you client-side it:

| Concern | What breaks without a server |
|---|---|
| Gemini API key | Extractable from the app bundle in minutes |
| AI caps (5/day free, 100 premium) | Client-enforced caps are trivially bypassed → unmetered spend |
| Ember's system prompt | docs/04 evals #7/#8 require it be unextractable |
| UGC moderation | App Store Guideline 1.2 — a bypassable client check fails review |
| Author anonymity | Firestore rules gate documents, not fields (see `createPost`) |
| Entitlement → tier gating | Trusting the client = free Premium for everyone |
| Streak grants | docs/03 §11: server timestamps are authoritative |
| Nightly/weekly recalc | Needs Cloud Scheduler |
| Account deletion | Cross-collection erasure + post anonymization |

## The one architectural rule

```
journeys/{uid}   CLIENT-owned.  Functions may READ. Never write.
users/{uid}      SERVER-owned.  Functions write. Client READS only.
```

`FirebaseJourneyRepository.save()` writes the journey with a whole-document
`set()` on every optimistic mutation. **Any field a Function adds to
`journeys/{uid}` is clobbered by the user's very next puff tap.** So everything
the server computes — `entitlement`, `aiUsage`, `planAdvice`, `fcmTokens` —
lives in `users/{uid}`, which `firestore.rules` makes read-only to clients.

## Functions

| Function | Trigger | Job |
|---|---|---|
| `aiCoachChat` | callable (streaming) | Tier → quota → memory card → Gemini → persist both turns |
| `panicSession` | callable | Counts the session, reports AI availability. Never blocks. |
| `syncUserContext` | callable | The app's only write path into `users/{uid}` (tz, locale, device registry) |
| `setCoachName` | callable | Validates the coach's name and stores the server-owned copy — the only one `aiCoachChat` is ever told |
| `coachMemories` / `forgetCoachMemory` | callable | List and delete Ember's remembered facts (`users/{uid}/memories`) for their owner |
| `seedCoachMemories` | callable | Ember's first memories from onboarding, so the vector layer is not empty on day 1 |
| `deleteUserData` | callable | Full erasure; posts anonymize to `[departed quitter]` |
| `createPost` | callable | Stamps alias, writes `postAuthors`, lands `status: 'pending'`; idempotent on the app's `clientId` |
| `createReply` | callable | The reply write path (docs/03 §9): `replyAuthors` map, lands `pending`, flipped by moderation |
| `reportPost` / `reportReply` | callable | A reader's report; three reports auto-hide (`held` on the author's mirror) and clear `retryable` |
| `moderatePost` | Firestore onCreate | Gemini classification → live/pending/blocked on the post; live/`held`/blocked on the author's mirror `users/{uid}/posts/{id}` + review queue. Only words aimed at people are ever hidden (Sep 1 policy) |
| `remoderateHeld` | every 15 min cron | Re-asks the classifier about holds the pipeline itself caused (model down, unparseable verdict — queue rows with `retryable: true`), so an outage delays clean posts by minutes instead of parking them in the founder's queue |
| `moderateReply` | Firestore onCreate | The same classifier and verdicts for replies |
| `moderationQueue` / `resolveModeration` | callable (`admin` claim) | The founder's review queue and their verdict on a held item — a person's decision is never re-asked |
| `onReaction` | Firestore onWrite (`posts/{id}/reactors/{uid}`) | Recomputes the public reaction count from private per-person documents, by delta |
| `taperRecalc` | hourly cron | Adaptive taper advice (docs/03 §3.3) → `users/{uid}.planAdvice` |
| `weeklyInsight` | hourly cron | Premium-only Sunday report (docs/04 §5) |
| `pruneDevices` | cron | Drops push registrations nobody is behind any more (replaced or wiped phones) |
| `matchedTestimonials` | callable | The two beta-tester quotes for D3, ranked against the answers the caller sends |
| `rcWebhook` | HTTPS | RevenueCat → the trusted entitlement mirror (fetch-and-reconcile of the subscriber snapshot) |

`dangerHourPush` from docs/05 §7 is **deliberately absent**. Danger-hour
reminders are deterministic once computed, so they're scheduled on-device with
`flutter_local_notifications` — free, works offline, and deletes an hourly
fan-out over the whole userbase. FCM is reserved for genuinely server-side events.

### Cron fan-out at scale

Both crons run **hourly**, not nightly, and query
`users where recalcHourUtc == <current UTC hour>`. Each user stores the UTC
hour matching their local 01:00 (`recalcHourUtcFor`, refreshed on every
`syncUserContext` call, so DST self-corrects). That means one indexed equality
query touching ~1/24th of the userbase per run, and every user is processed
just after **their** midnight — not UTC's.

## Setup

```bash
cd functions
npm install

# Secrets live in Google Secret Manager, never in the repo.
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set REVENUECAT_WEBHOOK_TOKEN
firebase functions:secrets:set REVENUECAT_SECRET_API_KEY   # dashboard → API keys → New secret API key (sk_…, a v2 key)
```

The RevenueCat key must be a **v2** secret key with `customer_information:customers:read_and_write`,
`customer_information:subscriptions:read`, `customer_information:entitlements:read` and
`project_configuration:{products,entitlements}:read`. `src/lib/revenuecat.ts` speaks the v2 API
(`/v2/projects/{RC_PROJECT_ID}/customers/…`); the older `/v1/subscribers` refuses a v2 key with
403 `7243`, which is how the first device purchase left the mirror empty while the app showed
Premium. `RC_PROJECT_ID` (`proj…`) is a plain param in `.env.alastpuff`.

Point the RevenueCat dashboard webhook at the deployed `rcWebhook` URL with
`Authorization: Bearer <REVENUECAT_WEBHOOK_TOKEN>` (production + sandbox events, all apps —
the Test Store app included, or a Test Store purchase never reaches the mirror). The webhook
treats each event as a trigger and mirrors the customer snapshot it fetches with the secret
key — see `src/lib/revenuecat.ts`.

## Develop

```bash
npm run verify      # typecheck + lint + test — the deploy gate
npm run test:watch
npm run serve       # emulators: functions, firestore, auth (UI on :4000)
```

Under the emulator, App Check is not enforced (`FUNCTIONS_EMULATOR=true`).
Copy `.env.example` to `.env` for local model calls.

## Deploy

```bash
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only functions
```

`predeploy` runs `npm run verify`, so a red test blocks the deploy.

### Before the first production deploy

- [x] **`ENTITLEMENT_MODE=mirror`** — flipped Sep 3 2026 (docs/10 §18). Until
      then `tierFor()` returned `premium` for every caller, so every limit in
      `.env.alastpuff` was inert and no user could be given a reason to pay.
      **The param default in `config.ts` is now `mirror` too**, so an unloaded
      `.env` fails toward charging rather than toward giving the app away.
- [ ] `RC_ACCEPT_SANDBOX=true` stays on while sandbox purchases are still being
      verified (Play license testers, TestFlight); the mirror records
      `environment` either way. **Turn it off before the public build** — with
      it on, anyone who can make a sandbox purchase gets a real entitlement.

- [ ] **Enable App Check** (Play Integrity + App Attest) and register the apps.
      Every callable sets `enforceAppCheck: true`; without App Check registered,
      real clients will be rejected — and without it enforced, `aiCoachChat` is
      a public Gemini proxy.
- [ ] Set `COACH_MIN_INSTANCES=1` — a cold start on a 2am craving is a product
      failure, not a perf nit (~$15/mo).
- [ ] Confirm the Firestore location matches `REGION` in `src/config.ts`.
- [ ] Set a budget alert. `AI_COST_PANIC=true` is the kill-switch that routes
      all traffic to the cheap model without a code deploy.

## Model routing

`MODEL_FREE` / `MODEL_PREMIUM` / `MODEL_MODERATION` are deploy params, so an
EOL model is swapped without changing code. The live ids are in
`.env.alastpuff` (`gemini-3.5-flash-lite` for free and moderation,
`gemini-3.6-flash` for premium). An id must exist AND support
`generateContent` — `gemini-3.1-flash` did neither and silently broke the
coach for days — so no `-preview` ids and no `-latest` aliases (docs/04 §9
gates the coach on an eval pass that an alias would swap the model under),
and a non-lite id must be able to stop thinking (`.env.alastpuff` rule 4).
`aiCoachChat` logs the live catalogue on a 404 (`coach.models_available`);
read that rather than guessing. The pipeline end to end, with its cost per
turn, is `docs/11_AI_Flow.md`.

Only `src/ai/gemini.ts` imports a vendor SDK. Everything else depends on the
`TextModel` interface in `src/ai/model.ts` — dropping in Genkit (docs/05 §1),
Claude, or GPT means one new implementation of that interface, no handler
changes and no app release.

## Parity with the Dart engines

`src/domain/` ports `TaperEngine` and the streak rules to TypeScript because
`taperRecalc` and the coach's memory card need them server-side.

**Two implementations of the same math will drift.**
`test/taperEngine.test.ts` pins the identical B=200/P=30 table as
`test/domain/taper_engine_test.dart`. If those two files ever disagree, the app
and the server are quoting different limits to the same user on the same day.
Change one engine, change both.

## Descoped

Quit Buddies is cut (founder decision, Aug 2026), so the buddy-ping branch of
docs/03 §7 and the SOS buddy-notify of §9 are intentionally absent here.
