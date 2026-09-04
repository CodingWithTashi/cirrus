/**
 * `createReply` — the sibling of `createPost` for thread replies (docs/03 §9).
 *
 * This callable is referenced by `firestore.rules` ("createReply callable") but
 * was never written, which left replies impossible to create by ANY route: the
 * rules deny direct creates and nothing else could write them. The community
 * feed has been read-only in practice.
 *
 * It inherits every rule the post path established:
 *   - no author uid on the document (rules gate documents, not fields), the
 *     mapping lives in the server-only `replyAuthors`
 *   - `status: 'pending'` until `moderateReply` classifies it
 *   - text validated server-side, 300 chars per docs/03 §9
 *
 * Extra rule of its own: you may only reply to a post that is actually live.
 * Replying to a pending or blocked post would pull it back into a thread the
 * rules are deliberately hiding.
 */
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {REGION} from '../config';
import {prefilter, replyQuality} from '../ai/prefilter';
import {db, FieldValue, postsCol} from '../lib/firestore';
import {requireCaller, requireText} from '../lib/guards';

/** docs/03 §9 — replies are tighter than posts (500). */
const MAX_REPLY_CHARS = 300;

export const createReply = onCall(
  {region: REGION, enforceAppCheck: true, memory: '256MiB'},
  async (request): Promise<{replyId: string}> => {
    const caller = requireCaller(request);
    const data = (request.data ?? {}) as Record<string, unknown>;

    const postId = requireText(data['postId'], 'postId', 200);
    const text = requireText(data['text'], 'text', MAX_REPLY_CHARS);

    // Same door as createPost: a slur is refused before anything is written.
    if (prefilter(text)?.action === 'block') {
      throw new HttpsError('invalid-argument', 'That breaks the community rules.');
    }

    // …and the same "was anything said" floor, at a much lower bar than a
    // post's. A reply is a nod as often as it is a paragraph, so "thanks" and
    // "yes yes" both pass and only "aaaaaa" and an emoji wall do not.
    // Replying is free and uncapped, which makes it the wider spam surface of
    // the two even though it is the quieter one.
    if (replyQuality(text) !== null) {
      throw new HttpsError('invalid-argument', 'Say a little more than that.');
    }

    const parent = await postsCol().doc(postId).get();
    if (!parent.exists) {
      throw new HttpsError('not-found', 'That post is no longer here.');
    }
    if (parent.get('status') !== 'live') {
      // Deliberately the same message as not-found: whether a post is pending
      // or blocked is not a reader's business.
      throw new HttpsError('not-found', 'That post is no longer here.');
    }

    const replyRef = parent.ref.collection('replies').doc();

    // A batch, not a transaction: nothing needs re-reading, but the reply and
    // its authorship mapping must land together or neither does — an orphaned
    // reply could never be anonymized on account deletion.
    const batch = db.batch();
    batch.set(replyRef, {
      alias: typeof data['alias'] === 'string' ? data['alias'] : 'quitter',
      avatarEmoji:
        typeof data['avatarEmoji'] === 'string' ? data['avatarEmoji'] : '\u{1F525}',
      text,
      status: 'pending', // invisible until moderateReply clears it
      createdAt: FieldValue.serverTimestamp(),
    });
    // Server-only (see firestore.rules). This is what lets deleteUserData find
    // a departing user's replies without a uid ever touching the reply itself.
    batch.set(db.collection('replyAuthors').doc(replyRef.id), {
      uid: caller.uid,
      postId,
      createdAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();

    return {replyId: replyRef.id};
  },
);
