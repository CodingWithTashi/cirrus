/**
 * The three callables that had no test: `panicSession`, `syncUserContext` and
 * `reportReply`.
 *
 * Two of them are load-bearing in ways that are invisible when they break.
 * `syncUserContext` is the ONLY writer of `users/{uid}` from the app, so until
 * it runs the document does not exist and both nightly crons page over an
 * empty collection forever — the least visible call in the product and one of
 * the most important. `panicSession` is the only thing that counts cravings,
 * and it runs while somebody is mid-craving, so its failure mode has to be a
 * quieter app rather than a broken one.
 */
import {beforeEach, describe, expect, it} from 'vitest';
import type {CallableRequest} from 'firebase-functions/v2/https';
import {panicSession} from '../../src/handlers/panicSession';
import {syncUserContext} from '../../src/handlers/syncUserContext';
import {reportReply} from '../../src/handlers/reportReply';
import {db, postsCol, userDoc} from '../../src/lib/firestore';

const PROJECT = process.env['GCLOUD_PROJECT'] ?? 'demo-cirrus';
const HOST = process.env['FIRESTORE_EMULATOR_HOST'] ?? '127.0.0.1:8080';

async function clearFirestore(): Promise<void> {
  const url =
    `http://${HOST}/emulator/v1/projects/${PROJECT}` +
    `/databases/(default)/documents`;
  const res = await fetch(url, {method: 'DELETE'});
  if (!res.ok) throw new Error(`emulator clear failed: ${res.status}`);
}

function caller(
  data: Record<string, unknown> = {},
  uid = 'alice',
  timeZone = 'America/Toronto',
): CallableRequest<unknown> {
  return {
    data: {timeZone, locale: 'en-CA', ...data},
    auth: {uid, token: {}},
    rawRequest: {},
    acceptsStreaming: false,
  } as unknown as CallableRequest<unknown>;
}

beforeEach(async () => {
  await clearFirestore();
});

describe('syncUserContext', () => {
  it('creates the row both crons page over', async () => {
    // Before this ran even once, `users` was empty for everybody and
    // `taperRecalc` / `weeklyInsight` silently did nothing, forever.
    expect((await userDoc('alice').get()).exists).toBe(false);

    await syncUserContext.run(caller());

    const snap = await userDoc('alice').get();
    expect(snap.exists).toBe(true);
    expect(snap.get('tz')).toBe('America/Toronto');
    expect(snap.get('locale')).toBe('en-CA');
  });

  it('derives the cron hour from the caller timezone', async () => {
    // The crons fan out by UTC hour, so this number is what makes a user's
    // report arrive on THEIR Sunday rather than UTC's.
    await syncUserContext.run(caller({}, 'alice', 'Asia/Tokyo'));
    await syncUserContext.run(caller({}, 'bob', 'America/Los_Angeles'));

    const tokyo = (await userDoc('alice').get()).get('recalcHourUtc');
    const la = (await userDoc('bob').get()).get('recalcHourUtc');
    expect(tokyo).toBeTypeOf('number');
    expect(la).toBeTypeOf('number');
    expect(tokyo).not.toBe(la);
  });

  it('collects an FCM token without duplicating it', async () => {
    await syncUserContext.run(caller({fcmToken: 'device-1'}));
    await syncUserContext.run(caller({fcmToken: 'device-1'}));
    await syncUserContext.run(caller({fcmToken: 'device-2'}));

    expect((await userDoc('alice').get()).get('fcmTokens')).toEqual([
      'device-1',
      'device-2',
    ]);
  });

  it('does not write an empty token', async () => {
    await syncUserContext.run(caller({fcmToken: ''}));
    expect((await userDoc('alice').get()).get('fcmTokens')).toBeUndefined();
  });

  it('never clobbers the server-owned fields beside it', async () => {
    // `users/{uid}` is shared with entitlement, aiUsage and planAdvice. A
    // non-merging write here would revoke a paying customer on every launch.
    await userDoc('alice').set({
      entitlement: {tier: 'premium'},
      aiUsage: {day: '2026-08-30', msgCount: 3},
    });
    await syncUserContext.run(caller({fcmToken: 'device-1'}));

    const snap = await userDoc('alice').get();
    expect(snap.get('entitlement').tier).toBe('premium');
    expect(snap.get('aiUsage').msgCount).toBe(3);
  });

  it('refuses an unauthenticated caller', async () => {
    await expect(
      syncUserContext.run({
        data: {},
        auth: undefined,
        rawRequest: {},
      } as unknown as CallableRequest<unknown>),
    ).rejects.toThrow();
  });
});

