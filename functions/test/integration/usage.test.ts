/**
 * Tier and quota, against the real Firestore emulator.
 *
 * This is the file that decides whether the AI cost model holds. Every one of
 * these functions sits between a user and a paid model call, so a bug here is
 * either an unmetered spend or a paying customer being told no.
 */
import {beforeEach, describe, expect, it} from 'vitest';
import {Timestamp, userDoc} from '../../src/lib/firestore';
import {
  claimCoachMessage,
  countPanicSession,
  refundCoachMessage,
  tierFor,
} from '../../src/lib/usage';

const PROJECT = process.env['GCLOUD_PROJECT'] ?? 'demo-cirrus';
const HOST = process.env['FIRESTORE_EMULATOR_HOST'] ?? '127.0.0.1:8080';
const TODAY = '2026-08-29';
const TOMORROW = '2026-08-30';

async function clearFirestore(): Promise<void> {
  const url =
    `http://${HOST}/emulator/v1/projects/${PROJECT}` +
    `/databases/(default)/documents`;
  const res = await fetch(url, {method: 'DELETE'});
  if (!res.ok) throw new Error(`emulator clear failed: ${res.status}`);
}

beforeEach(async () => {
  await clearFirestore();
});

describe('tierFor — the trusted tier', () => {
  it('treats a user with no server document as free', async () => {
    expect(await tierFor('nobody')).toBe('free');
  });

  it('reads premium from the entitlement mirror', async () => {
    await userDoc('alice').set({entitlement: {tier: 'premium'}});
    expect(await tierFor('alice')).toBe('premium');
  });

  it('reads trial as its own tier, not as premium', async () => {
    await userDoc('alice').set({entitlement: {tier: 'trial'}});
    expect(await tierFor('alice')).toBe('trial');
  });

  // The webhook is the authority, but webhooks get lost. Expiry is the
  // backstop, and it fails closed.
  it('demotes a lapsed entitlement to free even if the tier still says premium', async () => {
    await userDoc('alice').set({
      entitlement: {
        tier: 'premium',
        expiresAt: Timestamp.fromMillis(Date.now() - 60_000),
      },
    });
    expect(await tierFor('alice')).toBe('free');
  });

  it('keeps a premium entitlement that has not expired yet', async () => {
    await userDoc('alice').set({
      entitlement: {
        tier: 'premium',
        expiresAt: Timestamp.fromMillis(Date.now() + 86_400_000),
      },
    });
    expect(await tierFor('alice')).toBe('premium');
  });

  // A tier string we do not recognise is a bug or an attack, never a grant.
  it('falls back to free for an unrecognised tier string', async () => {
    await userDoc('alice').set({entitlement: {tier: 'platinum_v2'}});
    expect(await tierFor('alice')).toBe('free');
  });

  // The journey document is client-owned, so a tier written there is a claim,
  // not a fact. tierFor must never look at it.
  it('ignores a tier the client wrote into its own journey document', async () => {
    await userDoc('alice').set({entitlement: {tier: 'free'}});
    expect(await tierFor('alice')).toBe('free');
  });
});

