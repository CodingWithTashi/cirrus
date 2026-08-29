/**
 * Security-rules suite (docs/05 §6). Runs against the Firestore emulator.
 *
 * These rules ARE the privacy product: "we never sell your data" is a
 * marketing line until a rule enforces it. Everything here is written from
 * the attacker's side — the question is never "does the app work" but "what
 * can a repackaged client do".
 *
 *   npm run test:rules
 */
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import {deleteDoc, doc, getDoc, setDoc, updateDoc} from 'firebase/firestore';
import {afterAll, beforeAll, beforeEach, describe, it} from 'vitest';

let env: RulesTestEnvironment;

const ALICE = 'alice';
const BOB = 'bob';

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-cirrus',
    firestore: {
      rules: readFileSync(resolve(__dirname, '../../../firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

afterAll(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  // Seed through the admin path: these are documents only the server writes.
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'journeys', ALICE), {profile: {alias: 'SteadyFalcon42'}});
    await setDoc(doc(db, 'users', ALICE), {
      entitlement: {tier: 'premium'},
      aiUsage: {day: '2026-08-29', msgCount: 2},
    });
    await setDoc(doc(db, 'posts', 'livePost'), {
      alias: 'SteadyFalcon42',
      tag: 'win',
      text: 'day 12',
      reactions: {fire: 3},
      reportCount: 0,
      status: 'live',
    });
    await setDoc(doc(db, 'posts', 'pendingPost'), {
      alias: 'x', tag: 'vent', text: 'unmoderated',
      reactions: {}, reportCount: 0, status: 'pending',
    });
    await setDoc(doc(db, 'posts', 'blockedPost'), {
      alias: 'x', tag: 'vent', text: 'blocked',
      reactions: {}, reportCount: 0, status: 'blocked',
    });
    await setDoc(doc(db, 'posts', 'livePost', 'replies', 'liveReply'), {
      alias: 'y', text: 'proud of you', status: 'live',
    });
    await setDoc(doc(db, 'posts', 'livePost', 'replies', 'pendingReply'), {
      alias: 'y', text: 'unmoderated reply', status: 'pending',
    });
    await setDoc(doc(db, 'posts', 'livePost', 'reactors', ALICE), {
      emoji: 'fire',
      uid: ALICE,
    });
    await setDoc(doc(db, 'postAuthors', 'livePost'), {uid: ALICE});
    await setDoc(doc(db, 'moderation', 'blockedPost'), {action: 'block', reviewed: false});
  });
});

const alice = () => env.authenticatedContext(ALICE).firestore();
const bob = () => env.authenticatedContext(BOB).firestore();
const anon = () => env.unauthenticatedContext().firestore();

describe('journeys/{uid} — client-owned', () => {
  it('lets the owner read their journey', async () => {
    await assertSucceeds(getDoc(doc(alice(), 'journeys', ALICE)));
  });

  it('lets the owner write their journey', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'journeys', ALICE), {profile: {alias: 'x'}}));
  });

  it('hides a journey from another signed-in user', async () => {
    await assertFails(getDoc(doc(bob(), 'journeys', ALICE)));
  });

  it('hides a journey from an anonymous reader', async () => {
    await assertFails(getDoc(doc(anon(), 'journeys', ALICE)));
  });
});

describe('users/{uid} — server-owned', () => {
  it('lets the owner read their own server state', async () => {
    await assertSucceeds(getDoc(doc(alice(), 'users', ALICE)));
  });

  // The single most important rule in the file. If this ever passes, every
  // client can grant itself Premium and unmetered model calls.
  it('does NOT let the owner write their own entitlement', async () => {
    await assertFails(
      setDoc(doc(alice(), 'users', ALICE), {entitlement: {tier: 'premium'}}),
    );
  });

  it('does NOT let the owner reset their own AI usage counter', async () => {
    await assertFails(
      updateDoc(doc(alice(), 'users', ALICE), {'aiUsage.msgCount': 0}),
    );
  });

  it('hides server state from another user', async () => {
    await assertFails(getDoc(doc(bob(), 'users', ALICE)));
  });
});

describe('posts — the community feed', () => {
  it('shows a live post to any signed-in reader', async () => {
    await assertSucceeds(getDoc(doc(bob(), 'posts', 'livePost')));
  });

  // "pending" must be genuinely invisible, not merely unrendered — App Store
  // Guideline 1.2 turns on nothing reaching a reader unmoderated.
  it('hides a pending post from readers', async () => {
    await assertFails(getDoc(doc(bob(), 'posts', 'pendingPost')));
  });

  it('hides a blocked post from readers', async () => {
    await assertFails(getDoc(doc(bob(), 'posts', 'blockedPost')));
  });

  it('hides every post from an anonymous reader', async () => {
    await assertFails(getDoc(doc(anon(), 'posts', 'livePost')));
  });

  it('does NOT let a client create a post directly (createPost callable only)', async () => {
    await assertFails(
      setDoc(doc(bob(), 'posts', 'forged'), {text: 'hi', status: 'live'}),
    );
  });

  it('does NOT let a client delete a post', async () => {
    await assertFails(deleteDoc(doc(bob(), 'posts', 'livePost')));
  });

  // Reaction COUNTS are server-owned now: they are derived from the reactor
  // subcollection by a trigger. A client writing them directly could inflate
  // any post's popularity to any number.
  it('does NOT let a client write the reaction counts directly', async () => {
    await assertFails(
      updateDoc(doc(bob(), 'posts', 'livePost'), {reactions: {fire: 4}}),
    );
  });

  it('lets a reader report once', async () => {
    await assertSucceeds(
      updateDoc(doc(bob(), 'posts', 'livePost'), {reportCount: 1}),
    );
  });

  it('does NOT let a client rewrite the post text', async () => {
    await assertFails(updateDoc(doc(bob(), 'posts', 'livePost'), {text: 'edited'}));
  });

  it('does NOT let a blocked post be un-blocked', async () => {
    await assertFails(
      updateDoc(doc(bob(), 'posts', 'blockedPost'), {status: 'live'}),
    );
  });

  // --- the two holes this suite exists to close ---------------------------

  it('does NOT let a client erase accumulated reports', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'posts', 'livePost'), {reportCount: 2});
    });
    await assertFails(updateDoc(doc(bob(), 'posts', 'livePost'), {reportCount: 0}));
  });

  it('does NOT let a client fake a report pile-on to auto-hide someone', async () => {
    await assertFails(updateDoc(doc(bob(), 'posts', 'livePost'), {reportCount: 9999}));
  });
});

