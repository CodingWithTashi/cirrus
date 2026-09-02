/**
 * The one file that speaks RevenueCat's REST API (v2). Two jobs: the customer
 * snapshot the webhook mirrors from, and the customer delete that
 * `deleteUserData` runs. Everything else about RevenueCat — the catalogue, the
 * entitlement id — lives in `domain/plans.ts`; the webhook itself only decides
 * WHICH customers to look at, never what they own.
 *
 * Why a fetch at all, when the webhook payload already says what happened:
 * the payload describes one event, and events arrive late, twice and out of
 * order (RevenueCat's own docs say to re-fetch after each one). The snapshot
 * is the current truth, so writing it is idempotent by construction — there
 * is no ordering to get wrong, CANCELLATION-then-RENEWAL races cannot revoke
 * a paying user, and TRANSFER needs no special casing beyond "look at both
 * sides".
 *
 * Why v2 and not the older `GET /v1/subscribers`: the dashboard's "New secret
 * API key" mints a **v2** key, and v1 refuses it with 403 `7243 "Secret API
 * keys should not be used in your app"` — which is exactly how the first
 * device purchase found this file (the mirror stayed empty while the app
 * showed Premium). The key needs `customer_information:*:read` for the
 * snapshot, `project_configuration:{products,entitlements}:read` to resolve
 * ids, and `customer_information:customers:read_and_write` for the delete.
 *
 * v2 speaks in RevenueCat's own ids: a subscription names `prod…`, an active
 * entitlement names `entl…`. Both are resolved to the identifiers this code
 * reasons about — the store product id (`cirrus_premium:yearly-399`) and the
 * entitlement lookup key (`cirrus_pro`) — and cached per instance, because a
 * project has a handful of products and they never change under a request.
 *
 * Whose word is access: RevenueCat's. A subscription counts when it says
 * `gives_access` (that folds in grace periods and pending renewals), and the
 * access horizon written to the mirror is the ACTIVE ENTITLEMENT's
 * `expires_at` — RevenueCat's own answer to "until when", which already
 * extends through a grace period and already moved when a renewal was
 * processed early. Re-deriving either from the subscription's period dates
 * revoked paying users twice over: a grace period is by definition past its
 * period end, and Apple renews up to a day before expiry.
 */
import {RC_PROJECT_ID, REVENUECAT_SECRET_API_KEY} from '../config';
import {ENTITLEMENT_ID, periodOf, type PlanPeriod} from '../domain/plans';
import type {SubscriptionTier} from '../domain/types';
import {log} from './logger';

const BASE_URL = 'https://api.revenuecat.com';
const REQUEST_TIMEOUT_MS = 10_000;
/** Pages followed per list. A customer with more rows than this is a tester. */
const MAX_PAGES = 5;

/** What `users/{uid}.entitlement` mirrors — see `firestore.ts` `Entitlement`. */
export interface SubscriberSnapshot {
  readonly tier: SubscriptionTier;
  readonly productId: string | null;
  readonly plan: PlanPeriod | null;
  /** Null when there is nothing active, and for grants with no end. */
  readonly expiresAtMs: number | null;
  readonly willRenew: boolean;
  readonly store: string | null;
  readonly environment: 'SANDBOX' | 'PRODUCTION' | null;
  readonly managementUrl: string | null;
}

/**
 * Everything `snapshotOf` needs, already fetched: the customer's subscriptions
 * and active entitlements as v2 returns them, plus the two id resolutions.
 */
export interface CustomerRecord {
  readonly subscriptions: readonly Record<string, unknown>[];
  readonly activeEntitlements: readonly Record<string, unknown>[];
  /** RevenueCat product id (`prod…`) → store identifier. */
  readonly products: ReadonlyMap<string, string>;
  /** RevenueCat's own id (`entl…`) for `ENTITLEMENT_ID`; null when unresolved. */
  readonly entitlementInternalId: string | null;
}

export interface SnapshotOptions {
  /** False drops sandbox subscriptions from the picture (`RC_ACCEPT_SANDBOX`). */
  readonly acceptSandbox?: boolean;
}

/**
 * RevenueCat could not be read: a non-2xx (its status), a network failure or
 * a timeout (status 0), or a project id this deployment does not have (status
 * 0, `reason`). The webhook turns every one into a 500 so the event is
 * retried rather than lost — and never into a "free" row.
 */
