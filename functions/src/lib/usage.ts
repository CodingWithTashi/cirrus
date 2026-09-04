/**
 * Tier and quota — the two things a client must never be trusted to report.
 *
 * `tierFor` reads the RevenueCat mirror in `users/{uid}.entitlement`, NOT the
 * `profile.tier` the app writes into its own journey document. That field is
 * a display value in a client-owned doc; believing it would let a repackaged
 * client grant itself Premium and unmetered model calls (docs/05 §6).
 *
 * Both counters are transactional. A check-then-write would let two parallel
 * taps each see "4 used" and both spend, which is exactly the shape of bug
 * that turns a $0.25/user/month budget into an incident.
 */
import {ENTITLEMENT_MODE} from '../config';
import {db, userDoc, type UserDoc} from './firestore';
import type {SubscriptionTier} from '../domain/types';

/**
 * True while the app ships with nothing locked. Read this rather than
 * comparing tiers by hand, so the flip to real entitlements is one param.
 */
export function ungated(): boolean {
  return ENTITLEMENT_MODE.value() === 'ungated';
}

export interface QuotaClaim {
  readonly allowed: boolean;
  /** Messages used today AFTER this claim (unchanged when denied). */
  readonly used: number;
  readonly limit: number;
  /**
   * Set only when the refusal was a COOLDOWN rather than a spent allowance —
   * milliseconds still to wait. The two need different words on screen:
   * "come back tomorrow" is wrong for something that clears in ten minutes.
   */
  readonly cooldownMsLeft?: number;
}

/**
 * The trusted tier. Falls back to `free` for every ambiguous case — no
 * entitlement, an unknown tier string, or a lapsed `expiresAt` the webhook
 * hasn't caught up with yet. Failing closed costs a paying user one retry;
 * failing open costs us the paywall.
 */
export async function tierFor(uid: string): Promise<SubscriptionTier> {
  // Pre-monetization: nothing is locked, so skip the read entirely.
  if (ungated()) return 'premium';
  const snap = await userDoc(uid).get();
  return tierOf(snap.data());
}

/**
 * The same reading, for a caller that already holds the document (the
 * nightly crons page through `users/*` and must not pay a second read per
 * user). Pure. Does NOT apply the `ungated` short-circuit — that is the
 * caller's decision, made once per run rather than once per user.
 */
export function tierOf(
  doc: UserDoc | undefined,
  nowMs: number = Date.now(),
): SubscriptionTier {
  const entitlement = doc?.entitlement;
  if (!entitlement) return 'free';
  const expiresAt = entitlement.expiresAt;
  if (expiresAt && expiresAt.toMillis() <= nowMs) return 'free';
  return entitlement.tier === 'premium' || entitlement.tier === 'trial'
    ? entitlement.tier
    : 'free';
}

/**
 * Claims one coach message against the day's allowance (docs/04 §7).
 *
 * The counter resets by `day` mismatch rather than a scheduled wipe, so it
 * rolls over at the USER's local midnight — `todayKey` is already computed in
 * their timezone by the caller.
 */
export async function claimCoachMessage(
  uid: string,
  todayKey: string,
  limit: number,
): Promise<QuotaClaim> {
  return db.runTransaction(async (tx) => {
    const ref = userDoc(uid);
    const snap = await tx.get(ref);
    const usage = (snap.data() as UserDoc | undefined)?.aiUsage;
    const used = usage && usage.day === todayKey ? usage.msgCount : 0;

    if (used >= limit) return {allowed: false, used, limit};

    tx.set(ref, {aiUsage: {day: todayKey, msgCount: used + 1}}, {merge: true});
    return {allowed: true, used: used + 1, limit};
  });
}

/**
 * Gives a coach message back after a failed turn. Nobody pays a quota unit
 * for our outage (docs/03's "the coach refunds the free message" rule).
 *
 * The single implementation. `aiCoachChat` used to carry a private copy, so
 * the tested one never ran in production; that duplication is gone.
 */
export async function refundCoachMessage(
  uid: string,
  todayKey: string,
): Promise<void> {
  await db.runTransaction(async (tx) => {
    const ref = userDoc(uid);
    const snap = await tx.get(ref);
    const usage = (snap.data() as UserDoc | undefined)?.aiUsage;
    if (!usage || usage.day !== todayKey || usage.msgCount <= 0) return;
    tx.set(
      ref,
      {aiUsage: {day: todayKey, msgCount: usage.msgCount - 1}},
      {merge: true},
    );
  });
}

