/**
 * `createPost` against the emulator.
 *
 * Invoked through the v2 `.run()` hook, so these exercise handler logic and
 * skip the HTTP transport — App Check and token parsing are Google's code.
 *
 * The anonymity contract is the thing under test: a post must carry no uid,
 * and the uid must land in the server-only postAuthors mapping instead. If
 * that ever inverts, every reader can de-anonymize the whole feed.
 */
import type {CallableRequest} from 'firebase-functions/v2/https';
import {afterEach, beforeEach, describe, expect, it, vi} from 'vitest';
import {
  DAILY_SOS_POSTS,
  FREE_DAILY_POSTS,
  PREMIUM_DAILY_POSTS,
} from '../../src/config';
import {createPost} from '../../src/handlers/createPost';
import {db, myPostsCol, postsCol} from '../../src/lib/firestore';

const PROJECT = process.env['GCLOUD_PROJECT'] ?? 'demo-cirrus';
const HOST = process.env['FIRESTORE_EMULATOR_HOST'] ?? '127.0.0.1:8080';

async function clearFirestore(): Promise<void> {
  const res = await fetch(
    `http://${HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`,
    {method: 'DELETE'},
  );
  if (!res.ok) throw new Error(`emulator clear failed: ${res.status}`);
}

function request(data: unknown, uid = 'alice'): CallableRequest<unknown> {
  return {
    data,
    auth: {uid, token: {}},
    rawRequest: {},
    acceptsStreaming: false,
  } as unknown as CallableRequest<unknown>;
}

const post = (text = 'day 12 and still here', tag = 'win') => ({
  text,
  tag,
  alias: 'SteadyFalcon42',
  avatarEmoji: '\u{1F525}',
  dayN: 12,
  timeZone: 'America/Toronto',
});

// Posting is Premium under `mirror`; these cases are about anonymity, input
// and the cap, not the gate, so they run under the deployed `ungated` default.
// The gate has its own describe below, which sets `mirror` itself.
const previousMode = process.env['ENTITLEMENT_MODE'];
beforeEach(() => {
  process.env['ENTITLEMENT_MODE'] = 'ungated';
});
afterEach(() => {
  if (previousMode === undefined) delete process.env['ENTITLEMENT_MODE'];
  else process.env['ENTITLEMENT_MODE'] = previousMode;
});

// Deploy-time params resolve to 0 with no `.env` loaded, and an allowance of
// 0 refuses every post before any of these assertions is reached — the same
// trap that made the coach answer `capReached` to everybody. Pinned to the
// production values so the tests read as the deployed behaviour.
beforeEach(() => {
  vi.spyOn(FREE_DAILY_POSTS, 'value').mockReturnValue(1);
  vi.spyOn(PREMIUM_DAILY_POSTS, 'value').mockReturnValue(3);
  vi.spyOn(DAILY_SOS_POSTS, 'value').mockReturnValue(5);
});
afterEach(() => vi.restoreAllMocks());

beforeEach(async () => {
  await clearFirestore();
});

describe('createPost — the anonymity contract', () => {
  it('writes the post without an author uid', async () => {
    const {postId} = await createPost.run(request(post()));
    const snap = await postsCol().doc(postId).get();

    expect(snap.exists).toBe(true);
    expect(snap.data()).not.toHaveProperty('uid');
    expect(snap.get('text')).toBe('day 12 and still here');
  });

  it('records authorship in the server-only mapping instead', async () => {
    const {postId} = await createPost.run(request(post()));
    const author = await db.collection('postAuthors').doc(postId).get();

    expect(author.get('uid')).toBe('alice');
  });

  it("writes the author's own mirror row, under their own document", async () => {
    // QA M5 / H3: the mirror is what lets the app say "in review" instead of
    // "Posted." followed by silence, and what answers "is this mine?" per
    // account instead of per session. Same batch as the post, so one cannot
    // exist without the other.
    const {postId} = await createPost.run(request(post()));
    const mine = await myPostsCol('alice').doc(postId).get();

    expect(mine.exists).toBe(true);
    expect(mine.get('status')).toBe('pending');
    expect(mine.get('text')).toBe('day 12 and still here');
    expect(mine.get('tag')).toBe('win');
    // Still no uid on the post itself.
    expect((await postsCol().doc(postId).get()).data()).not.toHaveProperty('uid');
  });

  // Nothing reaches a reader before moderatePost classifies it — the rules
  // only expose status == 'live'.
  it('lands pending, never live', async () => {
    const {postId} = await createPost.run(request(post()));
    expect((await postsCol().doc(postId).get()).get('status')).toBe('pending');
  });

  it('starts with a zeroed report count', async () => {
    const {postId} = await createPost.run(request(post()));
    expect((await postsCol().doc(postId).get()).get('reportCount')).toBe(0);
  });
});

