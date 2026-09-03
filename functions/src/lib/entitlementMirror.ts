/**
 * The one writer of `users/{uid}.entitlement` — the trusted tier mirror.
 *
 * Two callers reach it, for the same reason from opposite directions:
 *
 * - `rcWebhook`, when RevenueCat tells us something changed. Authoritative,
 *   but it arrives when it arrives.
 * - `refreshEntitlement`, when the app has just bought or restored and wants
 *   the mirror warm *now*. A purchase makes the client premium instantly (the
 *   SDK answers from the receipt) while the webhook is still in flight, so
 *   without this a freshly-paying user is metered by `aiCoachChat` or refused
 *   by `createPost` for as long as the round-trip takes. Under
 *   `ENTITLEMENT_MODE=ungated` nobody noticed; under `mirror` it is the first
 *   thing a paying customer would hit.
 *
 * Neither caller is trusted about the *content*: both fetch the subscriber
 * snapshot from RevenueCat and write that. The client's claim is only ever
 * "look again", never "I am premium" — which is why this takes no tier from
 * anyone and why the callable can be open to any signed-in user.
 *
 * `snapshotAt` orders concurrent writes. It is stamped BEFORE the fetch, so a
 * write that read earlier can never land on top of one that read later —
 * whether the two are two webhook deliveries, or a webhook racing the app's
 * own refresh, which is now a routine pairing rather than a rare one.
 */
import {
  FieldValue,
  Timestamp,
  type UserDoc,
  db,
  userDoc,
} from './firestore';
import {log} from './logger';
import {fetchSubscriber} from './revenuecat';

export interface MirrorOptions {
  /** Whether sandbox subscriptions count. `RC_ACCEPT_SANDBOX`. */
  acceptSandbox: boolean;
  /** RevenueCat's event id, for duplicate suppression. Null for a refresh. */
  eventId?: string | null;
  /** RevenueCat's event type, recorded for support. Null for a refresh. */
  eventType?: string | null;
}

export interface MirrorResult {
  /** The tier now standing in the mirror. */
  tier: 'free' | 'premium' | 'trial';
  /** False when a newer snapshot was already there and this one was dropped. */
  written: boolean;
}

/**
 * Fetches the customer's current standing from RevenueCat and mirrors it.
 *
 * Throws `RevenueCatUnavailable` (or whatever `fetchSubscriber` threw) when
 * the snapshot could not be read — deliberately, so the webhook can answer
 * 500 and be retried, and the callable can tell the app to try again. **A
 * failure here is never written as `free`**: an unreadable snapshot is not
 * evidence of anything, and treating it as one revokes paying customers.
 */
export async function mirrorEntitlement(
  uid: string,
  options: MirrorOptions,
): Promise<MirrorResult> {
  const {acceptSandbox, eventId = null, eventType = null} = options;
  const ref = userDoc(uid);

  if (eventId !== null) {
    const current = ((await ref.get()).data() as UserDoc | undefined)
      ?.entitlement;
    if (current?.lastEventId === eventId) {
      log.info('entitlement.duplicate', {uid, eventId});
      return {tier: current?.tier ?? 'free', written: false};
    }
  }

  // Stamped before the read — see the note at the top of this file.
  const fetchedAtMs = Date.now();
  const snapshot = await fetchSubscriber(uid, {acceptSandbox});

  const written = await db.runTransaction(async (tx) => {
    const current = ((await tx.get(ref)).data() as UserDoc | undefined)
      ?.entitlement;
    if ((current?.snapshotAt ?? 0) > fetchedAtMs) return false;
    tx.set(
      ref,
      {
        entitlement: {
          tier: snapshot.tier,
          productId: snapshot.productId,
          plan: snapshot.plan,
          expiresAt:
            snapshot.expiresAtMs === null
              ? null
              : Timestamp.fromMillis(snapshot.expiresAtMs),
          willRenew: snapshot.willRenew,
          store: snapshot.store,
          environment: snapshot.environment,
          managementUrl: snapshot.managementUrl,
          lastEventId: eventId,
          lastEventType: eventType,
          snapshotAt: fetchedAtMs,
          updatedAt: FieldValue.serverTimestamp(),
        },
      },
      {merge: true},
    );
    return true;
  });

  return {tier: snapshot.tier, written};
}
