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
import {beforeEach, describe, expect, it} from 'vitest';
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
    await createPost.run(request({text: 'day 12', tag: 'win'}, 'alice'));

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
      request({text: 'rough night', tag: 'sos'}, 'bob'),
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
