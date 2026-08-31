/**
 * `seedCoachMemories` — the first thing Ember knows about somebody.
 *
 * Nineteen onboarding screens reach the model exactly and for free through the
 * deterministic user card (`ai/memoryCard.ts`), and that is where chips and
 * enums belong: they are facts, and the vector layer would only turn them back
 * into probabilities. But `users/{uid}/memories` is written from exactly one
 * place — the extraction pass at the end of `aiCoachChat` — so it started
 * empty for every account and stayed empty until somebody happened to type
 * something into the coach. A coach whose memory is empty on day one is just a
 * chatbot with your stats.
 *
 * One optional free-text answer now closes that, and this carries it across.
 *
 * **The sentence is read from the stored journey, never from the request.**
 * `journeys/{uid}` is client-owned, so what is in it is whatever the app
 * wrote — but `decodeJourney` sanitizes it on the way through, and that is a
 * boundary a request parameter would sit on the wrong side of. A client that
 * could pass its own text here could write itself arbitrary memories, and a
 * memory goes into a system prompt.
 *
 * Why a callable rather than a lazy seed inside `aiCoachChat`: that handler is
 * latency-critical by design — it runs while somebody is mid-craving — and
 * adding a count read and an embedding call to its hot path to serve a
 * once-per-account concern is the wrong trade. This mirrors `setCoachName`:
 * a client-owned journey plus one validated server-side effect.
 */
import {onCall} from 'firebase-functions/v2/https';
import {GEMINI_API_KEY, REGION} from '../config';
import {geminiModel} from '../ai/gemini';
import {decodeJourney, JourneyDecodeError} from '../domain/journeyCodec';
import {FieldValue, journeyDoc, userDoc} from '../lib/firestore';
import {requireCaller} from '../lib/guards';
import {log} from '../lib/logger';
import {EMBEDDING_DIMENSIONS, remember} from '../lib/memories';

export const seedCoachMemories = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
    secrets: [GEMINI_API_KEY],
    memory: '256MiB',
    timeoutSeconds: 30,
  },
  async (request): Promise<{seeded: number}> => {
    const caller = requireCaller(request);

    // One shot per account. `remember` already merges a duplicate ROW below
    // its distance threshold, but that happens after the embedding has been
    // paid for — and a retry, a reinstall or a double tap would each buy one.
    const user = await userDoc(caller.uid).get();
    if (user.get('coachMemoriesSeeded') === true) return {seeded: 0};

    const snap = await journeyDoc(caller.uid).get();
    if (!snap.exists) return {seeded: 0};

    let words: string | null;
    try {
      words = decodeJourney(snap.data()).profile.whyWords;
    } catch (error) {
      // A journey this build cannot read is not a reason to fail the last
      // screen of onboarding.
      if (error instanceof JourneyDecodeError) return {seeded: 0};
      throw error;
    }
    // They skipped the question. Declining to answer is an answer, and there
    // is nothing here to remember.
    if (words === null) return {seeded: 0};

    try {
      const model = geminiModel(GEMINI_API_KEY.value());
      const vectors = await model.embed(
        [words],
        EMBEDDING_DIMENSIONS,
        // Stored side of an asymmetric pair — `recallRelevant` embeds the
        // query with 'query'. Swapping these degrades recall silently.
        'document',
      );
      const vector = vectors[0];
      if (vector === undefined) return {seeded: 0};

      await remember(caller.uid, words, 'motivation', vector);
    } catch (error) {
      // This runs between the paywall and the app. A model outage costs a
      // memory, never the account — and the flag below is deliberately NOT
      // set, so the next launch can try again.
      log.warn('memory.seed_failed', {
        uid: caller.uid,
        error: String(error),
      });
      return {seeded: 0};
    }

    await userDoc(caller.uid).set(
      {coachMemoriesSeeded: true, updatedAt: FieldValue.serverTimestamp()},
      {merge: true},
    );
    log.info('memory.seeded', {uid: caller.uid});
    return {seeded: 1};
  },
);
