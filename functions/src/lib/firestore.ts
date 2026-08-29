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

/** Weekly AI report, keyed by the user's local Sunday. */
export const insightDoc = (uid: string, weekId: string): DocumentReference =>
  userDoc(uid).collection('insights').doc(weekId);

// --- Community -------------------------------------------------------------

/** Posts carry no uid — see createPost for why the mapping lives elsewhere. */
export const postsCol = (): CollectionReference => db.collection('posts');

/** The founder's review queue. Server-only; no client can read it. */
export const moderationDoc = (postId: string): DocumentReference =>
  db.collection('moderation').doc(postId);

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
  /** IANA zone, written by syncUserContext. Crons page on this. */
  readonly tz?: string;
  readonly locale?: string;
  /** UTC hour matching 01:00 local — see taperRecalc.recalcHourUtcFor. */
  readonly recalcHourUtc?: number;
  readonly fcmTokens?: readonly string[];
  readonly entitlement?: Entitlement;
  /** docs/04 §7 coach quota. `day` is a local `yyyy-MM-dd` key. */
  readonly aiUsage?: {readonly day: string; readonly msgCount: number};
  readonly panicUsage?: DailyCounter;
  readonly planAdvice?: {
    readonly forDay: string;
    readonly limit: number;
    readonly adherence: number;
    readonly stretchDelta: number;
  };
}
