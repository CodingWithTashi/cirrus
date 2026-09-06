/**
 * Sending a push, and keeping the device registry honest.
 *
 * Until this file existed, push was dead in the most expensive way: every
 * sign-in registered an FCM token into `users/{uid}.fcmTokens`, and **nothing
 * ever read that field.** We were collecting a device identifier we had no use
 * for — which is both a dead re-engagement lever and data we had no business
 * holding.
 *
 * The second half of that bug outlived the first. A token went into the array
 * and could only ever come back out when a send to it failed, so **signing out
 * released nothing**: the next person to use that phone received the previous
 * account's pushes. `users/{uid}/devices/{tokenHash}` replaces the array —
 * one document per device, carrying the platform and a `lastSeenAt` the prune
 * cron can judge, and removable one device at a time.
 *
 * The array is still READ on the send path and never written. Someone who has
 * not reopened the app since the migration is still reachable; the first
 * `syncUserContext` after it moves them across.
 *
 * What earns a push here is deliberately narrow. Danger-hour reminders are NOT
 * sent from the server (see the header of `index.ts`): they are deterministic
 * once computed, so they are scheduled on-device where they are free, work
 * offline, and need no fan-out. A server push is only worth it when the
 * trigger is something the device could not have known by itself — somebody
 * else answered you, or a report finished generating.
 */
import {createHash} from 'node:crypto';
import {getMessaging} from 'firebase-admin/messaging';
import type {MulticastMessage} from 'firebase-admin/messaging';
import {ALLOWANCE_DEFAULTS, DAILY_PUSHES, allowance} from '../config';
import {dayKeyIn} from '../domain/dateKey';
import {DEFAULT_QUIET_END, DEFAULT_QUIET_START, inQuietHours} from '../domain/quietHours';
import {FieldValue, db, devicesCol, notificationsCol, userDoc} from './firestore';
import {log} from './logger';
import {pushCopy, type PushKey} from './pushCopy';
import {allowedByPrefs, specFor, type PushKind} from './pushKinds';

/** What the app runs on, as far as we are willing to believe it. */
export type DevicePlatform = 'android' | 'ios' | 'other';

const PLATFORMS: readonly string[] = ['android', 'ios'];

export interface DeviceRegistration {
  readonly token: string;
  /** Client-supplied, so anything unrecognised becomes 'other'. */
  readonly platform?: string | undefined;
}

export interface PushPayload {
  readonly title: string;
  readonly body: string;
  /** In-app destination. The client allow-lists this before navigating. */
  readonly route?: string;
}

/**
 * How to deliver, and under which rules.
 *
 * [kind] is required and has no default on purpose. It is what selects the
 * preference to honour, the channel to land in and whether quiet hours apply
 * — so a call site that could omit it would be a call site that silently
 * bypasses all three. `weeklyInsight` used to be exactly that: it called
 * `sendToUser` directly, never `sendLocalized`, and so would have sailed past
 * any gate placed in the wrapper above.
 */
/**
 * A payload, or a function that builds one once the recipient's language is
 * known.
 *
 * The factory form exists so localized copy does not cost its own read of
 * `users/{uid}`: the gate has already read that document, and it hands the
 * locale to the factory.
 */
export type PayloadSource =
  | PushPayload
  | ((locale: string | undefined) => PushPayload);

export interface SendOptions {
  readonly kind: PushKind;
  /**
   * Groups notifications that supersede one another. Becomes Android's
   * notification `tag` — which makes a later send REPLACE the shade line
   * rather than add to it, and is the half of collapse the server cannot do
   * on its own — plus the APNs collapse id.
   */
  readonly tag?: string;
  /** iOS conversation grouping, so several threads stack under one header. */
  readonly threadId?: string;
  /** Items being announced, for copy that counts. */
  readonly count?: number;
}

/** What the recipient's own row says about whether we may send at all. */
interface Gate {
  /** Whether the recipient wants this kind at all. Governs the inbox too. */
  readonly allowed: boolean;
  /** Whether a buzz is left in today's budget. The inbox ignores this. */
  readonly budgeted: boolean;
  readonly quiet: boolean;
  readonly locale: string | undefined;
  /**
   * The legacy `fcmTokens` array, carried out of the gate's own read.
   *
   * `users/{uid}` used to be read THREE times per push — once for the gate,
   * once for the locale, once alongside the device subcollection — for one
   * document whose contents do not change in between. Threading the parts
   * through makes it one read, and the send path is the hottest thing here.
   */
  readonly legacy: ReadonlySet<string>;
}

const NO_LEGACY: ReadonlySet<string> = new Set<string>();

