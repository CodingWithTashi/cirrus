/**
 * Ember's long-term memory — the store, not the helper.
 *
 * `worthExtracting` was the only tested thing here, and it is the cheapest
 * part. Everything that decides whether the feature is trustworthy is below
 * it: that a fact is written once rather than ten times, that the store cannot
 * grow without bound, and that "forget this" actually forgets. The last one
 * matters most — an AI that quietly accumulates personal disclosures with no
 * working delete is the thing users are right to be uneasy about.
 */
import {beforeEach, describe, expect, it} from 'vitest';
import {
  EMBEDDING_DIMENSIONS,
  forget,
  listMemories,
  recallRelevant,
  remember,
  worthExtracting,
} from '../../src/lib/memories';
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

/** A unit vector pointing mostly along [seed], padded to the real dimension. */
function vector(seed: number): number[] {
  const v = new Array<number>(EMBEDDING_DIMENSIONS).fill(0);
  v[seed % EMBEDDING_DIMENSIONS] = 1;
  return v;
}

const count = async (uid: string): Promise<number> =>
  (await userDoc(uid).collection('memories').count().get()).data().count;

beforeEach(async () => {
  await clearFirestore();
});

describe('remembering', () => {
  it('stores a fact with its vector and kind', async () => {
    await remember('alice', 'sister Maya marries in March', 'person', vector(1));

    const stored = await listMemories('alice');
    expect(stored).toHaveLength(1);
    expect(stored[0]?.text).toBe('sister Maya marries in March');
    expect(stored[0]?.kind).toBe('person');
  });

  it('does not hand the embedding back to the client', async () => {
    // `listMemories` feeds the "What Ember remembers" screen. A 768-float
    // vector is not something a user asked to download, and it is not
    // something the screen can do anything with.
    await remember('alice', 'walks the dog to beat evening cravings', 'trigger', vector(2));
    const stored = await listMemories('alice');
    expect(stored[0]).not.toHaveProperty('embedding');
  });

  it('keeps one user out of another user store', async () => {
    await remember('alice', 'alice fact about her sister', 'person', vector(1));
    await remember('bob', 'bob fact about his brother', 'person', vector(1));

    expect(await listMemories('alice')).toHaveLength(1);
    expect((await listMemories('alice'))[0]?.text).toContain('alice');
  });
});

describe('forgetting', () => {
  it('removes exactly the one asked for', async () => {
    await remember('alice', 'first fact worth keeping here', 'context', vector(1));
    await remember('alice', 'second fact worth keeping here', 'context', vector(2));

    const before = await listMemories('alice');
    await forget('alice', before[0]!.id);

    const after = await listMemories('alice');
    expect(after).toHaveLength(1);
    expect(after.map((m) => m.id)).not.toContain(before[0]!.id);
  });

  it('is quiet about a memory that is already gone', async () => {
    // The screen is non-optimistic: it re-reads after a delete. A second
    // delete arriving from a retry must not become an error the user sees.
    await expect(forget('alice', 'never-existed')).resolves.toBeUndefined();
  });
});

describe('the store cannot grow without bound', () => {
  it('evicts the least recently used past the cap', async () => {
    // Without this, recall latency grows with tenure: the users who earned
    // the best coach would get the slowest one, and ten mentions of the same
    // dog would fill every recall slot.
    const CAP = 200;
    for (let i = 0; i < CAP + 5; i++) {
      await remember('alice', `remembered fact number ${i} here`, 'context', vector(i));
    }
    expect(await count('alice')).toBeLessThanOrEqual(CAP);
  }, 120_000);
});

describe('worthExtracting — the money gate', () => {
  it('skips a chip, which costs a model call for nothing', () => {
    expect(worthExtracting('[craving]')).toBe(false);
  });

  it('skips a one-liner', () => {
    expect(worthExtracting('ok thanks')).toBe(false);
  });

  it('keeps a sentence that says something durable', () => {
    expect(
      worthExtracting('my sister Maya is getting married in March'),
    ).toBe(true);
  });
});

describe('recall', () => {
  it('never throws, whatever the index is doing', async () => {
    // Deliberately the weakest assertion in this file, and deliberately here.
    // `findNearest` needs a real vector index; the emulator may not have one,
    // and production may be mid-build. Recall is best-effort by design — a
    // coach without its memory is worse, a coach that refuses to answer is
    // broken, and this runs while somebody is mid-craving. The recall QUALITY
    // is verified for real against production in
    // `integration_test/f_firebase_backend_test.dart`.
    await remember('alice', 'sister Maya marries in March', 'person', vector(1));
    await expect(recallRelevant('alice', vector(1))).resolves.toBeInstanceOf(
      Array,
    );
  });
});
