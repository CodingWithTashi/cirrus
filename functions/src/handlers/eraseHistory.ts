/**
 * `eraseHistory` — the server half of "start a new plan from scratch".
 *
 * The new-plan screen offers two ways forward: keep everything (the default,
 * and the brand's "nothing resets"), or erase the history and begin again on
 * the same account. The journey itself is client-owned (`journeys/{uid}` is
 * written whole by the app), so the app wipes that; what lives here is the
 * server's own record of the same history, which the rules never let a client
 * touch — hence a callable.
 *
 * Erased, all of it, with no partial version — "from scratch" means the
 * whole history, and each of these is a record of it:
 *   - `cravings/*`      — every panic session.
 *   - `insights/*`      — weekly reports written about those weeks.
 *   - `planAdvice`      — last night's verdict, on the plan being replaced.
 *   - `coachMessages/*` — the coach transcript.
 *   - `coachSummary`    — the rolling summary of it.
 *   - `memories/*`      — everything the coach remembered.
 * The coach's three go together for a reason of their own: a transcript gone
 * while its summary and memories stay is a coach quoting back a journey the
 * person asked to forget.
 *
 * NEVER erased — the person is still here, on the same account:
 *   - `entitlement`, `coachName`, `pushPrefs`, `tz`/`locale`, `devices/*`.
 *   - `aiUsage` and the posting/SOS allowances. Erasing a counter would let
 *     anyone refill a free cap on demand.
 *   - `coachMemoriesSeeded`. The onboarding sentence was remembered once;
 *     forgetting everything must not quietly re-seed it on the next launch.
 *   - Community posts, replies, the author mirror and the notification inbox.
 *     Other people are reading those threads; erasing an account is what
 *     anonymizes them (`deleteUserData`), and that is a different decision.
 *
 * Idempotent: a retry after a partial failure finishes the job. The app waits
 * for this to answer before it changes anything locally, so a failure leaves
 * both sides exactly as they were.
 */
import {onCall} from 'firebase-functions/v2/https';
import {enforceAppCheck, REGION} from '../config';
import {coachMessages, cravingsCol, db, FieldValue, userDoc} from '../lib/firestore';
import {requireCaller} from '../lib/guards';
import {log} from '../lib/logger';

export const eraseHistory = onCall(
  {region: REGION, enforceAppCheck, memory: '512MiB', timeoutSeconds: 300},
  async (request): Promise<{erased: true}> => {
    const {uid} = requireCaller(request);

    await eraseUserHistory(uid);

    log.info('eraseHistory.done', {uid});
    return {erased: true};
  },
);

/**
 * The erase itself, apart from the callable so a test can drive it directly.
 *
 * Subcollections first, the document fields last: the fields are one merge
 * write that cannot half-happen, so if a sweep above throws, the retry still
 * finds everything it needs to finish.
 */
export async function eraseUserHistory(uid: string): Promise<void> {
  const user = userDoc(uid);
  await db.recursiveDelete(cravingsCol(uid));
  await db.recursiveDelete(user.collection('insights'));
  await db.recursiveDelete(coachMessages(uid));
  await db.recursiveDelete(user.collection('memories'));
  await user.set(
    {
      planAdvice: FieldValue.delete(),
      coachSummary: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}
