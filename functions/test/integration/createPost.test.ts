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
import {beforeEach, describe, expect, it} from 'vitest';
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
