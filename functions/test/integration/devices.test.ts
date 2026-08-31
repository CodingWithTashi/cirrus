/**
 * `users/{uid}/devices` — the push registry, and the sign-out path that was
 * missing from it.
 *
 * Until this existed, a device registered itself into a flat
 * `users/{uid}.fcmTokens` array and **nothing ever took it back out** except a
 * failed send. Sign out on a shared phone and the previous account's pushes
 * kept arriving on it. That is the case the `unregisters` block below exists
 * for, and it is a privacy bug rather than an untidiness.
 *
 * The legacy array is still read on the send path, so the tests here cover
 * three shapes deliberately: subcollection only, array only, and a token
 * present in both. Users who never reopen the app must keep receiving push
 * until they do.
 */
import {beforeEach, describe, expect, it, vi} from 'vitest';

const sendEachForMulticast = vi.fn();
vi.mock('firebase-admin/messaging', () => ({
  getMessaging: () => ({sendEachForMulticast}),
}));

import {
  deviceIdFor,
  listDeviceTokens,
  registerDevice,
  sendToUser,
  unregisterDevice,
} from '../../src/lib/push';
// Exported for this suite: the `onSchedule` wrapper around it is untestable,
// the same reason `taperRecalc` exports `recalcOne`.
import {pruneStaleDevices} from '../../src/handlers/pruneDevices';
import {Timestamp, devicesCol, userDoc} from '../../src/lib/firestore';

const PROJECT = process.env['GCLOUD_PROJECT'] ?? 'demo-cirrus';
const HOST = process.env['FIRESTORE_EMULATOR_HOST'] ?? '127.0.0.1:8080';

async function clearFirestore(): Promise<void> {
  const url =
    `http://${HOST}/emulator/v1/projects/${PROJECT}` +
    `/databases/(default)/documents`;
  const res = await fetch(url, {method: 'DELETE'});
  if (!res.ok) throw new Error(`emulator clear failed: ${res.status}`);
}

/** What `sendEachForMulticast` answers when every token is healthy. */
function allOk(count: number): {responses: {success: boolean}[]; successCount: number; failureCount: number} {
  return {
    responses: Array.from({length: count}, () => ({success: true})),
    successCount: count,
    failureCount: 0,
  };
}

beforeEach(async () => {
  await clearFirestore();
  vi.clearAllMocks();
  sendEachForMulticast.mockResolvedValue(allOk(1));
});

describe('registerDevice', () => {
  it('writes one document keyed by the hash of the token', async () => {
    await registerDevice('alice', {token: 'device-1', platform: 'android'});

    const snap = await devicesCol('alice').get();
    expect(snap.size).toBe(1);
    // The id is a hash, never the token: a document id turns up in logs, in
    // index entries and in error messages, and a push token is a credential.
    expect(snap.docs[0]!.id).toBe(deviceIdFor('device-1'));
    expect(snap.docs[0]!.id).not.toContain('device-1');
    expect(snap.docs[0]!.get('token')).toBe('device-1');
    expect(snap.docs[0]!.get('platform')).toBe('android');
    expect(snap.docs[0]!.get('createdAt')).toBeInstanceOf(Timestamp);
    expect(snap.docs[0]!.get('lastSeenAt')).toBeInstanceOf(Timestamp);
  });

  it('re-registering the same device overwrites rather than duplicating', async () => {
    await registerDevice('alice', {token: 'device-1', platform: 'android'});
    const first = await devicesCol('alice').doc(deviceIdFor('device-1')).get();
    const createdAt = first.get('createdAt') as FirebaseFirestore.Timestamp;

    await new Promise((r) => setTimeout(r, 25));
    await registerDevice('alice', {token: 'device-1', platform: 'android'});

    const snap = await devicesCol('alice').get();
    expect(snap.size).toBe(1);
    const again = snap.docs[0]!;
    // `createdAt` is when we first saw this device and must survive; the
    // freshness signal the prune cron reads is `lastSeenAt`.
    expect((again.get('createdAt') as FirebaseFirestore.Timestamp).toMillis()).toBe(
      createdAt.toMillis(),
    );
    expect(
      (again.get('lastSeenAt') as FirebaseFirestore.Timestamp).toMillis(),
    ).toBeGreaterThan(createdAt.toMillis());
  });

  it('keeps two real devices apart', async () => {
    await registerDevice('alice', {token: 'device-1', platform: 'android'});
    await registerDevice('alice', {token: 'device-2', platform: 'ios'});
    expect((await devicesCol('alice').get()).size).toBe(2);
  });

  it('ignores an empty token', async () => {
    await registerDevice('alice', {token: ''});
    await registerDevice('alice', {token: '   '});
    expect((await devicesCol('alice').get()).empty).toBe(true);
  });

  it('normalises an unknown platform rather than storing client text', async () => {
    await registerDevice('alice', {token: 'device-1', platform: 'HarmonyOS'});
    const doc = await devicesCol('alice').doc(deviceIdFor('device-1')).get();
    expect(doc.get('platform')).toBe('other');
  });
});

