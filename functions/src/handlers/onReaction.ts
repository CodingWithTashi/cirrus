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
import {isReactionEmoji} from '../domain/types';
import {FieldPath, FieldValue, postsCol} from '../lib/firestore';
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
  // Only the closed palette. A reactor document is written CLIENT-DIRECT (the
  // rules let its owner write it), so this is the one piece of text a reader
  // can put on somebody else's post without passing `createPost`, the
  // prefilter, the classifier or the slur check. It used to accept ANY
  // non-empty string, which then rendered verbatim as a pill in every reader's
  // feed — with no report path, no way for the author to remove it, and no
  // bound on how many distinct keys one person could add to the map. The rules
  // carry the same list; either half alone is sufficient and both are cheap.
  return isReactionEmoji(value) ? value : null;
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

    // `FieldPath`, never a template string. `update()` parses a string key as a
    // DOT-SEPARATED path, so an emoji containing a dot wrote a NESTED map
    // (`reactions: {a: {b: 1}}`) and every client then threw casting
    // `reactions` to Map<String,int> — taking the community tab down for
    // EVERY user, with no way for the server to heal it and no way for the
    // author to edit it. A FieldPath segment is treated literally. The palette
    // check above already refuses such a value; this is the second lock on the
    // same door, because the cost of that door failing is the feed being dead
    // for everyone at once.
    const updates: [FirebaseFirestore.FieldPath, FirebaseFirestore.FieldValue][] = [];
    if (delta.removed !== null) {
      updates.push([new FieldPath('reactions', delta.removed), FieldValue.increment(-1)]);
    }
    if (delta.added !== null) {
      updates.push([new FieldPath('reactions', delta.added), FieldValue.increment(1)]);
    }
    const [first, ...rest] = updates;
    if (first === undefined) return;

    try {
      await postsCol().doc(postId).update(first[0], first[1], ...rest.flat());
    } catch (error) {
      // The post may have been removed between the tap and this trigger.
      // A reaction on a deleted post is not worth a retry storm.
      log.warn('reaction.post_missing', {postId, error: String(error)});
    }
  },
);
