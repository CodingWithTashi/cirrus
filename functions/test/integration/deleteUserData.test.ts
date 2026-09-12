/**
 * `deleteUserData` — full erasure (docs/03 §11).
 *
 * Required by App Store Guideline 5.1.1(v), and by our own "we never sell your
 * data" positioning, which is worth nothing if we cannot actually let go of it.
 *
 * The interesting half is what must NOT be deleted: community content is
 * anonymized, not removed, so threads other quitters are still reading do not
 * develop holes where a departing user's messages were.
 */
import type {CallableRequest} from 'firebase-functions/v2/https';
import {getAuth} from 'firebase-admin/auth';
import {afterEach, beforeEach, describe, expect, it, vi} from 'vitest';
import {createPost} from '../../src/handlers/createPost';
import {createReply} from '../../src/handlers/createReply';
import {deleteUserData} from '../../src/handlers/deleteUserData';
import {db, journeyDoc, postsCol, userDoc} from '../../src/lib/firestore';

const PROJECT = process.env['GCLOUD_PROJECT'] ?? 'demo-cirrus';
const HOST = process.env['FIRESTORE_EMULATOR_HOST'] ?? '127.0.0.1:8080';
const DEPARTED = '[departed quitter]';

async function clearFirestore(): Promise<void> {
  const res = await fetch(
    `http://${HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`,
    {method: 'DELETE'},
  );
  if (!res.ok) throw new Error(`emulator clear failed: ${res.status}`);
}

function request(data: unknown, uid: string): CallableRequest<unknown> {
  return {
    data,
    auth: {uid, token: {}},
    rawRequest: {},
    acceptsStreaming: false,
  } as unknown as CallableRequest<unknown>;
}

/** A real Auth user, so the final getAuth().deleteUser() has something to remove. */
async function makeUser(uid: string): Promise<void> {
  try {
    await getAuth().deleteUser(uid);
  } catch {
    // not there yet — fine
  }
  await getAuth().createUser({uid, email: `${uid}@cirrus.test`});
}

// RevenueCat is never reached from a test: the emulator's own fetch (the
// wipe) passes through, anything at api.revenuecat.com answers 404 (done).
// Without this, a developer with the real secret exported in their shell
// would delete these customers against production.
const realFetch = globalThis.fetch;
beforeEach(() => {
  vi.stubGlobal(
    'fetch',
    vi.fn((input: string | URL | Request, init?: RequestInit) => {
      const url = String(input instanceof Request ? input.url : input);
      if (url.startsWith('https://api.revenuecat.com/')) {
        return Promise.resolve(new Response('', {status: 404}));
      }
      return realFetch(input, init);
    }),
  );
});
afterEach(() => vi.unstubAllGlobals());

// The posts these cases create come from free users; under `mirror` they
// would be refused at the door, so they run under the deployed `ungated`.
const previousMode = process.env['ENTITLEMENT_MODE'];
beforeEach(() => {
  process.env['ENTITLEMENT_MODE'] = 'ungated';
});
afterEach(() => {
  if (previousMode === undefined) delete process.env['ENTITLEMENT_MODE'];
  else process.env['ENTITLEMENT_MODE'] = previousMode;
});

beforeEach(async () => {
  await clearFirestore();
});

describe('deleteUserData — what goes', () => {
  it('removes the journey document', async () => {
    await makeUser('alice');
    await journeyDoc('alice').set({profile: {alias: 'SteadyFalcon42'}});

    await deleteUserData.run(request({}, 'alice'));

    expect((await journeyDoc('alice').get()).exists).toBe(false);
  });

  it('removes the server-owned tree, subcollections included', async () => {
    await makeUser('alice');
    await userDoc('alice').set({entitlement: {tier: 'premium'}});
    await userDoc('alice').collection('cravings').add({outcome: 'survived'});
    await userDoc('alice').collection('coachMessages').add({role: 'user', text: 'hi'});

    await deleteUserData.run(request({}, 'alice'));

    expect((await userDoc('alice').get()).exists).toBe(false);
    expect((await userDoc('alice').collection('cravings').get()).empty).toBe(true);
    expect((await userDoc('alice').collection('coachMessages').get()).empty).toBe(true);
  });

  it('removes the auth account itself', async () => {
    await makeUser('alice');
    await deleteUserData.run(request({}, 'alice'));

    await expect(getAuth().getUser('alice')).rejects.toThrow();
  });

  it('drops the authorship mappings that could re-identify them', async () => {
    await makeUser('alice');
    await createPost.run(request({text: 'day 12 and holding', tag: 'win'}, 'alice'));

    await deleteUserData.run(request({}, 'alice'));

    const authors = await db
      .collection('postAuthors')
      .where('uid', '==', 'alice')
      .get();
    expect(authors.empty).toBe(true);
  });
});