describe('createPost — input validation', () => {
  it('rejects an unauthenticated caller', async () => {
    const anon = {
      data: post(),
      rawRequest: {},
      acceptsStreaming: false,
    } as unknown as CallableRequest<unknown>;
    await expect(createPost.run(anon)).rejects.toThrow();
  });

  it('rejects empty text', async () => {
    await expect(createPost.run(request(post('   ')))).rejects.toThrow();
  });

  it('rejects text over the 500-character limit', async () => {
    await expect(createPost.run(request(post('x'.repeat(501))))).rejects.toThrow();
  });

  it('accepts text exactly at the limit', async () => {
    await expect(createPost.run(request(post('x'.repeat(500))))).resolves.toHaveProperty('postId');
  });

  it('requires a tag', async () => {
    const {tag: _tag, ...noTag} = post();
    await expect(createPost.run(request(noTag))).rejects.toThrow();
  });

  it('rejects a tag outside the allowed set', async () => {
    await expect(createPost.run(request(post('hi', 'spam')))).rejects.toThrow();
  });
});

describe('createPost — the 3-a-day cap', () => {
  it('allows three posts and refuses the fourth', async () => {
    for (let i = 0; i < 3; i++) {
      await expect(createPost.run(request(post(`post ${i}`)))).resolves.toBeDefined();
    }
    await expect(createPost.run(request(post('the fourth')))).rejects.toThrow();
  });

  it('meters each author separately', async () => {
    for (let i = 0; i < 3; i++) await createPost.run(request(post(`a${i}`), 'alice'));
    await expect(
      createPost.run(request(post('bob is fresh'), 'bob')),
    ).resolves.toBeDefined();
  });

  // The cap reads the count and then writes in a separate step. Five requests
  // arriving together can all observe "0 posted" and all proceed, which is how
  // a spam cap becomes decorative.
  it('holds the cap when posts arrive concurrently', async () => {
    const results = await Promise.allSettled(
      Array.from({length: 5}, (_, i) => createPost.run(request(post(`burst ${i}`)))),
    );
    const created = results.filter((r) => r.status === 'fulfilled');

    expect(created.length).toBeLessThanOrEqual(3);

    const stored = await postsCol().get();
    expect(stored.size).toBeLessThanOrEqual(3);
  });
});

describe('createPost — refuses rule-breaking text at the door', () => {
  // docs/09 issue 6: a "no" before posting, not "not published" after. The
  // same deterministic prefilter `moderatePost` runs first now also runs
  // here, so a slur is never written anywhere.
  const slur = 'quit? not with these faggots cheering';

  it('refuses a slur before anything is written', async () => {
    await expect(createPost.run(request(post(slur)))).rejects.toMatchObject({
      code: 'invalid-argument',
    });
    expect((await postsCol().get()).empty).toBe(true);
    expect((await db.collection('postAuthors').get()).empty).toBe(true);
    expect((await myPostsCol('alice').get()).empty).toBe(true);
  });

  it('spends no cap slot on a refusal', async () => {
    await expect(createPost.run(request(post(slur)))).rejects.toThrow();
    for (let i = 0; i < 3; i++) {
      await expect(createPost.run(request(post(`post ${i}`)))).resolves.toBeDefined();
    }
  });

  it('lets profanity through to the classifier — the target is the signal', async () => {
    await expect(createPost.run(request(post('fuck this app')))).resolves.toHaveProperty(
      'postId',
    );
  });
});

describe('createPost — posting is an allowance, not a wall', () => {
  // docs/12 §4.1. Posting used to be refused outright for a free account,
  // which left the feature we call our moat read-only for exactly the people
  // a subscriber pays to read — while replying stayed free, so the line was
  // arbitrary as well as costly. A free account posts once a day now.
  //
  // `tierFor` reads ENTITLEMENT_MODE at call time; the deployed default is
  // `ungated` (everyone premium), so tiering only exists under `mirror`.
  const previous = process.env['ENTITLEMENT_MODE'];
  beforeEach(() => {
    process.env['ENTITLEMENT_MODE'] = 'mirror';
  });
  afterEach(() => {
    if (previous === undefined) delete process.env['ENTITLEMENT_MODE'];
    else process.env['ENTITLEMENT_MODE'] = previous;
  });

  it('gives a free account its one post a day', async () => {
    const {postId} = await createPost.run(request(post('a win', 'win')));
    expect((await postsCol().doc(postId).get()).exists).toBe(true);
    expect(
      (await db.collection('users').doc('alice').get()).get('postUsage'),
    ).toMatchObject({count: 1});
  });

  it('refuses the second with the upgrade-shaped code, spending no slot', async () => {
    await createPost.run(request(post('a win', 'win')));
    await expect(createPost.run(request(post('another', 'win')))).rejects.toMatchObject({
      // `permission-denied`, not `resource-exhausted`: a subscription WOULD
      // have let this through, and the client turns exactly this code into a
      // door. It cannot make that call itself without trusting its own tier.
      code: 'permission-denied',
    });
    expect((await postsCol().get()).size).toBe(1);
    expect(
      (await db.collection('users').doc('alice').get()).get('postUsage'),
    ).toMatchObject({count: 1});
  });

  it('refuses a subscriber past THREE with no upgrade to offer', async () => {
    const future = new Date(Date.now() + 86_400_000);
    await db.collection('users').doc('prem').set({
      entitlement: {tier: 'premium', productId: 'p', expiresAt: future, updatedAt: new Date()},
    });
    for (let i = 0; i < 3; i++) {
      await expect(
        createPost.run(request(post(`win ${i}`, 'win'), 'prem')),
      ).resolves.toBeDefined();
    }
    await expect(
      createPost.run(request(post('one too many', 'win'), 'prem')),
    ).rejects.toMatchObject({
      // Nothing to sell them — they already bought it. "Come back tomorrow",
      // and no door.
      code: 'resource-exhausted',
    });
  });

  it('lets a trial post like a subscriber', async () => {
    const future = new Date(Date.now() + 86_400_000);
    await db.collection('users').doc('trialist').set({
      entitlement: {tier: 'trial', productId: 'p', expiresAt: future, updatedAt: new Date()},
    });
    for (let i = 0; i < 3; i++) {
      await expect(
        createPost.run(request(post(`win ${i}`, 'win'), 'trialist')),
      ).resolves.toBeDefined();
    }
  });

  it('an expired entitlement is free again', async () => {
    await db.collection('users').doc('lapsed').set({
      entitlement: {
        tier: 'premium',
        productId: 'p',
        expiresAt: new Date(Date.now() - 1000),
        updatedAt: new Date(),
      },
    });
    await createPost.run(request(post('day 12', 'win'), 'lapsed'));
    await expect(
      createPost.run(request(post('day 12 again', 'win'), 'lapsed')),
    ).rejects.toMatchObject({code: 'permission-denied'});
  });
});