describe('unregisterDevice', () => {
  it('removes exactly the one device, leaving the others reachable', async () => {
    await registerDevice('alice', {token: 'phone', platform: 'android'});
    await registerDevice('alice', {token: 'tablet', platform: 'android'});

    await unregisterDevice('alice', 'phone');

    expect(await listDeviceTokens('alice')).toEqual(['tablet']);
  });

  it('also drops the token from the legacy array', async () => {
    // A device that registered before the subcollection existed still has to
    // be releasable on sign-out, or the leak survives the migration.
    await userDoc('alice').set({fcmTokens: ['phone', 'tablet']});

    await unregisterDevice('alice', 'phone');

    expect((await userDoc('alice').get()).get('fcmTokens')).toEqual(['tablet']);
  });

  it('is silent about a device that was never registered', async () => {
    // Sign-out must never fail on this: the user is leaving either way.
    await expect(unregisterDevice('alice', 'never-seen')).resolves.toBeUndefined();
  });

  it('does not resurrect the legacy array on a user who never had one', async () => {
    // `arrayRemove` on a missing field CREATES it as `[]`. Every sign-out of
    // every post-migration user would quietly write an empty `fcmTokens` onto
    // a document whose docs say the field is written by nothing any more.
    await registerDevice('alice', {token: 'phone', platform: 'android'});
    await userDoc('alice').set({tz: 'UTC'}, {merge: true});

    await unregisterDevice('alice', 'phone');

    const user = await userDoc('alice').get();
    expect(user.get('fcmTokens')).toBeUndefined();
  });
});

describe('listDeviceTokens', () => {
  it('reads the subcollection', async () => {
    await registerDevice('alice', {token: 'device-1'});
    expect(await listDeviceTokens('alice')).toEqual(['device-1']);
  });

  it('still reads the legacy array, so live users keep receiving push', async () => {
    await userDoc('alice').set({fcmTokens: ['old-device']});
    expect(await listDeviceTokens('alice')).toEqual(['old-device']);
  });

  it('de-duplicates a token present on both sides', async () => {
    await userDoc('alice').set({fcmTokens: ['shared', 'legacy-only']});
    await registerDevice('alice', {token: 'shared'});
    await registerDevice('alice', {token: 'new-only'});

    const tokens = await listDeviceTokens('alice');
    expect(tokens.toSorted()).toEqual(['legacy-only', 'new-only', 'shared']);
  });

  it('is empty for a user who has never registered anything', async () => {
    expect(await listDeviceTokens('alice')).toEqual([]);
  });
});

