/**
 * `aiCoachChat` — the fallback ladder, the quota, and the refund.
 *
 * The handler had no test at all; only its exported `parseMemories` helper
 * did. That is the wrong shape of coverage for this file, because every one of
 * its failure branches returns a *cheerful* envelope rather than an error —
 * `connectionLost` looks exactly like a working coach having a quiet day. That
 * is not hypothetical: a wrong model id made every user get the warm fallback
 * for as long as it was deployed, and nothing anywhere said so.
 *
 * The model is stubbed. What is under test is what the handler does around it:
 * who gets charged a message, who gets it back, and what the client is told.
 */
import {beforeEach, describe, expect, it, vi} from 'vitest';

const generate = vi.fn();
const generateStream = vi.fn();
const embed = vi.fn();
const listModels = vi.fn();

vi.mock('../../src/ai/gemini', () => ({
  geminiModel: () => ({generate, generateStream, embed, listModels}),
}));

import type {CallableRequest, CallableResponse} from 'firebase-functions/v2/https';
import {aiCoachChat} from '../../src/handlers/aiCoachChat';
import {ModelUnavailableError} from '../../src/ai/model';
import {MEMORY_EXTRACTION_PROMPT} from '../../src/ai/prompts';
import {
  FREE_DAILY_COACH_MESSAGES,
  GEMINI_API_KEY,
  PREMIUM_DAILY_COACH_MESSAGES,
} from '../../src/config';
import {coachMessages, journeyDoc, userDoc} from '../../src/lib/firestore';

const PROJECT = process.env['GCLOUD_PROJECT'] ?? 'demo-cirrus';
const HOST = process.env['FIRESTORE_EMULATOR_HOST'] ?? '127.0.0.1:8080';

async function clearFirestore(): Promise<void> {
  const url =
    `http://${HOST}/emulator/v1/projects/${PROJECT}` +
    `/databases/(default)/documents`;
  const res = await fetch(url, {method: 'DELETE'});
  if (!res.ok) throw new Error(`emulator clear failed: ${res.status}`);
}

const JOURNEY = {
  profile: {
    alias: 'SteadyFalcon42', avatarEmoji: '🦅', tier: 'premium', email: null,
    gender: 'woman', birthYear: 2001, whys: ['health'], worries: ['cravings'],
    attempts: 'twoToFive', frequency: 'always', firstPuff: 'withinFive',
  },
  plan: {
    method: 'taper', paceDays: 30, startDate: '2026-08-04',
    baselinePuffsPerDay: 200, weeklySpend: 70, strength: 'mg50', stretchDays: 0,
  },
  days: {},
  cravingsSurvivedTotal: 3,
  repairTokens: 1,
  longestStreak: 4,
  goals: [],
  earnedBadges: [],
  lastPuffAt: null,
};

function caller(
  data: Record<string, unknown> = {},
  uid = 'alice',
): CallableRequest<unknown> {
  return {
    data: {text: 'craving hard right now', timeZone: 'UTC', locale: 'en', ...data},
    auth: {uid, token: {}},
    rawRequest: {},
    acceptsStreaming: false,
  } as unknown as CallableRequest<unknown>;
}

/** A streaming caller plus the chunks the handler pushed to it. */
function streamingCaller(data: Record<string, unknown> = {}): {
  request: CallableRequest<unknown>;
  response: CallableResponse<string>;
  chunks: string[];
} {
  const chunks: string[] = [];
  const request = {
    ...caller(data),
    acceptsStreaming: true,
  } as unknown as CallableRequest<unknown>;
  const response = {
    sendChunk: (c: string) => {
      chunks.push(c);
      return Promise.resolve(true);
    },
  } as unknown as CallableResponse<string>;
  return {request, response, chunks};
}

interface Envelope {
  template: string;
  args: Record<string, unknown>;
  text?: string;
  messagesLeft?: number;
  tier?: string;
}

const run = (
  request: CallableRequest<unknown>,
  response?: CallableResponse<string>,
): Promise<Envelope> =>
  (
    aiCoachChat as unknown as {
      run: (r: unknown, s?: unknown) => Promise<Envelope>;
    }
  ).run(request, response);

