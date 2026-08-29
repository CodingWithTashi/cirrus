/**
 * `panicSession` — records a craving session and reports whether AI panic
 * mode is available (docs/03 §7, docs/04 §7).
 *
 * The 3-step script itself runs on-device: a craving must not wait on a
 * network round-trip. This exists for the parts the client can't be trusted
 * with — the server-side session count and the tier read.
 *
 * It NEVER blocks. Past the free cap the client still shows the breathing
 * screen and the static reframe card; only the AI layer drops away. We do not
 * paywall someone mid-crisis (docs/04 §7).
 *
 * NOTE: docs/03 §7's buddy-ping branch is intentionally absent — Quit Buddies
 * is descoped (founder decision, Aug 2026).
 */
import {onCall} from 'firebase-functions/v2/https';
import {REGION} from '../config';
import {dayKeyIn} from '../domain/dateKey';
import {FieldValue, userDoc} from '../lib/firestore';
import {requireCaller} from '../lib/guards';
import {countPanicSession, tierFor} from '../lib/usage';

/** docs/04 §7 — free tier gets one AI-backed panic session per day. */
const FREE_DAILY_PANIC_SESSIONS = 1;

export const panicSession = onCall(
  {region: REGION, enforceAppCheck: true, memory: '256MiB'},
  async (request): Promise<{aiAvailable: boolean; sessionsToday: number}> => {
    const caller = requireCaller(request);
    const data = (request.data ?? {}) as Record<string, unknown>;
    const today = dayKeyIn(new Date(), caller.timeZone);

    const [tier, sessionsToday] = await Promise.all([
      tierFor(caller.uid),
      countPanicSession(caller.uid, today),
    ]);

    // Outcome is optional: the client posts it when the session ends, and a
    // session that ends with the app killed simply never reports one.
    const outcome = data['outcome'];
    if (outcome === 'survived' || outcome === 'slipped') {
      await userDoc(caller.uid).collection('cravings').add({
        outcome,
        intensity: typeof data['intensity'] === 'number' ? data['intensity'] : null,
        startedAt: FieldValue.serverTimestamp(),
      });
    }

    return {
      aiAvailable: tier !== 'free' || sessionsToday <= FREE_DAILY_PANIC_SESSIONS,
      sessionsToday,
    };
  },
);