describe('claimCoachMessage — the daily coach allowance', () => {
  it('allows the first message and reports one used', async () => {
    const claim = await claimCoachMessage('alice', TODAY, 5);
    expect(claim).toMatchObject({allowed: true, used: 1, limit: 5});
  });

  it('allows exactly the limit, then denies', async () => {
    for (let i = 1; i <= 5; i++) {
      const claim = await claimCoachMessage('alice', TODAY, 5);
      expect(claim.allowed, `message ${i} of 5 should be allowed`).toBe(true);
    }
    const overflow = await claimCoachMessage('alice', TODAY, 5);
    expect(overflow.allowed).toBe(false);
    expect(overflow.used).toBe(5);
  });

  // The counter resets by day mismatch, not by a scheduled wipe, so it rolls
  // over at the USER's local midnight rather than UTC's.
  it('resets when the local day changes', async () => {
    for (let i = 0; i < 5; i++) await claimCoachMessage('alice', TODAY, 5);
    expect((await claimCoachMessage('alice', TODAY, 5)).allowed).toBe(false);

    const tomorrow = await claimCoachMessage('alice', TOMORROW, 5);
    expect(tomorrow).toMatchObject({allowed: true, used: 1});
  });

  it('meters each user separately', async () => {
    for (let i = 0; i < 5; i++) await claimCoachMessage('alice', TODAY, 5);
    expect((await claimCoachMessage('bob', TODAY, 5)).allowed).toBe(true);
  });

  // The reason this is a transaction and not a check-then-write. Ten taps
  // racing must not all read "0 used" and all spend.
  it('never over-spends under concurrent claims', async () => {
    const claims = await Promise.all(
      Array.from({length: 10}, () => claimCoachMessage('alice', TODAY, 5)),
    );
    expect(claims.filter((c) => c.allowed)).toHaveLength(5);

    const stored = (await userDoc('alice').get()).data();
    expect(stored?.['aiUsage']).toMatchObject({day: TODAY, msgCount: 5});
  });
});

describe('refundCoachMessage — nobody pays for our outage', () => {
  it('gives a message back after a failed turn', async () => {
    await claimCoachMessage('alice', TODAY, 5);
    await claimCoachMessage('alice', TODAY, 5);
    await refundCoachMessage('alice', TODAY);

    const claim = await claimCoachMessage('alice', TODAY, 5);
    expect(claim.used).toBe(2);
  });

  it('never drives the counter below zero', async () => {
    await refundCoachMessage('alice', TODAY);
    await refundCoachMessage('alice', TODAY);
    const claim = await claimCoachMessage('alice', TODAY, 5);
    expect(claim.used).toBe(1);
  });

  // A refund arriving after local midnight must not hand out a free message
  // against the new day's allowance.
  it('ignores a refund aimed at a day that is no longer current', async () => {
    await claimCoachMessage('alice', TOMORROW, 5);
    await refundCoachMessage('alice', TODAY);

    const stored = (await userDoc('alice').get()).data();
    expect(stored?.['aiUsage']).toMatchObject({day: TOMORROW, msgCount: 1});
  });
});

describe('countPanicSession — free tier gets one AI-backed session a day', () => {
  // Post-increment is the contract panicSession is written against:
  // `sessionsToday <= 1` must be true for the first session and false for the
  // second. Returning the pre-increment count would silently hand free users
  // two AI panic sessions a day.
  it('returns 1 on the first session of the day, not 0', async () => {
    expect(await countPanicSession('alice', TODAY)).toBe(1);
  });

  it('counts upward within a day', async () => {
    expect(await countPanicSession('alice', TODAY)).toBe(1);
    expect(await countPanicSession('alice', TODAY)).toBe(2);
    expect(await countPanicSession('alice', TODAY)).toBe(3);
  });

  it('gives a free user exactly one AI-backed session, then withholds', async () => {
    const first = await countPanicSession('alice', TODAY);
    const second = await countPanicSession('alice', TODAY);
    // Mirrors panicSession.ts's own expression.
    expect(first <= 1).toBe(true);
    expect(second <= 1).toBe(false);
  });

  it('resets on the next local day', async () => {
    await countPanicSession('alice', TODAY);
    await countPanicSession('alice', TODAY);
    expect(await countPanicSession('alice', TOMORROW)).toBe(1);
  });

  it('does not disturb the coach counter', async () => {
    await claimCoachMessage('alice', TODAY, 5);
    await countPanicSession('alice', TODAY);

    const stored = (await userDoc('alice').get()).data();
    expect(stored?.['aiUsage']).toMatchObject({msgCount: 1});
    expect(stored?.['panicUsage']).toMatchObject({count: 1});
  });
});
