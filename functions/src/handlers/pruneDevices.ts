/**
 * `pruneDevices` — drops push registrations nobody is behind any more.
 *
 * FCM expires a token that has gone unused for around 270 days, and a dead one
 * is discovered on the send path (`lib/push.ts`). Neither of those catches the
 * common case: a phone that was replaced, wiped, or had the app deleted. Its
 * row sits in the registry forever, we keep a device identifier for a device
 * that no longer exists, and every send fans out one entry wider than it needs
 * to.
 *
 * SCALE PATTERN: a collection-group query, not a page over `users`. The cron
 * does not care who owns a stale device, and scanning the whole userbase to
 * find the few percent that have one is the expensive way to ask. This needs
 * the COLLECTION_GROUP field override on `devices.lastSeenAt` in
 * `firestore.indexes.json` — without it the query throws FAILED_PRECONDITION
 * at runtime and the cron quietly does nothing.
 *
 * The legacy `fcmTokens` array is deliberately untouched. Those entries carry
 * no timestamp, so there is no honest way to judge their age; they leave on a
 * failed send or on sign-out, never on a guess.
 *
 * It sweeps `notifThreads` on the same schedule and for the same reason: one
 * row per thread a user has been notified about, which would otherwise
 * accumulate for the life of the account. A Firestore TTL policy is the other
 * way to do this and was not taken — TTL fires up to 24 hours late, and it is
 * not implemented by the Firestore emulator, so no integration test could
 * ever cover it. This cron already has the shape, the index override and a
 * test harness.
 */
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {REGION} from '../config';
import {Timestamp, db} from '../lib/firestore';
import {log} from '../lib/logger';

/**
 * How long a device may go unseen before we let it go.
 *
 * `syncUserContext` refreshes `lastSeenAt` on every sign-in and every resume,
 * so any phone still opening the app touches this well inside the window. Two
 * months is long enough that a genuinely idle-but-real user is not silenced,
 * and short enough that we are not holding identifiers for hardware that is in
 * a drawer.
 */
export const STALE_DEVICE_DAYS = 60;

/**
 * How long a thread's notification state outlives its last reply.
 *
 * Only needs to cover the collapse group's own idle window with room to
 * spare — once a group has expired, the row says nothing the next reply
 * would not have decided identically from no row at all.
 */
export const STALE_THREAD_DAYS = 30;

/** Documents deleted per batch. Firestore caps a batch at 500 writes. */
const BATCH_SIZE = 400;

export const pruneDevices = onSchedule(
  {
    region: REGION,
    schedule: 'every day 03:30',
    timeZone: 'UTC',
    memory: '256MiB',
    timeoutSeconds: 540,
    retryCount: 1,
  },
  async () => {
    const cutoff = new Date(
      Date.now() - STALE_DEVICE_DAYS * 24 * 60 * 60 * 1000,
    );
    const removed = await pruneStaleDevices(cutoff);
    const threadCutoff = new Date(
      Date.now() - STALE_THREAD_DAYS * 24 * 60 * 60 * 1000,
    );
    const threads = await pruneStaleThreads(threadCutoff);
    const notifications = await pruneOldNotifications(threadCutoff);
    log.info('pruneDevices.done', {
      cutoff: cutoff.toISOString(),
      removed,
      threads,
      notifications,
    });
  },
);

/**
 * Deletes every device document last seen before [cutoff]. Returns how many.
 *
 * Exported for the integration suite — the scheduled wrapper is untestable,
 * the same arrangement `taperRecalc` makes for `recalcOne`.
 */
export async function pruneStaleDevices(cutoff: Date): Promise<number> {
  const before = Timestamp.fromDate(cutoff);
  let removed = 0;

  for (;;) {
    const page = await db
      .collectionGroup('devices')
      .where('lastSeenAt', '<', before)
      .limit(BATCH_SIZE)
      .get();
    if (page.empty) break;

    const batch = db.batch();
    for (const doc of page.docs) batch.delete(doc.ref);
    await batch.commit();
    removed += page.size;

    // No cursor: the rows this page matched are gone, so the next query
    // starts from what is left. Paging with `startAfter` over a collection
    // being deleted underneath is the version of this that skips documents.
    if (page.size < BATCH_SIZE) break;
  }

  return removed;
}

/**
 * Deletes every thread-notification row whose last reply predates [cutoff].
 *
 * Judged on `lastReplyAtMs`, an epoch number rather than a Timestamp, because
 * that is what the collapse state stores and what `decideNotification` reads.
 * Needs the COLLECTION_GROUP override on `notifThreads.lastReplyAtMs` for the
 * same reason `devices` does — without it this throws FAILED_PRECONDITION at
 * runtime and prunes nothing, silently.
 */
export async function pruneStaleThreads(cutoff: Date): Promise<number> {
  const before = cutoff.getTime();
  let removed = 0;

  for (;;) {
    const page = await db
      .collectionGroup('notifThreads')
      .where('lastReplyAtMs', '<', before)
      .limit(BATCH_SIZE)
      .get();
    if (page.empty) break;

    const batch = db.batch();
    for (const doc of page.docs) batch.delete(doc.ref);
    await batch.commit();
    removed += page.size;

    // Same no-cursor reasoning as `pruneStaleDevices`.
    if (page.size < BATCH_SIZE) break;
  }

  return removed;
}

/**
 * Deletes inbox rows older than [cutoff].
 *
 * The inbox is a record of what happened, not an archive: the app reads one
 * page of it and nothing looks further back. Unbounded growth here would be
 * one document per notification per user, for ever.
 *
 * Needs the COLLECTION_GROUP override on `notifications.createdAtMs`, same as
 * the two sweeps above — without it the query throws FAILED_PRECONDITION at
 * runtime and prunes nothing, silently.
 */
export async function pruneOldNotifications(cutoff: Date): Promise<number> {
  const before = cutoff.getTime();
  let removed = 0;

  for (;;) {
    const page = await db
      .collectionGroup('notifications')
      .where('createdAtMs', '<', before)
      .limit(BATCH_SIZE)
      .get();
    if (page.empty) break;

    const batch = db.batch();
    for (const doc of page.docs) batch.delete(doc.ref);
    await batch.commit();
    removed += page.size;

    if (page.size < BATCH_SIZE) break;
  }

  return removed;
}
