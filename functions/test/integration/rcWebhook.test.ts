/**
 * `rcWebhook` — the only writer of `users/{uid}.entitlement`.
 *
 * It is an unauthenticated public endpoint whose only security boundary is a
 * bearer token, and the field it writes is the single thing the coach trusts
 * when deciding whether someone gets a paid model call. A bug here is either
 * free Premium for anyone who can guess a URL, or a paying customer being
 * told no.
 *
 * The handler treats the event as a trigger and mirrors RevenueCat's current
 * customer snapshot, so the cases below script the SNAPSHOT (a stubbed v2
 * customer API) as much as the event — the event type must never
 * decide access on its own.
 *
 * Invoked directly with hand-built req/res doubles — an `onRequest` function
 * IS the express handler, unlike a callable — so these test the handler's
 * logic and skip the transport, the same way the other handler suites do.
 */
import {EventEmitter} from 'node:events';
import {getAuth} from 'firebase-admin/auth';
import {afterEach, beforeEach, describe, expect, it, vi} from 'vitest';
import {rcWebhook} from '../../src/handlers/rcWebhook';
import {resetRevenueCatCaches} from '../../src/lib/revenuecat';
import {
  RC_ACCEPT_SANDBOX,
  REVENUECAT_SECRET_API_KEY,
  REVENUECAT_WEBHOOK_TOKEN,
} from '../../src/config';
import {userDoc} from '../../src/lib/firestore';

const PROJECT = process.env['GCLOUD_PROJECT'] ?? 'demo-cirrus';
const HOST = process.env['FIRESTORE_EMULATOR_HOST'] ?? '127.0.0.1:8080';
const TOKEN = 'test-webhook-secret';

// Captured before any test stubs `fetch`: the emulator wipe needs the real one.
const realFetch = globalThis.fetch;

async function clearFirestore(): Promise<void> {
  const url =
    `http://${HOST}/emulator/v1/projects/${PROJECT}` +
    `/databases/(default)/documents`;
  const res = await realFetch(url, {method: 'DELETE'});
  if (!res.ok) throw new Error(`emulator clear failed: ${res.status}`);
}

/** A real Auth user — the handler refuses to mirror for a uid that has none. */
async function makeUser(uid: string): Promise<void> {
  try {
    await getAuth().createUser({uid, email: `${uid}@cirrus.test`});
  } catch (error) {
    if ((error as {code?: string}).code !== 'auth/uid-already-exists') throw error;
  }
}

interface Sent {
  status: number;
  body: unknown;
}

/**
 * Express-shaped doubles.
 *
 * The response has to be a real EventEmitter: firebase-functions wraps an
 * `onRequest` handler and attaches a `finish` listener to time the
 * invocation, so a plain object throws `res.on is not a function` before the
 * handler ever runs.
 */
async function call(
  body: unknown,
  {
    method = 'POST',
    authorization = `Bearer ${TOKEN}`,
    // `null` means "send no header at all". It cannot be `undefined`: that
    // triggers the JS default parameter, which would quietly send a VALID
    // token and turn this suite's most important case green for free.
  }: {method?: string; authorization?: string | null} = {},
): Promise<Sent> {
  const sent: Sent = {status: 0, body: undefined};
  const res = Object.assign(new EventEmitter(), {
    headersSent: false,
    status(code: number) {
      sent.status = code;
      return res;
    },
    send(payload: unknown) {
      sent.body = payload;
      res.headersSent = true;
      res.emit('finish');
      return res;
    },
    setHeader: () => res,
    getHeader: () => undefined,
    removeHeader: () => res,
    end: () => {
      res.emit('finish');
      return res;
    },
  });
  const req = {
    method,
    ip: '203.0.113.7',
    body,
    get: (name: string) =>
      name.toLowerCase() === 'authorization' && authorization !== null
        ? authorization
        : undefined,
  };
  // An `onRequest` function has no `.run()` hook — unlike a callable, it IS
  // the express handler, so it is invoked directly.
  await (
    rcWebhook as unknown as (r: unknown, s: unknown) => Promise<void>
  )(req, res);
  // The handler awaits its own Firestore write before responding, and the
  // express signature does not surface that promise; wait for the send.
  for (let i = 0; i < 300 && sent.status === 0; i++) {
    await new Promise((r) => setTimeout(r, 10));
  }
  return sent;
}

