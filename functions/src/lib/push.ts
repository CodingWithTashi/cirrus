/**
 * Sending a push, and keeping the token list honest.
 *
 * Until this file existed, push was dead in the most expensive way: every
 * sign-in registered an FCM token into `users/{uid}.fcmTokens`, and **nothing
 * ever read that field.** We were collecting a device identifier we had no use
 * for — which is both a dead re-engagement lever and data we had no business
 * holding.
 *
 * What earns a push here is deliberately narrow. Danger-hour reminders are NOT
 * sent from the server (see the header of `index.ts`): they are deterministic
 * once computed, so they are scheduled on-device where they are free, work
 * offline, and need no fan-out. A server push is only worth it when the
 * trigger is something the device could not have known by itself — somebody
 * else answered you, or a report finished generating.
 */
import {getMessaging} from 'firebase-admin/messaging';
import {FieldValue, userDoc} from './firestore';
import {log} from './logger';
import {pushCopy, type PushKey} from './pushCopy';

export interface PushPayload {
  readonly title: string;
  readonly body: string;
  /** In-app destination. The client allow-lists this before navigating. */
  readonly route?: string;
}

/**
 * Sends [payload] to every device [uid] has registered.
 *
 * Never throws: a push is a courtesy, and a failed one must not fail the
 * moderation pass or the cron that triggered it.
 *
 * Dead tokens are pruned as they are discovered. Without that, `fcmTokens`
 * grows forever — every reinstall adds one — and eventually every send fans
 * out across a list of mostly-dead entries.
 */
export async function sendToUser(
  uid: string,
  payload: PushPayload,
): Promise<void> {
  try {
    const snap = await userDoc(uid).get();
    const tokens: unknown = snap.get('fcmTokens');
    if (!Array.isArray(tokens) || tokens.length === 0) return;

    const valid = tokens.filter(
      (t): t is string => typeof t === 'string' && t.length > 0,
    );
    if (valid.length === 0) return;

    const response = await getMessaging().sendEachForMulticast({
      tokens: valid,
      notification: {title: payload.title, body: payload.body},
      // `data` is what survives into the tapped-notification handler; the
      // notification block alone cannot carry a destination.
      data: payload.route ? {route: payload.route} : {},
    });

    const dead: string[] = [];
    response.responses.forEach((result, i) => {
      const code = result.error?.code;
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token' ||
        code === 'messaging/invalid-argument'
      ) {
        const token = valid[i];
        if (token !== undefined) dead.push(token);
      }
    });
    if (dead.length > 0) {
      await userDoc(uid).set(
        {fcmTokens: FieldValue.arrayRemove(...dead)},
        {merge: true},
      );
    }

    log.info('push.sent', {
      uid,
      ok: response.successCount,
      failed: response.failureCount,
      pruned: dead.length,
    });
  } catch (error) {
    log.warn('push.failed', {uid, error: String(error)});
  }
}

/**
 * Sends a localized push, choosing the language from the recipient's own
 * `users/{uid}.locale` rather than from ours.
 *
 * The read happens twice (here and in [sendToUser]) and that is fine: this
 * runs at most once per user per event, and the alternative is threading a
 * snapshot through a function whose entire job is to not matter when it fails.
 */
export async function sendLocalized(
  uid: string,
  key: PushKey,
  route: string,
): Promise<void> {
  let locale: string | undefined;
  try {
    const snap = await userDoc(uid).get();
    const stored: unknown = snap.get('locale');
    if (typeof stored === 'string') locale = stored;
  } catch {
    // Fall through to English; a missing locale is not worth losing the push.
  }
  await sendToUser(uid, {...pushCopy(key, locale), route});
}
