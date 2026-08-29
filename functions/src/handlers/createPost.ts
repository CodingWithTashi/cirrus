/**
 * `createPost` — the only way a community post is born (docs/03 §9).
 *
 * WHY A FUNCTION AND NOT A RULE: docs/05 §6 requires the author's uid never
 * be exposed to clients. Firestore rules gate whole documents, not fields —
 * if the uid is stored on the post, every reader can see it. So the post is
 * written WITHOUT a uid and the mapping is kept in the server-only
 * `postAuthors/{postId}`, which `deleteUserData` uses to find a departing
 * user's posts.
 *
 * The post lands as `status: 'pending'` and only `moderatePost` can flip it
 * live — so nothing is ever visible before it has been classified.
 */
import {onCall} from 'firebase-functions/v2/https';
import {HttpsError} from 'firebase-functions/v2/https';
import {REGION} from '../config';
import {db, FieldValue, postsCol} from '../lib/firestore';
import {asEnum, requireCaller, requireText} from '../lib/guards';
import {POST_TAGS, type PostTag} from '../domain/types';

/** docs/03 §9: text <= 500 chars, one tag required, 3 posts/day. */
const MAX_POST_CHARS = 500;
const DAILY_POST_CAP = 3;

export const createPost = onCall(
  {region: REGION, enforceAppCheck: true, memory: '256MiB'},
  async (request): Promise<{postId: string}> => {
    const caller = requireCaller(request);
    const data = (request.data ?? {}) as Record<string, unknown>;

    const text = requireText(data['text'], 'text', MAX_POST_CHARS);
    const tag = asEnum<PostTag>(data['tag'], POST_TAGS);
    if (tag === null) {
      throw new HttpsError('invalid-argument', 'A post tag is required.');
    }

    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const recent = await db
      .collection('postAuthors')
      .where('uid', '==', caller.uid)
      .where('createdAt', '>', since)
      .count()
      .get();
    if (recent.data().count >= DAILY_POST_CAP) {
      throw new HttpsError('resource-exhausted', 'Daily post limit reached.');
    }

    const alias = typeof data['alias'] === 'string' ? data['alias'] : 'quitter';
    const post = postsCol().doc();

    // A batch, not a transaction: there is nothing to read first, and both
    // writes must still land together or neither does.
    const batch = db.batch();
    batch.set(post, {
      alias,
      avatarEmoji: typeof data['avatarEmoji'] === 'string' ? data['avatarEmoji'] : '🔥',
      dayN: typeof data['dayN'] === 'number' ? data['dayN'] : 0,
      tag,
      text,
      reactions: {},
      reportCount: 0,
      status: 'pending', // invisible until moderatePost clears it
      createdAt: FieldValue.serverTimestamp(),
    });
    // Server-only. Never readable by any client (see firestore.rules).
    batch.set(db.collection('postAuthors').doc(post.id), {
      uid: caller.uid,
      createdAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();

    return {postId: post.id};
  },
);
