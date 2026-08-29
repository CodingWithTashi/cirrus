/**
 * `moderationQueue` / `resolveModeration` — the founder's review queue.
 *
 * `moderation/{id}` has been written to since day one and read by nothing:
 * no admin UI, no admin claim, no function. App Store Guideline 1.2 requires
 * a means of acting on reported content, and docs/03 §9 promises review
 * inside 24 hours — neither is possible against a collection nobody can open.
 *
 * The access rule is the whole point of these tests: this endpoint returns
 * content that was flagged or blocked, so it must be unreachable by ordinary
 * users no matter how the request is shaped.
 */
import type {CallableRequest} from 'firebase-functions/v2/https';
import {beforeEach, describe, expect, it} from 'vitest';
import {
  moderationQueue,
  resolveModeration,
} from '../../src/handlers/moderationQueue';
import {db} from '../../src/lib/firestore';

const PROJECT = process.env['GCLOUD_PROJECT'] ?? 'demo-cirrus';
const HOST = process.env['FIRESTORE_EMULATOR_HOST'] ?? '127.0.0.1:8080';

async function clearFirestore(): Promise<void> {
  const res = await fetch(
    `http://${HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`,
    {method: 'DELETE'},
  );
  if (!res.ok) throw new Error(`emulator clear failed: ${res.status}`);
}

/// A caller with the admin custom claim, as the founder's account will have.
function admin(data: unknown = {}): CallableRequest<unknown> {
  return {
    data,
    auth: {uid: 'founder', token: {admin: true}},
    rawRequest: {},
    acceptsStreaming: false,
  } as unknown as CallableRequest<unknown>;
}

function member(data: unknown = {}): CallableRequest<unknown> {
  return {
    data,
    auth: {uid: 'alice', token: {}},
    rawRequest: {},
    acceptsStreaming: false,
  } as unknown as CallableRequest<unknown>;
}

async function seedFlag(id: string, reviewed = false): Promise<void> {
  await db.collection('moderation').doc(id).set({
    postId: id,
    action: 'flag',
    reason: 'possible medical claim',
    reviewed,
    createdAt: new Date(),
  });
  await db.collection('posts').doc(id).set({
    alias: 'SteadyFalcon42',
    text: 'nicotine patches cured me',
    status: 'live',
    tag: 'vent',
  });
}

beforeEach(async () => {
  await clearFirestore();
});

describe('moderationQueue — who may open it', () => {
  it('refuses an ordinary signed-in member', async () => {
    await seedFlag('p1');
    await expect(moderationQueue.run(member())).rejects.toThrow();
  });

  it('refuses an unauthenticated caller', async () => {
    const anon = {
      data: {},
      rawRequest: {},
      acceptsStreaming: false,
    } as unknown as CallableRequest<unknown>;
    await expect(moderationQueue.run(anon)).rejects.toThrow();
  });

  // A client can put anything in the payload; only the token is trustworthy.
  it('refuses a member who simply claims to be an admin in the payload', async () => {
    await expect(moderationQueue.run(member({admin: true}))).rejects.toThrow();
  });

  it('lets an admin through', async () => {
    await seedFlag('p1');
    const result = await moderationQueue.run(admin());
    expect(result.items).toHaveLength(1);
  });
});

describe('moderationQueue — what it returns', () => {
  it('returns the flag with the post text attached', async () => {
    await seedFlag('p1');
    const {items} = await moderationQueue.run(admin());

    expect(items[0]).toMatchObject({
      postId: 'p1',
      action: 'flag',
      reason: 'possible medical claim',
      text: 'nicotine patches cured me',
      status: 'live',
    });
  });

  it('shows only unreviewed items by default', async () => {
    await seedFlag('p1');
    await seedFlag('p2', true);

    const {items} = await moderationQueue.run(admin());
    expect(items.map((i) => i.postId)).toEqual(['p1']);
  });

  it('survives a flag whose post has already been deleted', async () => {
    await db.collection('moderation').doc('ghost').set({
      postId: 'ghost',
      action: 'block',
      reason: 'gone',
      reviewed: false,
      createdAt: new Date(),
    });

    const {items} = await moderationQueue.run(admin());
    expect(items[0]?.text).toBeNull();
  });
});

describe('resolveModeration', () => {
  it('marks an item reviewed so it leaves the queue', async () => {
    await seedFlag('p1');
    await resolveModeration.run(admin({postId: 'p1'}));

    const {items} = await moderationQueue.run(admin());
    expect(items).toHaveLength(0);
  });

  it('can block a post while resolving it', async () => {
    await seedFlag('p1');
    await resolveModeration.run(admin({postId: 'p1', action: 'block'}));

    expect((await db.collection('posts').doc('p1').get()).get('status')).toBe(
      'blocked',
    );
  });

  it('can clear a post back to live', async () => {
    await seedFlag('p1');
    await db.collection('posts').doc('p1').update({status: 'blocked'});
    await resolveModeration.run(admin({postId: 'p1', action: 'allow'}));

    expect((await db.collection('posts').doc('p1').get()).get('status')).toBe(
      'live',
    );
  });

  it('refuses an ordinary member', async () => {
    await seedFlag('p1');
    await expect(
      resolveModeration.run(member({postId: 'p1'})),
    ).rejects.toThrow();
  });
});
