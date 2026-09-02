/**
 * The single Firestore entry point, and the file that encodes the ownership
 * split the rest of the backend depends on.
 *
 * THE RULE (firestore.rules, functions/README.md):
 *
 *   journeys/{uid}   CLIENT-owned. `FirebaseJourneyRepository.save()` writes
 *                    the WHOLE document on every optimistic mutation, so any
 *                    server field written here is destroyed by the next puff
 *                    tap. The server reads this tree; it never writes it.
 *   users/{uid}      SERVER-owned. Entitlement, AI usage, plan advice.
 *                    Readable by its owner, writable only through the Admin
 *                    SDK (which bypasses rules by design).
 *
 * Every helper below is a path constructor, not a query layer — handlers own
 * their own queries. Centralizing the paths is what stops a typo'd collection
 * name from silently writing into a collection the rules deny-by-default.
 */
import {getApps, initializeApp} from 'firebase-admin/app';
import {
  FieldValue,
  Timestamp,
  getFirestore,
  type CollectionReference,
  type DocumentReference,
} from 'firebase-admin/firestore';
import type {SubscriptionTier} from '../domain/types';

// Deployed functions always have GCLOUD_PROJECT set; the fallback keeps a
// bare `vitest` import of a handler from touching credential discovery.
if (getApps().length === 0) {
  initializeApp({projectId: process.env['GCLOUD_PROJECT'] ?? 'alastpuff'});
}

export const db = getFirestore();

export {FieldValue, Timestamp};

// --- Client-owned ----------------------------------------------------------

/** The whole quit journey, one document. READ-ONLY from the server. */
export const journeyDoc = (uid: string): DocumentReference =>
  db.collection('journeys').doc(uid);

// --- Server-owned ----------------------------------------------------------

export const userDoc = (uid: string): DocumentReference =>
  db.collection('users').doc(uid);

/**
 * Coach transcript. Flat per user rather than docs/05 §6's
 * `coachThreads/{id}/messages/{id}` — MVP has exactly one thread, and living
 * under `users/{uid}` means `recursiveDelete` in deleteUserData sweeps it
 * without a second traversal.
 */
export const coachMessages = (uid: string): CollectionReference =>
  userDoc(uid).collection('coachMessages');

/** Panic sessions (docs/03 §7). One document per completed session. */
export const cravingsCol = (uid: string): CollectionReference =>
  userDoc(uid).collection('cravings');

/**
 * Push registrations, one document per device, keyed by the SHA-256 of the
 * token (see `lib/push.ts`).
 *
 * A document rather than an array entry so a device can carry its platform and
 * a `lastSeenAt` the prune cron can judge, and so sign-out can release exactly
 * one device. The flat `fcmTokens` array this replaces could only ever be
 * added to — which is how a signed-out phone kept receiving the previous
 * account's pushes.
 */
export const devicesCol = (uid: string): CollectionReference =>
  userDoc(uid).collection('devices');

/** Weekly AI report, keyed by the user's local Sunday. */
export const insightDoc = (uid: string, weekId: string): DocumentReference =>
  userDoc(uid).collection('insights').doc(weekId);

/**
 * The author's own view of their posts: `users/{uid}/posts/{postId}` carries
 * the post's text, tag and — the part that matters — its moderation
 * `status`, kept in step by every handler that flips `posts/{id}.status`.
 *
 * Why it exists: the feed rules expose only `status == 'live'`, and posts
 * carry no uid, so an author had NO way to learn that their post was held
 * or refused — it said "Posted." and was gone on the next launch (QA M5) —
 * and no durable way to know which live posts were theirs at all, which is
 * the condition that hides Report and Block (QA H3). Server-owned like
 * everything else under `users/{uid}`: readable by the owner through the
 * existing `users/{uid}/{document=**}` rule, written only from here, and
 * swept by `deleteUserData`'s `recursiveDelete` with the rest.
 */
export const myPostsCol = (uid: string): CollectionReference =>
  userDoc(uid).collection('posts');