async function usedToday(uid = 'alice'): Promise<number> {
  const usage = (await userDoc(uid).get()).get('aiUsage') as
    | {msgCount?: number}
    | undefined;
  return typeof usage?.msgCount === 'number' ? usage.msgCount : 0;
}

beforeEach(async () => {
  await clearFirestore();
  vi.clearAllMocks();
  vi.spyOn(GEMINI_API_KEY, 'value').mockReturnValue('test-key');
  // Deploy-time params resolve to 0 with no .env loaded, and a limit of 0
  // means every single call answers `capReached` before reaching the model —
  // which is how this suite first failed, and a decent illustration of why
  // the cap is worth testing at all.
  vi.spyOn(FREE_DAILY_COACH_MESSAGES, 'value').mockReturnValue(5);
  vi.spyOn(PREMIUM_DAILY_COACH_MESSAGES, 'value').mockReturnValue(100);
  embed.mockResolvedValue([[0.1, 0.2, 0.3]]);
  generate.mockResolvedValue({
    text: 'That wave is brutal. Fifteen minutes and it breaks.',
    inputTokens: 900,
    outputTokens: 20,
  });
  await journeyDoc('alice').set(JOURNEY);
  // Tier comes from the server mirror, never from `profile.tier`.
  await userDoc('alice').set({entitlement: {tier: 'premium'}}, {merge: true});
});

describe('the happy path', () => {
  it("returns the model's own words, not a template", async () => {
    const reply = await run(caller());
    expect(reply.text).toBe('That wave is brutal. Fifteen minutes and it breaks.');
    // `generic1` is the graceful degradation for a client too old to read
    // `text`; it must never contradict the words beside it.
    expect(reply.template).toBe('generic1');
  });

  it('persists both turns so the thread survives a restart', async () => {
    await run(caller());
    const stored = await coachMessages('alice').get();
    expect(stored.size).toBe(2);

    // Order is deliberately NOT asserted: both turns go in one batch with
    // `serverTimestamp()`, so they can land on the same millisecond and the
    // ordering between them is genuinely undefined. What matters is that both
    // roles are stored and carry their own text.
    const byRole = new Map(
      stored.docs.map((d) => [d.get('role') as string, d.get('text') as string]),
    );
    expect([...byRole.keys()].sort()).toEqual(['model', 'user']);
    expect(byRole.get('user')).toBe('craving hard right now');
    expect(byRole.get('model')).toContain('Fifteen minutes');
  });

  it('reports the allowance the server is actually enforcing', async () => {
    const reply = await run(caller());
    expect(reply.tier).toBeTypeOf('string');
    expect(reply.messagesLeft).toBeTypeOf('number');
  });

  it('charges exactly one message', async () => {
    await run(caller());
    expect(await usedToday()).toBe(1);
  });
});

describe('greeting before there is anything to coach', () => {
  it('greets a caller with no journey instead of burning a model call', async () => {
    const reply = await run(caller({}, 'stranger'));
    expect(reply.template).toBe('greeting');
    expect(generate).not.toHaveBeenCalled();
    // And it must not charge for a message it never sent.
    expect(await usedToday('stranger')).toBe(0);
  });
});

describe('the cap', () => {
  it('answers capReached without spending anything', async () => {
    vi.spyOn(FREE_DAILY_COACH_MESSAGES, 'value').mockReturnValue(2);
    await userDoc('alice').set({entitlement: {tier: 'free'}}, {merge: true});

    await run(caller());
    await run(caller());
    // Snapshot rather than a fixed count: `generate` also backs the memory
    // extraction pass, so a total would be measuring two things at once. What
    // the cap has to guarantee is that the refused call costs NOTHING MORE.
    const spentBefore = generate.mock.calls.length;
    const third = await run(caller());

    expect(third.template).toBe('capReached');
    expect(third.messagesLeft).toBe(0);
    expect(generate.mock.calls.length).toBe(spentBefore);
  });
});