describe('panicSession', () => {
  it('counts the session and answers availability', async () => {
    const first = await panicSession.run(caller());
    expect(first.sessionsToday).toBe(1);
    expect(first.aiAvailable).toBe(true);
  });

  it('counts each session, so the free allowance is enforceable', async () => {
    await panicSession.run(caller());
    const second = await panicSession.run(caller());
    expect(second.sessionsToday).toBe(2);
  });

  it('closes the AI option for a free user past their one session', async () => {
    // docs/04 §7 — ONE AI-backed session a day on free. `countPanicSession`
    // is post-increment, so the first call already reports 1: the session
    // being opened is the one being allowed, and the next is over the line.
    //
    // The answer only ever narrows the AI option. It never blocks the panic
    // flow, which has to work mid-craving whatever the tier says.
    await userDoc('alice').set({entitlement: {tier: 'free'}});
    const first = await panicSession.run(caller());
    const second = await panicSession.run(caller());

    expect(first.sessionsToday).toBe(1);
    expect(first.aiAvailable).toBe(true);
    expect(second.sessionsToday).toBe(2);
    expect(second.aiAvailable).toBe(false);
  });

  it('keeps the AI option open for premium however many times they need it', async () => {
    await userDoc('alice').set({entitlement: {tier: 'premium'}});
    for (let i = 0; i < 5; i++) await panicSession.run(caller());
    expect((await panicSession.run(caller())).aiAvailable).toBe(true);
  });

  it('records a survived craving with its intensity', async () => {
    await panicSession.run(caller({outcome: 'survived', intensity: 8}));

    const cravings = await userDoc('alice').collection('cravings').get();
    expect(cravings.size).toBe(1);
    expect(cravings.docs[0]?.get('outcome')).toBe('survived');
    expect(cravings.docs[0]?.get('intensity')).toBe(8);
  });

  it('records a slip just as plainly as a win', async () => {
    await panicSession.run(caller({outcome: 'slipped', intensity: 9}));
    const cravings = await userDoc('alice').collection('cravings').get();
    expect(cravings.docs[0]?.get('outcome')).toBe('slipped');
  });

  it('accepts a session that never reports an outcome', async () => {
    // The app can be killed mid-craving. That is an ordinary end to a
    // session, not an error.
    await panicSession.run(caller());
    expect((await userDoc('alice').collection('cravings').get()).size).toBe(0);
  });

  it('ignores an outcome it does not recognise', async () => {
    await panicSession.run(caller({outcome: 'exploded'}));
    expect((await userDoc('alice').collection('cravings').get()).size).toBe(0);
  });
});

describe('reportReply', () => {
  async function seedReply(status = 'live'): Promise<void> {
    await postsCol().doc('p1').set({alias: 'a', text: 'post', status: 'live'});
    await postsCol().doc('p1').collection('replies').doc('r9').set({
      alias: 'nightbee',
      text: 'just buy the 50mg ones',
      status,
    });
  }

  it('raises the count and files a flag the queue can read', async () => {
    // The button used to be a snackbar and nothing else: the app said the
    // report was filed and filed none, on the one surface Guideline 1.2 is
    // actually about.
    await seedReply();
    await reportReply.run(caller({postId: 'p1', replyId: 'r9'}));

    const reply = await postsCol()
      .doc('p1').collection('replies').doc('r9').get();
    expect(reply.get('reportCount')).toBe(1);

    const flag = await db.collection('moderation').doc('r9').get();
    expect(flag.exists).toBe(true);
    expect(flag.get('kind')).toBe('reply');
    expect(flag.get('postId')).toBe('p1');
    expect(flag.get('replyId')).toBe('r9');
    expect(flag.get('reviewed')).toBe(false);
  });

  it('counts one reporter once, however many times they tap', async () => {
    // A counter that gates a decision has to be keyed by the thing it counts.
    // Without this, one angry reader could drive a reply to the auto-hide
    // threshold alone.
    await seedReply();
    await reportReply.run(caller({postId: 'p1', replyId: 'r9'}));
    await reportReply.run(caller({postId: 'p1', replyId: 'r9'}));
    await reportReply.run(caller({postId: 'p1', replyId: 'r9'}));

    const reply = await postsCol()
      .doc('p1').collection('replies').doc('r9').get();
    expect(reply.get('reportCount')).toBe(1);
    expect(reply.get('status')).toBe('live');
  });

  it('hides a reply pending review once three different readers report it', async () => {
    await seedReply();
    for (const uid of ['alice', 'bob', 'carol']) {
      await reportReply.run(caller({postId: 'p1', replyId: 'r9'}, uid));
    }

    const reply = await postsCol()
      .doc('p1').collection('replies').doc('r9').get();
    expect(reply.get('reportCount')).toBe(3);
    // Pending, never deleted: the founder still has to be able to read it and
    // disagree.
    expect(reply.get('status')).toBe('pending');
  });

  it('refuses a reply that does not exist', async () => {
    await postsCol().doc('p1').set({alias: 'a', text: 'post', status: 'live'});
    await expect(
      reportReply.run(caller({postId: 'p1', replyId: 'ghost'})),
    ).rejects.toThrow();
  });

  it('refuses an unauthenticated caller', async () => {
    await seedReply();
    await expect(
      reportReply.run({
        data: {postId: 'p1', replyId: 'r9'},
        auth: undefined,
        rawRequest: {},
      } as unknown as CallableRequest<unknown>),
    ).rejects.toThrow();
  });

  it('never touches the reply text or its author', async () => {
    // The whole reason this is a callable rather than a client write: a
    // reader may raise a count, and nothing else.
    await seedReply();
    await reportReply.run(caller({postId: 'p1', replyId: 'r9'}));

    const reply = await postsCol()
      .doc('p1').collection('replies').doc('r9').get();
    expect(reply.get('text')).toBe('just buy the 50mg ones');
    expect(reply.get('alias')).toBe('nightbee');
  });
});
