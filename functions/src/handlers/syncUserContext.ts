/**
 * `syncUserContext` — the app's only way to write into the server-owned
 * `users/{uid}` document.
 *
 * That collection is server-write-only (see `lib/firestore.ts`), so the
 * client cannot just set its own timezone. It calls this instead, and the
 * function writes ONLY the fields a client is allowed to influence. Notably it
 * cannot touch `entitlement` or `aiUsage` — which is the entire point of
 * routing through a function rather than relaxing the rules.
 *
 * Call it on sign-in, on resume, and whenever the device timezone changes.
 *
 * It is also the push registry's only door, in both directions: `fcmToken`
 * registers this device, `removeFcmToken` releases it. Release lives here
 * rather than in a callable of its own because sign-out happens while the user
 * is still authenticated, and this is already the one write path — a second
 * door would be a second thing to forget.
 */
import {onCall} from 'firebase-functions/v2/https';
import {REGION} from '../config';
import {FieldValue, userDoc} from '../lib/firestore';
import {requireCaller} from '../lib/guards';
import {registerDevice, unregisterDevice} from '../lib/push';
import {recalcHourUtcFor} from './taperRecalc';

/** Free text is never trusted; this is only ever read as a short label. */
const MAX_LABEL_CHARS = 40;

function label(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim().length > 0
    ? value.trim().slice(0, MAX_LABEL_CHARS)
    : undefined;
}

export const syncUserContext = onCall(
  {region: REGION, enforceAppCheck: true, memory: '256MiB'},
  async (request): Promise<{ok: true}> => {
    const caller = requireCaller(request);
    const data = (request.data ?? {}) as Record<string, unknown>;

    await userDoc(caller.uid).set(
      {
        tz: caller.timeZone,
        locale: caller.locale,
        // Keeps the nightly crons firing just after the user's own midnight,
        // and re-derives across DST every time the app syncs.
        recalcHourUtc: recalcHourUtcFor(caller.timeZone),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    // After the user document exists, so a device row can never be the only
    // thing we hold for someone.
    const token = data['fcmToken'];
    if (typeof token === 'string' && token.trim().length > 0) {
      await registerDevice(caller.uid, {
        token,
        platform: label(data['platform']),
      });
    }

    // Sign-out. Separate from the register path on purpose: a client that
    // sends both is releasing one device and registering another, which is
    // exactly what a sign-out followed by a sign-in on one phone looks like.
    const removed = data['removeFcmToken'];
    if (typeof removed === 'string' && removed.trim().length > 0) {
      await unregisterDevice(caller.uid, removed);
    }

    return {ok: true};
  },
);
