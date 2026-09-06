/**
 * Telling people that somebody answered them.
 *
 * The one place a community reply turns into a push. Three handlers publish a
 * reply — the moderation trigger, the outage sweeper, and the founder
 * approving a held one — and all three call in here rather than each growing
 * their own idea of who deserves to hear about it.
 *
 * ## What it will not do
 *
 * * **Notify you about yourself.** The replier and the post's author are
 *   often the same person; before this checked, they pushed themselves.
 * * **Notify twice for one reply.** Three reports hide a live reply back to
 *   `pending`; when the founder later approves it, the approval path sees a
 *   was-pending reply and would announce it a second time — for a reply that
 *   was already live and already pushed, hours earlier. `notifiedAt` on the
 *   reply itself is the marker. It lives there rather than on the thread's
 *   collapse state because the collapse group has long since expired by then,
 *   and because one field that cannot grow beats a list that can.
 * * **Collapse an SOS.** See `pushKinds.ts`.
 */
import {COMMUNITY_PUSH} from '../config';
import {
  parseMentions,
  resolveMentions,
  type ThreadParticipant,
} from '../domain/mentions';
import {DEFAULT_COLLAPSE, decideNotification} from '../domain/notifyCollapse';
import type {ThreadNotifState} from '../domain/notifyCollapse';
import {FieldValue, db, notifThreadsCol, postsCol} from './firestore';
import {log} from './logger';
import {sendLocalized} from './push';

/** Replies scanned when resolving a mention. Bounded, and rarely reached. */
const MENTION_SCAN_LIMIT = 50;

/** The in-app destination a community push opens. */
export function threadRoute(postId: string): string {
  return `/community/post/${postId}`;
}

/** Groups every notification about one thread onto one shade line. */
export function threadTag(postId: string): string {
  return `thread:${postId}`;
}

/**
 * Announces a newly visible reply.
 *
 * Safe to call more than once for the same reply — the second call does
 * nothing. Never throws: a push is a courtesy, and a failed one must not fail
 * the moderation pass that triggered it.
 */
export async function notifyReply(
  postId: string,
  replyId: string,
  nowMs: number = Date.now(),
): Promise<void> {
  if (COMMUNITY_PUSH.value() === 'false') return;
  try {
    const postRef = postsCol().doc(postId);
    const replyRef = postRef.collection('replies').doc(replyId);
    const [post, reply, replyAuthor, postAuthor] = await Promise.all([
      postRef.get(),
      replyRef.get(),
      db.collection('replyAuthors').doc(replyId).get(),
      db.collection('postAuthors').doc(postId).get(),
    ]);

    if (!post.exists || !reply.exists) return;
    // Already announced. See the header — this is the report-hide-then-approve
    // path, and without it that reply pushes twice.
    if (reply.get('notifiedAt') !== undefined) return;

    const authorUid = asUid(postAuthor.get('uid'));
    // An unknown replier is not a reason to stay silent. `createReply` writes
    // the reply and its authorship in ONE batch, so a missing mapping means a
    // seeded fixture or a pre-mirror reply, never a real reply whose author we
    // lost — and the self-notify case this guards against cannot arise from a
    // reply we did not record. Only the checks that genuinely need the uid are
    // skipped: the self comparison, and mentions, which cannot exclude a
    // mentioner they cannot name.
    const replierUid = asUid(replyAuthor.get('uid'));

    const text = reply.get('text') as unknown;
    const isSos = post.get('tag') === 'sos';

    const mentioned =
      typeof text === 'string' && replierUid !== null
        ? await resolveThreadMentions(postRef, post, text, replierUid)
        : [];

    for (const uid of mentioned) {
      await sendLocalized(
        uid,
        'communityMention',
        threadRoute(postId),
        // A mention is addressed to one person, so it gets its own line
        // rather than joining the thread's collapsed one. Tagged by reply so
        // two mentions of the same person do not overwrite each other.
        {tag: `mention:${replyId}`, threadId: threadTag(postId)},
        nowMs,
      );
    }

    // The author hears about it unless they wrote it, or unless they were
    // already told by name — a mention is the more specific fact, and two
    // notifications for one reply is the noise this whole design exists to
    // avoid.
    if (
      authorUid !== null &&
      authorUid !== replierUid &&
      !mentioned.includes(authorUid)
    ) {
      await notifyAuthor(authorUid, postId, isSos, nowMs);
    }

    await replyRef.update({notifiedAt: FieldValue.serverTimestamp()});
  } catch (error) {
    log.warn('push.reply_failed', {postId, replyId, error: String(error)});
  }
}

