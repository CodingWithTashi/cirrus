/**
 * `weeklyInsight` — the fan-out, the two gates, and the report.
 *
 * Only `parseInsight` was tested. The cron body around it decides who gets a
 * report at all, and every one of its skips is silent by design (docs/04 §5
 * says a missed week is skipped, not retried) — so a gate that is wrong in
 * either direction produces no error anywhere. Too loose and free users cost
 * us premium model calls; too tight and paying users simply never hear from
 * us on a Sunday and nobody finds out.
 *
 * Time is pinned with fake timers so "the user's local Sunday" is a fact
 * rather than a property of the day the suite happens to run.
 */
import {afterEach, beforeEach, describe, expect, it, vi} from 'vitest';

const generate = vi.fn();

vi.mock('../../src/ai/gemini', () => ({
  geminiModel: () => ({
    generate,
    generateStream: vi.fn(),
    embed: vi.fn(),
    listModels: vi.fn(),
  }),
}));

import {weeklyInsight} from '../../src/handlers/weeklyInsight';
import {ENTITLEMENT_MODE, GEMINI_API_KEY} from '../../src/config';
import {db, journeyDoc, userDoc} from '../../src/lib/firestore';

const PROJECT = process.env['GCLOUD_PROJECT'] ?? 'demo-cirrus';
const HOST = process.env['FIRESTORE_EMULATOR_HOST'] ?? '127.0.0.1:8080';

/** A Sunday, 12:00 UTC. Chosen so it is Sunday in both zones used below. */
const SUNDAY = new Date('2026-08-30T12:00:00.000Z');
const WEDNESDAY = new Date('2026-08-26T12:00:00.000Z');

async function clearFirestore(): Promise<void> {
  const url =
    `http://${HOST}/emulator/v1/projects/${PROJECT}` +
    `/databases/(default)/documents`;
  const res = await fetch(url, {method: 'DELETE'});
  if (!res.ok) throw new Error(`emulator clear failed: ${res.status}`);
}

const day = (puffs: number) => ({
  puffs,
  limit: 150,
  hourBuckets: {'22': puffs},
  cravingsSurvived: 1,
  mood: null,
  moodNote: null,
  vapeFreeConfirmed: false,
  slipTrigger: null,
  repairTokenUsed: false,
});

/** A journey with seven completed days before [SUNDAY]. */
async function seedJourney(uid: string): Promise<void> {
  const days: Record<string, unknown> = {};
  for (let i = 1; i <= 7; i++) {
    const d = new Date(SUNDAY.getTime() - i * 86_400_000);
    days[d.toISOString().slice(0, 10)] = day(100 + i);
  }
  await journeyDoc(uid).set({
    profile: {
      alias: 'a', avatarEmoji: 'x', tier: 'premium', email: null, gender: null,
      birthYear: null, whys: [], worries: [], attempts: null, frequency: null,
      firstPuff: null,
    },
    plan: {
      method: 'taper', paceDays: 30, startDate: '2026-08-04',
      baselinePuffsPerDay: 200, weeklySpend: 70, strength: 'mg50',
      stretchDays: 0,
    },
    days,
    cravingsSurvivedTotal: 5,
    repairTokens: 1,
    longestStreak: 3,
    goals: [],
    earnedBadges: [],
    lastPuffAt: null,
  });
}

async function seedUser(
  uid: string,
  over: Record<string, unknown> = {},
): Promise<void> {
  await userDoc(uid).set({
    tz: 'UTC',
    locale: 'en',
    recalcHourUtc: SUNDAY.getUTCHours(),
    entitlement: {tier: 'premium'},
    ...over,
  });
  await seedJourney(uid);
}

const reports = async (uid: string): Promise<number> =>
  (await userDoc(uid).collection('insights').get()).size;

const run = () =>
  (weeklyInsight as unknown as {run: (e?: unknown) => Promise<void>}).run({});

beforeEach(async () => {
  await clearFirestore();
  vi.clearAllMocks();
  // ONLY Date. Faking setTimeout/setInterval as well freezes the timers the
  // Firestore SDK's own I/O depends on, and every await in the handler hangs
  // until the test times out — which is exactly how this suite first failed.
  vi.useFakeTimers({toFake: ['Date']});
  vi.setSystemTime(SUNDAY);
  vi.spyOn(GEMINI_API_KEY, 'value').mockReturnValue('test-key');
  vi.spyOn(ENTITLEMENT_MODE, 'value').mockReturnValue('mirror');
  generate.mockResolvedValue({
    text: JSON.stringify({
      headline: 'Your quietest week yet',
      pattern: 'Evenings are still the wall.',
      win: 'Three days under the line.',
      watchout: 'Friday crept up.',
      move: 'Put the vape in another room after 9pm.',
    }),
    inputTokens: 500,
    outputTokens: 90,
  });
});

