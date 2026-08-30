/**
 * Ember's long-term memory: `users/{uid}/memories/{id}`, retrieved by vector
 * similarity (Firestore `findNearest`).
 *
 * WHY THIS EXISTS ALONGSIDE THE USER CARD, not instead of it.
 *
 * The card (`ai/memoryCard.ts`) carries everything the app already knows for
 * certain — the plan, the numbers, the onboarding answers. It is exact, it is
 * free, and it can never be wrong. Anything derivable from the journey belongs
 * there, and putting it here instead would trade a fact for a probability.
 *
 * This layer is for the other half: the things a user only ever says out loud.
 * "My sister's wedding is in March." "It's always after arguments with my
 * dad." "I'm doing this so I can run with my kid." No amount of puff logging
 * produces those, and a coach that forgets them is interchangeable with any
 * chat app — which is the whole differentiator (docs/04 §1).
 *
 * Cost and privacy are the two constraints that shape every decision below:
 *
 * - **Recall is one embedding call per turn.** Nothing else. The search itself
 *   is a Firestore query.
 * - **Writing is gated** (see `worthExtracting`) so chips and one-word
 *   messages never trigger a model call.
 * - **Near-duplicates merge instead of accumulating**, so a user who mentions
 *   their dog ten times has one memory, not ten.
 * - **The set is capped and LRU-evicted**, so recall latency and storage stay
 *   flat no matter how long someone uses the app.
 * - **It lives under `users/{uid}`**, which `deleteUserData` already sweeps
 *   with `recursiveDelete`. Erasure needs no new code, and a memory can never
 *   outlive the account that produced it.
 */
import {FieldValue as AdminFieldValue} from 'firebase-admin/firestore';
import {FieldValue, userDoc} from './firestore';
import {log} from './logger';

/**
 * Embedding width. 768 rather than the model's native 3072: recall quality on
 * short first-person sentences is indistinguishable, while the index, the
 * document size and the query cost are all a quarter of it.
 */
export const EMBEDDING_DIMENSIONS = 768;

/** Memories retrieved per turn. Enough to be uncanny, few enough to be cheap. */
const RECALL_LIMIT = 5;

/**
 * Cosine distance above which a memory is treated as irrelevant.
 *
 * Without a cutoff `findNearest` always returns its limit, so an unrelated
 * message would still drag in the five least-unrelated memories and Ember
 * would bring up someone's sister for no reason. Worse than forgetting.
 */
const RECALL_MAX_DISTANCE = 0.45;

/** Below this, two memories are the same fact said twice — merge, don't add. */
const DUPLICATE_DISTANCE = 0.12;

/** Ceiling per user. Beyond it, the least recently useful memory is dropped. */
const MAX_MEMORIES = 200;

/** What kind of fact this is. Steers how the prompt is allowed to use it. */
export const MEMORY_KINDS = [
  'person', // someone in their life
  'trigger', // a situation that makes them want to vape
  'motivation', // a reason they are doing this
  'milestone', // something they are working toward or proud of
  'preference', // how they want to be talked to
  'context', // anything else durable about their life
] as const;
export type MemoryKind = (typeof MEMORY_KINDS)[number];

export interface Memory {
  readonly id: string;
  readonly text: string;
  readonly kind: MemoryKind;
}

interface StoredMemory {
  text: string;
  kind: MemoryKind;
  embedding: FirebaseFirestore.VectorValue;
  createdAt: FirebaseFirestore.FieldValue;
  lastUsedAt: FirebaseFirestore.FieldValue;
  useCount: number;
}

const memoriesCol = (uid: string): FirebaseFirestore.CollectionReference =>
  userDoc(uid).collection('memories');

/**
 * Whether a message could plausibly contain something worth remembering.
 *
 * A pure heuristic, and deliberately generous — a missed memory costs one
 * forgotten detail, while running the extraction model on every "[craving]"
 * chip tap would roughly double the coach's per-turn cost for nothing. Chips
 * arrive as `[craving]`; those carry no new information by construction.
 */
export function worthExtracting(userText: string): boolean {
  const trimmed = userText.trim();
  if (trimmed.startsWith('[') && trimmed.endsWith(']')) return false;
  // Under ~5 words there is rarely a durable fact ("ok", "thanks", "yeah").
  return trimmed.split(/\s+/).length >= 5;
}

/**
 * The memories most relevant to [queryVector], nearest first.
 *
 * Returns [] rather than throwing on any failure: a coach that answers without
 * its memory is degraded, a coach that fails to answer is broken.
 */
