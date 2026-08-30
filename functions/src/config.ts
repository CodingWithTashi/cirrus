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

// --- Tunables --------------------------------------------------------------

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
  default: 'gemini-3.7-flash',
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

/** Hard ceiling on a coach reply. docs/04's length law is ~80 words. */
export const MAX_OUTPUT_TOKENS = 500;

/** Conversation turns kept in context (docs/04 §3). Never the full history. */
export const COACH_CONTEXT_TURNS = 10;
