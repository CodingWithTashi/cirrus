/**
 * Sending a push, and keeping the device registry honest.
 *
 * Until this file existed, push was dead in the most expensive way: every
 * sign-in registered an FCM token into `users/{uid}.fcmTokens`, and **nothing
 * ever read that field.** We were collecting a device identifier we had no use
 * for — which is both a dead re-engagement lever and data we had no business
 * holding.
 *
 * The second half of that bug outlived the first. A token went into the array
 * and could only ever come back out when a send to it failed, so **signing out
 * released nothing**: the next person to use that phone received the previous
 * account's pushes. `users/{uid}/devices/{tokenHash}` replaces the array —
 * one document per device, carrying the platform and a `lastSeenAt` the prune
 * cron can judge, and removable one device at a time.
 *
 * The array is still READ on the send path and never written. Someone who has
 * not reopened the app since the migration is still reachable; the first
 * `syncUserContext` after it moves them across.
 *
 * What earns a push here is deliberately narrow. Danger-hour reminders are NOT
 * sent from the server (see the header of `index.ts`): they are deterministic
 * once computed, so they are scheduled on-device where they are free, work
 * offline, and need no fan-out. A server push is only worth it when the
 * trigger is something the device could not have known by itself — somebody
 * else answered you, or a report finished generating.
 */
import {createHash} from 'node:crypto';
import {getMessaging} from 'firebase-admin/messaging';
import {FieldValue, db, devicesCol, userDoc} from './firestore';
import {log} from './logger';
import {pushCopy, type PushKey} from './pushCopy';

/** What the app runs on, as far as we are willing to believe it. */
export type DevicePlatform = 'android' | 'ios' | 'other';

const PLATFORMS: readonly string[] = ['android', 'ios'];

export interface DeviceRegistration {
  readonly token: string;
  /** Client-supplied, so anything unrecognised becomes 'other'. */
  readonly platform?: string | undefined;
}

export interface PushPayload {
  readonly title: string;
  readonly body: string;
  /** In-app destination. The client allow-lists this before navigating. */
  readonly route?: string;
}

/**
 * The document id for [token].
 *
 * Hashed rather than used directly because a document id is not a private
 * place: it appears in index entries, in error messages and in every log line
 * that names the path. A registration token is a credential — anyone holding
 * one can push to that device — so it belongs in a field, not in a key.
 *
 * It also makes re-registration an idempotent overwrite instead of a second
 * row, which is what stops the list growing without bound.
 */
export function deviceIdFor(token: string): string {
  return createHash('sha256').update(token.trim()).digest('hex');
}

function normalisePlatform(value: string | undefined): DevicePlatform {
  const lowered = value?.trim().toLowerCase() ?? '';
  return PLATFORMS.includes(lowered) ? (lowered as DevicePlatform) : 'other';
}

/**
 * Records that [uid] can be reached on this device, or refreshes the record if
 * we already knew.
 *
 * `createdAt` is read before writing so it survives a refresh: it is when we
 * first saw the device, and the freshness signal — the one `pruneStaleDevices`
 * judges — is `lastSeenAt`. Two concurrent syncs could both decide the row is
 * new, which costs a `createdAt` a few milliseconds out and nothing else.
 */