export async function recallRelevant(
  uid: string,
  queryVector: number[],
): Promise<Memory[]> {
  try {
    const snap = await memoriesCol(uid)
      .findNearest({
        vectorField: 'embedding',
        queryVector,
        limit: RECALL_LIMIT,
        distanceMeasure: 'COSINE',
        distanceResultField: 'distance',
      })
      .get();

    const distances = snap.docs.map((d) => d.get('distance') as number);
    const hits = snap.docs.filter(
      (doc) => (doc.get('distance') as number) <= RECALL_MAX_DISTANCE,
    );
    // The threshold is the one number here that cannot be reasoned out from
    // first principles — it depends on the embedding model's geometry and on
    // how people actually phrase things. Logging what was considered and what
    // survived is what makes it tunable from evidence instead of taste.
    log.info('memory.recall', {
      uid,
      considered: snap.size,
      kept: hits.length,
      nearest: distances.length > 0 ? Number(distances[0]!.toFixed(3)) : null,
      threshold: RECALL_MAX_DISTANCE,
    });

    // Recency-of-use is what the eviction policy reads, so touch what we used.
    if (hits.length > 0) await markUsed(hits);

    return hits.map((doc) => ({
      id: doc.id,
      text: doc.get('text') as string,
      kind: doc.get('kind') as MemoryKind,
    }));
  } catch (error) {
    log.warn('memory.recall_failed', {uid, error: String(error)});
    return [];
  }
}

/**
 * Stores [text], merging into a near-identical memory when one exists.
 *
 * The merge is what keeps the store honest over months: without it, someone
 * who mentions their sister in ten conversations ends up with ten nearly
 * identical vectors, all five recall slots filled by the same fact, and no
 * room for anything else.
 */
export async function remember(
  uid: string,
  text: string,
  kind: MemoryKind,
  embedding: number[],
): Promise<void> {
  const col = memoriesCol(uid);
  try {
    const existing = await col
      .findNearest({
        vectorField: 'embedding',
        queryVector: embedding,
        limit: 1,
        distanceMeasure: 'COSINE',
        distanceResultField: 'distance',
      })
      .get();

    const nearest = existing.docs[0];
    if (nearest && (nearest.get('distance') as number) <= DUPLICATE_DISTANCE) {
      // Same fact, said again — keep the newer phrasing and refresh recency
      // rather than adding a second copy.
      await nearest.ref.update({
        text,
        kind,
        embedding: FieldValue.vector(embedding),
        lastUsedAt: FieldValue.serverTimestamp(),
        useCount: AdminFieldValue.increment(1),
      });
      return;
    }

    const doc: StoredMemory = {
      text,
      kind,
      embedding: FieldValue.vector(embedding),
      createdAt: FieldValue.serverTimestamp(),
      lastUsedAt: FieldValue.serverTimestamp(),
      useCount: 0,
    };
    await col.add(doc);
    await evictIfOverCap(uid);
  } catch (error) {
    // A lost memory is not worth failing a reply over.
    log.warn('memory.write_failed', {uid, error: String(error)});
  }
}

/** Refreshes recency on the memories a turn actually used. */
async function markUsed(
  docs: readonly FirebaseFirestore.QueryDocumentSnapshot[],
): Promise<void> {
  const batch = docs[0]!.ref.firestore.batch();
  for (const doc of docs) {
    batch.update(doc.ref, {
      lastUsedAt: FieldValue.serverTimestamp(),
      useCount: AdminFieldValue.increment(1),
    });
  }
  await batch.commit();
}

/**
 * Keeps the store at [MAX_MEMORIES], dropping least-recently-used first.
 *
 * Bounded on purpose: `findNearest` scans the collection, so an unbounded
 * store means recall latency that grows with tenure — the users who have
 * earned the best coach would get the slowest one.
 */
async function evictIfOverCap(uid: string): Promise<void> {
  const col = memoriesCol(uid);
  const count = (await col.count().get()).data().count;
  if (count <= MAX_MEMORIES) return;

  const stale = await col
    .orderBy('lastUsedAt', 'asc')
    .limit(count - MAX_MEMORIES)
    .get();
  const batch = col.firestore.batch();
  for (const doc of stale.docs) batch.delete(doc.ref);
  await batch.commit();
  log.info('memory.evicted', {uid, dropped: stale.size});
}

/** Everything Ember remembers, newest first. Powers the user-facing list. */
export async function listMemories(uid: string): Promise<Memory[]> {
  const snap = await memoriesCol(uid).orderBy('createdAt', 'desc').limit(100).get();
  return snap.docs.map((doc) => ({
    id: doc.id,
    text: doc.get('text') as string,
    kind: doc.get('kind') as MemoryKind,
  }));
}

/** Forgets one memory. The user's right, and the reason the list exists. */
export async function forget(uid: string, memoryId: string): Promise<void> {
  await memoriesCol(uid).doc(memoryId).delete();
}