describe('createPost — an SOS spends its own allowance', () => {
  const previous = process.env['ENTITLEMENT_MODE'];
  beforeEach(() => {
    process.env['ENTITLEMENT_MODE'] = 'mirror';
  });
  afterEach(() => {
    if (previous === undefined) delete process.env['ENTITLEMENT_MODE'];
    else process.env['ENTITLEMENT_MODE'] = previous;
  });

  it('is never refused for tier', async () => {
    const {postId} = await createPost.run(request(post('need a hand right now', 'sos')));
    expect((await postsCol().doc(postId).get()).exists).toBe(true);
  });

  it('survives a spent ordinary allowance', async () => {
    // The rule this protects: nobody is told they are out of posts while
    // asking for help. A shared counter would have refused this.
    await createPost.run(request(post('a win', 'win')));
    await expect(createPost.run(request(post('another', 'win')))).rejects.toThrow();

    await expect(
      createPost.run(request(post('please talk to me', 'sos'))),
    ).resolves.toBeDefined();
  });

  it('does not spend the ordinary allowance either', async () => {
    await createPost.run(request(post('help', 'sos')));
    // The free post is still there to use.
    await expect(createPost.run(request(post('a win', 'win')))).resolves.toBeDefined();
    const user = await db.collection('users').doc('alice').get();
    expect(user.get('sosUsage')).toMatchObject({count: 1});
    expect(user.get('postUsage')).toMatchObject({count: 1});
  });

  it('is still bounded — a pinned post is not an unlimited megaphone', async () => {
    // SOS posts pin to the top of the feed for an hour, so "uncapped" would
    // hand anyone who wanted one a permanent billboard.
    for (let i = 0; i < 5; i++) {
      await expect(createPost.run(request(post(`help ${i}`, 'sos')))).resolves.toBeDefined();
    }
    await expect(createPost.run(request(post('help 6', 'sos')))).rejects.toMatchObject({
      // Not `permission-denied`: no subscription buys more of these, so
      // there is no door to offer.
      code: 'resource-exhausted',
    });
  });
});

describe('createPost — idempotent on the client id', () => {
  // The app's retry re-sends a post whose response was lost. Without this a
  // committed-but-unheard send became two posts and two cap slots.
  it('the same clientId twice is one post and one cap slot', async () => {
    const first = await createPost.run(request({...post('once'), clientId: 'p1'}));
    const second = await createPost.run(request({...post('once'), clientId: 'p1'}));
    expect(second.postId).toBe(first.postId);
    expect((await postsCol().get()).size).toBe(1);
    const usage = (await db.collection('users').doc('alice').get()).get('postUsage') as {
      count: number;
    };
    expect(usage.count).toBe(1);
  });

  it('another user with the same clientId gets their own post', async () => {
    const a = await createPost.run(request({...post('mine'), clientId: 'p1'}, 'alice'));
    const b = await createPost.run(request({...post('mine'), clientId: 'p1'}, 'bob'));
    expect(a.postId).not.toBe(b.postId);
  });

  it('an unusable clientId falls back to a fresh id every time', async () => {
    const a = await createPost.run(request({...post('x'), clientId: 'no spaces here!'}));
    const b = await createPost.run(request({...post('x'), clientId: 'no spaces here!'}));
    expect(a.postId).not.toBe(b.postId);
  });
});
