/**
 * `deleteUserData` — full erasure (docs/03 §11, docs/05 §7).
 *
 * Required by App Store Guideline 5.1.1(v) (account deletion in-app) and by
 * our own "we never sell your data" promise, which is worth nothing if we
 * can't actually let go of it.
 *
 * Community posts are ANONYMIZED, not deleted: removing them would gut reply
 * threads other quitters are still reading. The authoring uid goes, the words
 * stay under "[departed quitter]" (docs/03 §11).
 *
 * A reader leaves a trail without ever writing a word, and that is erased too
 * — see [deleteReactions] and [deleteReports].
 */
import {onCall} from 'firebase-functions/v2/https';
import {getAuth} from 'firebase-admin/auth';
import {REGION, REVENUECAT_SECRET_API_KEY} from '../config';
import {db, journeyDoc, postsCol, userDoc} from '../lib/firestore';
import {requireCaller} from '../lib/guards';
import {log} from '../lib/logger';
import {deleteSubscriber} from '../lib/revenuecat';

const DEPARTED_ALIAS = '[departed quitter]';
const DEPARTED_EMOJI = '\u{1F464}';

export const deleteUserData = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
    memory: '512MiB',
    timeoutSeconds: 300,
    secrets: [REVENUECAT_SECRET_API_KEY],
  },
  async (request): Promise<{deleted: true}> => {
    const {uid} = requireCaller(request);

    // Order matters. The one third-party call goes FIRST: it is idempotent
    // (404 is done), and a RevenueCat outage must throw before anything here
    // has changed — not after the posts already read "[departed quitter]"
    // while the account still exists. The RevenueCat customer is keyed by
    // this uid and holds purchase history, which the erasure promise covers;
    // the store subscription itself is untouched, and a later restore on a
    // new account transfers it (project restore behaviour: transfer). Then
    // anonymize while we can still find the posts by uid, then drop the
    // trees, then the auth record last — if anything above throws, the user
    // still has an account to retry with.
    await deleteSubscriber(uid);
    await anonymizePosts(uid);
    await anonymizeReplies(uid);
    await deleteReactions(uid);
    await deleteReports(uid);
    await db.recursiveDelete(userDoc(uid));
    await journeyDoc(uid).delete();
    await getAuth().deleteUser(uid);

    log.info('deleteUserData.done', {uid});
    return {deleted: true};
  },
);

/**
 * Page size for an erasure sweep.
 *
 * Each matched document costs at most two writes (an anonymizing update plus
 * the mapping delete), so 200 stays under Firestore's 500-write batch cap.
 *
 * It also bounds MEMORY, which is the reason it is paged at all: an unlimited
 * `.get()` materialises the entire result set, and while posts are capped at
 * three a day, REPLIES and REACTIONS are uncapped — a heavy reader accumulates
 * them without limit, inside a function with 512MiB.
 */
const ERASE_PAGE = 200;

/**
 * Deletes every document matching [query], one bounded page at a time, running
 * [also] first for whatever extra write each one implies.
 *
 * The matched document is ALWAYS deleted, and that is what makes the loop
 * terminate: every pass shrinks the result set, so the query eventually comes
 * back empty. Content that has to survive — a post, a reply — is edited
 * through [also] and is never itself the thing being matched.
 *
 * Each page commits on its own, so an erasure interrupted part way has still
 * made progress and a retry resumes rather than starting over.
 */
async function sweepDelete(
  query: FirebaseFirestore.Query,
  also?: (
    batch: FirebaseFirestore.WriteBatch,
    doc: FirebaseFirestore.QueryDocumentSnapshot,
  ) => void,
): Promise<void> {
  for (;;) {
    const page = await query.limit(ERASE_PAGE).get();
    if (page.empty) return;
    const batch = db.batch();
    for (const doc of page.docs) {
      also?.(batch, doc);
      batch.delete(doc.ref);
    }
    await batch.commit();
    // A short page is the last one; skip the extra round trip.
    if (page.size < ERASE_PAGE) return;
  }
}

/**
 * Posts carry no uid (see `createPost`), so the authorship mapping in the
 * server-only `postAuthors` collection is what makes erasure possible at all.
 * Both the post's byline and the mapping row go.
 *
 * The update assumes a mapping row implies its post, which `createPost`
 * guarantees by writing both in one batch and nothing else ever deletes. If
 * something one day does, it must delete the mapping row with it: an orphan
 * here fails the batch and leaves that account unable to erase itself.
 */
async function anonymizePosts(uid: string): Promise<void> {
  await sweepDelete(
    db.collection('postAuthors').where('uid', '==', uid),
    (batch, author) => {
      batch.update(postsCol().doc(author.id), {
        alias: DEPARTED_ALIAS,
        avatarEmoji: DEPARTED_EMOJI,
      });
    },
  );
}

/**
 * Replies get the same treatment as posts: the words stay so threads other
 * quitters are reading do not develop holes, the authorship goes.
 *
 * Reply documents are nested under their post, so the mapping carries postId —
 * without it there is no way to address the reply for update.
 */
async function anonymizeReplies(uid: string): Promise<void> {
  await sweepDelete(
    db.collection('replyAuthors').where('uid', '==', uid),
    (batch, author) => {
      const postId = author.get('postId') as unknown;
      if (typeof postId !== 'string') return;
      batch.update(postsCol().doc(postId).collection('replies').doc(author.id), {
        alias: DEPARTED_ALIAS,
        avatarEmoji: DEPARTED_EMOJI,
      });
    },
  );
}

/**
 * A reaction is nothing BUT an identity — there are no words to keep — so it
 * is deleted outright rather than anonymized.
 *
 * These were missed entirely. `posts/{id}/reactors/{uid}` is keyed by the uid
 * *and* carries it as a field, and it sits under `posts`, so neither
 * `recursiveDelete(users/{uid})` nor the two anonymize passes reached it. After
 * a full erasure the departed account's uid was still written on every post it
 * had ever reacted to — a record of what that person read and how they felt
 * about it, outliving the one operation whose whole promise is that nothing
 * does.
 *
 * `onReaction` fires on each delete and decrements the post's aggregate, so the
 * count follows the person out. The field already has the COLLECTION_GROUP
 * index this query needs (the app runs the same one for its own reactions).
 */
async function deleteReactions(uid: string): Promise<void> {
  await sweepDelete(db.collectionGroup('reactors').where('uid', '==', uid));
}

/**
 * Reports: the identity goes, the COUNT stays.
 *
 * Deliberately not symmetrical with reactions. `reportCount` is what auto-hides
 * a post at three, and a report was a real judgement by a real reader — undoing
 * it because they later closed their account would quietly un-hide content the
 * community had flagged. Nothing decrements on this delete (there is no trigger
 * on `reporters`), which is exactly what we want.
 *
 * The uid is repeated as a FIELD on these rows purely so this query can find
 * them: a collection-group filter on `documentId()` needs a full resource
 * path, so the document id alone is not queryable.
 */
async function deleteReports(uid: string): Promise<void> {
  await sweepDelete(db.collectionGroup('reporters').where('uid', '==', uid));
}
