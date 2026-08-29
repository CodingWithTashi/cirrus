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
import {REGION} from '../config';
import {db, journeyDoc, postsCol, userDoc} from '../lib/firestore';
import {requireCaller} from '../lib/guards';
import {log} from '../lib/logger';

const DEPARTED_ALIAS = '[departed quitter]';

export const deleteUserData = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
    memory: '512MiB',
    timeoutSeconds: 300,
  },
  async (request): Promise<{deleted: true}> => {
    const {uid} = requireCaller(request);

    // Order matters: anonymize while we can still find the posts by uid, then
    // drop the trees, then the auth record last — if anything above throws,
    // the user still has an account to retry with.
    await anonymizePosts(uid);
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
