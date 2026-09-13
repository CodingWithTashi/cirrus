/**
 * `onReplyStatus` / `recountReplies` — the denormalised `posts/{id}.replyCount`.
 *
 * The feed used to download every live reply in the app to render "3 replied".
 * This field replaces that query, so the number has to be right in every state
 * a reply can reach, and has to survive a re-delivered trigger — which is the
 * whole reason it recounts instead of incrementing.
 *
 * The trigger is invoked directly with event doubles (an `onDocumentWritten`
 * handler is just a function), but the RECOUNT runs against real emulator
 * documents — so these assert the actual aggregation, not a stub.
 */
import {beforeEach, describe, expect, it} from 'vitest';
import {onReplyStatus} from '../../src/handlers/onReplyStatus';
import {recountReplies} from '../../src/lib/replyCount';
import {postsCol} from '../../src/lib/firestore';

const PROJECT = process.env['GCLOUD_PROJECT'] ?? 'demo-cirrus';
const HOST = process.env['FIRESTORE_EMULATOR_HOST'] ?? '127.0.0.1:8080';

async function clearFirestore(): Promise<void> {
  const res = await fetch(
    `http://${HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`,
    {method: 'DELETE'},
  );
  if (!res.ok) throw new Error(`emulator clear failed: ${res.status}`);
}

/** A document snapshot double that answers `get`, like the real one. */
const snap = (data: Record<string, unknown> | null) => ({
  exists: data !== null,
  get: (field: string) => (data === null ? undefined : data[field]),
  data: () => data ?? undefined,
});

/** An `onDocumentWritten` event. `null` on either side means "did not exist". */
const written = (
  before: Record<string, unknown> | null,
  after: Record<string, unknown> | null,
  postId = 'p1',
) =>
  ({
    params: {postId, replyId: 'r1'},
    data: {before: snap(before), after: snap(after)},
  }) as never;

async function fire(
  before: Record<string, unknown> | null,
  after: Record<string, unknown> | null,
  postId = 'p1',
): Promise<void> {
  await onReplyStatus.run(written(before, after, postId));
}

async function seedPost(id = 'p1', replyCount?: number): Promise<void> {
  await postsCol()
    .doc(id)
    .set({
      alias: 'SteadyFalcon42',
      tag: 'win',
      text: 'day twelve and still here',
      reactions: {},
      reportCount: 0,
      status: 'live',
      ...(replyCount === undefined ? {} : {replyCount}),
    });
}

/** Writes [statuses.length] replies under the post, one per given status. */
async function seedReplies(statuses: string[], postId = 'p1'): Promise<void> {
  const col = postsCol().doc(postId).collection('replies');
  await Promise.all(
    statuses.map((status, i) =>
      col.doc(`r${i}`).set({alias: 'QuietFox11', text: 'hold the line', status}),
    ),
  );
}

const storedCount = async (postId = 'p1'): Promise<unknown> =>
  (await postsCol().doc(postId).get()).get('replyCount');

beforeEach(async () => {
  await clearFirestore();
});

describe('recountReplies', () => {
  it('counts the live replies and nothing else', async () => {
    await seedPost();
    await seedReplies(['live', 'live', 'pending', 'blocked', 'held', 'live']);
    expect(await recountReplies('p1')).toBe(3);
    expect(await storedCount()).toBe(3);
  });

  it('writes zero for a post whose replies were all taken down', async () => {
    await seedPost('p1', 4);
    await seedReplies(['blocked', 'pending']);
    expect(await recountReplies('p1')).toBe(0);
    expect(await storedCount()).toBe(0);
  });

  it('does not conjure a post that is gone', async () => {
    // A reply transitioning on a deleted post must not recreate it — `update`
    // rather than `set(..., {merge: true})` is what guarantees that.
    await expect(recountReplies('never-existed')).resolves.toBeNull();
    expect((await postsCol().doc('never-existed').get()).exists).toBe(false);
  });
});

