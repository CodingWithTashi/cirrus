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

/**
 * The documented value of every daily allowance, in one place.
 *
 * Declared as constants rather than inline literals because each one is needed
 * TWICE: once as the param's `default`, and once as the floor `allowance()`
 * falls back to. Two literals would drift, and the drift would be silent.
 */
export const ALLOWANCE_DEFAULTS = {
  freeCoachMessages: 5,
  premiumCoachMessages: 100,
  freePosts: 1,
  premiumPosts: 3,
  sosPosts: 3,
} as const;

/**
 * Reads a daily allowance, refusing to believe an unusable answer.
 *
 * A deploy-time param resolves to **0** when nothing supplies a value — no
 * `.env` for the active project, a typo'd key, a test process that never
 * loaded one. Zero is not a small allowance, it is a total outage that looks
 * like a policy: a coach limit of 0 answers every single user `capReached`
 * before the model is ever called, and a post limit of 0 refuses every post
 * in the app. That exact failure has already shipped here once.
 *
 * No allowance is ever legitimately 0 or negative — that would mean "nobody
 * may ever use this" — so anything outside the usable range degrades to the
 * documented default instead of taking the feature down. Params that CAN be
 * zero (`COACH_MIN_INSTANCES`) deliberately do not go through this.
 */
export function allowance(
  param: {value(): number},
  fallback: number,
): number {
  const value = param.value();
  return Number.isFinite(value) && value > 0 ? Math.floor(value) : fallback;
}

/** docs/04 §7 — free tier gets 5 coach messages/day, premium 100 (fair use). */
export const FREE_DAILY_COACH_MESSAGES = defineInt('FREE_DAILY_COACH_MESSAGES', {
  default: ALLOWANCE_DEFAULTS.freeCoachMessages,
});
export const PREMIUM_DAILY_COACH_MESSAGES = defineInt(
  'PREMIUM_DAILY_COACH_MESSAGES',
  {default: ALLOWANCE_DEFAULTS.premiumCoachMessages},
);

/**
 * Community posting (docs/12 §4.1). Posting used to be refused outright for a
 * free account, which made the feature we call our moat read-only for exactly
 * the people whose posts a subscriber is paying to read. It is an allowance
 * now, not a wall.
 *
 * An SOS has its OWN allowance and never touches these. Two reasons, and both
 * matter: nobody may be refused a call for help because they used their
 * ordinary posts earlier, and an SOS pins to the top of the feed for an hour,
 * so an unbounded one would be a pinning megaphone for whoever wanted it.
 * Generous enough that no real crisis meets it; bounded enough that abuse does.
 */
export const FREE_DAILY_POSTS = defineInt('FREE_DAILY_POSTS', {
  default: ALLOWANCE_DEFAULTS.freePosts,
});
export const PREMIUM_DAILY_POSTS = defineInt('PREMIUM_DAILY_POSTS', {
  default: ALLOWANCE_DEFAULTS.premiumPosts,
});
export const DAILY_SOS_POSTS = defineInt('DAILY_SOS_POSTS', {
  default: ALLOWANCE_DEFAULTS.sosPosts,
});

/**
 * Every allowance read, each bound to its OWN default.
 *
 * `allowance(param, fallback)` takes the two separately, so nothing stops a
 * call site pairing one allowance's param with another's default — the exact
 * drift `ALLOWANCE_DEFAULTS` exists to prevent, reintroduced at the point of
 * USE. Reading through here makes the pairing structural: there is one
 * expression per allowance and no way to write a mismatched one.
 *
 * The params stay exported so tests can still `vi.spyOn(P, 'value')`.
 */
export const readAllowance = {
  freeCoachMessages: (): number =>
    allowance(FREE_DAILY_COACH_MESSAGES, ALLOWANCE_DEFAULTS.freeCoachMessages),
  premiumCoachMessages: (): number =>
    allowance(
      PREMIUM_DAILY_COACH_MESSAGES,
      ALLOWANCE_DEFAULTS.premiumCoachMessages,
    ),
  freePosts: (): number =>
    allowance(FREE_DAILY_POSTS, ALLOWANCE_DEFAULTS.freePosts),
  premiumPosts: (): number =>
    allowance(PREMIUM_DAILY_POSTS, ALLOWANCE_DEFAULTS.premiumPosts),
  sosPosts: (): number =>
    allowance(DAILY_SOS_POSTS, ALLOWANCE_DEFAULTS.sosPosts),
} as const;

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
 * Where the trusted tier comes from.
 *
 *   'mirror'  — the real behaviour, and the default since Sep 3 2026: tier
 *               comes from `users/{uid}.entitlement`, written by `rcWebhook`
 *               and by the app's post-purchase `refreshEntitlement`.
 *   'ungated' — everyone is premium. What ran from Aug 29 to Sep 3 2026,
 *               while RevenueCat was being wired and nothing could be bought.
 *
 * **The default is `mirror` deliberately, and it is the one param here whose
 * default is a security decision rather than a convenience.** Every other
 * param in this file fails toward "do less" when nothing supplies a value;
 * this one used to default to `ungated`, which fails toward *giving the
 * product away* — an unloaded `.env`, a new project, a misconfigured deploy,
 * and every caller is silently premium with no error anywhere. `allowance()`
 * below exists because of the mirror-image trap (a param resolving to 0 is a
 * total outage wearing the costume of a policy); this is the same lesson
 * pointing the other way.
 *
 * The gating code stays live and tested in both modes on purpose. Deleting it
 * and re-adding it later is how paywalls ship broken; flipping one param is
 * not — which is what makes `ungated` worth keeping as an escape hatch if the
 * mirror is ever wrong in the direction that costs customers.
 */
export const ENTITLEMENT_MODE = defineString('ENTITLEMENT_MODE', {
  default: 'mirror',
  description: "'mirror' (real entitlements) or 'ungated' (everyone premium).",
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

/**
 * Whether a coach turn also suggests what the user might tap to say next.
 *
 * A kill switch, not a feature flag: the suggestions are one extra cheap-model
 * call per turn (~5% on the ~$0.001 premium turn, docs/11 §4) and they ride
 * the same `Promise.all` as memory extraction, so if that call ever starts
 * failing or costing more than it is worth, this turns it off without a
 * deploy. Off simply means the app falls back to its four static chips, which
 * is what it showed for the first year.
 *
 * Read as `!== 'false'` at the call site, never `=== 'true'`: an unset param
 * resolves to the EMPTY STRING, and a switch that reads that as "off" turns
 * the feature off for every project whose `.env` never mentioned it, while
 * looking exactly like a policy decision. Same trap `allowance()` above
 * exists for, pointed the same way — the unresolved case must fail toward the
 * intended default.
 */
export const COACH_FOLLOWUPS = defineString('COACH_FOLLOWUPS', {
  default: 'true',
  description: "Set 'false' to stop suggesting follow-ups on coach turns.",
});

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