describe('the fallback ladder', () => {
  it('falls back warmly when the model is unavailable', async () => {
    generate.mockRejectedValue(new ModelUnavailableError(new Error('503')));
    const reply = await run(caller());
    expect(reply.template).toBe('connectionLost');
  });

  it('refunds the message, because nobody pays for our outage', async () => {
    generate.mockRejectedValue(new ModelUnavailableError(new Error('503')));
    await run(caller());
    expect(await usedToday()).toBe(0);
  });

  it('asks the provider what it CAN call when the model id is wrong', async () => {
    // The failure that made this branch necessary: `gemini-3.1-flash` did not
    // exist, every reply came back `connectionLost`, and nothing anywhere
    // named which ids would have worked.
    generate.mockRejectedValue(
      new ModelUnavailableError(new Error('404 models/x is not found')),
    );
    listModels.mockResolvedValue(['gemini-3.7-flash']);

    await run(caller());
    expect(listModels).toHaveBeenCalled();
  });

  it('does not list models for an ordinary outage', async () => {
    // Failure-path only, and only for the one failure whose fix is knowable.
    generate.mockRejectedValue(new ModelUnavailableError(new Error('503')));
    await run(caller());
    expect(listModels).not.toHaveBeenCalled();
  });

  it('treats an empty reply as a failure, not as an answer', async () => {
    generate.mockResolvedValue({text: '   ', inputTokens: 10, outputTokens: 0});
    const reply = await run(caller());
    expect(reply.template).toBe('connectionLost');
    expect(await usedToday()).toBe(0);
  });

  it('still answers when the embedding fails, just without memory', async () => {
    // Recall is best-effort by design: a coach without its memory is worse, a
    // coach that refuses to answer is broken — and this runs mid-craving.
    embed.mockRejectedValue(new Error('embedding down'));
    const reply = await run(caller());
    expect(reply.text).toContain('Fifteen minutes');
  });

  it('re-throws anything that is not a model problem', async () => {
    // A programming error must not be laundered into warm copy.
    generate.mockRejectedValue(new TypeError('undefined is not a function'));
    await expect(run(caller())).rejects.toThrow(TypeError);
  });
});

describe('streaming', () => {
  it('sends the reply in pieces when the client asks for them', async () => {
    generateStream.mockImplementation(function* () {
      yield {type: 'text', text: 'That wave '};
      yield {type: 'text', text: 'is brutal.'};
      yield {type: 'usage', inputTokens: 900, outputTokens: 12};
    });

    const {request, response, chunks} = streamingCaller();
    const reply = await run(request, response);

    expect(chunks).toEqual(['That wave ', 'is brutal.']);
    expect(reply.text).toBe('That wave is brutal.');
    // The REPLY came from the stream and nothing fell back to a blocking
    // generate. Asserting `generate` was never called at all would also be
    // asserting that nothing was learned from the turn, which is a different
    // feature that happens to share the method.
    expect(generateStream).toHaveBeenCalledTimes(1);
    for (const [request] of generate.mock.calls) {
      expect((request as {systemInstruction: string}).systemInstruction).toBe(
        MEMORY_EXTRACTION_PROMPT,
      );
    }
  });

  it('falls back warmly when the stream dies mid-sentence', async () => {
    // These used to escape the `instanceof ModelUnavailableError` check and
    // surface as an unhandled `internal`, so a dropped connection became a red
    // error instead of Ember's fallback — and burned the message with it.
    generateStream.mockImplementation(function* () {
      yield {type: 'text', text: 'That wave '};
      throw new ModelUnavailableError(new Error('stream died'));
    });

    const {request, response} = streamingCaller();
    const reply = await run(request, response);

    expect(reply.template).toBe('connectionLost');
    expect(await usedToday()).toBe(0);
  });
});

describe('auth', () => {
  it('refuses an unauthenticated caller before anything costs money', async () => {
    await expect(
      run({
        data: {text: 'hi', timeZone: 'UTC', locale: 'en'},
        auth: undefined,
        rawRequest: {},
      } as unknown as CallableRequest<unknown>),
    ).rejects.toThrow();
    expect(generate).not.toHaveBeenCalled();
  });
});