describe('onReplyStatus — every path a reply takes in or out of live', () => {
  it('counts a reply moderatePost cleared', async () => {
    await seedPost('p1', 0);
    await seedReplies(['live']);
    await fire({status: 'pending'}, {status: 'live'});
    expect(await storedCount()).toBe(1);
  });

  it('uncounts one the model blocked', async () => {
    await seedPost('p1', 1);
    await seedReplies(['blocked']);
    await fire({status: 'live'}, {status: 'blocked'});
    expect(await storedCount()).toBe(0);
  });

  it('uncounts one the third report auto-hid', async () => {
    // `reportReply` sets `status: 'pending'` at AUTO_HIDE_AT.
    await seedPost('p1', 2);
    await seedReplies(['live', 'pending']);
    await fire({status: 'live'}, {status: 'pending'});
    expect(await storedCount()).toBe(1);
  });

  it('counts one the founder restored', async () => {
    // `resolveModeration` flips a held reply to live.
    await seedPost('p1', 0);
    await seedReplies(['live', 'live']);
    await fire({status: 'held'}, {status: 'live'});
    expect(await storedCount()).toBe(2);
  });

  it('uncounts one the founder blocked', async () => {
    await seedPost('p1', 3);
    await seedReplies(['live', 'live', 'blocked']);
    await fire({status: 'live'}, {status: 'blocked'});
    expect(await storedCount()).toBe(2);
  });

  it('uncounts a deleted reply', async () => {
    await seedPost('p1', 1);
    await fire({status: 'live'}, null);
    expect(await storedCount()).toBe(0);
  });
});

describe('onReplyStatus — what it deliberately ignores', () => {
  /**
   * These prove the guard by leaving a WRONG count in place: if the handler
   * recounted, the number would be corrected and the test would fail. That is
   * the only way to assert "it did not do the work".
   */
  it('ignores a reply being created pending', async () => {
    await seedPost('p1', 99);
    await seedReplies(['pending']);
    await fire(null, {status: 'pending'});
    expect(await storedCount()).toBe(99);
  });

  it('ignores anonymization, which rewrites a live reply without moving it', async () => {
    // `deleteUserData` updates alias and avatarEmoji and leaves status alone.
    // Every departing account would otherwise cost one aggregation read per
    // reply it had ever written, for a number that cannot have changed.
    await seedPost('p1', 99);
    await seedReplies(['live']);
    await fire(
      {status: 'live', alias: 'QuietFox11'},
      {status: 'live', alias: '[departed quitter]'},
    );
    expect(await storedCount()).toBe(99);
  });

  it('ignores a hold being re-held by remoderateHeld', async () => {
    await seedPost('p1', 99);
    await fire({status: 'held'}, {status: 'held', retryable: true});
    expect(await storedCount()).toBe(99);
  });
});

describe('onReplyStatus — at-least-once delivery', () => {
  it('is idempotent: the same event twice leaves the same number', async () => {
    // THE reason this recounts instead of incrementing. Firestore triggers are
    // at-least-once, so a re-delivery of one event is normal — and with
    // `FieldValue.increment` it would inflate the count permanently, with
    // nothing to correct it.
    await seedPost('p1', 0);
    await seedReplies(['live', 'live']);
    await fire({status: 'pending'}, {status: 'live'});
    expect(await storedCount()).toBe(2);
    await fire({status: 'pending'}, {status: 'live'});
    await fire({status: 'pending'}, {status: 'live'});
    expect(await storedCount()).toBe(2);
  });

  it('self-heals a post written before the field existed', async () => {
    // No `replyCount` at all — the shape of every post already in Firestore.
    // The first reply that moves repairs it, so no backfill is required for
    // any post that stays active.
    await postsCol().doc('p1').set({
      alias: 'SteadyFalcon42',
      tag: 'win',
      text: 'a post from before the field',
      reactions: {},
      reportCount: 0,
      status: 'live',
    });
    await seedReplies(['live', 'live', 'live']);
    expect(await storedCount()).toBeUndefined();
    await fire({status: 'pending'}, {status: 'live'});
    expect(await storedCount()).toBe(3);
  });

  it('recovers from a count that drifted for any reason', async () => {
    await seedPost('p1', 41);
    await seedReplies(['live']);
    await fire({status: 'pending'}, {status: 'live'});
    expect(await storedCount()).toBe(1);
  });
});