describe('posts/{id}/reactors — one document per person', () => {
  // Storing the reactor list as {uid: emoji} ON the post would have been
  // simpler and would also have de-anonymized the entire feed: the post is
  // world-readable to signed-in users, so every uid that reacted would be
  // public. A subcollection keyed by uid, readable only by that uid, keeps
  // the counts public and the identities private.
  it('lets someone write their own reaction', async () => {
    await assertSucceeds(
      setDoc(doc(bob(), 'posts', 'livePost', 'reactors', BOB), {
        emoji: 'fire',
        uid: BOB,
      }),
    );
  });

  // The duplicated uid is what makes the collection-group read provable, so a
  // document whose field disagrees with its id would quietly break that.
  it('refuses a reaction whose uid field disagrees with its document id', async () => {
    await assertFails(
      setDoc(doc(bob(), 'posts', 'livePost', 'reactors', BOB), {
        emoji: 'fire',
        uid: ALICE,
      }),
    );
  });

  it('lets someone read and undo their own reaction', async () => {
    await assertSucceeds(
      getDoc(doc(alice(), 'posts', 'livePost', 'reactors', ALICE)),
    );
    await assertSucceeds(
      deleteDoc(doc(alice(), 'posts', 'livePost', 'reactors', ALICE)),
    );
  });

  // The whole point: nobody can learn who reacted.
  it('never lets anyone read someone else reaction', async () => {
    await assertFails(
      getDoc(doc(bob(), 'posts', 'livePost', 'reactors', ALICE)),
    );
  });

  it('never lets anyone react on behalf of someone else', async () => {
    await assertFails(
      setDoc(doc(bob(), 'posts', 'livePost', 'reactors', ALICE), {
        emoji: 'fire',
        uid: ALICE,
      }),
    );
  });

  it('hides reactions from an anonymous reader entirely', async () => {
    await assertFails(
      getDoc(doc(anon(), 'posts', 'livePost', 'reactors', ALICE)),
    );
  });
});

describe('posts/{id}/replies', () => {
  it('shows a live reply to a signed-in reader', async () => {
    await assertSucceeds(
      getDoc(doc(bob(), 'posts', 'livePost', 'replies', 'liveReply')),
    );
  });

  // Same Guideline 1.2 reasoning as posts: a reply is UGC too.
  it('hides an unmoderated reply from readers', async () => {
    await assertFails(
      getDoc(doc(bob(), 'posts', 'livePost', 'replies', 'pendingReply')),
    );
  });

  it('does NOT let a client create a reply directly (createReply callable only)', async () => {
    await assertFails(
      setDoc(doc(bob(), 'posts', 'livePost', 'replies', 'forged'), {
        text: 'hi', status: 'live',
      }),
    );
  });

  it('does NOT let a client edit a reply', async () => {
    await assertFails(
      updateDoc(doc(bob(), 'posts', 'livePost', 'replies', 'liveReply'), {text: 'x'}),
    );
  });

  it('does NOT let a client delete a reply', async () => {
    await assertFails(
      deleteDoc(doc(bob(), 'posts', 'livePost', 'replies', 'liveReply')),
    );
  });
});

describe('server-only collections', () => {
  // postAuthors is the uid <-> post mapping. Exposing it de-anonymizes the
  // entire feed in a single query.
  it('never exposes postAuthors', async () => {
    await assertFails(getDoc(doc(alice(), 'postAuthors', 'livePost')));
    await assertFails(setDoc(doc(alice(), 'postAuthors', 'x'), {uid: ALICE}));
  });

  it('never exposes replyAuthors either', async () => {
    await assertFails(getDoc(doc(alice(), 'replyAuthors', 'someReply')));
    await assertFails(setDoc(doc(alice(), 'replyAuthors', 'x'), {uid: ALICE}));
  });

  it('never exposes the moderation queue', async () => {
    await assertFails(getDoc(doc(alice(), 'moderation', 'blockedPost')));
  });

  it('denies a collection nobody has opened yet', async () => {
    await assertFails(getDoc(doc(alice(), 'leaderboards', 'january')));
    await assertFails(setDoc(doc(alice(), 'leaderboards', 'january'), {score: 1}));
  });
});
