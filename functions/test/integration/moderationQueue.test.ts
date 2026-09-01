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
import {beforeEach, describe, expect, it, vi} from 'vitest';

vi.mock('../../src/lib/push', () => ({
  sendLocalized: vi.fn().mockResolvedValue(undefined),
}));

import {
  moderationQueue,
  resolveModeration,
} from '../../src/handlers/moderationQueue';
import {db, myPostsCol} from '../../src/lib/firestore';
import {sendLocalized} from '../../src/lib/push';

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
  vi.clearAllMocks();
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

  it('hydrates a reply flag from the reply, not from its parent', async () => {
    // This showed the founder the parent post's text, so they reviewed
    // innocent content and either cleared a reply they never read or blocked
    // a post nobody had reported.
    await seedFlag('p1');
    await db.collection('posts').doc('p1').collection('replies').doc('r9').set({
      alias: 'nightbee',
      text: 'just buy the 50mg ones',
      status: 'live',
    });
    await db.collection('moderation').doc('r9').set({
      postId: 'p1',
      replyId: 'r9',
      kind: 'reply',
      action: 'flag',
      reason: 'sourcing',
      reviewed: false,
      createdAt: new Date(),
    });

    const {items} = await moderationQueue.run(admin());
    const replyFlag = items.find((i) => i.kind === 'reply');
    expect(replyFlag?.flagId).toBe('r9');
    expect(replyFlag?.replyId).toBe('r9');
    expect(replyFlag?.text).toBe('just buy the 50mg ones');
    expect(replyFlag?.text).not.toBe('nicotine patches cured me');
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
    await resolveModeration.run(admin({flagId: 'p1'}));

    const {items} = await moderationQueue.run(admin());
    expect(items).toHaveLength(0);
  });

  it('can block a post while resolving it', async () => {
    await seedFlag('p1');
    await resolveModeration.run(admin({flagId: 'p1', action: 'block'}));

    expect((await db.collection('posts').doc('p1').get()).get('status')).toBe(
      'blocked',
    );
  });

  it('can clear a post back to live', async () => {
    await seedFlag('p1');
    await db.collection('posts').doc('p1').update({status: 'blocked'});
    await resolveModeration.run(admin({flagId: 'p1', action: 'allow'}));

    expect((await db.collection('posts').doc('p1').get()).get('status')).toBe(
      'live',
    );
  });

  it("a decision on a post reaches its author's mirror row", async () => {
    // The founder's Allow on a held post is the moment it goes live for
    // everyone — and the moment the author's "in review" chip should go.
    await seedFlag('p1');
    await db.collection('posts').doc('p1').update({status: 'pending'});
    await db.collection('postAuthors').doc('p1').set({uid: 'alice'});
    await myPostsCol('alice').doc('p1').set({status: 'pending', text: 'x', tag: 'vent'});

    await resolveModeration.run(admin({flagId: 'p1', action: 'allow'}));
    expect((await myPostsCol('alice').doc('p1').get()).get('status')).toBe('live');

    await resolveModeration.run(admin({flagId: 'p1', action: 'block'}));
    expect((await myPostsCol('alice').doc('p1').get()).get('status')).toBe('blocked');
  });

  it('resolves a REPLY flag, and the reply — not its parent post', async () => {
    // The bug this pins: a reply flag lives at `moderation/{replyId}` with the
    // parent as a field. Resolving by `postId` wrote to a DIFFERENT document,
    // so the reply's flag was never marked reviewed and returned to the queue
    // every day, while the innocent parent post got blocked in its place.
    await seedFlag('p1');
    await db.collection('posts').doc('p1').collection('replies').doc('r9').set({
      alias: 'nightbee',
      text: 'just buy the 50mg ones',
      status: 'live',
    });
    await db.collection('moderation').doc('r9').set({
      postId: 'p1',
      replyId: 'r9',
      kind: 'reply',
      action: 'flag',
      reason: 'sourcing',
      reviewed: false,
      createdAt: new Date(),
    });

    await resolveModeration.run(admin({flagId: 'r9', action: 'block'}));

    // The reply is blocked...
    const reply = await db
      .collection('posts').doc('p1')
      .collection('replies').doc('r9').get();
    expect(reply.get('status')).toBe('blocked');
    // ...its parent is untouched...
    expect((await db.collection('posts').doc('p1').get()).get('status'))
      .toBe('live');
    // ...and the reply's own flag is the one marked reviewed.
    expect((await db.collection('moderation').doc('r9').get()).get('reviewed'))
      .toBe(true);
    expect((await db.collection('moderation').doc('p1').get()).get('reviewed'))
      .toBe(false);
  });

  it('refuses to dismiss a held (pending) item without a decision', async () => {
    // Dismiss on invisible content = invisible forever with nothing left
    // pointing at it. The widget hides the button; this is the server-side
    // guarantee behind that UX.
    await seedFlag('h1');
    await db.collection('posts').doc('h1').update({status: 'pending'});

    await expect(resolveModeration.run(admin({flagId: 'h1'}))).rejects.toThrow();
    // The row stays unreviewed — still in tomorrow's queue.
    expect(
      (await db.collection('moderation').doc('h1').get()).get('reviewed'),
    ).toBe(false);
  });

  it('publishing a held reply notifies the SOS author it answered', async () => {
    // The trigger rightly skips the "someone answered" push for a held reply;
    // the founder's Allow is when the support actually becomes visible, so
    // that is when the person mid-craving gets told.
    await db.collection('posts').doc('p1').set({
      alias: 'a', text: 'sitting outside a gas station', status: 'live', tag: 'sos',
    });
    await db.collection('postAuthors').doc('p1').set({uid: 'author1'});
    await db.collection('posts').doc('p1').collection('replies').doc('r9').set({
      alias: 'nightbee', text: 'hang in there, drink water', status: 'pending',
    });
    await db.collection('moderation').doc('r9').set({
      postId: 'p1', replyId: 'r9', kind: 'reply', action: 'hold',
      reason: 'hostile', reviewed: false, createdAt: new Date(),
    });

    await resolveModeration.run(admin({flagId: 'r9', action: 'allow'}));

    const reply = await db
      .collection('posts').doc('p1')
      .collection('replies').doc('r9').get();
    expect(reply.get('status')).toBe('live');
    expect(vi.mocked(sendLocalized)).toHaveBeenCalledWith('author1', 'sosReply', '/community');
  });

  it('allowing an already-visible reply does not push a second time', async () => {
    // A `flag` reply was live from the start and the trigger already pushed.
    await db.collection('posts').doc('p1').set({
      alias: 'a', text: 'post', status: 'live', tag: 'sos',
    });
    await db.collection('postAuthors').doc('p1').set({uid: 'author1'});
    await db.collection('posts').doc('p1').collection('replies').doc('r9').set({
      alias: 'nightbee', text: 'mild aggression', status: 'live',
    });
    await db.collection('moderation').doc('r9').set({
      postId: 'p1', replyId: 'r9', kind: 'reply', action: 'flag',
      reason: 'borderline', reviewed: false, createdAt: new Date(),
    });

    await resolveModeration.run(admin({flagId: 'r9', action: 'allow'}));
    expect(vi.mocked(sendLocalized)).not.toHaveBeenCalled();
  });

  it('refuses to resolve a flag that does not exist', async () => {
    await expect(
      resolveModeration.run(admin({flagId: 'nope'})),
    ).rejects.toThrow();
  });

  it('refuses an ordinary member', async () => {
    await seedFlag('p1');
    await expect(
      resolveModeration.run(member({flagId: 'p1'})),
    ).rejects.toThrow();
  });
});
