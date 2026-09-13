/**
 * `onReplyStatus` — keeps `posts/{postId}.replyCount` in step with the replies
 * subcollection, so the feed can render "3 replied" without downloading three
 * replies (or, as it did, every live reply in the app). The full reasoning,
 * and the cost table that motivated it, is on `lib/replyCount.ts`.
 *
 * ## One owner, on purpose
 *
 * FOUR paths move a reply in or out of `live`: `moderateReply` on the model's
 * verdict, `reportReply` when the third report auto-hides it, `remoderateHeld`
 * when a retryable hold is re-asked, and `resolveModeration` when the founder
 * decides. Incrementing at each of those would be four places to remember and
 * a fifth to forget. A trigger on the reply document sees all of them and
 * cannot be bypassed.
 *
 * ## Why this recounts where `onReaction` takes deltas
 *
 * Not an inconsistency — the two aggregates are different shapes.
 * `posts.reactions` is a map of counts PER EMOJI, which no single aggregation
 * query can produce, so recomputing it would mean reading every reactor
 * document; two atomic increments are the right answer there.
 *
 * `replyCount` is one number, so `count()` answers it in a single aggregation
 * read (billed per 1000 index entries, not per document — one read for any
 * thread anyone will ever write). That buys two properties increments cannot
 * have. Firestore triggers are at-least-once, so a re-delivered event would
 * increment twice and be permanently wrong; a recount is idempotent. And a
 * recount is self-healing — it repairs drift from any cause, including posts
 * written before this field existed, the first time anyone replies to them.
 */
import {onDocumentWritten} from 'firebase-functions/v2/firestore';
import {REGION} from '../config';
import {recountReplies} from '../lib/replyCount';

export const onReplyStatus = onDocumentWritten(
  {
    region: REGION,
    document: 'posts/{postId}/replies/{replyId}',
    memory: '256MiB',
    // Matching `onReaction`: the next status change recomputes from scratch,
    // so a lost invocation self-corrects rather than compounding.
    retry: false,
  },
  async (event) => {
    // Only live-ness matters. A reply is written several times in its life
    // without changing whether it counts — created `pending`, anonymized by
    // `deleteUserData` (alias and avatar, status untouched), re-held by
    // `remoderateHeld`. Recounting on each of those would be an aggregation
    // read for a number that cannot have moved.
    //
    // A missing snapshot reads as undefined, which is the correct answer for
    // both ends: a create has no `before`, a delete has no `after`, and
    // neither is `live`.
    const wasLive = event.data?.before.get('status') === 'live';
    const isLive = event.data?.after.get('status') === 'live';
    if (wasLive === isLive) return;

    await recountReplies(event.params.postId);
  },
);
