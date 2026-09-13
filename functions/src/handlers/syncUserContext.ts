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
import {enforceAppCheck, REGION} from '../config';
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
 * Inbox rows one call may mark read.
 *
 * Must not be lower than the page the app reads, which is 50
 * (`FirebaseNotificationsRepository._limit`). Opening the inbox marks
 * EVERYTHING on screen read in one call, so a cap below the page size drops
 * the overflow silently: the badge cleared optimistically, the rows past the
 * cap stayed unread on the server, and the number came back on the next
 * launch — for ever, since every open sent the same over-long list.
 */
const MAX_READ_NOTIFICATIONS = 50;

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

/** Document ids from [value], deduped and capped at [limit]. */
function readIdsFrom(value: unknown, limit: number): string[] {
  if (!Array.isArray(value)) return [];
  const ids = new Set<string>();
  for (const entry of value) {
    if (typeof entry !== 'string') continue;
    const id = entry.trim();
    // A document id, not a path: a slash here would let a caller address a
    // subcollection of its own choosing under its notifThreads row.
    if (id.length === 0 || id.length > 200 || id.includes('/')) continue;
    ids.add(id);
    if (ids.size === limit) break;
  }
  return [...ids];
}

export const syncUserContext = onCall(
  {region: REGION, enforceAppCheck, memory: '256MiB'},
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
    const readIds = readIdsFrom(data['readNotifications'], MAX_READ_NOTIFICATIONS);
    if (readIds.length > 0) {
      // Existing rows ONLY, and the read is what makes that true.
      //
      // A merging `set` CREATES the document when the id is unknown, and the
      // row it creates carries `readAtMs` and nothing else — no `createdAtMs`.
      // Such a row is invisible to the app (its query orders by `createdAtMs`,
      // which excludes documents missing the field) AND to
      // `pruneOldNotifications` (whose sweep is `createdAtMs < cutoff`), so it
      // is unreachable and uncollectable, for ever. At 50 ids a call that is a
      // cheap way for a buggy or hostile client to grow someone's subcollection
      // without bound.
      //
      // `batch.update` is not the fix: a Firestore batch is atomic, so one
      // stale id would fail every other mark in the same call. Reading first
      // costs at most 50 gets, once, when somebody opens their inbox.
      const refs = readIds.map((id) => notificationsCol(caller.uid).doc(id));
      const snaps = await db.getAll(...refs);
      const present = snaps.filter((snap) => snap.exists);
      if (present.length > 0) {
        const batch = db.batch();
        const readAtMs = Date.now();
        for (const snap of present) {
          batch.set(snap.ref, {readAtMs}, {merge: true});
        }
        await batch.commit();
      }
    }

    const seen = readIdsFrom(data['readThreads'], MAX_READ_THREADS);
    if (seen.length > 0) {
      // Existing rows only, for exactly the reason the inbox marks above do.
      // A merging `set` on an unknown id CREATES the document, and a
      // `{seenAtMs}`-only row carries no `lastReplyAtMs` — the only field
      // `pruneStaleThreads` sweeps on — so it can never be collected. Twenty
      // client-supplied ids a call is a cheap way to grow this subcollection
      // for ever.
      //
      // Skipping a thread with no row is also correct on its own terms, not
      // just cheaper: the mark exists to reset a collapse GROUP, and
      // `readThreadState` already reads a row without one as "never notified".
      // There is nothing for a seen-mark to reset when no group exists.
      const refs = seen.map((postId) => notifThreadsCol(caller.uid).doc(postId));
      const snaps = await db.getAll(...refs);
      const present = snaps.filter((snap) => snap.exists);
      if (present.length > 0) {
        const batch = db.batch();
        const seenAtMs = Date.now();
        for (const snap of present) {
          // `merge`, and only this field: the rest of the row is collapse
          // state that the client has no business overwriting.
          batch.set(snap.ref, {seenAtMs}, {merge: true});
        }
        await batch.commit();
      }
    }

    return {ok: true};
  },
);
