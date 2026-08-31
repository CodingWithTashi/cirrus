/**
 * The three Firestore triggers, whose BODIES had no test.
 *
 * `parseVerdict` and `reactionDelta` were covered as pure helpers, which is
 * the easy half — the half that decides what a user sees is the write that
 * follows. A `moderatePost` that classifies correctly and then flips the
 * wrong field leaves objectionable content live, and `parseVerdict` stays
 * green throughout.
 *
 * The classifier is stubbed: it costs a model call, and what is under test
 * here is what the handler DOES with a verdict, not the verdict itself.
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
import {moderatePost} from '../../src/handlers/moderatePost';
import {moderateReply} from '../../src/handlers/moderateReply';
import {onReaction} from '../../src/handlers/onReaction';
import {db, postsCol} from '../../src/lib/firestore';

const PROJECT = process.env['GCLOUD_PROJECT'] ?? 'demo-cirrus';
const HOST = process.env['FIRESTORE_EMULATOR_HOST'] ?? '127.0.0.1:8080';

async function clearFirestore(): Promise<void> {
  const url =
    `http://${HOST}/emulator/v1/projects/${PROJECT}` +
    `/databases/(default)/documents`;
  const res = await fetch(url, {method: 'DELETE'});
  if (!res.ok) throw new Error(`emulator clear failed: ${res.status}`);
}

const verdict = (action: string, reason = 'because') =>
  vi.mocked(classify).mockResolvedValue({action, reason} as never);

/**
 * A created-document event carrying a real snapshot from the emulator.
 *
 * Cast to `never` so it satisfies whichever `FirestoreEvent<…>` the trigger
 * under test declares; the handlers only read `.data` and `.params`.
 */
async function created(
  ref: FirebaseFirestore.DocumentReference,
  params: Record<string, string>,
): Promise<never> {
  return {data: await ref.get(), params} as unknown as never;
}

beforeEach(async () => {
  await clearFirestore();
  vi.clearAllMocks();
});

describe('moderatePost', () => {
  async function seed(text: unknown = 'day one, terrified'): Promise<
    FirebaseFirestore.DocumentReference
  > {
    const ref = postsCol().doc('p1');
    await ref.set({alias: 'a', text, status: 'pending', tag: 'day1'});
    return ref;
  }

  it('publishes a clean post', async () => {
    verdict('allow');
    const ref = await seed();
    await moderatePost.run(await created(ref, {postId: 'p1'}));

    expect((await ref.get()).get('status')).toBe('live');
    // Nothing clean should reach the founder's queue.
    expect((await db.collection('moderation').doc('p1').get()).exists).toBe(
      false,
    );
  });

  it('blocks a post the classifier rejects, and files it', async () => {
    verdict('block', 'sourcing');
    const ref = await seed('dm me for cheap 50mg pods');
    await moderatePost.run(await created(ref, {postId: 'p1'}));

    expect((await ref.get()).get('status')).toBe('blocked');
    const flag = await db.collection('moderation').doc('p1').get();
    expect(flag.get('action')).toBe('block');
    expect(flag.get('reason')).toBe('sourcing');
    expect(flag.get('reviewed')).toBe(false);
  });

  it('leaves a flagged post visible but queued for review', async () => {
    // docs/03 §9: `flag` is "a human should look", not "hide it". Treating
    // flag as block would silently censor ordinary venting.
    verdict('flag', 'possible medical claim');
    const ref = await seed('patches fixed me honestly');
    await moderatePost.run(await created(ref, {postId: 'p1'}));

    expect((await ref.get()).get('status')).toBe('live');
    expect((await db.collection('moderation').doc('p1').get()).exists).toBe(
      true,
    );
  });

  it('blocks an empty post without spending a model call', async () => {
    const ref = await seed('   ');
    await moderatePost.run(await created(ref, {postId: 'p1'}));

    expect((await ref.get()).get('status')).toBe('blocked');
    expect(vi.mocked(classify)).not.toHaveBeenCalled();
  });

  it('holds an undecidable post: stays pending, but always queued', async () => {
    // Fail-closed (S3-8): `hold` covers hostile rants AND every model
    // failure. The post stays invisible, and the queue row is what keeps it
    // from stranding — a pending post with no row is reviewable by nobody.
    verdict('hold', 'moderation unavailable — held for human review');
    const ref = await seed('fuck this app');
    await moderatePost.run(await created(ref, {postId: 'p1'}));

    expect((await ref.get()).get('status')).toBe('pending');
    const flag = await db.collection('moderation').doc('p1').get();
    expect(flag.exists).toBe(true);
    expect(flag.get('action')).toBe('hold');
    expect(flag.get('reviewed')).toBe(false);
  });

  it('hands the classifier the tag alongside the text', async () => {
    // A celebratory WIN tag on a hostile rant is itself a signal — the field
    // test's "fuck this app" wore one. The tag is a server-validated enum.
    verdict('allow');
    const ref = await seed('made it through the morning');
    await moderatePost.run(await created(ref, {postId: 'p1'}));
    expect(vi.mocked(classify)).toHaveBeenCalledWith(
      'made it through the morning',
      'day1',
    );
  });

  it('stamps when it looked, so an unmoderated post is identifiable', async () => {
    verdict('allow');
    const ref = await seed();
    await moderatePost.run(await created(ref, {postId: 'p1'}));
    expect((await ref.get()).get('moderatedAt')).not.toBeUndefined();
  });

  it('does nothing at all when the event carries no document', async () => {
    await expect(
      moderatePost.run({data: undefined, params: {postId: 'p1'}} as never),
    ).resolves.toBeUndefined();
  });
});

