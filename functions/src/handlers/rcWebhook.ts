/**
 * `rcWebhook` — RevenueCat → the trusted entitlement mirror (docs/05 §7).
 *
 * This endpoint is the ONLY writer of `users/{uid}.entitlement`, and that
 * field is the ONLY thing the coach trusts when choosing a tier. The app's
 * own `profile.tier` is a display value; believing it would let a repackaged
 * client grant itself Premium and unlimited model calls.
 *
 * Unauthenticated by nature (RevenueCat calls it), so the shared secret in
 * the Authorization header is the whole security boundary.
 */
import {onRequest} from 'firebase-functions/v2/https';
import {REGION, REVENUECAT_WEBHOOK_TOKEN} from '../config';
import {FieldValue, Timestamp, userDoc} from '../lib/firestore';
import {log} from '../lib/logger';

/** Event types that mean "this user currently has access". */
const GRANTING = new Set([
  'INITIAL_PURCHASE', 'RENEWAL', 'PRODUCT_CHANGE', 'UNCANCELLATION',
  'NON_RENEWING_PURCHASE', 'SUBSCRIPTION_EXTENDED', 'TRANSFER',
]);
/** Event types that revoke access immediately. */
const REVOKING = new Set(['EXPIRATION', 'REFUND', 'SUBSCRIPTION_PAUSED']);

export const rcWebhook = onRequest(
  {
    region: REGION,
    secrets: [REVENUECAT_WEBHOOK_TOKEN],
    memory: '256MiB',
    cors: false,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('method not allowed');
      return;
    }
    // Constant-time-ish comparison is overkill for a bearer token of this
    // shape, but rejecting before any parsing is not.
    if (req.get('authorization') !== `Bearer ${REVENUECAT_WEBHOOK_TOKEN.value()}`) {
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
    const uid = typeof e['app_user_id'] === 'string' ? e['app_user_id'] : null;
    const type = typeof e['type'] === 'string' ? e['type'] : '';

    if (uid === null) {
      res.status(400).send('missing app_user_id');
      return;
    }

    // CANCELLATION means "will not renew", NOT "access ends now" — the user
    // keeps Premium until expiry. Treating it as revocation is the classic
    // way to enrage a paying customer.
    if (type === 'CANCELLATION') {
      log.info('rcWebhook.cancellation_noted', {uid});
      res.status(200).send('ok');
      return;
    }

    if (GRANTING.has(type)) {
      const expiresMs =
        typeof e['expiration_at_ms'] === 'number' ? e['expiration_at_ms'] : null;
      const isTrial = e['period_type'] === 'TRIAL';
      await userDoc(uid).set(
        {
          entitlement: {
            tier: isTrial ? 'trial' : 'premium',
            productId: typeof e['product_id'] === 'string' ? e['product_id'] : null,
            expiresAt: expiresMs === null ? null : Timestamp.fromMillis(expiresMs),
            updatedAt: FieldValue.serverTimestamp(),
          },
        },
        {merge: true},
      );
    } else if (REVOKING.has(type)) {
      await userDoc(uid).set(
        {
          entitlement: {
            tier: 'free',
            expiresAt: null,
            updatedAt: FieldValue.serverTimestamp(),
          },
        },
        {merge: true},
      );
    }

    log.info('rcWebhook.handled', {uid, type});
    // Always 200 on a handled-or-ignored event: a non-2xx makes RevenueCat
    // retry, and an unknown future event type is not a failure.
    res.status(200).send('ok');
  },
);