/**
 * `held` exists on the MIRROR only. The post document itself never carries
 * it — there a hold stays `pending`, which the rules treat as invisible — but
 * the author's private row distinguishes "not classified yet" (`pending`,
 * rendered "Posting…") from "a human must look" (`held`, "In review"). See
 * `MIRROR_STATUS` in handlers/moderatePost.ts.
 */
export type PostStatus = 'live' | 'pending' | 'held' | 'blocked';

/**
 * Reflects a post's new status into its author's mirror row.
 *
 * Looks the author up through the server-only `postAuthors` mapping, so the
 * post itself still carries no uid. A post with no mapping (seeded fixtures,
 * a pre-mirror post) is left alone; a missing mirror row is created, so a
 * status change on an older post still tells its author.
 */
export async function mirrorPostStatus(
  postId: string,
  status: PostStatus,
): Promise<void> {
  const author = await db.collection('postAuthors').doc(postId).get();
  const uid = author.get('uid') as string | undefined;
  if (uid === undefined) return;
  await myPostsCol(uid).doc(postId).set(
    {status, moderatedAt: FieldValue.serverTimestamp()},
    {merge: true},
  );
}

// --- Community -------------------------------------------------------------

/** Posts carry no uid — see createPost for why the mapping lives elsewhere. */
export const postsCol = (): CollectionReference => db.collection('posts');

/** The founder's review queue. Server-only; no client can read it. */
export const moderationDoc = (postId: string): DocumentReference =>
  db.collection('moderation').doc(postId);

/**
 * Beta-tester quotes for the D3 rating ask. Server-only, like `moderation`:
 * the rows carry consent references and locale provenance that no client has
 * any business reading, and `matchedTestimonials` returns only the two fields
 * the screen renders.
 */
export const testimonialsCol = (): CollectionReference =>
  db.collection('testimonials');

// --- Shape of the server-owned document -------------------------------------

/** Mirror of RevenueCat. The ONLY thing the coach trusts for tier. */
export interface Entitlement {
  readonly tier: SubscriptionTier;
  readonly productId?: string | null;
  readonly expiresAt?: Timestamp | null;
  readonly updatedAt?: Timestamp;
}

/** Per-day counter. Reset is by `day` mismatch, not by a scheduled wipe. */
export interface DailyCounter {
  readonly day: string;
  readonly count: number;
}

export interface UserDoc {
  /** What this person renamed their coach to. Set by `setCoachName` only. */
  readonly coachName?: string;
  /** IANA zone, written by syncUserContext. Crons page on this. */
  readonly tz?: string;
  readonly locale?: string;
  /** UTC hour matching 01:00 local — see taperRecalc.recalcHourUtcFor. */
  readonly recalcHourUtc?: number;
  /**
   * LEGACY. Superseded by the `devices` subcollection; still read on the send
   * path so a user who has not reopened the app since the migration keeps
   * receiving push. Written by nothing any more — entries only ever leave,
   * on a failed send or on sign-out.
   */
  readonly fcmTokens?: readonly string[];
  readonly entitlement?: Entitlement;
  /** docs/04 §7 coach quota. `day` is a local `yyyy-MM-dd` key. */
  readonly aiUsage?: {readonly day: string; readonly msgCount: number};
  /** One-shot flag: the onboarding answer has been embedded into `memories`. */
  readonly coachMemoriesSeeded?: boolean;
  /**
   * Rolling conversation summary for the coach. Written only by `aiCoachChat`
   * and injected each turn as background context, so Ember stays continuous
   * beyond the 10-turn verbatim window. Lives HERE and never in
   * `coachMessages` — the app renders every non-user doc of that collection
   * as a visible chat bubble.
   */
  readonly coachSummary?: {
    readonly text: string;
    /** Successful exchanges since the summary was last rebuilt. */
    readonly turnsSince: number;
    readonly updatedAt?: Timestamp;
  };
  readonly panicUsage?: DailyCounter;
  /** docs/03 §9 community post cap. Same shape, same rollover rule. */
  readonly postUsage?: DailyCounter;
  readonly planAdvice?: {
    readonly forDay: string;
    readonly limit: number;
    readonly adherence: number;
    readonly stretchDelta: number;
  };
}
