/**
 * `refreshEntitlement` — "look at the store again, now."
 *
 * Called by the app immediately after a purchase or a restore. The client is
 * premium the instant the store sheet returns (the SDK reads the receipt),
 * but `users/{uid}.entitlement` — the only tier the server trusts — is not
 * written until RevenueCat's webhook arrives. In between, the app shows
 * Premium while `aiCoachChat` still meters the free allowance and
 * `createPost` still refuses a second post.
 *
 * That window was invisible while `ENTITLEMENT_MODE=ungated` made everyone
 * premium. Under `mirror` it is the first thing a paying customer meets, and
 * a wall shown to someone who has just paid is the worst refusal in the app.
 *
 * **This takes no tier from the caller.** The request carries nothing but the
 * App Check token and the caller's identity; the tier written is whatever
 * RevenueCat reports for that uid. So the endpoint is safe to hand to any
 * signed-in user: the most a liar achieves is making us re-read their own
 * unchanged record. Rate-limited only by that pointlessness and by App Check.
 *
 * Idempotent, and safe to call when nothing changed — the snapshot is written
 * whole, ordered by `snapshotAt`, exactly as the webhook writes it.
 */
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {RC_ACCEPT_SANDBOX, REGION, REVENUECAT_SECRET_API_KEY} from '../config';
import {mirrorEntitlement} from '../lib/entitlementMirror';
import {requireCaller} from '../lib/guards';
import {log} from '../lib/logger';
import {RevenueCatUnavailable} from '../lib/revenuecat';

export const refreshEntitlement = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
    secrets: [REVENUECAT_SECRET_API_KEY],
    memory: '256MiB',
  },
  async (request): Promise<{tier: string}> => {
    const {uid} = requireCaller(request);

    try {
      const result = await mirrorEntitlement(uid, {
        acceptSandbox: RC_ACCEPT_SANDBOX.value() === 'true',
      });
      log.info('entitlement.refreshed', {
        uid,
        tier: result.tier,
        written: result.written,
      });
      return {tier: result.tier};
    } catch (error) {
      const known = error instanceof RevenueCatUnavailable;
      log.error('entitlement.refresh_failed', {
        uid,
        status: known ? error.status : -1,
        reason: known ? error.reason : String(error),
      });
      // `unavailable` and not `internal`: the caller's own retry is the right
      // response, and the webhook will land the same write regardless. The
      // app treats a failure here as "not yet", never as "you are free".
      throw new HttpsError('unavailable', 'Could not reach the store.');
    }
  },
);