describe('moderateReply', () => {
  async function seed(text: unknown = 'hold the line'): Promise<
    FirebaseFirestore.DocumentReference
  > {
    await postsCol().doc('p1').set({
      alias: 'a',
      text: 'sitting outside a gas station',
      status: 'live',
      tag: 'sos',
    });
    const ref = postsCol().doc('p1').collection('replies').doc('r9');
    await ref.set({alias: 'nightbee', text, status: 'pending'});
    return ref;
  }

  it('publishes a clean reply', async () => {
    verdict('allow');
    const ref = await seed();
    await moderateReply.run(
      await created(ref, {postId: 'p1', replyId: 'r9'}),
    );
    expect((await ref.get()).get('status')).toBe('live');
  });

  it('files a reply flag under the REPLY id, with its parent as a field', async () => {
    // This is what makes the flag resolvable. Keying it by postId would let a
    // flagged reply overwrite its parent's row, and resolving it would then
    // address the wrong document entirely.
    verdict('flag', 'sourcing');
    const ref = await seed('just buy the 50mg ones');
    await moderateReply.run(
      await created(ref, {postId: 'p1', replyId: 'r9'}),
    );

    const flag = await db.collection('moderation').doc('r9').get();
    expect(flag.exists).toBe(true);
    expect(flag.get('kind')).toBe('reply');
    expect(flag.get('postId')).toBe('p1');
    expect(flag.get('replyId')).toBe('r9');
    // The parent post has no flag of its own.
    expect((await db.collection('moderation').doc('p1').get()).exists).toBe(
      false,
    );
  });

  it('blocks an empty reply without a model call', async () => {
    const ref = await seed('');
    await moderateReply.run(
      await created(ref, {postId: 'p1', replyId: 'r9'}),
    );
    expect((await ref.get()).get('status')).toBe('blocked');
    expect(vi.mocked(classify)).not.toHaveBeenCalled();
  });

  it('holds an undecidable reply and never announces it to the author', async () => {
    // Pushing "someone answered your SOS" for a reply that is invisible
    // until a human clears it would promise support that may never appear.
    await db.collection('postAuthors').doc('p1').set({uid: 'author1'});
    verdict('hold', 'hostile');
    const ref = await seed('give up already');
    await moderateReply.run(
      await created(ref, {postId: 'p1', replyId: 'r9'}),
    );

    expect((await ref.get()).get('status')).toBe('pending');
    expect((await db.collection('moderation').doc('r9').get()).get('action')).toBe('hold');
    expect(vi.mocked(sendLocalized)).not.toHaveBeenCalled();
  });

  it('still announces a flagged (visible) reply on an SOS post', async () => {
    await db.collection('postAuthors').doc('p1').set({uid: 'author1'});
    verdict('flag', 'mild aggression');
    const ref = await seed('tough love incoming');
    await moderateReply.run(
      await created(ref, {postId: 'p1', replyId: 'r9'}),
    );

    expect((await ref.get()).get('status')).toBe('live');
    expect(vi.mocked(sendLocalized)).toHaveBeenCalledWith('author1', 'sosReply', '/community');
  });
});

describe('onReaction', () => {
  /** A written-document event; `before`/`after` are plain data doubles. */
  const written = (before: unknown, after: unknown, postId = 'p1') => ({
    params: {postId, uid: 'alice'},
    data: {
      before: {data: () => before},
      after: {data: () => after},
    },
  });

  beforeEach(async () => {
    await postsCol().doc('p1').set({
      alias: 'a',
      text: 'day 30',
      status: 'live',
      reactions: {},
    });
  });

  it('counts a reaction the moment somebody leaves one', async () => {
    await onReaction.run(written(undefined, {emoji: '💪'}) as never);
    expect((await postsCol().doc('p1').get()).get('reactions')).toEqual({
      '💪': 1,
    });
  });

  it('moves the count when somebody changes their mind', async () => {
    await postsCol().doc('p1').update({reactions: {'💪': 1}});
    await onReaction.run(written({emoji: '💪'}, {emoji: '🔥'}) as never);

    expect((await postsCol().doc('p1').get()).get('reactions')).toEqual({
      '💪': 0,
      '🔥': 1,
    });
  });

  it('takes the count back when a reaction is removed', async () => {
    await postsCol().doc('p1').update({reactions: {'💪': 1}});
    await onReaction.run(written({emoji: '💪'}, undefined) as never);
    expect((await postsCol().doc('p1').get()).get('reactions')['💪']).toBe(0);
  });

  it('ignores a re-write of the same emoji', async () => {
    // A double tap or a retried write must not inflate the count — this is
    // the case the pure `reactionDelta` test exists for, verified here
    // against the actual document.
    await postsCol().doc('p1').update({reactions: {'💪': 1}});
    await onReaction.run(written({emoji: '💪'}, {emoji: '💪'}) as never);
    expect((await postsCol().doc('p1').get()).get('reactions')['💪']).toBe(1);
  });

  it('survives a reaction on a post that has since been deleted', async () => {
    // The gap between the tap and this trigger is real, and a retry storm
    // over a deleted post helps nobody.
    await expect(
      onReaction.run(written(undefined, {emoji: '💪'}, 'gone') as never),
    ).resolves.toBeUndefined();
  });
});