describe('sendToUser', () => {
  it('fans out over the subcollection', async () => {
    await registerDevice('alice', {token: 'device-1'});
    await registerDevice('alice', {token: 'device-2'});
    sendEachForMulticast.mockResolvedValue(allOk(2));

    await sendToUser('alice', {title: 'hi', body: 'there', route: '/coach'});

    expect(sendEachForMulticast).toHaveBeenCalledTimes(1);
    const arg = sendEachForMulticast.mock.calls[0]![0] as {tokens: string[]; data: unknown};
    expect(arg.tokens.toSorted()).toEqual(['device-1', 'device-2']);
    expect(arg.data).toEqual({route: '/coach'});
  });

  it('sends nothing at all when the user has no devices', async () => {
    await sendToUser('alice', {title: 'hi', body: 'there'});
    expect(sendEachForMulticast).not.toHaveBeenCalled();
  });

  it('prunes a dead token from the subcollection', async () => {
    await registerDevice('alice', {token: 'live'});
    await registerDevice('alice', {token: 'dead'});
    sendEachForMulticast.mockImplementation(
      (message: {tokens: string[]}) => ({
        responses: message.tokens.map((t) =>
          t === 'dead'
            ? {success: false, error: {code: 'messaging/registration-token-not-registered'}}
            : {success: true},
        ),
        successCount: message.tokens.length - 1,
        failureCount: 1,
      }),
    );

    await sendToUser('alice', {title: 'hi', body: 'there'});

    expect(await listDeviceTokens('alice')).toEqual(['live']);
  });

  it('prunes a dead token from the legacy array too', async () => {
    await userDoc('alice').set({fcmTokens: ['live', 'dead']});
    sendEachForMulticast.mockImplementation(
      (message: {tokens: string[]}) => ({
        responses: message.tokens.map((t) =>
          t === 'dead'
            ? {success: false, error: {code: 'messaging/invalid-registration-token'}}
            : {success: true},
        ),
        successCount: message.tokens.length - 1,
        failureCount: 1,
      }),
    );

    await sendToUser('alice', {title: 'hi', body: 'there'});

    expect((await userDoc('alice').get()).get('fcmTokens')).toEqual(['live']);
  });

  it('never throws — a push is a courtesy, not a transaction', async () => {
    await registerDevice('alice', {token: 'device-1'});
    sendEachForMulticast.mockRejectedValue(new Error('FCM is having a day'));
    await expect(
      sendToUser('alice', {title: 'hi', body: 'there'}),
    ).resolves.toBeUndefined();
  });
});

describe('pruneStaleDevices', () => {
  /** Writes a device row with an explicit age, bypassing the register path. */
  async function aged(uid: string, token: string, lastSeen: string): Promise<void> {
    const at = Timestamp.fromDate(new Date(lastSeen));
    await devicesCol(uid).doc(deviceIdFor(token)).set({
      token,
      platform: 'android',
      createdAt: at,
      lastSeenAt: at,
    });
  }

  it('sweeps every user in one pass and keeps the current devices', async () => {
    // A collection-group query, not a page over `users`: the cron does not
    // care who owns a stale device, and scanning the whole userbase to find
    // the few percent that have one is the expensive way to ask.
    await aged('alice', 'alice-stale', '2026-01-01T00:00:00Z');
    await aged('alice', 'alice-fresh', '2026-08-29T00:00:00Z');
    await aged('bob', 'bob-stale', '2025-11-02T00:00:00Z');

    const removed = await pruneStaleDevices(new Date('2026-07-01T00:00:00Z'));

    expect(removed).toBe(2);
    expect(await listDeviceTokens('alice')).toEqual(['alice-fresh']);
    expect(await listDeviceTokens('bob')).toEqual([]);
  });

  it('removes nothing when every device is current', async () => {
    await registerDevice('alice', {token: 'device-1'});
    expect(await pruneStaleDevices(new Date('2020-01-01T00:00:00Z'))).toBe(0);
  });

  it('leaves the legacy array alone', async () => {
    // Those entries carry no timestamp, so there is no honest way to judge
    // their age. They leave on a failed send or on sign-out, not on a guess.
    await userDoc('alice').set({fcmTokens: ['ancient']});
    await pruneStaleDevices(new Date('2026-07-01T00:00:00Z'));
    expect((await userDoc('alice').get()).get('fcmTokens')).toEqual(['ancient']);
  });
});