/** A RevenueCat webhook body. Only `type` and the ids matter to the handler. */
const event = (over: Record<string, unknown> = {}) => ({
  event: {
    id: 'evt-1',
    type: 'INITIAL_PURCHASE',
    app_user_id: 'alice',
    product_id: 'cirrus_premium:monthly-799',
    period_type: 'NORMAL',
    environment: 'PRODUCTION',
    event_timestamp_ms: Date.UTC(2026, 8, 2),
    ...over,
  },
});

// --- the scripted RevenueCat --------------------------------------------------

interface Scripted {
  tier: 'free' | 'premium' | 'trial';
  productId?: string;
  cancelled?: boolean;
  sandbox?: boolean;
  store?: string;
  /** Renewed early: the current period ends tomorrow, the next runs a year. */
  renewedEarly?: boolean;
  /** Past the period end, inside a billing-issue grace period. */
  grace?: boolean;
}

const IN_A_WEEK = new Date(Date.now() + 7 * 86_400_000).toISOString();
const IN_THREE_DAYS = new Date(Date.now() + 3 * 86_400_000).toISOString();
const IN_A_YEAR = new Date(Date.now() + 365 * 86_400_000).toISOString();
const YESTERDAY = new Date(Date.now() - 86_400_000).toISOString();

/** What the v2 customer endpoints answer per customer; absent = 503. */
const subscribers = new Map<string, Scripted>();
/** Customer ids whose subscriptions were read — one entry per snapshot. */
const fetchedIds: string[] = [];

/** RevenueCat's own product id for a store identifier, as v2 would name it. */
const rcProductId = (storeId: string) => `prod_${storeId.replace(/[^a-z0-9]/gi, '_')}`;

/** `GET /customers/{id}/subscriptions` — v2's shape, ms timestamps. */
function subscriptionsJson(s: Scripted): Record<string, unknown> {
  if (s.tier === 'free') return {items: [], next_page: null};
  const productId = s.productId ?? 'cirrus_premium:monthly-799';
  return {
    items: [
      {
        id: 'sub1',
        product_id: rcProductId(productId),
        status: s.grace ? 'in_grace_period' : s.tier === 'trial' ? 'trialing' : 'active',
        gives_access: true,
        auto_renewal_status: s.renewedEarly
          ? 'has_already_renewed'
          : s.cancelled
            ? 'will_not_renew'
            : 'will_renew',
        current_period_starts_at: Date.parse(YESTERDAY),
        current_period_ends_at: s.grace ? Date.parse(YESTERDAY) : Date.parse(IN_A_WEEK),
        ends_at: s.grace
          ? Date.parse(YESTERDAY)
          : s.renewedEarly
            ? Date.parse(IN_A_YEAR)
            : Date.parse(IN_A_WEEK),
        store: s.store ?? 'play_store',
        environment: s.sandbox === true ? 'sandbox' : 'production',
        management_url: 'https://play.google.com/store/account/subscriptions',
        entitlements: {items: [{id: 'entl1', lookup_key: 'cirrus_pro'}]},
      },
    ],
    next_page: null,
  };
}

const json = (body: unknown, status = 200) =>
  Promise.resolve(
    new Response(JSON.stringify(body), {
      status,
      headers: {'Content-Type': 'application/json'},
    }),
  );