/**
 * Records a panic session and returns the count INCLUDING this one.
 *
 * Post-increment is the contract `panicSession` is written against: its
 * `sessionsToday <= FREE_DAILY_PANIC_SESSIONS` check must be true for a free
 * user's first session of the day (1 <= 1) and false for the second (2 > 1).
 * Returning the pre-increment count here would silently hand free users two
 * AI-backed sessions a day.
 *
 * This never gates the breathing screen — only the AI layer. We do not
 * paywall someone mid-crisis (docs/04 §7).
 */
export async function countPanicSession(
  uid: string,
  todayKey: string,
): Promise<number> {
  return db.runTransaction(async (tx) => {
    const ref = userDoc(uid);
    const snap = await tx.get(ref);
    const usage = (snap.data() as UserDoc | undefined)?.panicUsage;
    const next = (usage && usage.day === todayKey ? usage.count : 0) + 1;

    tx.set(ref, {panicUsage: {day: todayKey, count: next}}, {merge: true});
    return next;
  });
}

/**
 * Which allowance a post spends. An SOS has its own (docs/12 §4.1) so that
 * spending your ordinary posts can never refuse a call for help, and a
 * pinned-for-an-hour SOS still cannot be posted without limit.
 */
export type PostBucket = 'postUsage' | 'sosUsage';

/**
 * Claims one community post against the day's allowance (docs/03 §9,
 * docs/12 §4.1).
 *
 * Replaces createPost's original count-then-write, which was decorative under
 * concurrency: five requests arriving together all read "0 posted" and all
 * proceeded. Same transactional counter as the coach and panic quotas.
 *
 * This also moves the cap from a rolling trailing-24h window to a per-local-day
 * one, which is what docs/03 §9 actually says and matches how every other
 * quota in the app rolls over.
 *
 * [bucket] names the field, so the two allowances share one transactional
 * implementation and cannot drift apart the way two copies would. It is
 * REQUIRED, with no default: the whole point of the split is that an SOS and
 * an ordinary post are different, and a default would let a future caller
 * quietly spend the wrong one.
 *
 * [retryKey], when given, is the client's own id for this attempt. A claim
 * carrying the same key as the last one is a RETRY of it, not a second
 * attempt, and skips the cooldown. `createPost` already returns early for a
 * `clientId` whose document exists — this covers the narrow window where the
 * claim committed and the batch that follows it did not, which would
 * otherwise answer a legitimate "tap to retry" with "your SOS is still up"
 * about a post that never landed.
 *
 * [cooldownMs], when given, additionally refuses a claim made too soon after
 * the last one. It exists for the SOS bucket: an SOS pins to the top of the
 * feed for an hour, so three a day arriving in the same minute is three
 * simultaneous megaphones rather than three calls for help. The timestamp
 * rides the counter the transaction already reads and writes, so it costs no
 * extra read — and it is refused BEFORE the counter moves, so a rejected
 * attempt never spends the day's allowance.
 */
export async function claimDailyPost(
  uid: string,
  todayKey: string,
  limit: number,
  bucket: PostBucket,
  cooldownMs = 0,
  retryKey?: string,
): Promise<QuotaClaim> {
  return db.runTransaction(async (tx) => {
    const ref = userDoc(uid);
    const snap = await tx.get(ref);
    const usage = (snap.data() as UserDoc | undefined)?.[bucket];
    const used = usage !== undefined && usage.day === todayKey ? usage.count : 0;

    if (used >= limit) return {allowed: false, used, limit};

    const now = Date.now();
    // Read UNCONDITIONALLY, never behind the same-day check the counter uses.
    // `lastAtMs` is a wall-clock timestamp and the pin window is wall-clock
    // too; scoping it to the day key meant an SOS at 23:55 and another at
    // 00:05 both passed — two of the same person's posts pinned to the top of
    // the feed at once, which is the exact thing the cooldown exists to stop.
    // The day key also comes from the CLIENT's timezone, so a caller could
    // have flipped it on demand.
    const isRetry =
      retryKey !== undefined && usage?.lastKey === retryKey;
    if (!isRetry && cooldownMs > 0 && typeof usage?.lastAtMs === 'number') {
      const left = usage.lastAtMs + cooldownMs - now;
      // A clock that jumped backwards would otherwise lock someone out for
      // however long the jump was; `left <= cooldownMs` bounds it.
      if (left > 0 && left <= cooldownMs) {
        return {allowed: false, used, limit, cooldownMsLeft: left};
      }
    }

    tx.set(
      ref,
      {
        [bucket]: {
          day: todayKey,
          // A retry re-uses the slot it already spent rather than taking a
          // second one.
          count: isRetry ? used : used + 1,
          lastAtMs: now,
          ...(retryKey !== undefined ? {lastKey: retryKey} : {}),
        },
      },
      {merge: true},
    );
    return {allowed: true, used: isRetry ? used : used + 1, limit};
  });
}
