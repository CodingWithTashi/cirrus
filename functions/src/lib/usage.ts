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
/**
 * The allowance window a claim belongs to, which only ever moves FORWARD.
 *
 * The day key is derived from the timezone the CLIENT declares on every
 * request, and `normalizeTimeZone` accepts any real IANA zone — so a caller
 * can move its own "today" across a 26-hour spread at will. A usage row
 * remembers exactly one day, so flipping zones reset the counter in BOTH
 * directions: exhaust the cap in Kiritimati (UTC+14), claim a fresh one in
 * Niue (UTC-11), flip back, and get another. Not twice the allowance —
 * unbounded, on the gates that cost real money per call.
 *
 * A key EARLIER than the stored one therefore keeps the stored window, so a
 * flip buys nothing; a genuinely later key — a real midnight, anywhere —
 * resets exactly as before. Someone who truly flies east to west waits at most
 * one extra day for their reset and is never given less than they already had.
 *
 * The other half of this was already understood: [claimDailyPost] reads the SOS
 * `lastAtMs` unconditionally precisely "because the day key also comes from the
 * CLIENT's timezone, so a caller could have flipped it on demand". The counter
 * needed the same suspicion.
 *
 * Keys are `yyyy-MM-dd`, so a string compare is a chronological one.
 */
function windowFor(storedDay: string | undefined, todayKey: string): string {
  return storedDay !== undefined && todayKey < storedDay ? storedDay : todayKey;
}

export async function claimCoachMessage(
  uid: string,
  todayKey: string,
  limit: number,
): Promise<QuotaClaim> {
  return db.runTransaction(async (tx) => {
    const ref = userDoc(uid);
    const snap = await tx.get(ref);
    const usage = (snap.data() as UserDoc | undefined)?.aiUsage;
    const day = windowFor(usage?.day, todayKey);
    const used = usage !== undefined && usage.day === day ? usage.msgCount : 0;

    if (used >= limit) return {allowed: false, used, limit};

    tx.set(ref, {aiUsage: {day, msgCount: used + 1}}, {merge: true});
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
/**
 * Spends one PANIC message — the free tier's allowance on top of its five.
 *
 * docs/04 §7 specifies "5 coach msgs/day + 1 panic session/day", and the panic
 * half existed only as a number `panicSession` returned to the client and
 * nothing ever enforced: `aiCoachChat` claimed an ordinary coach message for
 * every turn, panic or not. So the one moment the product exists for — someone
 * at 9/10 intensity tapping the option the loop screen had just told them was
 * available — answered "you've used your 5 messages for today".
 *
 * Its own counter, on its own key, so it can neither be drained by ordinary
 * chat nor drain it. Returns false when the panic allowance is spent, and the
 * caller then falls back to the ordinary one rather than refusing outright —
 * a paid-for message is still a message, and nobody is turned away mid-craving
 * while they have any allowance left at all.
 *
 * Forward-only on the window, like every other claim here; see [windowFor].
 */
export async function claimPanicMessage(
  uid: string,
  todayKey: string,
  limit: number,
): Promise<boolean> {
  if (limit <= 0) return false;
  return db.runTransaction(async (tx) => {
    const ref = userDoc(uid);
    const snap = await tx.get(ref);
    const usage = (snap.data() as UserDoc | undefined)?.panicMsgUsage;
    const day = windowFor(usage?.day, todayKey);
    const used = usage !== undefined && usage.day === day ? usage.count : 0;
    if (used >= limit) return false;
    tx.set(ref, {panicMsgUsage: {day, count: used + 1}}, {merge: true});
    return true;
  });
}

/**
 * Gives a panic message back after a failed turn — the panic-allowance twin of
 * [refundCoachMessage], and for the same reason: nobody pays for our outage.
 *
 * Strict key compare, like its sibling, and for the same reason: it is not
 * client-callable, and widening it would hand out a free message to a window
 * it never spent from.
 */
export async function refundPanicMessage(
  uid: string,
  todayKey: string,
): Promise<void> {
  await db.runTransaction(async (tx) => {
    const ref = userDoc(uid);
    const snap = await tx.get(ref);
    const usage = (snap.data() as UserDoc | undefined)?.panicMsgUsage;
    if (!usage || usage.day !== todayKey || usage.count <= 0) return;
    tx.set(
      ref,
      {panicMsgUsage: {day: todayKey, count: usage.count - 1}},
      {merge: true},
    );
  });
}

export async function refundCoachMessage(
  uid: string,
  todayKey: string,
): Promise<void> {
  await db.runTransaction(async (tx) => {
    const ref = userDoc(uid);
    const snap = await tx.get(ref);
    const usage = (snap.data() as UserDoc | undefined)?.aiUsage;
    // Deliberately the RAW key, and deliberately NOT [windowFor]: a refund
    // must only ever touch the window it spent from. Widening it to match the
    // stored window would let a refund arriving after local midnight decrement
    // the new day's allowance, which is the free message the strict compare
    // exists to refuse. Nothing client-callable reaches here — only
    // `aiCoachChat`, on its own model failure, with the key it claimed under —
    // so this needs no defence against a chosen timezone.
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
    // Forward-only, like every other window here — this one narrows the AI
    // option for the rest of the day, so a flip would widen it again.
    const day = windowFor(usage?.day, todayKey);
    const next = (usage !== undefined && usage.day === day ? usage.count : 0) + 1;

    tx.set(ref, {panicUsage: {day, count: next}}, {merge: true});
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
    // Forward-only, for the reason spelled out on [windowFor]: the day key is
    // the client's to choose, and one stored day made flipping zones a reset.
    const day = windowFor(usage?.day, todayKey);
    const used = usage !== undefined && usage.day === day ? usage.count : 0;

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
          day,
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
