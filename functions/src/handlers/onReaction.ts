/**
 * `onReaction` — keeps `posts/{postId}.reactions` in step with the reactors
 * subcollection.
 *
 * Reaction counts used to be client-writable, which meant any repackaged
 * client could give any post any popularity it liked. They are derived now:
 * the client writes only its OWN `reactors/{uid}` document (rules enforce
 * that), and this recomputes the aggregate.
 *
 * Deltas, not recounts. Re-reading every reactor on each tap would turn a
 * popular post into a hot document and cost a read per existing reaction; two
 * atomic increments cost the same whether ten people have reacted or ten
 * thousand.
 */
import {onDocumentWritten} from 'firebase-functions/v2/firestore';
import {REGION} from '../config';
import {FieldValue, postsCol} from '../lib/firestore';
import {log} from '../lib/logger';

/** What changed for one person: which emoji they left, and which they took back. */
export interface ReactionDelta {
  readonly added: string | null;
  readonly removed: string | null;
}

/**
 * Pure so it can be reasoned about and tested without Firestore.
 *
 * The case that matters is the third one: re-writing the SAME emoji (a double
 * tap, or a retried write) must produce no delta at all, or a flaky network
 * would inflate the count.
 */
export function reactionDelta(
  before: string | null,
  after: string | null,
): ReactionDelta {
  if (before === after) return {added: null, removed: null};
  return {added: after, removed: before};
}

const emojiOf = (
  data: FirebaseFirestore.DocumentData | undefined,
): string | null => {
  // DocumentData values are `any`; narrow through unknown before trusting it.
  const value = (data as Record<string, unknown> | undefined)?.['emoji'];
  return typeof value === 'string' && value.length > 0 ? value : null;
};

export const onReaction = onDocumentWritten(
  {
    region: REGION,
    document: 'posts/{postId}/reactors/{uid}',
    memory: '256MiB',
    retry: false,
  },
  async (event) => {
    const {postId} = event.params;
    const delta = reactionDelta(
      emojiOf(event.data?.before.data()),
      emojiOf(event.data?.after.data()),
    );
    if (delta.added === null && delta.removed === null) return;

    const update: Record<string, FirebaseFirestore.FieldValue> = {};
    if (delta.removed !== null) {
      update[`reactions.${delta.removed}`] = FieldValue.increment(-1);
    }
    if (delta.added !== null) {
      update[`reactions.${delta.added}`] = FieldValue.increment(1);
    }

    try {
      await postsCol().doc(postId).update(update);
    } catch (error) {
      // The post may have been removed between the tap and this trigger.
      // A reaction on a deleted post is not worth a retry storm.
      log.warn('reaction.post_missing', {postId, error: String(error)});
    }
  },
);