export class RevenueCatUnavailable extends Error {
  constructor(
    readonly status: number,
    readonly reason: string = `RevenueCat answered ${status}`,
  ) {
    super(reason);
  }
}

type Fetch = typeof fetch;

function headers(): Record<string, string> {
  return {
    Authorization: `Bearer ${REVENUECAT_SECRET_API_KEY.value()}`,
    'Content-Type': 'application/json',
  };
}

/**
 * The project every v2 URL is scoped to. An unset param is a deployment
 * fault, and one that would otherwise 404 every customer into "free": a
 * `defineString` default is a deploy-time hint, and `.value()` is empty when
 * no .env supplied it.
 */
function projectUrl(): string {
  const project = RC_PROJECT_ID.value();
  if (!project) {
    throw new RevenueCatUnavailable(0, 'RC_PROJECT_ID is not set');
  }
  return `${BASE_URL}/v2/projects/${encodeURIComponent(project)}`;
}

/** One authenticated GET; a JSON body on 2xx, throws otherwise (404 too). */
async function getJson(
  url: string,
  fetchImpl: Fetch,
): Promise<Record<string, unknown>> {
  let res: Response;
  try {
    res = await fetchImpl(url, {
      headers: headers(),
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
  } catch (error) {
    throw new RevenueCatUnavailable(0, `fetch failed: ${describe(error)}`);
  }
  if (!res.ok) throw new RevenueCatUnavailable(res.status);
  try {
    return record(await res.json());
  } catch (error) {
    throw new RevenueCatUnavailable(0, `bad body: ${describe(error)}`);
  }
}

/** Every item across the pages of a v2 list, bounded by [MAX_PAGES]. */
async function listAll(
  url: string,
  fetchImpl: Fetch,
): Promise<Record<string, unknown>[]> {
  const out: Record<string, unknown>[] = [];
  let next: string | null = url;
  for (let page = 0; next !== null && page < MAX_PAGES; page++) {
    const body: Record<string, unknown> = await getJson(next, fetchImpl);
    const list = body['items'];
    if (Array.isArray(list)) out.push(...list.map(record));
    const more = str(body['next_page']);
    next = more === null ? null : more.startsWith('http') ? more : `${BASE_URL}${more}`;
  }
  if (next !== null) log.warn('revenuecat.list_truncated', {url, pages: MAX_PAGES});
  return out;
}

// Per-instance caches. Products and entitlements are project configuration:
// a handful of rows that change only when someone edits the dashboard, and a
// warm instance answering stale for its lifetime is the accepted cost. Only
// misses are fetched, and a `prod…` → store identifier mapping is immutable.
const productStoreIds = new Map<string, string>();
let entitlementInternalId: string | null = null;

/** Visible so tests can start from a cold instance. */
export function resetRevenueCatCaches(): void {
  productStoreIds.clear();
  entitlementInternalId = null;
}

/**
 * The customer's current standing, resolved and ready for [snapshotOf].
 *
 * A 404 is NOT "free": every event names a customer RevenueCat has, so a
 * missing one is a wrong project id or a wrong key, and the only safe answer
 * is a retry (the webhook's 500). Silently mirroring "free" here is how a
 * misdeployment would revoke every paying user who renews.
 */
export async function fetchSubscriber(
  appUserId: string,
  options: SnapshotOptions = {},
  fetchImpl: Fetch = fetch,
): Promise<SubscriberSnapshot> {
  const customer = `${projectUrl()}/customers/${encodeURIComponent(appUserId)}`;
  let subscriptions: Record<string, unknown>[];
  try {
    subscriptions = await listAll(`${customer}/subscriptions?limit=50`, fetchImpl);
  } catch (error) {
    if (error instanceof RevenueCatUnavailable && error.status === 404) {
      log.error('revenuecat.customer_not_found', {uid: appUserId});
    }
    throw error;
  }
  const activeEntitlements = await listAll(
    `${customer}/active_entitlements?limit=50`,
    fetchImpl,
  );

  for (const subscription of subscriptions) {
    const productId = str(subscription['product_id']);
    if (productId === null || productStoreIds.has(productId)) continue;
    const product = await getJson(
      `${projectUrl()}/products/${encodeURIComponent(productId)}`,
      fetchImpl,
    );
    const storeId = str(product['store_identifier']);
    if (storeId !== null) productStoreIds.set(productId, storeId);
  }

  if (entitlementInternalId === null && activeEntitlements.length > 0) {
    for (const entitlement of await listAll(
      `${projectUrl()}/entitlements?limit=100`,
      fetchImpl,
    )) {
      if (entitlement['lookup_key'] === ENTITLEMENT_ID) {
        entitlementInternalId = str(entitlement['id']);
      }
    }
    if (entitlementInternalId === null) {
      // Dashboard drift: no entitlement carries our lookup key. The snapshot
      // fails closed for grants (see `snapshotOf`); say so where it is seen.
      log.error('revenuecat.entitlement_unresolved', {lookupKey: ENTITLEMENT_ID});
    }
  }

  return snapshotOf(
    {
      subscriptions,
      activeEntitlements,
      products: productStoreIds,
      entitlementInternalId,
    },
    Date.now(),
    options,
  );
}

/**
 * `DELETE /customers/{id}` — erases the RevenueCat customer and its history.
 * 404 is success (already gone, or never seen). An unset key, an unset
 * project id, or a key without the write permission (401/403) skip with an
 * error log rather than blocking erasure: a misconfigured dashboard must never
 * trap someone in an account they asked to delete. A network failure or a
 * 5xx still throws — that is retryable, and the caller leaves everything in
 * place to retry. The store subscription itself is untouched either way, and
 * only the store can end it.
 */
export async function deleteSubscriber(
  appUserId: string,
  fetchImpl: Fetch = fetch,
): Promise<void> {
  if (!REVENUECAT_SECRET_API_KEY.value()) {
    log.warn('revenuecat.delete_skipped_no_key', {uid: appUserId});
    return;
  }
  let url: string;
  try {
    url = `${projectUrl()}/customers/${encodeURIComponent(appUserId)}`;
  } catch (error) {
    log.error('revenuecat.delete_skipped_misconfigured', {
      uid: appUserId,
      reason: describe(error),
    });
    return;
  }
  let res: Response;
  try {
    res = await fetchImpl(url, {
      method: 'DELETE',
      headers: headers(),
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
  } catch (error) {
    throw new RevenueCatUnavailable(0, `fetch failed: ${describe(error)}`);
  }
  if (res.ok) return;
  if (res.status === 404) {
    // Fine for one account; a 100% rate would mean the ids never matched.
    log.info('revenuecat.delete_not_found', {uid: appUserId});
    return;
  }
  if (res.status === 401 || res.status === 403) {
    log.error('revenuecat.delete_forbidden', {uid: appUserId, status: res.status});
    return;
  }
  throw new RevenueCatUnavailable(res.status);
}

/**
 * Pure: the mirror row from a fetched [CustomerRecord]. Fails closed on every
 * ambiguity — nothing that gives access, an entitlement that cannot be told
 * apart from another, a shape this code does not recognise — because failing
 * open costs the paywall.
 *
 * A subscription counts when RevenueCat itself says it `gives_access` AND it
 * carries our entitlement (inline `lookup_key`). With several, the one that
 * lasts longest wins — a yearly bought over a lapsing monthly is the yearly.
 * The expiry written is the matching active entitlement's `expires_at` when
 * RevenueCat lists one (its access horizon: through grace, past an early
 * renewal); only without one does the subscription's own latest end stand
 * in, and then a past end fails closed. With no subscription at all, an
 * active entitlement on its own is a promotional grant (the beta cohort's
 * lifetime Premium is exactly this), premium with no store row behind it —
 * recognised only when our entitlement's id is resolved, so a stray grant
 * for some other entitlement never unlocks this one.
 */
export function snapshotOf(
  customer: CustomerRecord,
  nowMs: number = Date.now(),
  options: SnapshotOptions = {},
): SubscriberSnapshot {
  const acceptSandbox = options.acceptSandbox ?? true;
  const grant = ourActiveEntitlement(customer);
  // A grant RevenueCat lists as active but dates in the past cannot be read
  // either way; fail closed.
  if (grant !== null && grant.expiresAtMs !== null && grant.expiresAtMs <= nowMs) {
    return FREE;
  }

  let best: Record<string, unknown> | null = null;
  let bestEnd = -Infinity;
  for (const subscription of customer.subscriptions) {
    if (subscription['gives_access'] !== true) continue;
    if (!grantsOurEntitlement(subscription)) continue;
    if (!acceptSandbox && subscription['environment'] === 'sandbox') continue;
    const end = latestEndOf(subscription);
    // Without RevenueCat's own horizon to lean on, a period already over is
    // not access, whatever the flag says.
    if (grant === null && end !== null && end <= nowMs) continue;
    const rank = end ?? Infinity;
    if (rank > bestEnd) {
      best = subscription;
      bestEnd = rank;
    }
  }

  if (best !== null) {
    const rcProductId = str(best['product_id']);
    const productId =
      rcProductId === null ? null : (customer.products.get(rcProductId) ?? null);
    const renewal = str(best['auto_renewal_status']);
    const environment = str(best['environment']);
    return {
      tier: best['status'] === 'trialing' ? 'trial' : 'premium',
      productId,
      plan: productId === null ? null : periodOf(productId),
      expiresAtMs: horizonOf(grant, best),
      willRenew:
        renewal === 'will_renew' ||
        renewal === 'will_change_product' ||
        renewal === 'has_already_renewed',
      store: str(best['store']),
      environment:
        environment === 'sandbox'
          ? 'SANDBOX'
          : environment === 'production'
            ? 'PRODUCTION'
            : null,
      managementUrl: str(best['management_url']),
    };
  }

  if (grant !== null) {
    return {
      tier: 'premium',
      productId: null,
      plan: null,
      expiresAtMs: grant.expiresAtMs,
      willRenew: false,
      store: 'promotional',
      environment: null,
      managementUrl: null,
    };
  }

  return FREE;
}

const FREE: SubscriberSnapshot = {
  tier: 'free',
  productId: null,
  plan: null,
  expiresAtMs: null,
  willRenew: false,
  store: null,
  environment: null,
  managementUrl: null,
};

/**
 * Until when the winning subscription gives access: the later of RevenueCat's
 * own entitlement horizon (through grace, past an early renewal) and the
 * subscription's own latest period end. Both are RevenueCat's numbers; taking
 * the later one means a lagging entitlement row never expires a subscriber
 * whose subscription plainly runs on. A grant with no end stays without end.
 */
function horizonOf(
  grant: {expiresAtMs: number | null} | null,
  subscription: Record<string, unknown>,
): number | null {
  const own = latestEndOf(subscription);
  if (grant === null) return own;
  if (grant.expiresAtMs === null) return null;
  return own === null ? grant.expiresAtMs : Math.max(grant.expiresAtMs, own);
}

/**
 * The customer's active entitlement that is ours — matched by RevenueCat's
 * internal id, so it needs that id resolved. `expires_at: null` is a grant
 * with no end.
 */
function ourActiveEntitlement(
  customer: CustomerRecord,
): {expiresAtMs: number | null} | null {
  const wanted = customer.entitlementInternalId;
  if (wanted === null) return null;
  for (const entitlement of customer.activeEntitlements) {
    if (str(entitlement['entitlement_id']) !== wanted) continue;
    const expires = entitlement['expires_at'];
    return {expiresAtMs: expires === null ? null : num(expires)};
  }
  return null;
}

/**
 * v2 lists a subscription's entitlements inline. Our entitlement must be on
 * the list; a subscription for some other entitlement (a future add-on) must
 * not unlock this one, and a row without the list cannot be told apart from
 * one — fail closed.
 */
function grantsOurEntitlement(subscription: Record<string, unknown>): boolean {
  const list = record(subscription['entitlements'])['items'];
  if (!Array.isArray(list)) return false;
  return list.some((e) => record(e)['lookup_key'] === ENTITLEMENT_ID);
}

/**
 * The later of the two period ends. `ends_at` moves ahead of
 * `current_period_ends_at` once a renewal has been processed early
 * (`has_already_renewed`), so the current period alone would expire a
 * subscriber who just paid for the next one.
 */
function latestEndOf(subscription: Record<string, unknown>): number | null {
  const current = num(subscription['current_period_ends_at']);
  const ends = num(subscription['ends_at']);
  if (current === null) return ends;
  if (ends === null) return current;
  return Math.max(current, ends);
}

function record(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function str(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0 ? value : null;
}

function num(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function describe(error: unknown): string {
  return error instanceof Error ? `${error.name}: ${error.message}` : String(error);
}