describe('deleteUserData — what stays', () => {
  it('keeps the post but strips the byline', async () => {
    await makeUser('alice');
    const {postId} = await createPost.run(
      request({text: 'made it to day 12', tag: 'win', alias: 'SteadyFalcon42'}, 'alice'),
    );

    await deleteUserData.run(request({}, 'alice'));

    const post = await postsCol().doc(postId).get();
    expect(post.exists).toBe(true);
    expect(post.get('text')).toBe('made it to day 12');
    expect(post.get('alias')).toBe(DEPARTED);
  });

  it('anonymizes replies too, not just top-level posts', async () => {
    await makeUser('alice');
    await makeUser('bob');
    // Bob owns the thread; Alice replies and then leaves.
    const {postId} = await createPost.run(
      request({text: 'rough night, help', tag: 'sos'}, 'bob'),
    );
    await postsCol().doc(postId).update({status: 'live'});
    const {replyId} = await createReply.run(
      request({postId, text: 'you have got this', alias: 'QuietFox11'}, 'alice'),
    );

    await deleteUserData.run(request({}, 'alice'));

    const reply = await postsCol().doc(postId).collection('replies').doc(replyId).get();
    expect(reply.exists).toBe(true);
    expect(reply.get('text')).toBe('you have got this');
    expect(reply.get('alias')).toBe(DEPARTED);
  });

  it('leaves other people’s content untouched', async () => {
    await makeUser('alice');
    await makeUser('bob');
    const {postId} = await createPost.run(
      request({text: 'bob is still here', tag: 'win', alias: 'BoldOtter7'}, 'bob'),
    );

    await deleteUserData.run(request({}, 'alice'));

    const post = await postsCol().doc(postId).get();
    expect(post.get('alias')).toBe('BoldOtter7');
    expect((await journeyDoc('bob').get()).exists).toBe(false); // never had one
    await expect(getAuth().getUser('bob')).resolves.toBeDefined();
  });
});

/**
 * The trail a reader leaves without ever writing a word.
 *
 * Both of these live UNDER `posts`, keyed by the uid, so neither
 * `recursiveDelete(users/{uid})` nor the two anonymize passes reached them.
 * A full erasure used to leave the departed account's uid written on every
 * post it had reacted to or reported — a durable record of what that person
 * read and how they felt about it, outliving the one operation whose whole
 * promise is that nothing does.
 */
describe('deleteUserData — the reader trail', () => {
  const reactorRef = (postId: string, uid: string) =>
    postsCol().doc(postId).collection('reactors').doc(uid);
  const reporterRef = (postId: string, uid: string) =>
    postsCol().doc(postId).collection('reporters').doc(uid);

  it('removes every reaction the departing account left', async () => {
    await makeUser('alice');
    await makeUser('bob');
    const a = await createPost.run(
      request({text: 'a post worth reacting to', tag: 'win'}, 'bob'),
    );
    const b = await createPost.run(
      request({text: 'another one worth reacting to', tag: 'win'}, 'bob'),
    );
    // The client writes its OWN reactor document; the uid is both the id and
    // a field, which is what makes it findable at erasure time.
    await reactorRef(a.postId, 'alice').set({uid: 'alice', emoji: '\u{1F525}'});
    await reactorRef(b.postId, 'alice').set({uid: 'alice', emoji: '\u{1F4AA}'});
    await reactorRef(a.postId, 'bob').set({uid: 'bob', emoji: '\u{1F525}'});

    await deleteUserData.run(request({}, 'alice'));

    expect((await reactorRef(a.postId, 'alice').get()).exists).toBe(false);
    expect((await reactorRef(b.postId, 'alice').get()).exists).toBe(false);
    // Somebody else's reaction is none of this operation's business.
    expect((await reactorRef(a.postId, 'bob').get()).exists).toBe(true);
  });

  it('removes every report they filed, but never the count', async () => {
    // Deliberately not symmetrical with reactions. `reportCount` is what
    // auto-hides a post at three; undoing a real reader's judgement because
    // they later closed their account would quietly un-hide flagged content.
    await makeUser('alice');
    await makeUser('bob');
    const {postId} = await createPost.run(
      request({text: 'a post somebody flagged', tag: 'win'}, 'bob'),
    );
    await postsCol().doc(postId).update({reportCount: 2});
    await reporterRef(postId, 'alice').set({uid: 'alice', reportedAt: new Date()});
    await reporterRef(postId, 'bob').set({uid: 'bob', reportedAt: new Date()});

    await deleteUserData.run(request({}, 'alice'));

    expect((await reporterRef(postId, 'alice').get()).exists).toBe(false);
    expect((await reporterRef(postId, 'bob').get()).exists).toBe(true);
    expect((await postsCol().doc(postId).get()).get('reportCount')).toBe(2);
  });

  it('leaves no document anywhere still carrying the uid', async () => {
    // The catch-all. Anything new that files a row under `posts` keyed by the
    // reader rather than the author has to be added to the erasure path, and
    // this is what fails when it is not.
    await makeUser('alice');
    await makeUser('bob');
    const {postId} = await createPost.run(
      request({text: 'the post everything hangs off', tag: 'win'}, 'bob'),
    );
    await reactorRef(postId, 'alice').set({uid: 'alice', emoji: '\u{1F525}'});
    await reporterRef(postId, 'alice').set({uid: 'alice', reportedAt: new Date()});

    await deleteUserData.run(request({}, 'alice'));

    for (const group of ['reactors', 'reporters', 'postAuthors', 'replyAuthors']) {
      const left = await db.collectionGroup(group).where('uid', '==', 'alice').get();
      expect(left.empty, `${group} still names the departed account`).toBe(true);
    }
  });
});