function stubRevenueCat(): void {
  vi.stubGlobal(
    'fetch',
    vi.fn((input: string | URL | Request) => {
      const url = new URL(String(input instanceof Request ? input.url : input));
      const path = url.pathname;
      const prefix = '/v2/projects/proj2bbaaf3f/';
      if (url.host !== 'api.revenuecat.com' || !path.startsWith(prefix)) {
        throw new Error(`unexpected fetch ${url.href}`);
      }
      const rest = path.slice(prefix.length);
      const customer = /^customers\/([^/]+)\/(subscriptions|active_entitlements)$/.exec(rest);
      if (customer !== null) {
        const id = decodeURIComponent(customer[1] ?? '');
        const scripted = subscribers.get(id);
        if (customer[2] === 'subscriptions') fetchedIds.push(id);
        if (scripted === undefined) return json('down', 503);
        if (customer[2] === 'subscriptions') return json(subscriptionsJson(scripted));
        // The access horizon RevenueCat itself grants: through a grace
        // period, and already moved by an early renewal.
        const horizon = scripted.grace
          ? Date.parse(IN_THREE_DAYS)
          : scripted.renewedEarly
            ? Date.parse(IN_A_YEAR)
            : Date.parse(IN_A_WEEK);
        return json({
          items:
            scripted.tier === 'free'
              ? []
              : [{entitlement_id: 'entl1', expires_at: horizon}],
          next_page: null,
        });
      }
      const product = /^products\/(.+)$/.exec(rest);
      if (product !== null) {
        const id = decodeURIComponent(product[1] ?? '');
        // Invert `rcProductId` for the catalogue ids the tests use.
        for (const storeId of [
          'cirrus_premium:monthly-799',
          'cirrus_premium:yearly-399',
          'cirrus_premium:weekly-299',
        ]) {
          if (rcProductId(storeId) === id) return json({id, store_identifier: storeId});
        }
        return json({message: 'no such product'}, 404);
      }
      if (rest === 'entitlements') {
        return json({items: [{id: 'entl1', lookup_key: 'cirrus_pro'}], next_page: null});
      }
      throw new Error(`unexpected fetch ${url.href}`);
    }),
  );
}

beforeEach(async () => {
  await clearFirestore();
  resetRevenueCatCaches();
  await makeUser('alice');
  await makeUser('bob');
  subscribers.clear();
  fetchedIds.length = 0;
  stubRevenueCat();
  // Deploy-time params resolve to nothing under the emulator; pin them.
  vi.spyOn(REVENUECAT_WEBHOOK_TOKEN, 'value').mockReturnValue(TOKEN);
  vi.spyOn(REVENUECAT_SECRET_API_KEY, 'value').mockReturnValue('sk_test');
  vi.spyOn(RC_ACCEPT_SANDBOX, 'value').mockReturnValue('true');
});

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

type MirrorRow = Partial<
  Record<
    | 'tier'
    | 'productId'
    | 'plan'
    | 'expiresAt'
    | 'willRenew'
    | 'store'
    | 'environment'
    | 'managementUrl'
    | 'lastEventId'
    | 'lastEventType',
    unknown
  >
>;

const entitlementOf = async (uid: string) =>
  (await userDoc(uid).get()).get('entitlement') as MirrorRow | undefined;

describe('the security boundary', () => {
  it('refuses a request with no Authorization header', async () => {
    const res = await call(event(), {authorization: null});
    expect(res.status).toBe(401);
    expect((await userDoc('alice').get()).exists).toBe(false);
    expect(fetchedIds).toEqual([]);
  });

  it('refuses a wrong token', async () => {
    const res = await call(event(), {authorization: 'Bearer not-the-secret'});
    expect(res.status).toBe(401);
    expect((await userDoc('alice').get()).exists).toBe(false);
  });

  it('refuses a bare token without the Bearer scheme', async () => {
    const res = await call(event(), {authorization: TOKEN});
    expect(res.status).toBe(401);
  });

  it('refuses a token of the right length but wrong bytes', async () => {
    const res = await call(event(), {
      authorization: `Bearer ${TOKEN.replace(/./g, 'x')}`,
    });
    expect(res.status).toBe(401);
  });

  it('refuses anything that is not a POST', async () => {
    const res = await call(event(), {method: 'GET'});
    expect(res.status).toBe(405);
  });

  it('rejects before parsing, so a malformed body cannot reach the writer', async () => {
    const res = await call({nonsense: true}, {authorization: 'Bearer wrong'});
    expect(res.status).toBe(401);
  });
});

