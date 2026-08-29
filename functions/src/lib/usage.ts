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
import {db, userDoc, type UserDoc} from './firestore';
import type {SubscriptionTier} from '../domain/types';

export interface QuotaClaim {
  readonly allowed: boolean;
  /** Messages used today AFTER this claim (unchanged when denied). */
  readonly used: number;
  readonly limit: number;
}

/**
 * The trusted tier. Falls back to `free` for every ambiguous case — no
 * entitlement, an unknown tier string, or a lapsed `expiresAt` the webhook
 * hasn't caught up with yet. Failing closed costs a paying user one retry;
 * failing open costs us the paywall.
 */
export async function tierFor(uid: string): Promise<SubscriptionTier> {
  const snap = await userDoc(uid).get();
  const entitlement = (snap.data() as UserDoc | undefined)?.entitlement;
  if (!entitlement) return 'free';

  const expiresAt = entitlement.expiresAt;
  if (expiresAt && expiresAt.toMillis() <= Date.now()) return 'free';

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
 * Exported for handlers that need it; `aiCoachChat` currently carries its own
 * copy — if you touch one, reconcile the other.
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
