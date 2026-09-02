/**
 * The outage sweeper. `classify` fails closed, and this is what keeps that
 * from turning a five-minute model outage into a queue of innocent posts
 * waiting on a human (docs/09 issue 6).
 *
 * The classifier is stubbed, as in `triggers.test.ts`: what is under test is
 * what the sweep DOES with each answer, not the answer itself.
 */
import {beforeEach, describe, expect, it, vi} from 'vitest';

vi.mock('../../src/ai/moderation', () => ({
  classify: vi.fn(),
  parseVerdict: vi.fn(),
}));

vi.mock('../../src/lib/push', () => ({
  sendLocalized: vi.fn().mockResolvedValue(undefined),
}));

import {classify} from '../../src/ai/moderation';
import {sendLocalized} from '../../src/lib/push';
import {
  MAX_ATTEMPTS,
  SWEEPER_REVIEWER,
  remoderateOnce,
} from '../../src/handlers/remoderate';
import {db, myPostsCol, postsCol} from '../../src/lib/firestore';

const PROJECT = process.env['GCLOUD_PROJECT'] ?? 'demo-cirrus';
const HOST = process.env['FIRESTORE_EMULATOR_HOST'] ?? '127.0.0.1:8080';

async function clearFirestore(): Promise<void> {
  const url =
    `http://${HOST}/emulator/v1/projects/${PROJECT}` +
    `/databases/(default)/documents`;
  const res = await fetch(url, {method: 'DELETE'});
  if (!res.ok) throw new Error(`emulator clear failed: ${res.status}`);
}

const OUTAGE = 'moderation unavailable — held for human review';

const verdict = (action: string, reason = 'because', retryable = false) =>
  vi.mocked(classify).mockResolvedValue(
    {action, reason, ...(retryable ? {retryable: true} : {})} as never,
  );

/** What an outage leaves behind: a pending post, a held mirror, a retryable row. */
async function seedOutageHold(
  postId: string,
  text = 'day one, terrified',
  tag = 'day1',
): Promise<void> {
  await postsCol().doc(postId).set({alias: 'a', text, status: 'pending', tag});
  await db.collection('postAuthors').doc(postId).set({uid: 'alice'});
  await myPostsCol('alice').doc(postId).set({text, status: 'held', tag});
  await db.collection('moderation').doc(postId).set({
    postId,
    action: 'hold',
    reason: OUTAGE,
    retryable: true,
    reviewed: false,
    createdAt: new Date(),
  });
}

beforeEach(async () => {
  await clearFirestore();
  vi.clearAllMocks();
});

