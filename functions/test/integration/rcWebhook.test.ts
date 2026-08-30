/**
 * `rcWebhook` — the only writer of `users/{uid}.entitlement`.
 *
 * This had **no test of any kind**, which is the wrong place in this codebase
 * to have none. It is an unauthenticated public endpoint whose only security
 * boundary is a bearer token, and the field it writes is the single thing the
 * coach trusts when deciding whether someone gets a paid model call. A bug
 * here is either free Premium for anyone who can guess a URL, or a paying
 * customer being told no.
 *
 * Invoked directly with hand-built req/res doubles — an `onRequest` function
 * IS the express handler, unlike a callable — so these test the handler's
 * logic and skip the transport, the same way the other handler suites do.
 */
import {EventEmitter} from 'node:events';
import {beforeEach, describe, expect, it, vi} from 'vitest';
import {rcWebhook} from '../../src/handlers/rcWebhook';
import {REVENUECAT_WEBHOOK_TOKEN} from '../../src/config';
import {userDoc} from '../../src/lib/firestore';

const PROJECT = process.env['GCLOUD_PROJECT'] ?? 'demo-cirrus';
const HOST = process.env['FIRESTORE_EMULATOR_HOST'] ?? '127.0.0.1:8080';
const TOKEN = 'test-webhook-secret';

async function clearFirestore(): Promise<void> {
  const url =
    `http://${HOST}/emulator/v1/projects/${PROJECT}` +
    `/databases/(default)/documents`;
  const res = await fetch(url, {method: 'DELETE'});
  if (!res.ok) throw new Error(`emulator clear failed: ${res.status}`);
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
  for (let i = 0; i < 200 && sent.status === 0; i++) {
    await new Promise((r) => setTimeout(r, 10));
  }
  return sent;
}

const event = (over: Record<string, unknown> = {}) => ({
  event: {
    app_user_id: 'alice',
    type: 'INITIAL_PURCHASE',
    product_id: 'monthly_799',
    period_type: 'NORMAL',
    expiration_at_ms: Date.UTC(2026, 8, 30),
    ...over,
  },
});

beforeEach(async () => {
  await clearFirestore();
  // The secret is a deploy-time param; pin it for the suite.
  vi.spyOn(REVENUECAT_WEBHOOK_TOKEN, 'value').mockReturnValue(TOKEN);
});

describe('the security boundary', () => {
  it('refuses a request with no Authorization header', async () => {
    const res = await call(event(), {authorization: null});
    expect(res.status).toBe(401);
    expect((await userDoc('alice').get()).exists).toBe(false);
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

  it('refuses anything that is not a POST', async () => {
    const res = await call(event(), {method: 'GET'});
    expect(res.status).toBe(405);
  });

  it('rejects before parsing, so a malformed body cannot reach the writer', async () => {
    const res = await call({nonsense: true}, {authorization: 'Bearer wrong'});
    expect(res.status).toBe(401);
  });
});

describe('granting access', () => {
  it('writes a premium entitlement on a purchase', async () => {
    const res = await call(event());
    expect(res.status).toBe(200);

    const entitlement = (await userDoc('alice').get()).get('entitlement');
    expect(entitlement.tier).toBe('premium');
    expect(entitlement.productId).toBe('monthly_799');
    expect(entitlement.expiresAt).not.toBeNull();
  });

  it('marks a trial as trial, not as premium', async () => {
    // The tiers differ in what they are allowed to cost us, so collapsing
    // them would silently hand trialists the premium model budget.
    await call(event({period_type: 'TRIAL'}));
    expect((await userDoc('alice').get()).get('entitlement').tier).toBe('trial');
  });

  it('grants on every renewal-shaped event', async () => {
    for (const type of [
      'RENEWAL',
      'PRODUCT_CHANGE',
      'UNCANCELLATION',
      'NON_RENEWING_PURCHASE',
      'SUBSCRIPTION_EXTENDED',
      'TRANSFER',
    ]) {
      await clearFirestore();
      await call(event({type}));
      expect(
        (await userDoc('alice').get()).get('entitlement').tier,
        `${type} should grant`,
      ).toBe('premium');
    }
  });

  it('tolerates a missing expiry rather than dropping the grant', async () => {
    await call(event({expiration_at_ms: undefined}));
    const entitlement = (await userDoc('alice').get()).get('entitlement');
    expect(entitlement.tier).toBe('premium');
    expect(entitlement.expiresAt).toBeNull();
  });
});

describe('revoking access', () => {
  it('drops to free on expiry, refund or pause', async () => {
    for (const type of ['EXPIRATION', 'REFUND', 'SUBSCRIPTION_PAUSED']) {
      await clearFirestore();
      await userDoc('alice').set({entitlement: {tier: 'premium'}});
      await call(event({type}));
      expect(
        (await userDoc('alice').get()).get('entitlement').tier,
        `${type} should revoke`,
      ).toBe('free');
    }
  });

  it('does NOT revoke on cancellation', async () => {
    // CANCELLATION means "will not renew", not "access ends now". Treating it
    // as revocation is the classic way to enrage someone who has already paid
    // for the rest of the month.
    await userDoc('alice').set({entitlement: {tier: 'premium'}});
    const res = await call(event({type: 'CANCELLATION'}));

    expect(res.status).toBe(200);
    expect((await userDoc('alice').get()).get('entitlement').tier).toBe(
      'premium',
    );
  });
});

describe('malformed and unknown events', () => {
  it('refuses a body with no event', async () => {
    expect((await call({})).status).toBe(400);
  });

  it('refuses an event with no app_user_id', async () => {
    // `app_user_id` must be the Firebase uid; without it there is no document
    // to write and guessing one would grant a stranger Premium.
    const res = await call(event({app_user_id: undefined}));
    expect(res.status).toBe(400);
  });

  it('acknowledges an unknown future event without writing anything', async () => {
    // A non-2xx makes RevenueCat retry forever, and a type we have not heard
    // of is not a failure — it is a product we have not shipped yet.
    const res = await call(event({type: 'SOME_FUTURE_EVENT'}));
    expect(res.status).toBe(200);
    expect((await userDoc('alice').get()).exists).toBe(false);
  });

  it('leaves other fields on the user document alone', async () => {
    // The document is shared with aiUsage, planAdvice and the FCM tokens; a
    // non-merging write here would silently wipe a user's push registration
    // and their quota every time they renewed.
    await userDoc('alice').set({
      fcmTokens: ['device-1'],
      aiUsage: {day: '2026-08-30', msgCount: 4},
    });
    await call(event());

    const snap = await userDoc('alice').get();
    expect(snap.get('fcmTokens')).toEqual(['device-1']);
    expect(snap.get('aiUsage').msgCount).toBe(4);
    expect(snap.get('entitlement').tier).toBe('premium');
  });
});
