/**
 * `syncUserContext` — the app's only way to write into the server-owned
 * `users/{uid}` document.
 *
 * That collection is server-write-only (see `lib/firestore.ts`), so the
 * client cannot just set its own timezone. It calls this instead, and the
 * function writes ONLY the three fields a client is allowed to influence.
 * Notably it cannot touch `entitlement` or `aiUsage` — which is the entire
 * point of routing through a function rather than relaxing the rules.
 *
 * Call it on sign-in, on resume, and whenever the device timezone changes.
 */
import {onCall} from 'firebase-functions/v2/https';
import {REGION} from '../config';
import {FieldValue, userDoc} from '../lib/firestore';
import {requireCaller} from '../lib/guards';
import {recalcHourUtcFor} from './taperRecalc';

export const syncUserContext = onCall(
  {region: REGION, enforceAppCheck: true, memory: '256MiB'},
  async (request): Promise<{ok: true}> => {
    const caller = requireCaller(request);
    const data = (request.data ?? {}) as Record<string, unknown>;
    const token = data['fcmToken'];

    await userDoc(caller.uid).set(
      {
        tz: caller.timeZone,
        locale: caller.locale,
        // Keeps the nightly crons firing just after the user's own midnight,
        // and re-derives across DST every time the app syncs.
        recalcHourUtc: recalcHourUtcFor(caller.timeZone),
        updatedAt: FieldValue.serverTimestamp(),
        ...(typeof token === 'string' && token.length > 0
          ? {fcmTokens: FieldValue.arrayUnion(token)}
          : {}),
      },
      {merge: true},
    );

    return {ok: true};
  },
);
