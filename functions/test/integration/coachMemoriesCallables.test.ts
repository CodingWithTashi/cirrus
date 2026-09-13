/**
 * The two memory CALLABLES. `memories.test.ts` covers the library underneath;
 * neither callable had a test of its own, and `forgetCoachMemory` had none
 * anywhere.
 *
 * That is the wrong thing to leave untested here. This file's own rationale is
 * that "an AI that quietly accumulates personal disclosures and gives the
 * person no way to see or remove them is a product people are right to
 * distrust" — so the list being complete, and the delete actually deleting,
 * ARE the feature. Both had a hole: the list returned 100 against a store cap
 * of 200, and a reserved Firestore id crashed the delete with a 500.
 */
import {beforeEach, describe, expect, it} from 'vitest';
import type {CallableRequest} from 'firebase-functions/v2/https';
import {
  coachMemories,
  forgetCoachMemory,
} from '../../src/handlers/coachMemories';
import {userDoc} from '../../src/lib/firestore';

const PROJECT = process.env['GCLOUD_PROJECT'] ?? 'demo-cirrus';
const HOST = process.env['FIRESTORE_EMULATOR_HOST'] ?? '127.0.0.1:8080';

async function clearFirestore(): Promise<void> {
  const url =
    `http://${HOST}/emulator/v1/projects/${PROJECT}` +
    `/databases/(default)/documents`;
  const res = await fetch(url, {method: 'DELETE'});
  if (!res.ok) throw new Error(`emulator clear failed: ${res.status}`);
}

function caller(
  data: Record<string, unknown>,
  uid: string | null = 'alice',
): CallableRequest<unknown> {
  return {
    data: {timeZone: 'America/Toronto', locale: 'en-CA', ...data},
    auth: uid === null ? null : {uid, token: {}},
    rawRequest: {},
    acceptsStreaming: false,
  } as unknown as CallableRequest<unknown>;
}

const col = (uid: string) => userDoc(uid).collection('memories');

/** Writes a memory straight to the store — no model call, no embedding cost. */
async function seed(uid: string, id: string, minute = 0): Promise<void> {
  await col(uid).doc(id).set({
    text: `fact ${id}`,
    kind: 'context',
    createdAt: new Date(2026, 0, 1, 0, minute),
    lastUsedAt: new Date(2026, 0, 1, 0, minute),
    embedding: [0.1, 0.2, 0.3],
  });
}

const forget = (memoryId: unknown, uid: string | null = 'alice') =>
  forgetCoachMemory.run(caller({memoryId}, uid));

const list = async (uid: string | null = 'alice') =>
  (await coachMemories.run(caller({}, uid))).memories;

const idsIn = async (uid: string): Promise<string[]> =>
  (await col(uid).get()).docs.map((d) => d.id).sort();

beforeEach(async () => {
  await clearFirestore();
});

describe('forgetCoachMemory', () => {
  it('requires a caller', async () => {
    await expect(forget('m1', null)).rejects.toMatchObject({
      code: 'unauthenticated',
    });
  });

  it('refuses an id that is not usable text', async () => {
    for (const bad of [undefined, null, 7, true, ['m1'], {id: 'm1'}, '', '   ']) {
      await expect(forget(bad)).rejects.toMatchObject({
        code: 'invalid-argument',
      });
    }
    await expect(forget('a'.repeat(201))).rejects.toMatchObject({
      code: 'invalid-argument',
    });
  });

  it('refuses every id Firestore reserves — as invalid-argument, not a 500', async () => {
    // A slash addresses a different collection. `.`, `..` and `__like_this__`
    // are reserved, and the SDK throws a PLAIN Error for them rather than
    // returning an error — which escaped the callable as `internal`, so a bad
    // argument arrived at the client as a server fault and burned the error
    // budget. All four are the same clean refusal now.
    for (const bad of ['a/b', '/etc', '.', '..', '__proto__', '__name__']) {
      await expect(forget(bad)).rejects.toMatchObject({
        code: 'invalid-argument',
        message: 'Bad memoryId.',
      });
    }
  });

  it('forgets exactly the one asked for', async () => {
    await seed('alice', 'm1');
    await seed('alice', 'm2');
    await seed('alice', 'm3');
    await expect(forget('m2')).resolves.toEqual({forgotten: true});
    expect(await idsIn('alice')).toEqual(['m1', 'm3']);
  });

  it('is quiet about a memory that is already gone', async () => {
    // Tapping forget twice, or on a list the server has since pruned, is not
    // an error the user should ever see — the state they asked for is the
    // state they get.
    await expect(forget('never-existed')).resolves.toEqual({forgotten: true});
  });

  it('cannot reach another account memory', async () => {
    // The id is scoped to the caller's own subcollection, so knowing somebody
    // else's id buys nothing.
    await seed('bob', 'secret');
    await expect(forget('secret', 'alice')).resolves.toEqual({forgotten: true});
    expect(await idsIn('bob')).toEqual(['secret']);
  });
});

describe('coachMemories', () => {
  it('requires a caller', async () => {
    await expect(list(null)).rejects.toMatchObject({code: 'unauthenticated'});
  });

  it('returns only the caller own memories', async () => {
    await seed('alice', 'mine');
    await seed('bob', 'theirs');
    expect((await list('alice')).map((m) => m.id)).toEqual(['mine']);
  });

  it('never hands the embedding to the client', async () => {
    // ~3KB of float per line, for data a phone can do nothing with.
    await seed('alice', 'm1');
    const [first] = await list();
    expect(first).toBeDefined();
    expect(Object.keys(first as object).sort()).toEqual(['id', 'kind', 'text']);
  });

  it('returns EVERYTHING the store holds, not a page of it', async () => {
    // The store's ceiling is 200 and this read 100, so a long-tenured user had
    // up to a hundred memories that the coach kept using and they could never
    // see or delete. The two orderings did not cancel out: eviction drops by
    // `lastUsedAt`, this lists by `createdAt`, so an old memory in constant use
    // was precisely the one that was never evicted and never shown.
    for (let i = 0; i < 120; i += 1) {
      await seed('alice', `m${String(i).padStart(3, '0')}`, i);
    }
    expect((await col('alice').count().get()).data().count).toBe(120);
    expect(await list()).toHaveLength(120);
  }, 120_000);

  it('stays newest-first', async () => {
    await seed('alice', 'older', 1);
    await seed('alice', 'newer', 5);
    expect((await list()).map((m) => m.id)).toEqual(['newer', 'older']);
  });
});