afterEach(() => {
  vi.useRealTimers();
});

describe('who gets a report', () => {
  it('writes one for a premium user on their local Sunday', async () => {
    await seedUser('alice');
    await run();

    expect(await reports('alice')).toBe(1);
    const report = (await userDoc('alice').collection('insights').get()).docs[0];
    expect(report?.get('headline')).toBe('Your quietest week yet');
    expect(report?.get('move')).toContain('another room');
  });

  it('skips a free user rather than spending a premium call on them', async () => {
    // docs/04 §5: free users see the headline blurred. Generating anyway and
    // hiding it would be paying for tokens nobody reads.
    await seedUser('alice', {entitlement: {tier: 'free'}});
    await run();

    expect(await reports('alice')).toBe(0);
    expect(generate).not.toHaveBeenCalled();
  });

  it('skips a user with no entitlement at all', async () => {
    await seedUser('alice', {entitlement: null});
    await run();
    expect(await reports('alice')).toBe(0);
  });

  it('includes everyone once entitlement is ungated', async () => {
    // Pre-monetization the whole product is unlocked, and the cron has to
    // agree with that or nobody gets a report before billing ships.
    vi.spyOn(ENTITLEMENT_MODE, 'value').mockReturnValue('ungated');
    await seedUser('alice', {entitlement: null});
    await run();
    expect(await reports('alice')).toBe(1);
  });

  it('skips anyone whose cron hour is not this one', async () => {
    // The fan-out is what keeps a global userbase off one hourly spike.
    await seedUser('alice', {recalcHourUtc: (SUNDAY.getUTCHours() + 5) % 24});
    await run();
    expect(await reports('alice')).toBe(0);
  });

  it('skips a user for whom it is not Sunday yet', async () => {
    // Their Sunday, not UTC's. Kiritimati is +14: still Saturday there when
    // it is Sunday noon in UTC.
    await seedUser('alice', {tz: 'Pacific/Kiritimati'});
    vi.setSystemTime(new Date('2026-08-30T23:00:00.000Z'));
    await run();
    expect(await reports('alice')).toBe(0);
  });

  it('does nothing at all on a Wednesday', async () => {
    await seedUser('alice');
    vi.setSystemTime(WEDNESDAY);
    await run();
    expect(await reports('alice')).toBe(0);
  });
});

describe('when it cannot say anything true', () => {
  it('skips a week with too few logged days', async () => {
    // Under three days there is not enough signal, and a report built on one
    // day would be exactly the invented-statistics problem the Insight screen
    // was rebuilt to remove.
    await seedUser('alice');
    await journeyDoc('alice').update({
      days: {'2026-08-29': day(120)},
    });
    await run();

    expect(await reports('alice')).toBe(0);
    expect(generate).not.toHaveBeenCalled();
  });

  it('skips silently when the model returns something unparseable', async () => {
    generate.mockResolvedValue({text: 'sorry what', inputTokens: 1, outputTokens: 1});
    await seedUser('alice');
    await run();
    expect(await reports('alice')).toBe(0);
  });

  it('skips a user with no journey', async () => {
    await userDoc('ghost').set({
      tz: 'UTC',
      recalcHourUtc: SUNDAY.getUTCHours(),
      entitlement: {tier: 'premium'},
    });
    await run();
    expect(await reports('ghost')).toBe(0);
  });

  it('one failing user does not stop the rest of the page', async () => {
    // A cron that aborts on the first bad document silently drops everybody
    // ordered after them, every week, forever.
    await seedUser('alice');
    await seedUser('zoe');
    await journeyDoc('alice').set({garbage: true});

    await run();
    expect(await reports('zoe')).toBe(1);
  });
});

describe('the report document', () => {
  it('is keyed by the local Sunday, so a rerun does not duplicate it', async () => {
    await seedUser('alice');
    await run();
    await run();

    expect(await reports('alice')).toBe(1);
  });

  it('lands under the user, so account deletion sweeps it', async () => {
    // `deleteUserData` does one `recursiveDelete(users/{uid})`. Anything
    // written outside that tree would survive an erasure request.
    await seedUser('alice');
    await run();

    const path = (await userDoc('alice').collection('insights').get()).docs[0]
      ?.ref.path;
    expect(path?.startsWith('users/alice/')).toBe(true);
    expect(await db.collection('insights').get()).toHaveProperty('size', 0);
  });
});
