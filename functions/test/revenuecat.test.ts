/**
 * `snapshotOf` — the pure half of the entitlement mirror: a fetched v2
 * customer record in, the row `users/{uid}.entitlement` gets out.
 *
 * Every case here is a shape RevenueCat actually sends (ms timestamps,
 * `gives_access`, `auto_renewal_status`, inline entitlement lookup keys) and
 * every ambiguity fails closed — because failing open costs the paywall.
 */
import {beforeEach, describe, expect, it} from 'vitest';
import {
  deleteSubscriber,
  fetchSubscriber,
  resetRevenueCatCaches,
  RevenueCatUnavailable,
  snapshotOf,
  type CustomerRecord,
} from '../src/lib/revenuecat';

// Params resolve from the environment; the client refuses to run without.
process.env['RC_PROJECT_ID'] = 'proj_test';
process.env['REVENUECAT_SECRET_API_KEY'] = 'sk_test_not_a_real_key';

const NOW = Date.UTC(2026, 8, 2, 12);
const IN_A_WEEK = NOW + 7 * 86_400_000;
const IN_A_YEAR = NOW + 365 * 86_400_000;
const YESTERDAY = NOW - 86_400_000;

const PRODUCTS = new Map([
  ['prod_monthly', 'cirrus_premium:monthly-799'],
  ['prod_yearly', 'cirrus_premium:yearly-399'],
  ['prod_test_yearly', 'yearly'],
]);

function subscription(over: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: 'sub1',
    product_id: 'prod_monthly',
    status: 'active',
    gives_access: true,
    auto_renewal_status: 'will_renew',
    current_period_starts_at: YESTERDAY,
    current_period_ends_at: IN_A_WEEK,
    ends_at: IN_A_WEEK,
    store: 'play_store',
    environment: 'production',
    management_url: 'https://play.google.com/store/account/subscriptions',
    entitlements: {items: [{id: 'entl1', lookup_key: 'cirrus_pro'}]},
    ...over,
  };
}

function customer(over: Partial<CustomerRecord> = {}): CustomerRecord {
  return {
    subscriptions: [subscription()],
    activeEntitlements: [{entitlement_id: 'entl1', expires_at: IN_A_WEEK}],
    products: PRODUCTS,
    entitlementInternalId: 'entl1',
    ...over,
  };
}

