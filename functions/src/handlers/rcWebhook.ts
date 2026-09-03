/**
 * `rcWebhook` — RevenueCat → the trusted entitlement mirror (docs/05 §7).
 *
 * This endpoint is the ONLY writer of `users/{uid}.entitlement`, and that
 * field is the ONLY thing the coach trusts when choosing a tier. The app's
 * own view of its tier comes from the RevenueCat SDK's customer record; the
 * server never believes anything the app says about it.
 *
 * Unauthenticated by nature (RevenueCat calls it), so the shared secret in
 * the Authorization header is the whole security boundary.
 *
 * The event is a TRIGGER, not the truth. For every customer it names — the
 * `app_user_id`, plus both sides of a TRANSFER — the handler fetches the
 * current subscriber snapshot from RevenueCat and writes THAT. So a late,
 * duplicated or reordered delivery cannot revoke a paying user, CANCELLATION
 * keeps access until expiry because the snapshot says so, BILLING_ISSUE keeps
 * access through the grace period because the snapshot says so, and the
 * event-type switch this replaced (with its five known holes) is gone.
 */
import {timingSafeEqual} from 'node:crypto';
import {getAuth} from 'firebase-admin/auth';
import {onRequest} from 'firebase-functions/v2/https';
import {
  RC_ACCEPT_SANDBOX,
  REGION,
  REVENUECAT_SECRET_API_KEY,
  REVENUECAT_WEBHOOK_TOKEN,
} from '../config';
import {mirrorEntitlement} from '../lib/entitlementMirror';
import {log} from '../lib/logger';
import {RevenueCatUnavailable} from '../lib/revenuecat';

export const rcWebhook = onRequest(
  {
    region: REGION,
    secrets: [REVENUECAT_WEBHOOK_TOKEN, REVENUECAT_SECRET_API_KEY],
    memory: '256MiB',
    cors: false,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('method not allowed');
      return;
    }
    if (!authorized(req.get('authorization'))) {
      log.warn('rcWebhook.unauthorized', {ip: req.ip});
      res.status(401).send('unauthorized');
      return;
    }

    const event = (req.body as Record<string, unknown> | undefined)?.['event'];
    if (event === null || typeof event !== 'object') {
      res.status(400).send('missing event');
      return;
    }
    const e = event as Record<string, unknown>;
    const type = typeof e['type'] === 'string' ? e['type'] : '';
    const eventId = typeof e['id'] === 'string' ? e['id'] : null;
    const uids = affectedUids(e);

    // RevenueCat's dashboard "send test event" names a customer that does not
    // exist; nothing to mirror, and answering 200 is what lights it green.
    if (type === 'TEST') {
      log.info('rcWebhook.test_event');
      res.status(200).send('ok');
      return;
    }
    if (uids.length === 0) {
      res.status(400).send('missing app_user_id');
      return;
    }
    if (e['environment'] === 'SANDBOX' && RC_ACCEPT_SANDBOX.value() !== 'true') {
      log.info('rcWebhook.sandbox_ignored', {type, uids});
      res.status(200).send('ok');
      return;
    }

    const acceptSandbox = RC_ACCEPT_SANDBOX.value() === 'true';
    for (const uid of uids) {
      // Only a Firebase-shaped uid can be one of ours. Anything else — a
      // custom id from another integration, a malformed value — is skipped
      // before it can reach `getUser` (which throws `invalid-uid`, not
      // `user-not-found`, for an overlong id) or a document path.
      if (!UID.test(uid)) {
        log.warn('rcWebhook.invalid_uid', {type, length: uid.length});
        continue;
      }
      // A RevenueCat-anonymous id, or an account `deleteUserData` already
      // erased: never re-create a `users/{uid}` for either.
      if (!(await userExists(uid))) {
        log.warn('rcWebhook.orphan', {uid, type});
        continue;
      }
      // The write itself is shared with `refreshEntitlement` — see
      // `lib/entitlementMirror.ts` for why both doors exist and why neither
      // trusts its caller about the content.
      let result;
      try {
        result = await mirrorEntitlement(uid, {
          acceptSandbox,
          eventId,
          eventType: type,
        });
      } catch (error) {
        // A non-2xx makes RevenueCat retry (5, 10, 20, 40, 80 min) — the
        // right outcome for a snapshot we could not read, whatever stopped
        // us: a status, a timeout, a missing project id.
        const known = error instanceof RevenueCatUnavailable;
        log.error('rcWebhook.revenuecat_unavailable', {
          uid,
          type,
          status: known ? error.status : -1,
          reason: known ? error.reason : String(error),
        });
        res.status(500).send('revenuecat unavailable');
        return;
      }
      if (result.written) {
        log.info('rcWebhook.mirrored', {uid, type, tier: result.tier});
      } else {
        log.info('rcWebhook.stale_snapshot', {uid, type});
      }
    }

    // 200 on handled-or-ignored: an unknown future event type is not a
    // failure, and only a snapshot we could not read is worth a retry.
    res.status(200).send('ok');
  },
);

/** Firebase Auth uids: 1–128 chars of `[A-Za-z0-9_-]`. */
const UID = /^[A-Za-z0-9_-]{1,128}$/;

/**
 * Constant-time compare of the whole `Bearer <token>` header. An unset token
 * (an emulator without the secret, a mis-bound deploy) closes the endpoint
 * rather than opening it to `Authorization: Bearer `.
 */
function authorized(header: string | undefined): boolean {
  const token = REVENUECAT_WEBHOOK_TOKEN.value();
  if (!token) return false;
  const expected = Buffer.from(`Bearer ${token}`);
  const given = Buffer.from(header ?? '');
  return given.length === expected.length && timingSafeEqual(given, expected);
}

/**
 * Every customer the event is about. `app_user_id` is absent on TRANSFER,
 * which carries only `transferred_from` / `transferred_to` — both sides get
 * re-read, so the old owner loses access in the same request the new one
 * gains it.
 */
function affectedUids(e: Record<string, unknown>): string[] {
  const out = new Set<string>();
  const one = e['app_user_id'];
  if (typeof one === 'string' && one.length > 0) out.add(one);
  for (const key of ['transferred_from', 'transferred_to']) {
    const many = e[key];
    if (!Array.isArray(many)) continue;
    for (const v of many) {
      if (typeof v === 'string' && v.length > 0) out.add(v);
    }
  }
  return [...out];
}

async function userExists(uid: string): Promise<boolean> {
  try {
    await getAuth().getUser(uid);
    return true;
  } catch (error) {
    if ((error as {code?: string}).code === 'auth/user-not-found') return false;
    throw error;
  }
}