describe('mirroring the snapshot', () => {
  it('writes the whole entitlement row on a purchase', async () => {
    subscribers.set('alice', {tier: 'premium'});
    const res = await call(event());
    expect(res.status).toBe(200);

    const e = await entitlementOf('alice');
    expect(e?.tier).toBe('premium');
    expect(e?.productId).toBe('cirrus_premium:monthly-799');
    expect(e?.plan).toBe('monthly');
    expect(e?.expiresAt).not.toBeNull();
    expect(e?.willRenew).toBe(true);
    expect(e?.store).toBe('play_store');
    expect(e?.environment).toBe('PRODUCTION');
    expect(e?.managementUrl).toContain('play.google.com');
    expect(e?.lastEventId).toBe('evt-1');
    expect(e?.lastEventType).toBe('INITIAL_PURCHASE');
  });

  it('marks a trial as trial, not as premium', async () => {
    // The tiers differ in what they are allowed to cost us, so collapsing
    // them would silently hand trialists the premium model budget.
    subscribers.set('alice', {tier: 'trial', productId: 'cirrus_premium:yearly-399'});
    await call(event({period_type: 'TRIAL'}));
    const e = await entitlementOf('alice');
    expect(e?.tier).toBe('trial');
    expect(e?.plan).toBe('yearly');
  });

  it('the event type never decides: a late EXPIRATION cannot revoke an active sub', async () => {
    subscribers.set('alice', {tier: 'premium'});
    await call(event({type: 'EXPIRATION', id: 'evt-late'}));
    expect((await entitlementOf('alice'))?.tier).toBe('premium');
  });

  it('… and a RENEWAL for a customer who is actually free writes free', async () => {
    subscribers.set('alice', {tier: 'free'});
    await userDoc('alice').set({entitlement: {tier: 'premium', productId: 'old'}});
    await call(event({type: 'RENEWAL'}));
    const e = await entitlementOf('alice');
    expect(e?.tier).toBe('free');
    expect(e?.productId).toBeNull();
    expect(e?.plan).toBeNull();
    expect(e?.expiresAt).toBeNull();
  });

  it('an early renewal mirrors the NEW horizon, so the subscriber is not '
     + 'expired by the period still running', async () => {
    subscribers.set('alice', {tier: 'premium', renewedEarly: true});
    await call(event({type: 'RENEWAL'}));
    const e = await entitlementOf('alice');
    expect(e?.tier).toBe('premium');
    expect(e?.willRenew).toBe(true);
    expect((e?.expiresAt as {toMillis(): number} | undefined)?.toMillis()).toBe(Date.parse(IN_A_YEAR));
  });

  it('a billing-issue grace period keeps access to the horizon RevenueCat grants', async () => {
    subscribers.set('alice', {tier: 'premium', grace: true});
    await call(event({type: 'BILLING_ISSUE'}));
    const e = await entitlementOf('alice');
    expect(e?.tier).toBe('premium');
    expect((e?.expiresAt as {toMillis(): number} | undefined)?.toMillis()).toBe(Date.parse(IN_THREE_DAYS));
  });

  it('an older snapshot never overwrites a newer one', async () => {
    // Two deliveries for one customer can run at once; the one that read
    // RevenueCat earlier must not land later. Simulated by a row already
    // stamped with a read from the future.
    await userDoc('alice').set({
      entitlement: {tier: 'premium', snapshotAt: Date.now() + 60_000, lastEventId: 'older'},
    });
    subscribers.set('alice', {tier: 'free'});
    const res = await call(event({id: 'evt-late', type: 'EXPIRATION'}));
    expect(res.status).toBe(200);
    expect((await entitlementOf('alice'))?.tier).toBe('premium');
  });

  it('cancellation keeps access until expiry, and says it will not renew', async () => {
    subscribers.set('alice', {tier: 'premium', cancelled: true});
    await call(event({type: 'CANCELLATION'}));
    const e = await entitlementOf('alice');
    expect(e?.tier).toBe('premium');
    expect(e?.willRenew).toBe(false);
  });

  it('TRANSFER re-reads both sides: the old owner loses, the new one gains', async () => {
    // RevenueCat's TRANSFER payload carries no app_user_id at all.
    await userDoc('alice').set({entitlement: {tier: 'premium'}});
    subscribers.set('alice', {tier: 'free'});
    subscribers.set('bob', {tier: 'premium'});
    const res = await call(
      event({
        type: 'TRANSFER',
        app_user_id: undefined,
        transferred_from: ['alice'],
        transferred_to: ['bob'],
      }),
    );
    expect(res.status).toBe(200);
    expect((await entitlementOf('alice'))?.tier).toBe('free');
    expect((await entitlementOf('bob'))?.tier).toBe('premium');
  });

  it('a retried event (same id) is acknowledged without a second fetch', async () => {
    subscribers.set('alice', {tier: 'premium'});
    await call(event());
    expect(fetchedIds).toEqual(['alice']);
    const res = await call(event());
    expect(res.status).toBe(200);
    expect(fetchedIds).toEqual(['alice']);
  });

  it('a sandbox purchase mirrors when allowed, and records that it is sandbox', async () => {
    subscribers.set('alice', {tier: 'premium', sandbox: true});
    await call(event({environment: 'SANDBOX'}));
    const e = await entitlementOf('alice');
    expect(e?.tier).toBe('premium');
    expect(e?.environment).toBe('SANDBOX');
  });

  it('a sandbox purchase is ignored when RC_ACCEPT_SANDBOX is off', async () => {
    vi.spyOn(RC_ACCEPT_SANDBOX, 'value').mockReturnValue('false');
    subscribers.set('alice', {tier: 'premium', sandbox: true});
    const res = await call(event({environment: 'SANDBOX'}));
    expect(res.status).toBe(200);
    expect((await userDoc('alice').get()).exists).toBe(false);
    expect(fetchedIds).toEqual([]);
  });

  it('leaves other fields on the user document alone', async () => {
    // The document is shared with aiUsage, planAdvice and the FCM tokens; a
    // non-merging write here would silently wipe a user's push registration
    // and their quota every time they renewed.
    await userDoc('alice').set({
      fcmTokens: ['device-1'],
      aiUsage: {day: '2026-08-30', msgCount: 4},
    });
    subscribers.set('alice', {tier: 'premium'});
    await call(event());

    const snap = await userDoc('alice').get();
    expect(snap.get('fcmTokens')).toEqual(['device-1']);
    expect(snap.get('aiUsage').msgCount).toBe(4);
    expect(snap.get('entitlement').tier).toBe('premium');
  });
});