describe('snapshotOf', () => {
  it('an active paid subscription is premium, renewing, with its plan', () => {
    const s = snapshotOf(customer(), NOW);
    expect(s.tier).toBe('premium');
    expect(s.productId).toBe('cirrus_premium:monthly-799');
    expect(s.plan).toBe('monthly');
    expect(s.expiresAtMs).toBe(IN_A_WEEK);
    expect(s.willRenew).toBe(true);
    expect(s.store).toBe('play_store');
    expect(s.environment).toBe('PRODUCTION');
    expect(s.managementUrl).toContain('play.google.com');
  });

  it('a free trial is `trial`, and the yearly base plan as created maps', () => {
    const s = snapshotOf(
      customer({
        subscriptions: [subscription({status: 'trialing', product_id: 'prod_yearly'})],
      }),
      NOW,
    );
    expect(s.tier).toBe('trial');
    expect(s.plan).toBe('yearly');
  });

  it('cancelled keeps access until expiry but will not renew', () => {
    const s = snapshotOf(
      customer({subscriptions: [subscription({auto_renewal_status: 'will_not_renew'})]}),
      NOW,
    );
    expect(s.tier).toBe('premium');
    expect(s.willRenew).toBe(false);
    expect(s.expiresAtMs).toBe(IN_A_WEEK);
  });

  it('a grace period keeps access — past its period end, on the horizon '
     + 'RevenueCat still grants', () => {
    // By definition a grace period is PAST the period end; the access
    // horizon is the active entitlement's `expires_at`, not the period's.
    const s = snapshotOf(
      customer({
        subscriptions: [
          subscription({
            status: 'in_grace_period',
            current_period_ends_at: YESTERDAY,
            ends_at: YESTERDAY,
          }),
        ],
        activeEntitlements: [{entitlement_id: 'entl1', expires_at: IN_A_WEEK}],
      }),
      NOW,
    );
    expect(s.tier).toBe('premium');
    expect(s.expiresAtMs).toBe(IN_A_WEEK);
    expect(s.willRenew).toBe(true);
  });

  it('an early renewal moves the horizon to the NEW period, not the one still running', () => {
    // Apple renews up to a day early: `ends_at` is next year while
    // `current_period_ends_at` is tomorrow. Reading the current period alone
    // expired a subscriber who had just paid for the next year.
    const s = snapshotOf(
      customer({
        subscriptions: [
          subscription({
            auto_renewal_status: 'has_already_renewed',
            current_period_ends_at: NOW + 3_600_000,
            ends_at: IN_A_YEAR,
          }),
        ],
        activeEntitlements: [{entitlement_id: 'entl1', expires_at: IN_A_YEAR}],
      }),
      NOW,
    );
    expect(s.tier).toBe('premium');
    expect(s.expiresAtMs).toBe(IN_A_YEAR);
    expect(s.willRenew).toBe(true);
    // Even with no entitlement row to lean on, the LATER end is the horizon.
    const bare = snapshotOf(
      customer({
        subscriptions: [
          subscription({
            auto_renewal_status: 'has_already_renewed',
            current_period_ends_at: YESTERDAY,
            ends_at: IN_A_YEAR,
          }),
        ],
        activeEntitlements: [],
      }),
      NOW,
    );
    expect(bare.tier).toBe('premium');
    expect(bare.expiresAtMs).toBe(IN_A_YEAR);
  });

  it('sandbox rows are dropped when sandbox is not accepted', () => {
    const sandbox = customer({
      subscriptions: [subscription({environment: 'sandbox'})],
      activeEntitlements: [],
    });
    expect(snapshotOf(sandbox, NOW, {acceptSandbox: false}).tier).toBe('free');
    expect(snapshotOf(sandbox, NOW, {acceptSandbox: true}).tier).toBe('premium');
  });

  it('a subscription with no entitlement list cannot be told apart — fails closed', () => {
    const s = snapshotOf(
      customer({
        subscriptions: [subscription({entitlements: undefined})],
        activeEntitlements: [],
      }),
      NOW,
    );
    expect(s.tier).toBe('free');
  });

  it('a subscription that no longer gives access is free with nothing on the row', () => {
    const s = snapshotOf(
      customer({
        subscriptions: [
          subscription({status: 'expired', gives_access: false, ends_at: YESTERDAY}),
        ],
        activeEntitlements: [],
      }),
      NOW,
    );
    expect(s).toMatchObject({tier: 'free', productId: null, plan: null, expiresAtMs: null});
  });

  it('a period already over fails closed even if the flag lags', () => {
    const s = snapshotOf(
      customer({
        subscriptions: [subscription({current_period_ends_at: YESTERDAY, ends_at: YESTERDAY})],
        activeEntitlements: [],
      }),
      NOW,
    );
    expect(s.tier).toBe('free');
  });

  it('nothing at all is free', () => {
    const s = snapshotOf(customer({subscriptions: [], activeEntitlements: []}), NOW);
    expect(s.tier).toBe('free');
    expect(s.managementUrl).toBeNull();
  });

  it('a subscription for some other entitlement does not unlock this one', () => {
    const s = snapshotOf(
      customer({
        subscriptions: [
          subscription({entitlements: {items: [{id: 'entl9', lookup_key: 'addon'}]}}),
        ],
        activeEntitlements: [],
      }),
      NOW,
    );
    expect(s.tier).toBe('free');
  });

  it('the longest-lasting access wins when several give it', () => {
    const s = snapshotOf(
      customer({
        activeEntitlements: [{entitlement_id: 'entl1', expires_at: IN_A_YEAR}],
        subscriptions: [
          subscription({auto_renewal_status: 'will_not_renew'}),
          subscription({
            id: 'sub2',
            product_id: 'prod_yearly',
            current_period_ends_at: IN_A_YEAR,
            ends_at: IN_A_YEAR,
          }),
        ],
      }),
      NOW,
    );
    expect(s.plan).toBe('yearly');
    expect(s.expiresAtMs).toBe(IN_A_YEAR);
    expect(s.willRenew).toBe(true);
  });

  it('a grant is not recognised while our entitlement id is unresolved', () => {
    // Dashboard drift: no entitlement carries our lookup key. Any active
    // entitlement used to unlock Premium; now nothing does until it resolves.
    const s = snapshotOf(
      customer({
        subscriptions: [],
        activeEntitlements: [{entitlement_id: 'entl1', expires_at: null}],
        entitlementInternalId: null,
      }),
      NOW,
    );
    expect(s.tier).toBe('free');
  });

  it('a lagging entitlement row never shortens a subscription that runs on', () => {
    const s = snapshotOf(
      customer({
        activeEntitlements: [{entitlement_id: 'entl1', expires_at: IN_A_WEEK}],
        subscriptions: [subscription({product_id: 'prod_yearly', ends_at: IN_A_YEAR})],
      }),
      NOW,
    );
    expect(s.expiresAtMs).toBe(IN_A_YEAR);
  });

  it('a promotional grant with no store row is premium, uncatalogued', () => {
    const s = snapshotOf(
      customer({
        subscriptions: [],
        activeEntitlements: [{entitlement_id: 'entl1', expires_at: null}],
      }),
      NOW,
    );
    expect(s.tier).toBe('premium');
    expect(s.productId).toBeNull();
    expect(s.plan).toBeNull();
    expect(s.expiresAtMs).toBeNull();
    expect(s.store).toBe('promotional');
    expect(s.willRenew).toBe(false);
  });

  it('an expired grant, or one for another entitlement, is free', () => {
    expect(
      snapshotOf(
        customer({
          subscriptions: [],
          activeEntitlements: [{entitlement_id: 'entl1', expires_at: YESTERDAY}],
        }),
        NOW,
      ).tier,
    ).toBe('free');
    expect(
      snapshotOf(
        customer({
          subscriptions: [],
          activeEntitlements: [{entitlement_id: 'entl9', expires_at: null}],
        }),
        NOW,
      ).tier,
    ).toBe('free');
  });

  it('a Test Store purchase mirrors as sandbox with its own product id', () => {
    const s = snapshotOf(
      customer({
        subscriptions: [
          subscription({
            product_id: 'prod_test_yearly',
            store: 'test_store',
            environment: 'sandbox',
            management_url: null,
          }),
        ],
      }),
      NOW,
    );
    expect(s.tier).toBe('premium');
    expect(s.productId).toBe('yearly');
    expect(s.plan).toBe('yearly');
    expect(s.store).toBe('test_store');
    expect(s.environment).toBe('SANDBOX');
    expect(s.managementUrl).toBeNull();
  });

  it('an unresolved product id still grants — the plan is simply unknown', () => {
    const s = snapshotOf(
      customer({subscriptions: [subscription({product_id: 'prod_new'})]}),
      NOW,
    );
    expect(s.tier).toBe('premium');
    expect(s.productId).toBeNull();
    expect(s.plan).toBeNull();
  });

  it('garbage shapes fail closed rather than throwing', () => {
    const empty: CustomerRecord = {
      subscriptions: [],
      activeEntitlements: [],
      products: new Map(),
      entitlementInternalId: null,
    };
    expect(snapshotOf(empty, NOW).tier).toBe('free');
    expect(
      snapshotOf(
        {
          ...empty,
          subscriptions: [{gives_access: 'yes', ends_at: 'soon'}, {}],
          activeEntitlements: [{expires_at: 'never'}],
        },
        NOW,
      ).tier,
    ).toBe('free');
  });
});

