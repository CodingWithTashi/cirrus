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
import {reportPost} from '../../src/handlers/reportPost';
import {reportReply} from '../../src/handlers/reportReply';
import {matchedTestimonials} from '../../src/handlers/testimonials';
import {
  db,
  devicesCol,
  myPostsCol,
  postsCol,
  testimonialsCol,
  userDoc,
} from '../../src/lib/firestore';
import {listDeviceTokens} from '../../src/lib/push';

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
    await syncUserContext.run(
      caller({fcmToken: 'device-1', platform: 'android'}),
    );
    await syncUserContext.run(
      caller({fcmToken: 'device-1', platform: 'android'}),
    );
    await syncUserContext.run(caller({fcmToken: 'device-2', platform: 'ios'}));

    expect((await listDeviceTokens('alice')).toSorted()).toEqual([
      'device-1',
      'device-2',
    ]);
    expect((await devicesCol('alice').get()).size).toBe(2);
  });

  it('does not write an empty token', async () => {
    await syncUserContext.run(caller({fcmToken: ''}));
    expect((await devicesCol('alice').get()).empty).toBe(true);
  });

  it('releases the device on sign-out', async () => {
    // The bug this closes: a token went in and could only ever come back out
    // when a send to it failed, so the next person to use the phone received
    // the previous account's pushes.
    await syncUserContext.run(caller({fcmToken: 'phone'}));
    expect(await listDeviceTokens('alice')).toEqual(['phone']);

    await syncUserContext.run(caller({removeFcmToken: 'phone'}));

    expect(await listDeviceTokens('alice')).toEqual([]);
  });

  it('leaves the rest of the user document standing when it releases one', async () => {
    await userDoc('alice').set({entitlement: {tier: 'premium'}}, {merge: true});
    await syncUserContext.run(caller({fcmToken: 'phone'}));
    await syncUserContext.run(caller({removeFcmToken: 'phone'}));

    const snap = await userDoc('alice').get();
    expect(snap.exists).toBe(true);
    expect(snap.get('entitlement').tier).toBe('premium');
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

describe('reportPost', () => {
  // The mirror of `reportReply`, and it closes the same bug (S3-10): the
  // client used to write a raw increment nobody read — reporting a post
  // raised a counter with no auto-hide and no queue row behind it.
  async function seedPost(): Promise<void> {
    await postsCol().doc('p1').set({
      alias: 'a',
      text: 'this app is a scam, dm me for real pods',
      status: 'live',
      tag: 'win',
      reportCount: 0,
    });
  }

  it('raises the count and files a flag the queue can read', async () => {
    await seedPost();
    await reportPost.run(caller({postId: 'p1'}));

    expect((await postsCol().doc('p1').get()).get('reportCount')).toBe(1);

    const flag = await db.collection('moderation').doc('p1').get();
    expect(flag.exists).toBe(true);
    expect(flag.get('kind')).toBe('post');
    expect(flag.get('postId')).toBe('p1');
    expect(flag.get('reason')).toBe('user_report');
    expect(flag.get('reviewed')).toBe(false);
  });

  it('counts one reporter once, however many times they tap', async () => {
    await seedPost();
    await reportPost.run(caller({postId: 'p1'}));
    await reportPost.run(caller({postId: 'p1'}));
    await reportPost.run(caller({postId: 'p1'}));

    const post = await postsCol().doc('p1').get();
    expect(post.get('reportCount')).toBe(1);
    expect(post.get('status')).toBe('live');
  });

  it('hides a post pending review once three different readers report it', async () => {
    await seedPost();
    for (const uid of ['alice', 'bob', 'carol']) {
      await reportPost.run(caller({postId: 'p1'}, uid));
    }

    const post = await postsCol().doc('p1').get();
    expect(post.get('reportCount')).toBe(3);
    // Pending, never deleted: the founder still has to be able to read it
    // and disagree.
    expect(post.get('status')).toBe('pending');
  });

  it("an auto-hide tells the author through their mirror row", async () => {
    await seedPost();
    await db.collection('postAuthors').doc('p1').set({uid: 'dave'});
    await myPostsCol('dave').doc('p1').set({status: 'live', text: 'x', tag: 'win'});
    for (const uid of ['alice', 'bob', 'carol']) {
      await reportPost.run(caller({postId: 'p1'}, uid));
    }

    expect((await myPostsCol('dave').doc('p1').get()).get('status')).toBe('pending');
  });

  it('refuses a post that does not exist', async () => {
    await expect(reportPost.run(caller({postId: 'ghost'}))).rejects.toThrow();
  });

  it('refuses an unauthenticated caller', async () => {
    await seedPost();
    await expect(
      reportPost.run({
        data: {postId: 'p1'},
        auth: undefined,
        rawRequest: {},
      } as unknown as CallableRequest<unknown>),
    ).rejects.toThrow();
  });

  it('never touches the post text, tag or author', async () => {
    await seedPost();
    await reportPost.run(caller({postId: 'p1'}));

    const post = await postsCol().doc('p1').get();
    expect(post.get('text')).toBe('this app is a scam, dm me for real pods');
    expect(post.get('alias')).toBe('a');
    expect(post.get('tag')).toBe('win');
  });

  it("re-opens an existing queue row without clobbering the classifier's verdict", async () => {
    // The model's `action`/`reason` are the evidence the founder reads, and
    // `createdAt` is the oldest-first queue position. A report re-opens the
    // row; it must not rewrite the verdict or send the row to the back.
    await seedPost();
    const verdictTime = new Date('2026-08-30T10:00:00Z');
    await db.collection('moderation').doc('p1').set({
      postId: 'p1',
      kind: 'post',
      action: 'hold',
      reason: 'prefilter: slur',
      reviewed: true,
      createdAt: verdictTime,
    });

    await reportPost.run(caller({postId: 'p1'}));

    const row = await db.collection('moderation').doc('p1').get();
    expect(row.get('action')).toBe('hold');
    expect(row.get('reason')).toBe('prefilter: slur');
    expect((row.get('createdAt') as {toDate(): Date}).toDate()).toEqual(verdictTime);
    // Re-opened for review — the one field a fresh report may change.
    expect(row.get('reviewed')).toBe(false);
  });
});

describe('matchedTestimonials', () => {
  async function seed(
    id: string,
    fields: Record<string, unknown> = {},
  ): Promise<void> {
    await testimonialsCol().doc(id).set({
      text: `quote ${id}`,
      locale: 'en',
      status: 'live',
      whys: [],
      worries: [],
      attempts: [],
      gender: [],
      dependence: [],
      weight: 0.5,
      consentRef: 'release-2026-08',
      ...fields,
    });
  }

  it('returns the two quotes that answer the fear they named', async () => {
    await seed('cravings', {worries: ['cravings']});
    await seed('stress', {worries: ['stress']});
    await seed('generic');

    const {testimonials} = await matchedTestimonials.run(
      caller({worries: ['cravings']}),
    );

    expect(testimonials).toHaveLength(2);
    expect(testimonials[0]!.id).toBe('cravings');
    // The rows carry a consent reference and translation provenance. Only the
    // two fields the card renders may cross the wire.
    expect(Object.keys(testimonials[0]!).sort()).toEqual(['id', 'text']);
  });

  it('never returns a quote that is not live', async () => {
    await seed('hidden-one', {status: 'hidden'});
    await seed('live-one');
    await seed('live-two');

    const {testimonials} = await matchedTestimonials.run(caller());

    expect(testimonials.map((t) => t.id).sort()).toEqual(['live-one', 'live-two']);
  });

  it('falls back to English rather than half-filling the screen', async () => {
    // One tailored card beside one generic one reads as a bug, so the fallback
    // is wholesale.
    await seed('fr-only', {locale: 'fr'});
    await seed('en-one');
    await seed('en-two');

    const {testimonials} = await matchedTestimonials.run({
      data: {timeZone: 'Europe/Paris', locale: 'fr-FR'},
      auth: {uid: 'alice', token: {}},
      rawRequest: {},
      acceptsStreaming: false,
    } as unknown as CallableRequest<unknown>);

    expect(testimonials.map((t) => t.id).sort()).toEqual(['en-one', 'en-two']);
  });

  it('returns nothing rather than one card when the pool is short', async () => {
    await seed('lonely');

    const {testimonials} = await matchedTestimonials.run(caller());

    // The client keeps its bundled quotes; two honest generic ones beat a
    // half-filled screen.
    expect(testimonials).toEqual([]);
  });

  it('refuses an unauthenticated caller', async () => {
    await expect(
      matchedTestimonials.run({
        data: {},
        rawRequest: {},
        acceptsStreaming: false,
      } as unknown as CallableRequest<unknown>),
    ).rejects.toThrow();
  });

  it('ignores tag values it does not recognise', async () => {
    await seed('a');
    await seed('b');

    const {testimonials} = await matchedTestimonials.run(
      caller({worries: ['telepathy'], gender: 'martian', dependence: 7}),
    );

    expect(testimonials).toHaveLength(2);
  });
});