export async function registerDevice(
  uid: string,
  registration: DeviceRegistration,
): Promise<void> {
  const token = registration.token.trim();
  if (token.length === 0) return;

  const ref = devicesCol(uid).doc(deviceIdFor(token));
  const existing = await ref.get();
  await ref.set(
    {
      token,
      platform: normalisePlatform(registration.platform),
      ...(existing.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
      lastSeenAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

/**
 * Releases this device, from both the subcollection and the legacy array.
 *
 * Called on sign-out, and it is the whole reason the subcollection exists. It
 * must never throw at its caller: the user is leaving either way, and a failed
 * release is not a reason to fail the sign-out in front of them.
 */
export async function unregisterDevice(
  uid: string,
  token: string,
): Promise<void> {
  const trimmed = token.trim();
  if (trimmed.length === 0) return;

  await devicesCol(uid).doc(deviceIdFor(trimmed)).delete();
  try {
    // Only touch the legacy array where one exists: `arrayRemove` on a
    // missing field CREATES it as `[]`, which would quietly resurrect a
    // field documented as written by nothing any more, on every sign-out.
    const snap = await userDoc(uid).get();
    const legacy: unknown = snap.get('fcmTokens');
    if (!Array.isArray(legacy) || !legacy.includes(trimmed)) return;
    // `update`, not a merging `set`: a set would create `users/{uid}` for a
    // user who has none, leaving a stub row the crons would page over.
    await userDoc(uid).update({fcmTokens: FieldValue.arrayRemove(trimmed)});
  } catch {
    // No user document, or no legacy array. Nothing to release.
  }
}

/** Where a token was found, so a dead one is removed from the right place. */
interface TokenSources {
  readonly tokens: readonly string[];
  readonly legacy: ReadonlySet<string>;
}

async function collectTokens(uid: string): Promise<TokenSources> {
  const [devices, user] = await Promise.all([
    devicesCol(uid).get(),
    userDoc(uid).get(),
  ]);

  const tokens = new Set<string>();
  for (const doc of devices.docs) {
    const token: unknown = doc.get('token');
    if (typeof token === 'string' && token.length > 0) tokens.add(token);
  }

  const legacy = new Set<string>();
  const stored: unknown = user.get('fcmTokens');
  if (Array.isArray(stored)) {
    for (const token of stored) {
      if (typeof token === 'string' && token.length > 0) {
        legacy.add(token);
        tokens.add(token);
      }
    }
  }

  return {tokens: [...tokens], legacy};
}

/** Every token [uid] can currently be reached on, from both stores. */
export async function listDeviceTokens(uid: string): Promise<string[]> {
  return [...(await collectTokens(uid)).tokens];
}

/**
 * Forgets tokens FCM has told us are dead.
 *
 * Without this the registry grows forever — every reinstall adds one — and
 * eventually every send fans out across a list of mostly-dead entries.
 */
async function dropTokens(
  uid: string,
  tokens: readonly string[],
  legacy: ReadonlySet<string>,
): Promise<void> {
  const batch = db.batch();
  for (const token of tokens) {
    batch.delete(devicesCol(uid).doc(deviceIdFor(token)));
  }
  const fromArray = tokens.filter((t) => legacy.has(t));
  if (fromArray.length > 0) {
    batch.update(userDoc(uid), {
      fcmTokens: FieldValue.arrayRemove(...fromArray),
    });
  }
  await batch.commit();
}

/** Error codes that mean the token is gone for good, not that FCM hiccupped. */
const DEAD_TOKEN_CODES: readonly string[] = [
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
];

/**
 * Sends [payload] to every device [uid] has registered.
 *
 * Never throws: a push is a courtesy, and a failed one must not fail the
 * moderation pass or the cron that triggered it.
 */
export async function sendToUser(
  uid: string,
  payload: PushPayload,
): Promise<void> {
  try {
    const {tokens, legacy} = await collectTokens(uid);
    if (tokens.length === 0) return;

    const response = await getMessaging().sendEachForMulticast({
      tokens: [...tokens],
      notification: {title: payload.title, body: payload.body},
      // `data` is what survives into the tapped-notification handler; the
      // notification block alone cannot carry a destination.
      data: payload.route ? {route: payload.route} : {},
    });

    const dead: string[] = [];
    response.responses.forEach((result, i) => {
      if (DEAD_TOKEN_CODES.includes(result.error?.code ?? '')) {
        const token = tokens[i];
        if (token !== undefined) dead.push(token);
      }
    });
    if (dead.length > 0) await dropTokens(uid, dead, legacy);

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
