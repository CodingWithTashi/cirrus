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
import {createHash} from 'node:crypto';
import {onCall} from 'firebase-functions/v2/https';
import {HttpsError} from 'firebase-functions/v2/https';
import {REGION} from '../config';
import {prefilter} from '../ai/prefilter';
import {dayKeyIn} from '../domain/dateKey';
import {db, FieldValue, myPostsCol, postsCol} from '../lib/firestore';
import {asEnum, requireCaller, requireText} from '../lib/guards';
import {claimDailyPost} from '../lib/usage';
import {POST_TAGS, type PostTag} from '../domain/types';

/** docs/03 §9: text <= 500 chars, one tag required, 3 posts/day. */
const MAX_POST_CHARS = 500;

/** The app's local post id (`p<micros>`); anything else gets a fresh id. */
const CLIENT_ID = /^[A-Za-z0-9_-]{1,64}$/;
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

    // Refused at the door, not after the write: the same deterministic list
    // `moderatePost` runs first. A slur never lands in Firestore, never
    // claims a cap slot, and its author hears "no" while the composer is
    // still open rather than "not published" later (docs/09 issue 6).
    if (prefilter(text)?.action === 'block') {
      throw new HttpsError('invalid-argument', 'That breaks the community rules.');
    }

    // Idempotent on the client's own id, so a retry of a send whose RESPONSE
    // was lost (the batch committed, the phone never heard) does not mint a
    // second post or spend a second cap slot. The document id is derived
    // from uid + clientId, so no caller can address another user's post.
    const clientId = data['clientId'];
    const keyed = typeof clientId === 'string' && CLIENT_ID.test(clientId);
    const post = keyed
      ? postsCol().doc(
          createHash('sha256')
            .update(`${caller.uid}:${clientId}`)
            .digest('hex')
            .slice(0, 20),
        )
      : postsCol().doc();
    if (keyed && (await post.get()).exists) return {postId: post.id};

    // Transactional, not count-then-write. The aggregate-query version let
    // five concurrent requests all observe "0 posted" and all proceed, which
    // made the cap decorative exactly when it mattered — pinned by
    // test/integration/createPost.test.ts.
    const claim = await claimDailyPost(
      caller.uid,
      dayKeyIn(new Date(), caller.timeZone),
      DAILY_POST_CAP,
    );
    if (!claim.allowed) {
      throw new HttpsError('resource-exhausted', 'Daily post limit reached.');
    }

    const alias = typeof data['alias'] === 'string' ? data['alias'] : 'quitter';

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
    // The author's own copy, under their own document: what lets the app
    // show "in review" instead of "Posted." followed by silence, and what
    // makes "is this mine?" a backend answer rather than a session memory.
    // Same batch, so a post can never exist without its author knowing.
    batch.set(myPostsCol(caller.uid).doc(post.id), {
      alias,
      avatarEmoji: typeof data['avatarEmoji'] === 'string' ? data['avatarEmoji'] : '🔥',
      dayN: typeof data['dayN'] === 'number' ? data['dayN'] : 0,
      tag,
      text,
      status: 'pending',
      createdAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();

    return {postId: post.id};
  },
);
