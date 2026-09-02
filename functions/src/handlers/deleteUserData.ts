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
 */
import {onCall} from 'firebase-functions/v2/https';
import {getAuth} from 'firebase-admin/auth';
import {REGION, REVENUECAT_SECRET_API_KEY} from '../config';
import {db, journeyDoc, postsCol, userDoc} from '../lib/firestore';
import {requireCaller} from '../lib/guards';
import {log} from '../lib/logger';
import {deleteSubscriber} from '../lib/revenuecat';

const DEPARTED_ALIAS = '[departed quitter]';

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
    await db.recursiveDelete(userDoc(uid));
    await journeyDoc(uid).delete();
    await getAuth().deleteUser(uid);

    log.info('deleteUserData.done', {uid});
    return {deleted: true};
  },
);

/**
 * Posts carry no uid (see `createPost`), so the authorship mapping in the
 * server-only `postAuthors` collection is what makes erasure possible at all.
 * Both the post's byline and the mapping row go.
 */
async function anonymizePosts(uid: string): Promise<void> {
  const snap = await db.collection('postAuthors').where('uid', '==', uid).get();
  if (snap.empty) return;
  // Firestore caps a batch at 500 writes; each post costs two.
  for (let i = 0; i < snap.docs.length; i += 200) {
    const batch = db.batch();
    for (const author of snap.docs.slice(i, i + 200)) {
      batch.update(postsCol().doc(author.id), {
        alias: DEPARTED_ALIAS,
        avatarEmoji: '\u{1F464}',
      });
      batch.delete(author.ref);
    }
    await batch.commit();
  }
}

/**
 * Replies get the same treatment as posts: the words stay so threads other
 * quitters are reading do not develop holes, the authorship goes.
 *
 * Reply documents are nested under their post, so the mapping carries postId —
 * without it there is no way to address the reply for update.
 */
async function anonymizeReplies(uid: string): Promise<void> {
  const snap = await db.collection('replyAuthors').where('uid', '==', uid).get();
  if (snap.empty) return;
  for (let i = 0; i < snap.docs.length; i += 200) {
    const batch = db.batch();
    for (const author of snap.docs.slice(i, i + 200)) {
      const postId = author.get('postId') as unknown;
      if (typeof postId === 'string') {
        batch.update(postsCol().doc(postId).collection('replies').doc(author.id), {
          alias: DEPARTED_ALIAS,
          avatarEmoji: '\u{1F464}',
        });
      }
      batch.delete(author.ref);
    }
    await batch.commit();
  }
}
