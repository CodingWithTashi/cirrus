/**
 * `eraseHistory` — starting a new plan from scratch, server side.
 *
 * Two halves, and the second matters more than the first. What goes is the
 * server's record of the history the person asked to erase. What STAYS is the
 * account: the subscription mirror, the coach's validated name, the push
 * preferences and — the one an erase must never touch — the day's allowances,
 * because a callable that reset `aiUsage` would refill a free coach cap on
 * demand.
 */
import type {CallableRequest} from 'firebase-functions/v2/https';
import {beforeEach, describe, expect, it} from 'vitest';
import {eraseHistory} from '../../src/handlers/eraseHistory';
import {coachMessages, cravingsCol, db, journeyDoc, postsCol, userDoc} from '../../src/lib/firestore';

const PROJECT = process.env['GCLOUD_PROJECT'] ?? 'demo-cirrus';
const HOST = process.env['FIRESTORE_EMULATOR_HOST'] ?? '127.0.0.1:8080';

async function clearFirestore(): Promise<void> {
  const res = await fetch(
    `http://${HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`,
    {method: 'DELETE'},
  );
  if (!res.ok) throw new Error(`emulator clear failed: ${res.status}`);
}

function request(data: unknown, uid: string): CallableRequest<unknown> {
  return {
    data,
    auth: {uid, token: {}},
    rawRequest: {},
    acceptsStreaming: false,
  } as unknown as CallableRequest<unknown>;
}

/** An account a few weeks in, with something in every corner. */
async function lived(uid: string): Promise<void> {
  await userDoc(uid).set({
    entitlement: {tier: 'premium', expiresAt: '2027-01-01'},
    coachName: 'Sol',
    coachMemoriesSeeded: true,
    pushPrefs: {replies: true, mentions: false, weekly: true},
    tz: 'America/New_York',
    aiUsage: {day: '2026-11-16', count: 4},
    planAdvice: {forDay: '2026-11-16', limit: 40, adherence: 0.9, stretchDelta: 0},
    coachSummary: {text: 'Struggles after dinner.', turnsSince: 3},
  });
  await cravingsCol(uid).add({outcome: 'survived', intensityBefore: 7});
  await cravingsCol(uid).add({outcome: 'survived', intensityBefore: 5});
  await userDoc(uid).collection('insights').doc('2026-11-15').set({pattern: 'evenings'});
  await coachMessages(uid).add({role: 'user', text: 'after dinner is the worst'});
  await coachMessages(uid).add({role: 'model', text: 'Let us plan for 8pm.'});
  await userDoc(uid).collection('memories').add({text: 'Vapes after dinner', kind: 'trigger'});
  await userDoc(uid).collection('devices').doc('d1').set({platform: 'android'});
  await userDoc(uid).collection('posts').doc('p1').set({status: 'live'});
  await userDoc(uid).collection('notifications').doc('n1').set({kind: 'reply'});
}

const count = async (col: FirebaseFirestore.CollectionReference): Promise<number> =>
  (await col.get()).size;

beforeEach(async () => {
  await clearFirestore();
});

describe('eraseHistory — what goes', () => {
  it('erases the cravings, the weekly reports and the nightly advice', async () => {
    await lived('alice');

    await eraseHistory.run(request({}, 'alice'));

    expect(await count(cravingsCol('alice'))).toBe(0);
    expect(await count(userDoc('alice').collection('insights'))).toBe(0);
    expect((await userDoc('alice').get()).get('planAdvice')).toBeUndefined();
  });

  it('and the coach, all three together: transcript, summary, memories', async () => {
    await lived('alice');

    const answer = await eraseHistory.run(request({}, 'alice'));

    expect(answer).toEqual({erased: true});
    expect(await count(coachMessages('alice'))).toBe(0);
    expect(await count(userDoc('alice').collection('memories'))).toBe(0);
    expect((await userDoc('alice').get()).get('coachSummary')).toBeUndefined();
  });

  it('whatever the app sends with it: there is no partial erase to ask for', async () => {
    for (const data of [null, {coach: false}, {coach: 'no'}]) {
      await clearFirestore();
      await lived('alice');
      await eraseHistory.run(request(data, 'alice'));
      expect(await count(coachMessages('alice')), JSON.stringify(data)).toBe(0);
      expect(await count(cravingsCol('alice')), JSON.stringify(data)).toBe(0);
    }
  });
});

describe('eraseHistory — what stays', () => {
  it('the account: subscription, coach name, preferences, timezone', async () => {
    await lived('alice');

    await eraseHistory.run(request({}, 'alice'));

    const user = await userDoc('alice').get();
    expect(user.get('entitlement')).toEqual({tier: 'premium', expiresAt: '2027-01-01'});
    expect(user.get('coachName')).toBe('Sol');
    expect(user.get('pushPrefs')).toEqual({replies: true, mentions: false, weekly: true});
    expect(user.get('tz')).toBe('America/New_York');
  });

  it("today's allowance, or erasing would refill a free cap on demand", async () => {
    await lived('alice');

    await eraseHistory.run(request({}, 'alice'));

    expect((await userDoc('alice').get()).get('aiUsage')).toEqual({
      day: '2026-11-16',
      count: 4,
    });
  });

  it('the seeded flag, so forgetting everything does not re-seed a memory', async () => {
    await lived('alice');

    await eraseHistory.run(request({}, 'alice'));

    expect((await userDoc('alice').get()).get('coachMemoriesSeeded')).toBe(true);
  });

  it('devices, the community mirror and the inbox', async () => {
    await lived('alice');

    await eraseHistory.run(request({}, 'alice'));

    expect(await count(userDoc('alice').collection('devices'))).toBe(1);
    expect(await count(userDoc('alice').collection('posts'))).toBe(1);
    expect(await count(userDoc('alice').collection('notifications'))).toBe(1);
  });

  it('the journey document, which is the app\'s to rewrite, not ours', async () => {
    await lived('alice');
    await journeyDoc('alice').set({profile: {alias: 'SteadyFalcon42'}, days: {x: 1}});

    await eraseHistory.run(request({}, 'alice'));

    expect((await journeyDoc('alice').get()).get('days')).toEqual({x: 1});
  });

  it('nobody else', async () => {
    await lived('alice');
    await lived('bob');
    await postsCol().doc('shared').set({status: 'live', text: 'hello'});

    await eraseHistory.run(request({}, 'alice'));

    expect(await count(cravingsCol('bob'))).toBe(2);
    expect(await count(coachMessages('bob'))).toBe(2);
    expect(await count(userDoc('bob').collection('memories'))).toBe(1);
    expect((await postsCol().doc('shared').get()).exists).toBe(true);
  });
});

describe('eraseHistory — idempotent', () => {
  it('answers the same on an account with nothing left to erase', async () => {
    await eraseHistory.run(request({}, 'nobody'));
    const answer = await eraseHistory.run(request({}, 'nobody'));

    expect(answer).toEqual({erased: true});
    expect((await db.collection('users').doc('nobody').get()).get('planAdvice')).toBeUndefined();
  });

  it('refuses a caller with no account', async () => {
    const anonymous = {
      data: {},
      rawRequest: {},
      acceptsStreaming: false,
    } as unknown as CallableRequest<unknown>;

    await expect(eraseHistory.run(anonymous)).rejects.toThrow();
  });
});
