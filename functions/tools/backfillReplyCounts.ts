/**
 * One-time backfill of `posts/{id}.replyCount`.
 *
 * Deliberately OUTSIDE `src/`, so it never lands in the deploy bundle and no
 * cold start pays for it.
 *
 * ## Why it is needed at all
 *
 * `onReplyStatus` recounts on every transition in or out of `live`, which makes
 * the field self-healing — but only for a post somebody still replies to. A
 * post written before the field existed whose thread has gone quiet keeps no
 * count at all, and the feed then falls back to the replies it holds, which is
 * none. It would read "no replies" under a thread that has ten.
 *
 * So: run this once after deploying the trigger. It is idempotent and safe to
 * re-run — it writes the same number it computes — so a partial run is simply
 * resumed by running it again.
 *
 *   npm run backfill:replyCounts
 *
 * Reads a page of posts at a time rather than all of them: `posts` is the one
 * collection with no ceiling, and holding the whole feed in memory to write one
 * integer per row is exactly the shape this whole change exists to remove.
 */
import {initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';

const PAGE = 200;

async function main(): Promise<void> {
  initializeApp();
  const db = getFirestore();
  const dryRun = process.argv.includes('--dry-run');

  let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  let scanned = 0;
  let written = 0;
  let alreadyRight = 0;

  for (;;) {
    let q = db.collection('posts').orderBy('__name__').limit(PAGE);
    if (cursor !== undefined) q = q.startAfter(cursor);
    const page = await q.get();
    if (page.empty) break;

    for (const post of page.docs) {
      scanned += 1;
      const agg = await post.ref
        .collection('replies')
        .where('status', '==', 'live')
        .count()
        .get();
      const replyCount = agg.data().count;
      if (post.get('replyCount') === replyCount) {
        alreadyRight += 1;
        continue;
      }
      if (!dryRun) await post.ref.update({replyCount});
      written += 1;
      // eslint-disable-next-line no-console
      console.log(
        `${dryRun ? 'would set' : 'set'} ${post.id}.replyCount = ${replyCount}` +
          ` (was ${String(post.get('replyCount'))})`,
      );
    }

    cursor = page.docs[page.docs.length - 1];
    if (page.size < PAGE) break;
  }

  // eslint-disable-next-line no-console
  console.log(
    `\n${scanned} posts scanned · ${written} ${dryRun ? 'would be updated' : 'updated'}` +
      ` · ${alreadyRight} already correct`,
  );
}

main().catch((error: unknown) => {
  // eslint-disable-next-line no-console
  console.error(error);
  process.exitCode = 1;
});