/**
 * Sends the author's notification, collapsing where the kind allows.
 *
 * The collapse read and write are one transaction. Two replies 800ms apart
 * run in two concurrent instances, and a read-then-write would let both find
 * the throttle lapsed and both send — the exact burst the throttle exists to
 * stop. `reportReply` carries the same warning about its counter.
 */
async function notifyAuthor(
  uid: string,
  postId: string,
  isSos: boolean,
  nowMs: number,
): Promise<void> {
  if (isSos) {
    // Never collapsed and never quiet: the hour an SOS matters most is the
    // hour quiet hours would silence it, and the news IS how many people
    // came. See `pushKinds.ts`.
    await sendLocalized(
      uid,
      'sosReply',
      threadRoute(postId),
      {tag: threadTag(postId), threadId: threadTag(postId)},
      nowMs,
    );
    return;
  }

  const ref = notifThreadsCol(uid).doc(postId);
  const decision = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const state = snap.exists ? (snap.data() as ThreadNotifState) : null;
    const next = decideNotification(state, nowMs, DEFAULT_COLLAPSE);
    tx.set(ref, {...next.next, kind: 'communityReply'}, {merge: true});
    return next;
  });

  if (!decision.send) {
    log.info('push.collapsed', {uid, postId, count: decision.announceCount});
    return;
  }

  await sendLocalized(
    uid,
    'communityReply',
    threadRoute(postId),
    {
      // The same tag every time, so a later send REPLACES the shade line
      // instead of stacking. This is the half of "twenty replies, one
      // notification" that the server cannot do by itself.
      tag: threadTag(postId),
      threadId: threadTag(postId),
      count: decision.announceCount,
    },
    nowMs,
  );
}

/**
 * The uids an `@alias` in [text] refers to, resolved against this thread.
 *
 * Cheap in the common case, which is a reply mentioning nobody: it costs
 * nothing at all. Only when an alias-shaped token appears does it read the
 * thread, and even then it looks up authorship for the handful of replies
 * whose alias actually matches rather than for all of them.
 */
async function resolveThreadMentions(
  postRef: FirebaseFirestore.DocumentReference,
  post: FirebaseFirestore.DocumentSnapshot,
  text: string,
  replierUid: string,
): Promise<string[]> {
  const wanted = new Set(parseMentions(text).map((a) => a.toLowerCase()));
  if (wanted.size === 0) return [];

  const participants: ThreadParticipant[] = [];

  // The author speaks first by definition, which is what makes the
  // first-claimant rule in `resolveMentions` mean what it says.
  const postAlias = post.get('alias') as unknown;
  if (typeof postAlias === 'string' && wanted.has(postAlias.toLowerCase())) {
    const author = await db.collection('postAuthors').doc(post.id).get();
    const uid = asUid(author.get('uid'));
    if (uid !== null) participants.push({alias: postAlias, uid});
  }

  const replies = await postRef
    .collection('replies')
    .where('status', '==', 'live')
    .orderBy('createdAt', 'asc')
    .limit(MENTION_SCAN_LIMIT)
    .get();

  const matches = replies.docs.filter((doc) => {
    const alias = doc.get('alias') as unknown;
    return typeof alias === 'string' && wanted.has(alias.toLowerCase());
  });

  const authors = await Promise.all(
    matches.map((doc) => db.collection('replyAuthors').doc(doc.id).get()),
  );
  matches.forEach((doc, i) => {
    const uid = asUid(authors[i]?.get('uid'));
    if (uid !== null) participants.push({alias: doc.get('alias') as string, uid});
  });

  return resolveMentions(text, participants, replierUid);
}

function asUid(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0 ? value : null;
}
