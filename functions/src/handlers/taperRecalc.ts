/**
 * `taperRecalc` — the nightly adaptive layer (docs/03 §3.3, docs/05 §7).
 *
 * SCALE PATTERN: the naive version ("every night, scan all users") both
 * ignores timezones and turns into a full-collection scan. Instead each user
 * carries `recalcHourUtc` — the UTC hour their local 01:00 falls in — and
 * this runs hourly against a single equality query. One index, ~1/24th of the
 * userbase per run, and every user is processed just after THEIR midnight.
 *
 * WRITES GO TO `users/{uid}.planAdvice`, never to `journeys/{uid}` — the app
 * overwrites that document wholesale on every puff tap. The client reads the
 * advice and folds it into its own next write.
 */
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {REGION} from '../config';
import {db, FieldValue, journeyDoc, userDoc} from '../lib/firestore';
import {log} from '../lib/logger';
import {decodeJourney, JourneyDecodeError} from '../domain/journeyCodec';
import {dayKeyIn} from '../domain/dateKey';
import {trailingDays} from '../domain/streakEngine';
import {adviseTomorrow, dayNumber} from '../domain/taperEngine';
import {totalDays} from '../domain/types';

/** Users handled per scheduled run before paging. Keeps memory flat. */
const PAGE_SIZE = 500;

export const taperRecalc = onSchedule(
  {
    region: REGION,
    schedule: 'every 1 hours',
    timeZone: 'UTC',
    memory: '512MiB',
    timeoutSeconds: 540,
    retryCount: 1,
  },
  async () => {
    const hourUtc = new Date().getUTCHours();
    let processed = 0;
    let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;

    for (;;) {
      let query = db
        .collection('users')
        .where('recalcHourUtc', '==', hourUtc)
        .orderBy('__name__')
        .limit(PAGE_SIZE);
      if (cursor) query = query.startAfter(cursor);

      const page = await query.get();
      if (page.empty) break;

      // Sequential within a page on purpose: a 500-wide Promise.all against
      // Firestore is how you find the connection pool limit in production.
      for (const doc of page.docs) {
        try {
          await recalcOne(doc.id, (doc.get('tz') as string | undefined) ?? 'UTC');
          processed++;
        } catch (error) {
          // One bad journey must not abort the batch.
          log.warn('taperRecalc.user_failed', {uid: doc.id, error: String(error)});
        }
      }

      cursor = page.docs.at(-1);
      if (page.size < PAGE_SIZE) break;
    }

    log.info('taperRecalc.done', {hourUtc, processed});
  },
);

async function recalcOne(uid: string, timeZone: string): Promise<void> {
  const snap = await journeyDoc(uid).get();
  if (!snap.exists) return;

  let journey;
  try {
    journey = decodeJourney(snap.data());
  } catch (error) {
    if (error instanceof JourneyDecodeError) return; // not onboarded / malformed
    throw error;
  }

  const todayKey = dayKeyIn(new Date(), timeZone);
  const day = dayNumber(journey.plan, todayKey);
  // Past Freedom Day the plan is over; maintenance mode has no limit to bend.
  if (day < 1 || day > totalDays(journey.plan)) return;

  const window = trailingDays(journey.days, todayKey, 3).map((d) => ({
    puffs: d.puffs,
    limit: d.limit,
  }));
  const lastTwo = window.slice(-2);
  const strugglingTwoDays =
    lastTwo.length === 2 &&
    lastTwo.every((d) => d.limit > 0 && d.puffs / d.limit > 1.1);

  const advice = adviseTomorrow(journey.plan, day, window, strugglingTwoDays);

  await userDoc(uid).set(
    {
      planAdvice: {
        forDay: todayKey,
        limit: advice.limitTomorrow,
        adherence: advice.adherence,
        stretchDelta: advice.stretchDelta,
        computedAt: FieldValue.serverTimestamp(),
      },
    },
    {merge: true},
  );
}

/**
 * The UTC hour matching 01:00 local for [timeZone]. Call this whenever a
 * user's tz is written so `recalcHourUtc` stays correct across DST.
 */
export function recalcHourUtcFor(timeZone: string, now = new Date()): number {
  const localHour = Number.parseInt(
    new Intl.DateTimeFormat('en-GB', {timeZone, hour: '2-digit', hour12: false}).format(now),
    10,
  );
  return (now.getUTCHours() - localHour + 1 + 48) % 24;
}