function legacyTokensOf(snap: FirebaseFirestore.DocumentSnapshot): Set<string> {
  const out = new Set<string>();
  const stored: unknown = snap.get('fcmTokens');
  if (Array.isArray(stored)) {
    for (const token of stored) {
      if (typeof token === 'string' && token.length > 0) out.add(token);
    }
  }
  return out;
}

/**
 * The document id for [token].
 *
 * Hashed rather than used directly because a document id is not a private
 * place: it appears in index entries, in error messages and in every log line
 * that names the path. A registration token is a credential — anyone holding
 * one can push to that device — so it belongs in a field, not in a key.
 *
 * It also makes re-registration an idempotent overwrite instead of a second
 * row, which is what stops the list growing without bound.
 */
export function deviceIdFor(token: string): string {
  return createHash('sha256').update(token.trim()).digest('hex');
}

function normalisePlatform(value: string | undefined): DevicePlatform {
  const lowered = value?.trim().toLowerCase() ?? '';
  return PLATFORMS.includes(lowered) ? (lowered as DevicePlatform) : 'other';
}

/**
 * Records that [uid] can be reached on this device, or refreshes the record if
 * we already knew.
 *
 * `createdAt` is read before writing so it survives a refresh: it is when we
 * first saw the device, and the freshness signal — the one `pruneStaleDevices`
 * judges — is `lastSeenAt`. Two concurrent syncs could both decide the row is
 * new, which costs a `createdAt` a few milliseconds out and nothing else.
 */
