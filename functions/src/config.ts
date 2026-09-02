/**
 * Deploy-time configuration. Everything tunable lives here as a Firebase
 * param so it can change without a code review, and every secret lives in
 * Google Secret Manager — never in the repo, never in the app bundle
 * (docs/05 §9).
 */
import {defineInt, defineSecret, defineString} from 'firebase-functions/params';

/**
 * Single region for every function. Keep it equal to the Firestore location:
 * a cross-region read adds latency to the panic path for no benefit.
 */
export const REGION = 'us-central1';

// --- Secrets (set with `firebase functions:secrets:set <NAME>`) -------------

export const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');

/**
 * Shared secret for the RevenueCat webhook's Authorization header. RevenueCat
 * sends it verbatim; without it the endpoint is an open entitlement grant.
 */
export const REVENUECAT_WEBHOOK_TOKEN = defineSecret('REVENUECAT_WEBHOOK_TOKEN');

/**
 * RevenueCat **v2** secret API key (`sk_…`, dashboard → API keys → "New
 * secret API key"). The webhook fetches the customer snapshot it mirrors
 * with it, and `deleteUserData` erases the RevenueCat customer with it, so
 * it needs `customer_information:customers:read_and_write`,
 * `customer_information:subscriptions:read`,
 * `customer_information:entitlements:read`, and
 * `project_configuration:{products,entitlements}:read`. Never the public
 * `goog_`/`appl_` SDK keys — those can start a purchase and read nothing,
 * which is the wrong way round for a server. And never a v1 "legacy" key:
 * `lib/revenuecat.ts` speaks v2, which answers 401 to one.
 */
export const REVENUECAT_SECRET_API_KEY = defineSecret('REVENUECAT_SECRET_API_KEY');

/**
 * The RevenueCat project every v2 URL is scoped to (`proj…`, dashboard →
 * Project settings). Configuration, not a secret: it is in every dashboard
 * URL.
 */
export const RC_PROJECT_ID = defineString('RC_PROJECT_ID', {
  default: 'proj2bbaaf3f',
  description: 'RevenueCat project id (proj…) for the v2 REST API.',
});

// --- Tunables --------------------------------------------------------------

/**
 * Whether SANDBOX purchases flip the entitlement mirror. Play license-tester
 * and TestFlight purchases are all sandbox and all ours, so 'true' through
 * beta and QA; set 'false' only if a sandbox grant ever needs to be shut out.
 * The mirror records `environment` either way, so a sandbox Premium is always
 * visible for what it is.
 */
export const RC_ACCEPT_SANDBOX = defineString('RC_ACCEPT_SANDBOX', {
  default: 'true',
  description: "'true' mirrors sandbox purchases too; 'false' ignores them.",
});

/**
 * Warm instances for the coach. 0 is right for dev; set 1–2 in prod — a cold
 * start on a 2am craving is a product failure, not a perf nit (~$15/mo).
 */
export const COACH_MIN_INSTANCES = defineInt('COACH_MIN_INSTANCES', {
  default: 0,
  description: 'Warm instances held for aiCoachChat. Set 1-2 in production.',
});

/** docs/04 §7 — free tier gets 5 coach messages/day, premium 100 (fair use). */
export const FREE_DAILY_COACH_MESSAGES = defineInt('FREE_DAILY_COACH_MESSAGES', {
  default: 5,
});
export const PREMIUM_DAILY_COACH_MESSAGES = defineInt(
  'PREMIUM_DAILY_COACH_MESSAGES',
  {default: 100},
);

/**
 * Model routing (docs/05 §8). Flash-Lite class for free + moderation, a
 * stronger Flash for premium. Names are params so an EOL model can be swapped
 * without a deploy of new code.
 *
 * These defaults are the fallback when no `.env.<project>` supplies a value —
 * see `.env.alastpuff` for the rules on choosing one. They must stay ids that
 * actually exist AND support `generateContent`: the previous default was
 * `gemini-3.1-flash`, which does neither, and the coach answered every user
 * with its warm fallback for as long as it was deployed.
 */
export const MODEL_FREE = defineString('MODEL_FREE', {
  default: 'gemini-3.5-flash-lite',
});
export const MODEL_PREMIUM = defineString('MODEL_PREMIUM', {
  // 3.6, not 3.7: gemini-3.7-flash cannot stop thinking (floor is LOW, a
  // variable 400-2000 thought tokens spent inside the output cap), which
  // truncated premium replies mid-word and delays the first streamed token
  // mid-craving. gemini-3.6-flash at thinkingLevel MINIMAL answers with zero
  // thought tokens — see ai/gemini.ts for the probed capability matrix.
  default: 'gemini-3.6-flash',
});
export const MODEL_MODERATION = defineString('MODEL_MODERATION', {
  default: 'gemini-3.5-flash-lite',
});

/**
 * Pre-monetization switch (founder decision, Aug 29 2026).
 *
 *   'ungated' — everyone is premium. RevenueCat is not wired yet and the app
 *               must work end-to-end with nothing locked.
 *   'mirror'  — the real behaviour: tier comes from users/{uid}.entitlement,
 *               written only by rcWebhook.
 *
 * The gating code stays live and tested in both modes on purpose. Deleting it
 * now and re-adding it at billing time is how paywalls ship broken; flipping
 * one param is not. **Set this to 'mirror' the day RevenueCat goes live.**
 */
export const ENTITLEMENT_MODE = defineString('ENTITLEMENT_MODE', {
  default: 'ungated',
  description: "'ungated' (everyone premium, pre-launch) or 'mirror' (real entitlements).",
});

/** Kill-switch: flip to "true" to route all AI traffic to the cheap model. */
export const AI_COST_PANIC = defineString('AI_COST_PANIC', {default: 'false'});

/**
 * Token ceiling on a coach turn — NOT the reply-length law. The ~80-word law
 * (docs/04) lives in the prompt; this cap exists so a runaway turn has a
 * hard stop. It must hold thoughts + text: the premium model cannot stop
 * thinking (see `ai/gemini.ts`) and spends its thought tokens inside this
 * budget — at docs/04 §3's original 500, every premium reply arrived cut off
 * mid-word, which the first automated eval run caught. docs/10 §11.10 records the
 * change.
 */
export const MAX_OUTPUT_TOKENS = 2000;

/** Conversation turns kept in context (docs/04 §3). Never the full history. */
export const COACH_CONTEXT_TURNS = 10;

/**
 * Rolling-summary cadence: `users/{uid}.coachSummary` is rebuilt every N
 * successful exchanges. 4 keeps every message inside a rebuild window — four
 * exchanges are 8 message docs and the verbatim window above holds 10, so no
 * turn can scroll out of context before a summary has folded it in.
 */
export const COACH_SUMMARY_EVERY = 4;

/**
 * Hard cap on the stored rolling summary (~250 tokens at four chars each).
 * The summarizer prompt asks for 120 words; this is the code guarantee
 * standing behind that request.
 */
export const COACH_SUMMARY_MAX_CHARS = 1200;