describe('remoderateOnce', () => {
  it('publishes a post that is clean on the second look and closes its row', async () => {
    await seedOutageHold('p1');
    verdict('allow', 'fine');

    const result = await remoderateOnce(50);

    expect(result).toMatchObject({scanned: 1, published: 1, decided: 0, stillDown: 0});
    expect((await postsCol().doc('p1').get()).get('status')).toBe('live');
    expect((await myPostsCol('alice').doc('p1').get()).get('status')).toBe('live');
    const row = await db.collection('moderation').doc('p1').get();
    expect(row.get('reviewed')).toBe(true);
    expect(row.get('reviewedBy')).toBe(SWEEPER_REVIEWER);
    expect(row.get('resolution')).toBe('allow');
    expect(row.get('retryable')).toBe(false);
  });

  it('re-asks with the tag, the way the trigger does', async () => {
    await seedOutageHold('p1', 'made it through the morning', 'win');
    verdict('allow');
    await remoderateOnce(50);
    expect(vi.mocked(classify)).toHaveBeenCalledWith('made it through the morning', 'win');
  });

  it('leaves everything alone while the model is still down', async () => {
    await seedOutageHold('p1');
    verdict('hold', OUTAGE, true);

    const result = await remoderateOnce(50);

    expect(result).toMatchObject({scanned: 1, published: 0, stillDown: 1});
    expect((await postsCol().doc('p1').get()).get('status')).toBe('pending');
    expect((await myPostsCol('alice').doc('p1').get()).get('status')).toBe('held');
    const row = await db.collection('moderation').doc('p1').get();
    expect(row.get('reviewed')).toBe(false);
    expect(row.get('retryable')).toBe(true);
    expect(row.get('retryAttempts')).toBe(1);
  });

  it('hands a row to the founder after MAX_ATTEMPTS asks still down', async () => {
    // A text the model answers garbage to every time is not an outage.
    await seedOutageHold('p1');
    await db
      .collection('moderation')
      .doc('p1')
      .set({retryAttempts: MAX_ATTEMPTS - 1}, {merge: true});
    verdict('hold', OUTAGE, true);

    const result = await remoderateOnce(50);

    expect(result.gaveUp).toBe(1);
    const row = await db.collection('moderation').doc('p1').get();
    expect(row.get('retryable')).toBe(false);
    expect(row.get('reviewed')).toBe(false);
    expect(row.get('retryAttempts')).toBe(MAX_ATTEMPTS);
    expect((await postsCol().doc('p1').get()).get('status')).toBe('pending');
  });

  it('never re-asks a row a person decided, even after reports re-open it', async () => {
    await seedOutageHold('p1');
    // resolveModeration: reviewed, and retryable cleared.
    await db
      .collection('moderation')
      .doc('p1')
      .set({reviewed: true, retryable: false}, {merge: true});
    // Three reports later: reportPost re-opens the row, retryable stays off.
    await db
      .collection('moderation')
      .doc('p1')
      .set({reviewed: false, retryable: false}, {merge: true});
    verdict('allow');

    const result = await remoderateOnce(50);

    expect(result.scanned).toBe(0);
    expect(vi.mocked(classify)).not.toHaveBeenCalled();
  });

  it('gives up early on an outage instead of burning the batch', async () => {
    for (const id of ['p1', 'p2', 'p3', 'p4', 'p5']) await seedOutageHold(id);
    verdict('hold', OUTAGE, true);

    const result = await remoderateOnce(50);

    expect(result.stillDown).toBe(3);
    expect(vi.mocked(classify)).toHaveBeenCalledTimes(3);
  });

  it('applies a real verdict and keeps the row for the founder', async () => {
    await seedOutageHold('p1', 'dm me for cheap pods');
    verdict('block', 'sourcing');

    const result = await remoderateOnce(50);

    expect(result).toMatchObject({published: 0, decided: 1});
    expect((await postsCol().doc('p1').get()).get('status')).toBe('blocked');
    expect((await myPostsCol('alice').doc('p1').get()).get('status')).toBe('blocked');
    const row = await db.collection('moderation').doc('p1').get();
    expect(row.get('reviewed')).toBe(false);
    expect(row.get('action')).toBe('block');
    expect(row.get('reason')).toBe('sourcing');
    expect(row.get('retryable')).toBe(false);
  });

  it('a model-chosen hold stays for a human — the row is never re-asked', async () => {
    // Retryable is the selector. A hold the model CHOSE carries
    // retryable:false and must not be re-rolled until it flips.
    await seedOutageHold('p1', 'you are all pathetic');
    await db.collection('moderation').doc('p1').set({retryable: false, reason: 'hostile'}, {merge: true});
    verdict('allow');

    const result = await remoderateOnce(50);

    expect(result.scanned).toBe(0);
    expect(vi.mocked(classify)).not.toHaveBeenCalled();
    expect((await postsCol().doc('p1').get()).get('status')).toBe('pending');
  });

  it('stops selecting a row whose post a person already decided', async () => {
    await seedOutageHold('p1');
    // The founder allowed it through resolveModeration meanwhile.
    await postsCol().doc('p1').update({status: 'live'});
    verdict('block');

    const result = await remoderateOnce(50);

    expect(result.dropped).toBe(1);
    expect(vi.mocked(classify)).not.toHaveBeenCalled();
    expect((await postsCol().doc('p1').get()).get('status')).toBe('live');
    expect((await db.collection('moderation').doc('p1').get()).get('retryable')).toBe(false);
  });

  it('stops selecting a row whose subject is gone', async () => {
    await seedOutageHold('p1');
    await postsCol().doc('p1').delete();

    const result = await remoderateOnce(50);

    expect(result.dropped).toBe(1);
    expect((await db.collection('moderation').doc('p1').get()).get('retryable')).toBe(false);
  });

  it('a reply cleared on the second look announces itself on an SOS post', async () => {
    await postsCol().doc('s1').set({alias: 'a', text: 'help', status: 'live', tag: 'sos'});
    await db.collection('postAuthors').doc('s1').set({uid: 'alice'});
    const reply = postsCol().doc('s1').collection('replies').doc('r1');
    await reply.set({alias: 'b', text: 'hang in there', status: 'pending'});
    await db.collection('moderation').doc('r1').set({
      postId: 's1',
      replyId: 'r1',
      kind: 'reply',
      action: 'hold',
      reason: OUTAGE,
      retryable: true,
      reviewed: false,
      createdAt: new Date(),
    });
    verdict('allow');

    const result = await remoderateOnce(50);

    expect(result.published).toBe(1);
    expect((await reply.get()).get('status')).toBe('live');
    expect(vi.mocked(classify)).toHaveBeenCalledWith('hang in there', undefined);
    expect(vi.mocked(sendLocalized)).toHaveBeenCalledWith('alice', 'sosReply', '/community');
  });
});
