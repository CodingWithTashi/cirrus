/**
 * `posts/{id}.replyCount` — how many LIVE replies a post has.
 *
 * ## Why the field exists
 *
 * The feed never needed reply bodies. `PostCard` uses exactly two things:
 * whether there are any replies, and how many. The bodies are only ever read
 * on the thread screen, which `fetchPost` loads from the post's own
 * subcollection.
 *
 * It got them anyway. `fetchPosts` limited posts to 50 and then ran
 * `collectionGroup('replies').where('status','==','live')` with **no limit at
 * all** — every live reply in the entire app, downloaded on every feed open,
 * to render a number. The trade was deliberate and reasonable when it was
 * written ("one query beats 51 round trips for a 50-post feed") and it stops
 * being reasonable quickly, because replying is uncapped and free by design:
 *
 *     live replies   feed opens/day   reads/day     $/month   payload/open
 *          1,000              500       500,000          $9        0.2 MB
 *         10,000            2,000    20,000,000        $360        2.0 MB
 *         45,000            5,000   225,000,000      $4,050        9.0 MB
 *        150,000           15,000 2,250,000,000     $40,500         30 MB
 *
 * It grows with replies TIMES readers, so it would have overtaken the AI
 * budget the PRD guards at $0.25/user/month long before launch traffic, and
 * approached the whole $44K MRR target after it. A denormalised count is the
 * same shape `onReaction` already maintains for `posts/{id}.reactions`.
 *
 * ## Why a recount rather than an increment
 *
 * Four separate paths move a reply in or out of `live` — `moderateReply`,
 * `reportReply`'s auto-hide, `resolveModeration` and `remoderateHeld` — so a
 * single owner is the only way this does not drift the first time a fifth is
 * added. That owner is the trigger in `handlers/onReplyStatus.ts`.
 *
 * And it writes an ABSOLUTE count, not `FieldValue.increment`. Firestore
 * triggers are at-least-once: a re-delivered event would increment twice and
 * the error would be permanent. A recount is idempotent under re-delivery and
 * self-healing if the number is ever wrong for any other reason — including
 * for posts written before this field existed. It costs one aggregation read
 * per status change, against the tens of thousands of document reads per feed
 * open it removes.
 */
import {postsCol} from './firestore';
import {log} from './logger';

/**
 * Recomputes and stores the live reply count for [postId].
 *
 * Returns the count written, or null when the post is gone — a reply
 * transitioning on a post that no longer exists is not worth a retry storm,
 * the same call `onReaction` makes.
 */
export async function recountReplies(postId: string): Promise<number | null> {
  const post = postsCol().doc(postId);
  const agg = await post
    .collection('replies')
    .where('status', '==', 'live')
    .count()
    .get();
  const replyCount = agg.data().count;
  try {
    // `update`, not `set(..., {merge: true})`: a post that is not there must
    // not be conjured into existence by one of its replies changing status.
    await post.update({replyCount});
    return replyCount;
  } catch (error) {
    log.warn('replyCount.post_missing', {postId, error: String(error)});
    return null;
  }
}
