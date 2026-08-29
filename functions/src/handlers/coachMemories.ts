/**
 * Reading and forgetting what Ember remembers.
 *
 * An AI that quietly accumulates personal disclosures and gives the person no
 * way to see or remove them is a product people are right to distrust — and
 * for an app whose whole promise is "we never sell your data" (PRD §6), an
 * invisible memory store would undercut the positioning more than the feature
 * adds. So the store is legible and revocable by construction.
 *
 * Why callables rather than a direct Firestore read, when `users/{uid}/**` is
 * already owner-readable:
 *
 * - Each memory carries a 768-float embedding. Handing that to a phone to
 *   render one sentence would be ~3KB of wire per line, for data the client
 *   can do nothing with.
 * - Deleting needs a server anyway: `firestore.rules` denies every client
 *   write under `users/{uid}`, and that denial is what stops a client from
 *   granting itself Premium.
 */
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {REGION} from '../config';
import {forget, listMemories, type Memory} from '../lib/memories';
import {requireCaller, requireText} from '../lib/guards';
import {log} from '../lib/logger';

export const coachMemories = onCall(
  {region: REGION, enforceAppCheck: true, memory: '256MiB'},
  async (request): Promise<{memories: Memory[]}> => {
    const {uid} = requireCaller(request);
    return {memories: await listMemories(uid)};
  },
);

export const forgetCoachMemory = onCall(
  {region: REGION, enforceAppCheck: true, memory: '256MiB'},
  async (request): Promise<{forgotten: true}> => {
    const {uid} = requireCaller(request);
    const data = (request.data ?? {}) as Record<string, unknown>;
    const memoryId = requireText(data['memoryId'], 'memoryId', 200);
    // Firestore ids are opaque, but this one arrives from a client and is
    // concatenated into a document path — a slash would address a different
    // collection entirely.
    if (memoryId.includes('/')) {
      throw new HttpsError('invalid-argument', 'Bad memory id.');
    }

    // Scoped to the caller's own subcollection, so there is no id a user can
    // send that reaches somebody else's memory.
    await forget(uid, memoryId);
    log.info('memory.forgotten', {uid});
    return {forgotten: true};
  },
);