// --- the REST client, against a scripted fetch -------------------------------

type Route = (url: URL) => Response | Promise<Response>;
type ScriptedFetch = typeof fetch & {readonly calls: string[]};

function scripted(routes: Record<string, Route>): ScriptedFetch {
  const calls: string[] = [];
  const impl = async (input: string | URL | Request): Promise<Response> => {
    const url = new URL(String(input instanceof Request ? input.url : input));
    calls.push(url.pathname);
    for (const [prefix, route] of Object.entries(routes)) {
      if (url.pathname.startsWith(prefix)) return route(url);
    }
    return new Response('nope', {status: 404});
  };
  return Object.assign(impl, {calls});
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {'Content-Type': 'application/json'},
  });

const BASE = '/v2/projects/proj_test';

describe('fetchSubscriber', () => {
  beforeEach(resetRevenueCatCaches);

  it('resolves product and entitlement ids, and caches both', async () => {
    const fetchImpl = scripted({
      [`${BASE}/customers/alice/subscriptions`]: () =>
        json({items: [subscription({product_id: 'prod_monthly'})], next_page: null}),
      [`${BASE}/customers/alice/active_entitlements`]: () =>
        json({items: [{entitlement_id: 'entl1', expires_at: IN_A_WEEK}], next_page: null}),
      [`${BASE}/products/prod_monthly`]: () =>
        json({id: 'prod_monthly', store_identifier: 'cirrus_premium:monthly-799'}),
      [`${BASE}/entitlements`]: () =>
        json({items: [{id: 'entl1', lookup_key: 'cirrus_pro'}], next_page: null}),
    });
    const first = await fetchSubscriber('alice', {}, fetchImpl);
    expect(first.tier).toBe('premium');
    expect(first.plan).toBe('monthly');
    expect(first.expiresAtMs).toBe(IN_A_WEEK);

    await fetchSubscriber('alice', {}, fetchImpl);
    expect(fetchImpl.calls.filter((c) => c.includes('/products/'))).toHaveLength(1);
    expect(fetchImpl.calls.filter((c) => c.endsWith('/entitlements'))).toHaveLength(1);
  });

  it('follows next_page', async () => {
    const fetchImpl = scripted({
      [`${BASE}/customers/alice/subscriptions`]: (url) =>
        url.searchParams.get('starting_after') === 'sub1'
          ? json({
              items: [subscription({id: 'sub2', product_id: 'prod_yearly', ends_at: IN_A_YEAR})],
              next_page: null,
            })
          : json({
              items: [subscription()],
              next_page: `${BASE}/customers/alice/subscriptions?starting_after=sub1`,
            }),
      [`${BASE}/customers/alice/active_entitlements`]: () => json({items: [], next_page: null}),
      [`${BASE}/products/prod_monthly`]: () =>
        json({store_identifier: 'cirrus_premium:monthly-799'}),
      [`${BASE}/products/prod_yearly`]: () =>
        json({store_identifier: 'cirrus_premium:yearly-399'}),
    });
    const s = await fetchSubscriber('alice', {}, fetchImpl);
    expect(s.plan).toBe('yearly');
  });

  it('a customer RevenueCat does not know is a retry, never "free"', async () => {
    const fetchImpl = scripted({});
    await expect(fetchSubscriber('ghost', {}, fetchImpl)).rejects.toMatchObject({
      status: 404,
    });
  });

  it('a network failure is unavailable (status 0), never a crash or a revoke', async () => {
    const fetchImpl = (() => Promise.reject(new TypeError('fetch failed'))) as unknown as typeof fetch;
    const error = await fetchSubscriber('alice', {}, fetchImpl).catch((e: unknown) => e);
    expect(error).toBeInstanceOf(RevenueCatUnavailable);
    expect((error as RevenueCatUnavailable).status).toBe(0);
  });

  it('an unset project id is a deployment fault, not a free customer', async () => {
    const previous = process.env['RC_PROJECT_ID'];
    process.env['RC_PROJECT_ID'] = '';
    try {
      await expect(fetchSubscriber('alice', {}, scripted({}))).rejects.toMatchObject({
        status: 0,
        reason: 'RC_PROJECT_ID is not set',
      });
    } finally {
      process.env['RC_PROJECT_ID'] = previous;
    }
  });
});

describe('deleteSubscriber', () => {
  const answering = (status: number) =>
    (() => Promise.resolve(new Response('', {status}))) as unknown as typeof fetch;

  it('200 and 404 are done', async () => {
    await expect(deleteSubscriber('alice', answering(200))).resolves.toBeUndefined();
    await expect(deleteSubscriber('alice', answering(404))).resolves.toBeUndefined();
  });

  it('a key without the write permission is logged, and erasure proceeds', async () => {
    await expect(deleteSubscriber('alice', answering(403))).resolves.toBeUndefined();
    await expect(deleteSubscriber('alice', answering(401))).resolves.toBeUndefined();
  });

  it('an outage throws, so the caller leaves everything in place to retry', async () => {
    await expect(deleteSubscriber('alice', answering(503))).rejects.toBeInstanceOf(
      RevenueCatUnavailable,
    );
    const failing = (() => Promise.reject(new TypeError('fetch failed'))) as unknown as typeof fetch;
    await expect(deleteSubscriber('alice', failing)).rejects.toBeInstanceOf(RevenueCatUnavailable);
  });
});