export async function registerDevice(
  uid: string,
  registration: DeviceRegistration,
): Promise<void> {
  const token = registration.token.trim();
  if (token.length === 0) return;

  const ref = devicesCol(uid).doc(deviceIdFor(token));
  const existing = await ref.get();
  await ref.set(
    {
      token,
      platform: normalisePlatform(registration.platform),
      ...(existing.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
      lastSeenAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

/**
 * Releases this device, from both the subcollection and the legacy array.
 *
 * Called on sign-out, and it is the whole reason the subcollection exists. It
 * must never throw at its caller: the user is leaving either way, and a failed
 * release is not a reason to fail the sign-out in front of them.
 */
export async function unregisterDevice(
  uid: string,
  token: string,
): Promise<void> {
  const trimmed = token.trim();
  if (trimmed.length === 0) return;

  await devicesCol(uid).doc(deviceIdFor(trimmed)).delete();
  try {
    // Only touch the legacy array where one exists: `arrayRemove` on a
    // missing field CREATES it as `[]`, which would quietly resurrect a
    // field documented as written by nothing any more, on every sign-out.
    const snap = await userDoc(uid).get();
    const legacy: unknown = snap.get('fcmTokens');
    if (!Array.isArray(legacy) || !legacy.includes(trimmed)) return;
    // `update`, not a merging `set`: a set would create `users/{uid}` for a
    // user who has none, leaving a stub row the crons would page over.
    await userDoc(uid).update({fcmTokens: FieldValue.arrayRemove(trimmed)});
  } catch {
    // No user document, or no legacy array. Nothing to release.
  }
}

/** Where a token was found, so a dead one is removed from the right place. */
interface TokenSources {
  readonly tokens: readonly string[];
  readonly legacy: ReadonlySet<string>;
}

/**
 * Every token [uid] can be reached on.
 *
 * [legacy] is supplied by the caller when it has already read the user
 * document, which the send path always has — see [Gate.legacy]. Only
 * `listDeviceTokens`, which has no such read, pays for one.
 */
async function collectTokens(
  uid: string,
  legacy: ReadonlySet<string>,
): Promise<TokenSources> {
  const devices = await devicesCol(uid).get();

  const tokens = new Set<string>();
  for (const doc of devices.docs) {
    const token: unknown = doc.get('token');
    if (typeof token === 'string' && token.length > 0) tokens.add(token);
  }
  for (const token of legacy) tokens.add(token);

  return {tokens: [...tokens], legacy};
}

/** Every token [uid] can currently be reached on, from both stores. */
export async function listDeviceTokens(uid: string): Promise<string[]> {
  const snap = await userDoc(uid).get();
  return [...(await collectTokens(uid, legacyTokensOf(snap))).tokens];
}

/**
 * Forgets tokens FCM has told us are dead.
 *
 * Without this the registry grows forever — every reinstall adds one — and
 * eventually every send fans out across a list of mostly-dead entries.
 */
async function dropTokens(
  uid: string,
  tokens: readonly string[],
  legacy: ReadonlySet<string>,
): Promise<void> {
  const batch = db.batch();
  for (const token of tokens) {
    batch.delete(devicesCol(uid).doc(deviceIdFor(token)));
  }
  const fromArray = tokens.filter((t) => legacy.has(t));
  if (fromArray.length > 0) {
    batch.update(userDoc(uid), {
      fcmTokens: FieldValue.arrayRemove(...fromArray),
    });
  }
  await batch.commit();
}

/** Error codes that mean the token is gone for good, not that FCM hiccupped. */
const DEAD_TOKEN_CODES: readonly string[] = [
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
];

/**
 * Whether [uid] may be sent a [kind] right now, and how loudly.
 *
 * One read of the user row answers all three questions, and it is the only
 * place any of them is asked. A preference check that lived in a wrapper
 * would be a preference check some call site did not use.
 *
 * The budget spend is transactional because two replies on two different
 * threads land in two concurrent function instances; a read-then-write would
 * let both see the same count and both spend the last slot. Refusing on a
 * read failure is the wrong direction — a push is a courtesy and a Firestore
 * hiccup is not a reason to stay silent — so an error here allows the send.
 */
async function openGate(uid: string, kind: PushKind, nowMs: number): Promise<Gate> {
  const spec = specFor(kind);
  try {
    return await db.runTransaction(async (tx) => {
      const snap = await tx.get(userDoc(uid));
      const prefs = snap.get('pushPrefs') as Record<string, unknown> | undefined;
      const locale = snap.get('locale') as string | undefined;
      const timeZone = snap.get('tz') as string | undefined;

      const legacy = legacyTokensOf(snap);
      if (!allowedByPrefs(kind, prefs)) {
        return {allowed: false, budgeted: false, quiet: false, locale, legacy};
      }

      const quiet =
        spec.respectsQuietHours &&
        inQuietHours(
          nowMs,
          timeZone,
          readHour(prefs?.['quietStart'], DEFAULT_QUIET_START),
          readHour(prefs?.['quietEnd'], DEFAULT_QUIET_END),
        );

      if (!spec.countsAgainstBudget) {
        return {allowed: true, budgeted: true, quiet, locale, legacy};
      }

      // The day is the RECIPIENT's, not UTC's — a cap that resets at 3am
      // local is a cap that does not mean what it says.
      const day = dayKeyIn(new Date(nowMs), timeZone ?? 'UTC');
      const usage = snap.get('pushUsage') as
        | {day?: string; count?: number}
        | undefined;
      const spent = usage?.day === day ? (usage.count ?? 0) : 0;
      if (spent >= allowance(DAILY_PUSHES, ALLOWANCE_DEFAULTS.dailyPushes)) {
        // Out of buzzes for today, but NOT out of the inbox: the budget caps
        // how often we interrupt someone, not what they are allowed to know.
        return {allowed: true, budgeted: false, quiet, locale, legacy};
      }
      tx.set(userDoc(uid), {pushUsage: {day, count: spent + 1}}, {merge: true});
      return {allowed: true, budgeted: true, quiet, locale, legacy};
    });
  } catch (error) {
    log.warn('push.gate_failed', {uid, kind, error: String(error)});
    return {
      allowed: true,
      budgeted: true,
      quiet: false,
      locale: undefined,
      legacy: NO_LEGACY,
    };
  }
}

/**
 * Files this notification in the recipient's in-app inbox.
 *
 * Written even when nothing can be delivered — no device registered, the
 * daily budget spent, the app uninstalled from one of two phones. A push is
 * a courtesy that may not arrive; the inbox is the record that it happened,
 * and it is the only surface that can answer "what did I miss" for somebody
 * who declined notifications outright.
 *
 * Keyed by [SendOptions.tag] where there is one, so a thread occupies ONE row
 * that updates in place — exactly what the notification tag does to the shade.
 * Without that, a busy thread would collapse to a single line on the phone and
 * still stack twenty rows in here.
 *
 * `readAt` is only cleared on a genuinely new row: an update to a thread the
 * reader has already opened should mark it unread again, which is why it is
 * written on every call rather than only on create.
 */
async function recordNotification(
  uid: string,
  payload: PushPayload,
  opts: SendOptions,
  nowMs: number,
): Promise<void> {
  try {
    const id = opts.tag !== undefined && opts.tag.length > 0
      ? opts.tag.replace(/\//g, '_')
      : notificationsCol(uid).doc().id;
    await notificationsCol(uid).doc(id).set(
      {
        kind: opts.kind,
        title: payload.title,
        body: payload.body,
        ...(payload.route ? {route: payload.route} : {}),
        createdAtMs: nowMs,
        readAtMs: null,
      },
      {merge: true},
    );
  } catch (error) {
    // Never at the caller's expense. A missing inbox row is a worse day than
    // a missing push and still not a reason to fail a moderation pass.
    log.warn('push.record_failed', {uid, kind: opts.kind, error: String(error)});
  }
}

function readHour(value: unknown, fallback: number): number {
  return typeof value === 'number' && Number.isInteger(value) && value >= 0 && value <= 24
    ? value
    : fallback;
}

/**
 * Builds the wire message.
 *
 * Split out so `devices.test.ts` can assert on the shape without a live FCM,
 * and because the field names here are the ones most easily got wrong: the
 * admin SDK camelCases `notification_priority` to `priority`, and setting
 * both `threadId` and a raw `thread-id` on `aps` throws `INVALID_PAYLOAD`.
 *
 * Quiet delivery is a CHANNEL swap on Android, not a priority flag. From
 * Android 8 the channel decides sound, vibration and heads-up, and the
 * per-message priority FCM accepts is ignored — so `priority` here is only
 * doing work on devices old enough to still read it.
 */
export function buildMessage(
  tokens: readonly string[],
  payload: PushPayload,
  opts: SendOptions,
  quiet: boolean,
): MulticastMessage {
  const spec = specFor(opts.kind);
  const channelId = quiet ? spec.quietChannelId : spec.channelId;
  return {
    tokens: [...tokens],
    notification: {title: payload.title, body: payload.body},
    // `data` is what survives into the tapped-notification handler; the
    // notification block alone cannot carry a destination.
    data: {
      kind: opts.kind,
      ...(payload.route ? {route: payload.route} : {}),
    },
    android: {
      ...(opts.tag ? {collapseKey: opts.tag} : {}),
      notification: {
        channelId,
        priority: quiet ? 'low' : 'default',
        ...(opts.tag ? {tag: opts.tag} : {}),
      },
    },
    apns: {
      ...(opts.tag ? {headers: {'apns-collapse-id': opts.tag.slice(0, 64)}} : {}),
      payload: {
        aps: {
          ...(opts.threadId ? {threadId: opts.threadId} : {}),
          ...(quiet ? {'interruption-level': 'passive'} : {}),
        },
      },
    },
  };
}

/**
 * Sends [payload] to every device [uid] has registered, if the gate allows.
 *
 * Never throws: a push is a courtesy, and a failed one must not fail the
 * moderation pass or the cron that triggered it. Returns whether anything
 * actually went out, which the caller needs in order not to record a
 * notification it never sent.
 */
export async function sendToUser(
  uid: string,
  source: PayloadSource,
  opts: SendOptions,
  nowMs: number = Date.now(),
): Promise<boolean> {
  try {
    const gate = await openGate(uid, opts.kind, nowMs);
    if (!gate.allowed) {
      log.info('push.suppressed', {uid, kind: opts.kind});
      return false;
    }

    // The gate's own read carried the locale out, so localized copy costs no
    // second lookup — it used to read the same document again just for this.
    const payload =
      typeof source === 'function' ? source(gate.locale) : source;

    // Before the token check on purpose: somebody with no device registered
    // still gets the in-app record of what happened.
    await recordNotification(uid, payload, opts, nowMs);

    if (!gate.budgeted) {
      log.info('push.over_budget', {uid, kind: opts.kind});
      return false;
    }

    const {tokens, legacy} = await collectTokens(uid, gate.legacy);
    if (tokens.length === 0) return false;

    const response = await getMessaging().sendEachForMulticast(
      buildMessage(tokens, payload, opts, gate.quiet),
    );

    const dead: string[] = [];
    response.responses.forEach((result, i) => {
      if (DEAD_TOKEN_CODES.includes(result.error?.code ?? '')) {
        const token = tokens[i];
        if (token !== undefined) dead.push(token);
      }
    });
    if (dead.length > 0) await dropTokens(uid, dead, legacy);

    log.info('push.sent', {
      uid,
      kind: opts.kind,
      quiet: gate.quiet,
      ok: response.successCount,
      failed: response.failureCount,
      pruned: dead.length,
    });
    return response.successCount > 0;
  } catch (error) {
    log.warn('push.failed', {uid, kind: opts.kind, error: String(error)});
    return false;
  }
}

/**
 * Sends a localized push, choosing the language from the recipient's own
 * `users/{uid}.locale` rather than from ours.
 *
 * The read happens twice (here and in [sendToUser]) and that is fine: this
 * runs at most once per user per event, and the alternative is threading a
 * snapshot through a function whose entire job is to not matter when it fails.
 */
export async function sendLocalized(
  uid: string,
  key: PushKey,
  route: string,
  opts: Omit<SendOptions, 'kind'> = {},
  nowMs: number = Date.now(),
): Promise<boolean> {
  const count = opts.count ?? 1;
  // No read here at all any more. The copy is chosen inside `sendToUser`,
  // from the locale its own gate read already returned.
  return sendToUser(
    uid,
    (locale) => ({...pushCopy(key, locale, count), route}),
    {...opts, kind: key},
    nowMs,
  );
}