describe('what it refuses to mirror', () => {
  it('a uid with no Auth user — a RevenueCat-anonymous id, or an erased account', async () => {
    subscribers.set('$RCAnonymousID:abc', {tier: 'premium'});
    const res = await call(event({app_user_id: '$RCAnonymousID:abc'}));
    expect(res.status).toBe(200);
    expect((await userDoc('$RCAnonymousID:abc').get()).exists).toBe(false);
    expect(fetchedIds).toEqual([]);
  });

  it("the dashboard's TEST event", async () => {
    const res = await call(event({type: 'TEST'}));
    expect(res.status).toBe(200);
    expect((await userDoc('alice').get()).exists).toBe(false);
    expect(fetchedIds).toEqual([]);
  });

  it('answers 500 when RevenueCat is down, so the event is retried', async () => {
    // No script for alice → the stub answers 503.
    const res = await call(event());
    expect(res.status).toBe(500);
    expect((await userDoc('alice').get()).exists).toBe(false);
  });
});

describe('malformed events', () => {
  it('refuses a body with no event', async () => {
    expect((await call({})).status).toBe(400);
  });

  it('refuses an event naming nobody', async () => {
    // `app_user_id` must be the Firebase uid; without any id there is no
    // document to write and guessing one would grant a stranger Premium.
    const res = await call(event({app_user_id: undefined}));
    expect(res.status).toBe(400);
  });

  it('acknowledges an unknown future event type by mirroring, not by guessing', async () => {
    subscribers.set('alice', {tier: 'premium'});
    const res = await call(event({type: 'SOME_FUTURE_EVENT'}));
    expect(res.status).toBe(200);
    expect((await entitlementOf('alice'))?.tier).toBe('premium');
  });
});
