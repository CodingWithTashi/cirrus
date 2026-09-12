/**
 * `createReply` — the callable firestore.rules has referenced since day one
 * but which was never written, leaving replies impossible to create by any
 * means (B10).
 *
 * It inherits the post contract: no uid on the document, authorship in a
 * server-only mapping, and `pending` until a model clears it.
 */
import type {CallableRequest} from 'firebase-functions/v2/https';
import {beforeEach, describe, expect, it} from 'vitest';
import {createReply} from '../../src/handlers/createReply';
import {db, postsCol} from '../../src/lib/firestore';

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

const LIVE_POST = 'livePost';

async function seedPost(id: string, status: string): Promise<void> {
  await postsCol().doc(id).set({
    alias: 'SteadyFalcon42',
    tag: 'sos',
    text: 'rough night, help',
    reactions: {},
    reportCount: 0,
    status,
  });
}

beforeEach(async () => {
  await clearFirestore();
  await seedPost(LIVE_POST, 'live');
});

const reply = (text = 'you have got this') => ({
  postId: LIVE_POST,
  text,
  alias: 'QuietFox11',
  avatarEmoji: '\u{1F98A}',
  timeZone: 'America/Toronto',
});

/// 320 characters of real words. A single repeated character is no longer a
/// valid reply however long it is — the quality floor asks for words.
const LONG = 'you have got this, keep going, '.repeat(12);

describe('createReply — inherits the post anonymity contract', () => {
  it('writes the reply under its parent post', async () => {
    const {replyId} = await createReply.run(request(reply()));
    const snap = await postsCol().doc(LIVE_POST).collection('replies').doc(replyId).get();

    expect(snap.exists).toBe(true);
    expect(snap.get('text')).toBe('you have got this');
  });

  it('never puts the author uid on the reply', async () => {
    const {replyId} = await createReply.run(request(reply()));
    const snap = await postsCol().doc(LIVE_POST).collection('replies').doc(replyId).get();

    expect(snap.data()).not.toHaveProperty('uid');
  });

  it('records authorship in a server-only mapping', async () => {
    const {replyId} = await createReply.run(request(reply()));
    const author = await db.collection('replyAuthors').doc(replyId).get();

    expect(author.get('uid')).toBe('alice');
    expect(author.get('postId')).toBe(LIVE_POST);
  });

  // The rules only expose status == 'live', so pending is genuinely invisible.
  it('lands pending, never live', async () => {
    const {replyId} = await createReply.run(request(reply()));
    const snap = await postsCol().doc(LIVE_POST).collection('replies').doc(replyId).get();

    expect(snap.get('status')).toBe('pending');
  });
});

describe('createReply — validation', () => {
  it('rejects an unauthenticated caller', async () => {
    const anon = {
      data: reply(),
      rawRequest: {},
      acceptsStreaming: false,
    } as unknown as CallableRequest<unknown>;
    await expect(createReply.run(anon)).rejects.toThrow();
  });

  it('rejects empty text', async () => {
    await expect(createReply.run(request(reply('   ')))).rejects.toThrow();
  });

  // docs/03 §9: replies cap at 300 characters, tighter than a post's 500.
  it('rejects text over the 300-character limit', async () => {
    await expect(createReply.run(request(reply(LONG.slice(0, 301))))).rejects.toThrow();
  });

  it('accepts text exactly at the limit', async () => {
    await expect(
      createReply.run(request(reply(LONG.slice(0, 300)))),
    ).resolves.toHaveProperty('replyId');
  });

  it('rejects a missing postId', async () => {
    const {postId: _postId, ...orphan} = reply();
    await expect(createReply.run(request(orphan))).rejects.toThrow();
  });

  it('refuses to reply to a post that does not exist', async () => {
    await expect(
      createReply.run(request({...reply(), postId: 'ghost'})),
    ).rejects.toThrow();
  });

  // Replying to something unmoderated or blocked would resurrect it into a
  // thread the rules are deliberately hiding.
  it('refuses to reply to a post that is not live', async () => {
    await seedPost('blockedPost', 'blocked');
    await expect(
      createReply.run(request({...reply(), postId: 'blockedPost'})),
    ).rejects.toThrow();

    await seedPost('pendingPost', 'pending');
    await expect(
      createReply.run(request({...reply(), postId: 'pendingPost'})),
    ).rejects.toThrow();
  });
});

describe('createReply — refuses rule-breaking text at the door', () => {
  it('refuses a slur before anything is written', async () => {
    await expect(
      createReply.run(request(reply('quit? not with these faggots cheering'))),
    ).rejects.toMatchObject({code: 'invalid-argument'});
    expect(
      (await postsCol().doc(LIVE_POST).collection('replies').get()).empty,
    ).toBe(true);
  });
});

describe('createReply — the postId is a path, not a label', () => {
  it('refuses every id Firestore reserves, cleanly', async () => {
    // This went straight into `postsCol().doc(postId)` unguarded. A slash
    // addresses a different path outright; `.`, `..` and `__like_this__` make
    // the SDK throw a plain Error, which escapes the callable as `internal` —
    // a 500 for a bad argument. Five of the six client-supplied ids in the
    // codebase had no guard at all; `requireDocId` is now the one door.
    for (const bad of ['a/b', '/etc', '.', '..', '__proto__', '__name__']) {
      await expect(
        createReply.run(request({...reply(), postId: bad})),
      ).rejects.toMatchObject({
        code: 'invalid-argument',
        message: 'Bad postId.',
      });
    }
  });
});

describe('createReply — length is counted the way a person counts', () => {
  it('accepts 300 characters that happen to contain emoji', async () => {
    // `requireText` counted UTF-16 code units while every composer counts
    // grapheme clusters, so the server was always the meanest of the three
    // layers. A reply of 300 characters containing emoji is well over 300
    // code units and was refused — and `addReply` drops the refusal on the
    // floor, so it rendered as sent and reached nobody.
    const text = 'you have got this, keep going, '.repeat(8) + '\u{1F525}'.repeat(52);
    expect([...text].length).toBe(300);
    expect(text.length).toBeGreaterThan(300); // more code units than characters
    await expect(
      createReply.run(request({...reply(), text})),
    ).resolves.toHaveProperty('replyId');
  });

  it('still refuses 301 characters', async () => {
    const text = 'you have got this, keep going, '.repeat(8) + '\u{1F525}'.repeat(53);
    expect([...text].length).toBe(301);
    await expect(
      createReply.run(request({...reply(), text})),
    ).rejects.toMatchObject({code: 'invalid-argument'});
  });

  it('refuses a payload that is small in characters but huge on the wire', async () => {
    // A grapheme is unbounded in code units — one family emoji is eleven — so
    // the character count alone is not a size limit. The wire backstop is.
    const family = '\u{1F469}‍\u{1F469}‍\u{1F467}‍\u{1F466}';
    const text = family.repeat(200);
    await expect(
      createReply.run(request({...reply(), text})),
    ).rejects.toMatchObject({code: 'invalid-argument'});
  });
});
