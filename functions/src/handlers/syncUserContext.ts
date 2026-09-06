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
import {
  FieldValue,
  db,
  notifThreadsCol,
  notificationsCol,
  userDoc,
} from '../lib/firestore';
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

/** Threads whose seen-marks one call may clear. Bounded, like everything here. */
const MAX_READ_THREADS = 20;

/**
 * The push preferences a client is allowed to set.
 *
 * Whitelisted rather than merged wholesale: this writes into the
 * server-owned document, and "whatever the client sent, under `pushPrefs`"
 * would be a place to smuggle arbitrary keys into a row the app is otherwise
 * forbidden to touch.
 */
const BOOLEAN_PREFS: readonly string[] = [
  'all',
  'communityReply',
  'communityMention',
  'insightReady',
  'promo',
];

const HOUR_PREFS: readonly string[] = ['quietStart', 'quietEnd'];

function pushPrefsFrom(value: unknown): Record<string, boolean | number> | null {
  if (typeof value !== 'object' || value === null) return null;
  const source = value as Record<string, unknown>;
  const prefs: Record<string, boolean | number> = {};
  for (const key of BOOLEAN_PREFS) {
    if (typeof source[key] === 'boolean') prefs[key] = source[key];
  }
  for (const key of HOUR_PREFS) {
    const hour = source[key];
    if (typeof hour === 'number' && Number.isInteger(hour) && hour >= 0 && hour <= 24) {
      prefs[key] = hour;
    }
  }
  return Object.keys(prefs).length > 0 ? prefs : null;
}

/** Post ids from [value], deduped and capped. */
function readThreadsFrom(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  const ids = new Set<string>();
  for (const entry of value) {
    if (typeof entry !== 'string') continue;
    const id = entry.trim();
    // A document id, not a path: a slash here would let a caller address a
    // subcollection of its own choosing under its notifThreads row.
    if (id.length === 0 || id.length > 200 || id.includes('/')) continue;
    ids.add(id);
    if (ids.size === MAX_READ_THREADS) break;
  }
  return [...ids];
}

export const syncUserContext = onCall(
  {region: REGION, enforceAppCheck: true, memory: '256MiB'},
  async (request): Promise<{ok: true}> => {
    const caller = requireCaller(request);
    const data = (request.data ?? {}) as Record<string, unknown>;

    // Push preferences live here, on the server, because the SERVER is what
    // decides to send. A preference kept only on the device can silence the
    // locally scheduled reminders and nothing else — which is exactly what
    // `notificationsOn` used to do, leaving every server push arriving after
    // the user had switched notifications off.
    const prefs = pushPrefsFrom(data['pushPrefs']);

    await userDoc(caller.uid).set(
      {
        tz: caller.timeZone,
        locale: caller.locale,
        // Keeps the nightly crons firing just after the user's own midnight,
        // and re-derives across DST every time the app syncs.
        recalcHourUtc: recalcHourUtcFor(caller.timeZone),
        ...(prefs ? {pushPrefs: prefs} : {}),
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

    // Threads the user has opened since we last heard from them. Marking one
    // seen is what lets the next reply start a fresh notification group
    // rather than adding to a count they have already read.
    //
    // It rides this call rather than a `markThreadSeen` callable of its own
    // for two reasons: `users/{uid}` is server-write-only, so the client
    // cannot write the field directly without punching a hole in the one
    // rule that keeps entitlement safe; and a dedicated callable would mean
    // an App Check round trip every time somebody opens a thread, often on
    // the cold network a notification tap arrives over.
    // Notifications the reader has opened, or cleared in one go from the
    // inbox. Same door and same reasoning as `readThreads` below it.
    const readIds = readThreadsFrom(data['readNotifications']);
    if (readIds.length > 0) {
      const batch = db.batch();
      const readAtMs = Date.now();
      for (const id of readIds) {
        batch.set(
          notificationsCol(caller.uid).doc(id),
          {readAtMs},
          {merge: true},
        );
      }
      await batch.commit();
    }

    const seen = readThreadsFrom(data['readThreads']);
    if (seen.length > 0) {
      const batch = db.batch();
      const seenAtMs = Date.now();
      for (const postId of seen) {
        // `merge`, and only this field: the rest of the row is collapse
        // state that the client has no business overwriting.
        batch.set(notifThreadsCol(caller.uid).doc(postId), {seenAtMs}, {merge: true});
      }
      await batch.commit();
    }

    return {ok: true};
  },
);
