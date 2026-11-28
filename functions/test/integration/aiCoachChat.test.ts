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
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {afterEach, beforeEach, describe, expect, it, vi} from 'vitest';

const generate = vi.fn();
const generateStream = vi.fn();
const embed = vi.fn();
const listModels = vi.fn();

vi.mock('../../src/ai/gemini', () => ({
  geminiModel: () => ({generate, generateStream, embed, listModels}),
}));

/**
 * Every read the handler makes of `users/{uid}/cravings` goes through here.
 * The real collection answers unless a case returns something else (or
 * throws), which is how "no read was made" and "the read failed" are told
 * apart from "the read found nothing".
 */
const cravingsRead = vi.fn();

vi.mock('../../src/lib/firestore', async (importOriginal) => {
  const real = await importOriginal<typeof FirestoreModule>();
  return {
    ...real,
    cravingsCol: (uid: string): unknown =>
      (cravingsRead(uid) as unknown) ?? real.cravingsCol(uid),
  };
});

import type {CallableRequest, CallableResponse} from 'firebase-functions/v2/https';
import type * as FirestoreModule from '../../src/lib/firestore';
import {aiCoachChat, parseFollowUps} from '../../src/handlers/aiCoachChat';
import {buildMemoryCard} from '../../src/ai/memoryCard';
import {ModelUnavailableError} from '../../src/ai/model';
import {
  COACH_SUMMARY_PROMPT,
  FOLLOW_UP_PROMPT,
  MEMORY_EXTRACTION_PROMPT,
  buildCoachInstruction,
  followUpPrompt,
} from '../../src/ai/prompts';
import {
  COACH_CONTEXT_LINES,
  COACH_FOLLOWUPS,
  COACH_UI_AUDIENCE,
  FREE_DAILY_COACH_MESSAGES,
  GEMINI_API_KEY,
  MODEL_FREE,
  PREMIUM_DAILY_COACH_MESSAGES,
} from '../../src/config';
import {dayKeyIn} from '../../src/domain/dateKey';
import {
  coachMessages,
  journeyDoc,
  Timestamp,
  userDoc,
} from '../../src/lib/firestore';
import {log} from '../../src/lib/logger';

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
  showWeekCard?: boolean;
  text?: string;
  messagesLeft?: number;
  tier?: string;
  followUps?: string[];
  ui?: {v: number; blocks: {t: string; exercise: string}[]};
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
  // The production value (`.env.alastpuff`). Re-stubbed before every test, so
  // a case that widens the audience or turns it off cannot leak into the next.
  vi.spyOn(COACH_UI_AUDIENCE, 'value').mockReturnValue('premium');
  // Also the production value: the card's context lines are OFF until the
  // coach eval's bar is met. The cases about the lines turn them on.
  vi.spyOn(COACH_CONTEXT_LINES, 'value').mockReturnValue('off');
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

afterEach(() => {
  vi.useRealTimers();
});

describe('the day the coach is anchored to', () => {
  it("anchors to the caller's calendar day, not UTC's", async () => {
    // 22:30 on Sat Sep 5 in New York is already Sep 6 in UTC. The card, the
    // anchor and the envelope must all say day 2 (the Home header's number),
    // never day 3. Only `Date` is faked: faking the timers as well freezes the
    // Firestore SDK's own I/O (see weeklyInsight.test.ts).
    vi.useFakeTimers({toFake: ['Date']});
    vi.setSystemTime(new Date('2026-09-06T02:30:00.000Z'));
    await journeyDoc('alice').set({
      ...JOURNEY,
      plan: {
        method: 'taper', paceDays: 30, startDate: '2026-09-04',
        baselinePuffsPerDay: 100, weeklySpend: 30, strength: 'mg50', stretchDays: 0,
      },
      days: {
        '2026-09-04': {
          puffs: 36, limit: 95, hourBuckets: {'14': 36}, cravingsSurvived: 0,
          mood: null, moodNote: null, vapeFreeConfirmed: false,
          slipTrigger: null, repairTokenUsed: false,
        },
      },
    });

    const reply = await run(caller({timeZone: 'America/New_York'}));

    // The first generate of a non-streaming turn is the coach reply itself.
    const instruction = (generate.mock.calls[0]![0] as {systemInstruction: string})
      .systemInstruction;
    expect(instruction).toContain('plan day: 2 of 30');
    expect(instruction).toContain('It is plan day 2 for this user (2026-09-05');
    expect(instruction).not.toContain('plan day: 3');
    expect(instruction).toContain('money saved: $3');
    expect(reply.args['day']).toBe(2);
  });
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

/**
 * docs/04 §7: "Free: 5 coach msgs/day + 1 panic session/day."
 *
 * The panic half was specified, counted in `panicUsage` and then read by
 * nothing — `aiCoachChat` claimed an ordinary coach message for every turn,
 * panic or not. So the one moment the product exists for answered "you've used
 * your 5 messages for today", on the screen that had just offered Ember.
 */
describe('the panic allowance is on TOP of the five', () => {
  // The suite's default alice is a subscriber; this allowance is the FREE
  // tier's, because a subscriber's 100 is not a wall anyone meets mid-craving.
  beforeEach(async () => {
    await userDoc('alice').set({entitlement: {tier: 'free'}}, {merge: true});
  });

  const panicUsed = async (uid = 'alice'): Promise<number> => {
    const usage = (await userDoc(uid).get()).get('panicMsgUsage') as
      | {count?: number}
      | undefined;
    return typeof usage?.count === 'number' ? usage.count : 0;
  };

  it('spends the panic allowance, not one of the five', async () => {
    await run(caller({panicIntensity: 8}));
    expect(await panicUsed()).toBe(1);
    expect(await usedToday()).toBe(0);
  });

  it('answers a craving even when the five are gone', async () => {
    // The whole point. Five ordinary messages spent, then a craving at 8/10.
    for (let i = 0; i < 5; i++) await run(caller());
    expect(await usedToday()).toBe(5);

    const reply = await run(caller({panicIntensity: 8}));
    expect(reply.template).not.toBe('capReached');
    expect(generate).toHaveBeenCalled();
  });

  it('falls through to the ordinary allowance once the panic one is spent', async () => {
    // A second craving the same day is not refused while they still have
    // messages left — nobody is turned away mid-craving with allowance in hand.
    await run(caller({panicIntensity: 8}));
    await run(caller({panicIntensity: 9}));
    expect(await panicUsed()).toBe(1);
    expect(await usedToday()).toBe(1);
  });

  it('still refuses once BOTH are spent', async () => {
    vi.spyOn(FREE_DAILY_COACH_MESSAGES, 'value').mockReturnValue(1);
    await run(caller({panicIntensity: 8})); // panic pot
    await run(caller({panicIntensity: 8})); // the single ordinary message
    const reply = await run(caller({panicIntensity: 8}));
    expect(reply.template).toBe('capReached');
  });

  it('reports the COACH messages left, which a panic turn did not touch', async () => {
    await run(caller()); // 1 of 5 ordinary
    const reply = await run(caller({panicIntensity: 8}));
    // Four ordinary left — not five, and not three.
    expect(reply.messagesLeft).toBe(4);
  });

  it('refunds the panic message when the model fails, not a coach one', async () => {
    await run(caller({panicIntensity: 8}));
    expect(await panicUsed()).toBe(1);
    generate.mockRejectedValueOnce(new ModelUnavailableError('down'));
    // The panic pot is spent, so this turn is on the ordinary allowance.
    await run(caller({panicIntensity: 8}));
    expect(await usedToday()).toBe(0); // refunded
    expect(await panicUsed()).toBe(1); // untouched
  });

  it('does not meter a subscriber twice', async () => {
    await userDoc('paid').set({
      entitlement: {
        tier: 'premium',
        expiresAt: new Date(Date.now() + 86_400_000),
      },
    });
    await journeyDoc('paid').set(
      (await journeyDoc('alice').get()).data() as Record<string, unknown>,
    );
    await run(caller({panicIntensity: 8}, 'paid'));
    expect(await panicUsed('paid')).toBe(0);
    expect(await usedToday('paid')).toBe(1);
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
    // asserting that nothing was learned from the turn and nothing was
    // suggested for the next one — different features that happen to share
    // the method — so this names the ones allowed to use it instead.
    expect(generateStream).toHaveBeenCalledTimes(1);
    for (const [request] of generate.mock.calls) {
      expect([MEMORY_EXTRACTION_PROMPT, FOLLOW_UP_PROMPT]).toContain(
        (request as {systemInstruction: string}).systemInstruction,
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

describe('the rolling summary', () => {
  const instructionOf = (call: unknown[]): string =>
    (call[0] as {systemInstruction: string}).systemInstruction;

  it('counts a successful exchange without rebuilding yet', async () => {
    await run(caller());
    const stored = (await userDoc('alice').get()).get('coachSummary') as
      | {text?: string; turnsSince?: number}
      | undefined;
    expect(stored?.turnsSince).toBe(1);
    // No rebuild yet — merge must not have invented a text either.
    expect(stored?.text).toBeUndefined();
    for (const call of generate.mock.calls) {
      expect(instructionOf(call)).not.toBe(COACH_SUMMARY_PROMPT);
    }
  });

  it('rebuilds on the fourth exchange and resets the counter', async () => {
    await userDoc('alice').set(
      {coachSummary: {text: '', turnsSince: 3}},
      {merge: true},
    );
    await run(caller());

    const rebuilds = generate.mock.calls.filter(
      (call) => instructionOf(call) === COACH_SUMMARY_PROMPT,
    );
    expect(rebuilds.length).toBe(1);
    const stored = (await userDoc('alice').get()).get('coachSummary') as {
      text: string;
      turnsSince: number;
    };
    expect(stored.turnsSince).toBe(0);
    // The stub answers every generate the same way; what matters is that the
    // summarizer's output — not the old text — is what got stored.
    expect(stored.text).toContain('Fifteen minutes');
  });

  it('hands the coach the stored summary as fenced background context', async () => {
    await userDoc('alice').set(
      {coachSummary: {text: 'They walk Rufus in the evenings.', turnsSince: 0}},
      {merge: true},
    );
    await run(caller());
    // The first generate of a non-streaming turn is the coach reply itself.
    const instruction = instructionOf(generate.mock.calls[0]!);
    expect(instruction).toContain('EARLIER CONVERSATIONS');
    expect(instruction).toContain('They walk Rufus in the evenings.');
  });

  it('keeps the reply when the summarizer fails, and leaves the retry armed', async () => {
    await userDoc('alice').set(
      {coachSummary: {text: 'old summary', turnsSince: 3}},
      {merge: true},
    );
    generate.mockImplementation((request: {systemInstruction: string}) =>
      request.systemInstruction === COACH_SUMMARY_PROMPT
        ? Promise.reject(new Error('summarizer down'))
        : Promise.resolve({
            text: 'That wave is brutal. Fifteen minutes and it breaks.',
            inputTokens: 900,
            outputTokens: 20,
          }),
    );

    const reply = await run(caller());
    expect(reply.template).toBe('generic1');
    expect(reply.text).toContain('Fifteen minutes');

    const stored = (await userDoc('alice').get()).get('coachSummary') as {
      text: string;
      turnsSince: number;
    };
    // Deliberately unmoved: sitting at the threshold means the very next
    // successful turn retries the rebuild.
    expect(stored.turnsSince).toBe(3);
    expect(stored.text).toBe('old summary');
  });

  it('does not move the counter on a refunded turn', async () => {
    generate.mockRejectedValue(new ModelUnavailableError(new Error('503')));
    await run(caller());
    expect((await userDoc('alice').get()).get('coachSummary')).toBeUndefined();
  });

  it('does not move the counter on a capped turn', async () => {
    vi.spyOn(FREE_DAILY_COACH_MESSAGES, 'value').mockReturnValue(1);
    await userDoc('alice').set({entitlement: {tier: 'free'}}, {merge: true});

    await run(caller()); // spends the one message, counter → 1
    const second = await run(caller());
    expect(second.template).toBe('capReached');

    const stored = (await userDoc('alice').get()).get('coachSummary') as {
      turnsSince: number;
    };
    expect(stored.turnsSince).toBe(1);
  });

  it('anchors memory extraction to the calendar', async () => {
    await run(caller());
    const extractions = generate.mock.calls.filter(
      (call) => instructionOf(call) === MEMORY_EXTRACTION_PROMPT,
    );
    expect(extractions.length).toBe(1);
    const turnText = (
      extractions[0]![0] as {turns: {text: string}[]}
    ).turns[0]!.text;
    // "next Friday" stored as-is means nothing months later; the DATE line is
    // what the extraction prompt anchors absolute dates to.
    expect(turnText).toMatch(/^DATE: \d{4}-\d{2}-\d{2}\n/);
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

/**
 * The follow-up suggestions (docs/12 §5c).
 *
 * Everything here defends one property: they are a nice-to-have riding on the
 * end of a turn, and a turn must never be worse for them. They cannot delay
 * the first token, cannot fail a reply, and cannot appear where a menu of
 * options is the wrong thing to put in front of somebody.
 */
describe('follow-up suggestions', () => {
  /** The follow-up call, whichever position in the batch it landed in. */
  const followUpCalls = (): unknown[][] =>
    generate.mock.calls.filter(
      (call) =>
        (call[0] as {systemInstruction: string}).systemInstruction ===
        FOLLOW_UP_PROMPT,
    );

  /**
   * Answers the follow-up call with [text] and every other call normally.
   *
   * The whole group drives the STREAMING path, because that is the only one
   * the suggestions run on — and the only one the app uses. On the unary path
   * nothing has been delivered yet, so the extra call would sit on the
   * critical path of every answer.
   */
  const suggesting = (text: string): void => {
    generateStream.mockImplementation(function* () {
      yield {type: 'text', text: 'That wave breaks.'};
      yield {type: 'usage', inputTokens: 900, outputTokens: 12};
    });
    generate.mockImplementation((request: {systemInstruction: string}) =>
      Promise.resolve(
        request.systemInstruction === FOLLOW_UP_PROMPT
          ? {text, inputTokens: 240, outputTokens: 22}
          : {text: 'That wave breaks.', inputTokens: 900, outputTokens: 12},
      ),
    );
  };

  /** A streaming turn, which is what every real client makes. */
  const streamed = (data: Record<string, unknown> = {}): Promise<Envelope> => {
    const {request, response} = streamingCaller(data);
    return run(request, response);
  };

  it("rides the envelope, in the user's own voice", async () => {
    suggesting(
      '{"followUps":["what if it doesnt","i already caved","that helped"]}',
    );

    const reply = await streamed();

    expect(reply.followUps).toEqual([
      'what if it doesnt',
      'i already caved',
      'that helped',
    ]);
    // The cheap model, always: four short strings in fixed JSON is a
    // structured-output task, and the premium model buys nothing here.
    const [call] = followUpCalls();
    expect((call?.[0] as {model: string}).model).toBe(MODEL_FREE.value());
    expect((call?.[0] as {json: boolean}).json).toBe(true);
  });

  it('never suggests anything mid-craving', async () => {
    // The panic rider is breath and presence only — thirty words, one step at
    // a time. A menu of four things to say next is the opposite of that, and
    // somebody at 9/10 does not need options.
    suggesting('{"followUps":["never shown"]}');
    const reply = await streamed({text: 'i cant do this', panicIntensity: 9});

    expect(reply.followUps).toBeUndefined();
    expect(followUpCalls()).toHaveLength(0);
  });

  it('costs a unary client nothing at all', async () => {
    // A client that cannot stream has had NOTHING yet when this block runs,
    // so the extra round-trip would be added to the wait for the answer
    // itself. It gets the static chips instead.
    suggesting('{"followUps":["not for you"]}');
    const reply = await run(caller());

    expect(reply.text).toBe('That wave breaks.');
    expect(reply.followUps).toBeUndefined();
    expect(followUpCalls()).toHaveLength(0);
  });

  it('answers normally when the suggestion call fails', async () => {
    generateStream.mockImplementation(function* () {
      yield {type: 'text', text: 'That wave breaks.'};
      yield {type: 'usage', inputTokens: 900, outputTokens: 12};
    });
    generate.mockImplementation((request: {systemInstruction: string}) =>
      request.systemInstruction === FOLLOW_UP_PROMPT
        ? Promise.reject(new Error('suggester exploded'))
        : Promise.resolve({
            text: 'That wave breaks.',
            inputTokens: 900,
            outputTokens: 12,
          }),
    );

    const reply = await streamed();

    // The reply the user asked for is untouched, the message still counted,
    // and the field is simply absent — which the app reads as "show the four
    // static chips".
    expect(reply.text).toBe('That wave breaks.');
    expect(reply.followUps).toBeUndefined();
    expect(await usedToday()).toBe(1);
  });

  it('omits the field rather than sending an empty list', async () => {
    suggesting('{"followUps":[]}');
    const reply = await streamed();
    expect(reply.followUps).toBeUndefined();
  });

  it('suggests nothing on a turn that never reached the model', async () => {
    // A cap costs no model call by design, so it cannot cost one for this
    // either — and there is nothing to follow up on.
    await userDoc('alice').set(
      {aiUsage: {day: dayKeyIn(new Date(), 'UTC'), msgCount: 5}},
      {merge: true},
    );
    vi.spyOn(PREMIUM_DAILY_COACH_MESSAGES, 'value').mockReturnValue(5);

    const reply = await streamed();

    expect(reply.template).toBe('capReached');
    expect(reply.followUps).toBeUndefined();
    expect(followUpCalls()).toHaveLength(0);
  });
});

/**
 * Coach cards (docs/superpowers/plans/2026-11-25-coach-cards.md, K3 and K6).
 *
 * `test/coachUi.test.ts` pins the policy as a pure function. What is under
 * test here is the handler around it: that the cards ride every envelope a
 * person can be left looking at (a reply, the cap, an outage) on both the
 * streaming and the plain call, that they cost no model call, and that
 * anybody who should see exactly today's reply does — an older app, a free
 * account, a turned-off audience, a request with junk in the field.
 *
 * Every "gets none" case first shows the same turn getting cards. A reply
 * with no `ui` is also what a handler that never attaches one produces, so
 * without that control each of them would pass against the old code.
 */
describe('coach cards', () => {
  const ALL_FIVE = ['breathing', 'orbs', 'tiles', 'blocks', 'sos'];

  /** What a current app sends with a turn: every exercise it can draw. */
  const cards = (
    over: Record<string, unknown> = {},
  ): Record<string, unknown> => ({
    v: 1,
    exercises: ALL_FIVE,
    craving: false,
    ...over,
  });

  /** A shared fixture's cards, as the reply carries them. */
  const fixtureUi = (name: string): unknown => {
    const file = resolve(__dirname, '../fixtures/coach_ui', `${name}.json`);
    const fixture = JSON.parse(readFileSync(file, 'utf8')) as {
      blocks: unknown[];
    };
    return {v: 1, blocks: fixture.blocks};
  };

  /** A reply over the stream; the follow-up call answers [followUps]. */
  const streamsAReply = (followUps = 'no suggestions'): void => {
    generateStream.mockImplementation(function* () {
      yield {type: 'text', text: 'That wave breaks.'};
      yield {type: 'usage', inputTokens: 900, outputTokens: 12};
    });
    generate.mockImplementation((request: {systemInstruction: string}) =>
      Promise.resolve(
        request.systemInstruction === FOLLOW_UP_PROMPT
          ? {text: followUps, inputTokens: 240, outputTokens: 22}
          : {text: 'That wave breaks.', inputTokens: 900, outputTokens: 12},
      ),
    );
  };

  const streamed = (data: Record<string, unknown>): Promise<Envelope> => {
    const {request, response} = streamingCaller(data);
    return run(request, response);
  };

  const keysOf = (reply: Envelope): string[] => Object.keys(reply).sort();

  /** Today's reply, key for key. */
  const REPLY_KEYS = [
    'args', 'messagesLeft', 'showWeekCard', 'template', 'text', 'tier',
  ];
  /** Today's `capReached` and `connectionLost`, key for key. */
  const REFUSAL_KEYS = ['args', 'messagesLeft', 'showWeekCard', 'template', 'tier'];

  const instructionOf = (call: unknown[]): string =>
    (call[0] as {systemInstruction: string}).systemInstruction;

  const makeFree = (): Promise<unknown> =>
    userDoc('alice').set({entitlement: {tier: 'free'}}, {merge: true});

  it('a subscriber who taps the craving chip gets the menu', async () => {
    streamsAReply();
    const reply = await streamed({chip: 'craving', ui: cards()});

    expect(reply.template).toBe('generic1');
    expect(reply.text).toBe('That wave breaks.');
    expect(reply.tier).toBe('premium');
    expect(reply.ui).toEqual(fixtureUi('craving_chip'));
  });

  it('a craving in progress gets one card', async () => {
    streamsAReply();
    const reply = await streamed({panicIntensity: 8, ui: cards()});

    expect(reply.text).toBe('That wave breaks.');
    expect(reply.ui).toEqual(fixtureUi('panic_default'));
    // The card cost no model call. The reply is the one stream; the one
    // `generate` is the memory pass a turn with this text has always made;
    // and mid-craving nothing is asked to suggest what to say next.
    expect(generateStream).toHaveBeenCalledTimes(1);
    expect(generate).toHaveBeenCalledTimes(1);
    expect(instructionOf(generate.mock.calls[0]!)).toBe(MEMORY_EXTRACTION_PROMPT);
    expect(
      generate.mock.calls.filter((c) => instructionOf(c) === FOLLOW_UP_PROMPT),
    ).toHaveLength(0);
  });

  it('the same on a call that does not stream', async () => {
    // `FirebaseCoachRepository` re-asks over the plain call when a stream
    // ends before a word arrives, so this is the path a recovering turn takes.
    const menu = await run(caller({chip: 'craving', ui: cards()}));
    expect(menu.text).toContain('Fifteen minutes');
    expect(menu.ui).toEqual(fixtureUi('craving_chip'));

    const one = await run(caller({panicIntensity: 8, ui: cards()}));
    expect(one.ui).toEqual(fixtureUi('panic_default'));
    expect(generateStream).not.toHaveBeenCalled();
  });

  it('a chat already in a craving gets one card, even on the craving chip', async () => {
    // The second and third message of a craving chat: the app says so with
    // `craving: true`, and the answer is one next step, never the menu again.
    const reply = await run(
      caller({chip: 'craving', ui: cards({craving: true})}),
    );
    expect(reply.ui).toEqual(fixtureUi('panic_default'));
  });

  it('an app that says nothing about cards gets the old envelope', async () => {
    // The control: this exact turn, from an app that can draw cards.
    expect(keysOf(await run(caller({chip: 'craving', ui: cards()})))).toEqual(
      [...REPLY_KEYS, 'ui'].sort(),
    );

    expect(keysOf(await run(caller({chip: 'craving'})))).toEqual(REPLY_KEYS);
    expect(keysOf(await run(caller({panicIntensity: 8})))).toEqual(REPLY_KEYS);

    // And on the stream, where a turn may also carry suggestions.
    streamsAReply('{"followUps":["what if it doesnt","that helped"]}');
    const overStream = await streamed({chip: 'craving'});
    expect(overStream.followUps).toEqual(['what if it doesnt', 'that helped']);
    expect(keysOf(overStream)).toEqual([...REPLY_KEYS, 'followUps'].sort());
  });

  it('a free account gets none', async () => {
    expect((await run(caller({chip: 'craving', ui: cards()}))).ui).toEqual(
      fixtureUi('craving_chip'),
    );

    await makeFree();
    const menu = await run(caller({chip: 'craving', ui: cards()}));
    expect(menu.tier).toBe('free');
    expect(keysOf(menu)).toEqual(REPLY_KEYS);
    // Not mid-craving either: the launch audience is subscribers only.
    const craving = await run(
      caller({panicIntensity: 8, ui: cards({craving: true})}),
    );
    expect(keysOf(craving)).toEqual(REPLY_KEYS);
  });

  it('audience off gets none', async () => {
    expect((await run(caller({chip: 'craving', ui: cards()}))).ui).toEqual(
      fixtureUi('craving_chip'),
    );

    vi.spyOn(COACH_UI_AUDIENCE, 'value').mockReturnValue('off');
    expect(keysOf(await run(caller({chip: 'craving', ui: cards()})))).toEqual(
      REPLY_KEYS,
    );
    expect(keysOf(await run(caller({panicIntensity: 8, ui: cards()})))).toEqual(
      REPLY_KEYS,
    );
  });

  it('audience all gives a free account only free exercises', async () => {
    vi.spyOn(COACH_UI_AUDIENCE, 'value').mockReturnValue('all');
    await makeFree();

    const reply = await run(caller({chip: 'craving', ui: cards()}));

    expect(reply.tier).toBe('free');
    expect(reply.ui).toEqual(fixtureUi('audience_all_free'));
    // Nobody lands on a lock: the app listed Tiles and Blocks, and neither
    // is offered to an account that cannot open them.
    const offered = (reply.ui?.blocks ?? []).map((b) => b.exercise);
    expect(offered).not.toContain('tiles');
    expect(offered).not.toContain('blocks');

    // The default menu never reaches a locked row (Orbs is the first focus
    // exercise and it is free), so the lines above hold for a handler that
    // forgot the tier. Narrow the app's list until a locked game would be
    // next: only the server's own read of the tier keeps Tiles out of this.
    const narrowed = await run(
      caller({chip: 'craving', ui: cards({exercises: ['tiles', 'blocks', 'sos']})}),
    );
    expect((narrowed.ui?.blocks ?? []).map((b) => b.exercise)).toEqual(['sos']);
  });

  it('an audience nobody set reads as premium', async () => {
    // What the param resolves to on a project whose .env never named it.
    vi.spyOn(COACH_UI_AUDIENCE, 'value').mockReturnValue('');
    expect((await run(caller({chip: 'craving', ui: cards()}))).ui).toEqual(
      fixtureUi('craving_chip'),
    );
    await makeFree();
    expect(keysOf(await run(caller({chip: 'craving', ui: cards()})))).toEqual(
      REPLY_KEYS,
    );
  });

  it('out of messages, the card still comes', async () => {
    await userDoc('alice').set(
      {aiUsage: {day: dayKeyIn(new Date(), 'UTC'), msgCount: 5}},
      {merge: true},
    );
    vi.spyOn(PREMIUM_DAILY_COACH_MESSAGES, 'value').mockReturnValue(5);

    const reply = await run(caller({chip: 'craving', ui: cards()}));

    // Ember has nothing left to say today. The exercise still works.
    expect(reply.template).toBe('capReached');
    expect(reply.messagesLeft).toBe(0);
    expect(reply.ui).toEqual(fixtureUi('craving_chip'));
    expect(generate).not.toHaveBeenCalled();
    expect(generateStream).not.toHaveBeenCalled();
    expect(embed).not.toHaveBeenCalled();

    // Mid-craving at the same wall: one card.
    const craving = await run(caller({panicIntensity: 8, ui: cards()}));
    expect(craving.template).toBe('capReached');
    expect(craving.ui).toEqual(fixtureUi('panic_default'));

    // And an older app at that wall gets exactly today's refusal.
    expect(keysOf(await run(caller({chip: 'craving'})))).toEqual(REFUSAL_KEYS);
    expect(generate).not.toHaveBeenCalled();
  });

  it('the model is down, the card still comes', async () => {
    generate.mockRejectedValue(new ModelUnavailableError(new Error('503')));

    const reply = await run(caller({chip: 'craving', ui: cards()}));

    expect(reply.template).toBe('connectionLost');
    expect(reply.ui).toEqual(fixtureUi('craving_chip'));
    // Still nobody's message: the refund is untouched by the card.
    expect(await usedToday()).toBe(0);

    // A stream that dies mid-sentence, mid-craving: one card.
    generateStream.mockImplementation(function* () {
      yield {type: 'text', text: 'That wave '};
      throw new ModelUnavailableError(new Error('stream died'));
    });
    const dropped = await streamed({panicIntensity: 8, ui: cards()});
    expect(dropped.template).toBe('connectionLost');
    expect(dropped.ui).toEqual(fixtureUi('panic_default'));

    // An older app in the same outage gets exactly today's fallback.
    expect(keysOf(await run(caller({chip: 'craving'})))).toEqual(REFUSAL_KEYS);
  });

  it('an empty reply is an outage too, and the card still comes', async () => {
    generate.mockResolvedValue({text: '   ', inputTokens: 10, outputTokens: 0});

    const reply = await run(caller({chip: 'craving', ui: cards()}));

    expect(reply.template).toBe('connectionLost');
    expect(reply.ui).toEqual(fixtureUi('craving_chip'));
    expect(await usedToday()).toBe(0);
    expect(keysOf(await run(caller({chip: 'craving'})))).toEqual(REFUSAL_KEYS);
  });

  it('a malformed ui never fails the turn', async () => {
    expect((await run(caller({chip: 'craving', ui: cards()}))).ui).toEqual(
      fixtureUi('craving_chip'),
    );

    const junk: unknown[] = [
      'x', 7, true, null, [], {}, {v: 1}, {exercises: 'x'},
      {v: 1, exercises: {length: 3}},
      {v: 1, exercises: [null, {}, 'teleport', 7], craving: true},
    ];
    for (const ui of junk) {
      const reply = await run(caller({chip: 'craving', ui}));
      expect(reply.template, JSON.stringify(ui)).toBe('generic1');
      expect(reply.text, JSON.stringify(ui)).toContain('Fifteen minutes');
      expect(keysOf(reply), JSON.stringify(ui)).toEqual(REPLY_KEYS);
    }
  });

  it('a caller with no journey is greeted without a card', async () => {
    expect((await run(caller({chip: 'craving', ui: cards()}))).ui).toEqual(
      fixtureUi('craving_chip'),
    );

    // A subscriber, so the tier is not what keeps the card away: there is
    // simply nothing to open before onboarding has made a plan.
    await userDoc('stranger').set({entitlement: {tier: 'premium'}});
    const reply = await run(
      caller({chip: 'craving', ui: cards()}, 'stranger'),
    );
    expect(reply).toEqual({template: 'greeting', args: {}, showWeekCard: false});
  });

  it('logs how many cards went out, and never which account', async () => {
    const info = vi.spyOn(log, 'info');
    try {
      await run(caller({chip: 'craving', ui: cards()}));
      await run(caller({panicIntensity: 8, ui: cards()}));
      await makeFree();
      await run(caller({chip: 'craving', ui: cards()}));

      const lines = info.mock.calls
        .filter(([event]) => event === 'coach.ui')
        .map(([, meta]) => meta);
      // `firebase functions:log --only aiCoachChat` is how the device run
      // against production is read: three for a subscriber's menu, zero for
      // the same turn on a free account.
      // `advertised` is whether the app said what it can draw, and `named`
      // how many exercises the follow-up call said the reply was about: with
      // both on the line, "no card" can be told apart from "an older build"
      // and from "an ordinary reply" without guessing.
      expect(lines).toEqual([
        {uidHash: expect.any(String), blocks: 3, craving: false, advertised: true, named: 0},
        {uidHash: expect.any(String), blocks: 1, craving: true, advertised: true, named: 0},
        {uidHash: expect.any(String), blocks: 0, craving: false, advertised: true, named: 0},
      ]);

      // One line a turn, whichever way it ended: an older app, and a turn
      // whose card came from what the reply was about.
      info.mockClear();
      await userDoc('alice').set({entitlement: {tier: 'premium'}}, {merge: true});
      await run(caller({chip: 'craving'}));
      streamsAReply();
      generate.mockImplementation((request: {systemInstruction: string}) =>
        Promise.resolve(
          request.systemInstruction.includes('"followUps"')
            ? {text: '{"followUps":[],"exercises":["breathing"]}', inputTokens: 300, outputTokens: 12}
            : {text: 'That wave breaks.', inputTokens: 900, outputTokens: 12},
        ),
      );
      await streamed({text: 'lets do it now', ui: cards()});
      expect(
        info.mock.calls
          .filter(([event]) => event === 'coach.ui')
          .map(([, meta]) => meta),
      ).toEqual([
        {uidHash: expect.any(String), blocks: 0, craving: false, advertised: false, named: 0},
        {uidHash: expect.any(String), blocks: 1, craving: false, advertised: true, named: 1},
      ]);
    } finally {
      info.mockRestore();
    }
  });

  /**
   * A card for what the reply was about (founder decision, Nov 28 2026).
   *
   * Until this, an ordinary message never carried a card: the coach could
   * say "want to try a 4-7-8 breath with me?", hear "let's do it now", and
   * answer in words with the breathing exercise nowhere on screen. The
   * follow-up call that already runs after every streamed reply now also
   * says which exercise, if any, that reply was about.
   *
   * What is under test: that it is the SAME call (no model call is added),
   * that only somebody who can be shown a card is asked, that code still
   * decides what a name becomes, and that a bad answer costs the card and
   * never the reply.
   */
  describe('a card for what the reply was about', () => {
    const NAMED = '{"followUps":["that felt calming"],"exercises":["breathing"]}';

    /** Either follow-up prompt: the plain one, or the one that asks for names. */
    const isFollowUp = (instruction: string): boolean =>
      instruction.includes('"followUps"');

    /** A streamed reply; the follow-up call, whichever prompt it carries, answers [text]. */
    const naming = (text: string): void => {
      generateStream.mockImplementation(function* () {
        yield {type: 'text', text: 'That wave breaks.'};
        yield {type: 'usage', inputTokens: 900, outputTokens: 12};
      });
      generate.mockImplementation((request: {systemInstruction: string}) =>
        Promise.resolve(
          isFollowUp(request.systemInstruction)
            ? {text, inputTokens: 330, outputTokens: 30}
            : {text: 'That wave breaks.', inputTokens: 900, outputTokens: 12},
        ),
      );
    };

    const followUpCalls = (): unknown[][] =>
      generate.mock.calls.filter((c) => isFollowUp(instructionOf(c)));

    const ONLY = (exercise: string): unknown => ({
      v: 1,
      blocks: [{t: 'launcher', exercise}],
    });

    it('an ordinary message whose reply offers an exercise carries its card', async () => {
      naming(NAMED);
      const reply = await streamed({text: 'lets do it now', ui: cards()});

      expect(reply.template).toBe('generic1');
      expect(reply.text).toBe('That wave breaks.');
      expect(reply.ui).toEqual(fixtureUi('suggested_one'));
      // The suggestions it has always carried are still there beside it.
      expect(reply.followUps).toEqual(['that felt calming']);
      expect(keysOf(reply)).toEqual([...REPLY_KEYS, 'followUps', 'ui'].sort());
    });

    it('costs no model call: the follow-up call that already ran is the one asked', async () => {
      naming(NAMED);
      await streamed({text: 'lets do it now', ui: cards()});

      expect(generateStream).toHaveBeenCalledTimes(1);
      expect(followUpCalls()).toHaveLength(1);
      const [call] = followUpCalls();
      const request = call?.[0] as {model: string; json: boolean};
      // Told exactly which exercises this person can open, and nothing else
      // about them. Still the cheap model, still strict JSON.
      expect(instructionOf(call!)).toBe(
        followUpPrompt(['breathing', 'orbs', 'tiles', 'blocks', 'sos']),
      );
      expect(instructionOf(call!)).not.toBe(FOLLOW_UP_PROMPT);
      expect(request.model).toBe(MODEL_FREE.value());
      expect(request.json).toBe(true);
    });

    it('a reply about none of them is the reply it always was', async () => {
      naming('{"followUps":["that helped"],"exercises":[]}');
      const reply = await streamed({text: 'how much have i saved', ui: cards()});

      expect(reply.followUps).toEqual(['that helped']);
      expect(keysOf(reply)).toEqual([...REPLY_KEYS, 'followUps'].sort());
    });

    it('nobody who cannot be shown a card is asked to name one', async () => {
      // The control: a subscriber on a current app is asked, and gets it.
      naming(NAMED);
      expect((await streamed({text: 'hi there', ui: cards()})).ui).toEqual(
        fixtureUi('suggested_one'),
      );

      // An older app: the follow-up call is today's, word for word, and a
      // name the model volunteers anyway becomes nothing.
      generate.mockClear();
      const old = await streamed({text: 'hi there'});
      expect(instructionOf(followUpCalls()[0]!)).toBe(FOLLOW_UP_PROMPT);
      expect(keysOf(old)).toEqual([...REPLY_KEYS, 'followUps'].sort());

      // A free account while the audience is subscribers only.
      await makeFree();
      generate.mockClear();
      const free = await streamed({text: 'hi there', ui: cards()});
      expect(free.tier).toBe('free');
      expect(instructionOf(followUpCalls()[0]!)).toBe(FOLLOW_UP_PROMPT);
      expect(keysOf(free)).toEqual([...REPLY_KEYS, 'followUps'].sort());
    });

    it('audience off asks for no names and shows none', async () => {
      vi.spyOn(COACH_UI_AUDIENCE, 'value').mockReturnValue('off');
      naming(NAMED);
      const reply = await streamed({text: 'hi there', ui: cards()});

      expect(instructionOf(followUpCalls()[0]!)).toBe(FOLLOW_UP_PROMPT);
      expect(reply.ui).toBeUndefined();
    });

    it('audience all: a free account is asked about, and shown, free exercises only', async () => {
      vi.spyOn(COACH_UI_AUDIENCE, 'value').mockReturnValue('all');
      await makeFree();
      // The model names a Premium game anyway.
      naming('{"followUps":[],"exercises":["tiles"]}');
      const reply = await streamed({text: 'a game maybe', ui: cards()});

      expect(instructionOf(followUpCalls()[0]!)).toBe(
        followUpPrompt(['breathing', 'orbs', 'sos']),
      );
      // Nobody lands on a lock: the free game stands in for it.
      expect(reply.ui).toEqual(fixtureUi('suggested_locked'));
    });

    it('an app is asked only about what it can draw', async () => {
      naming('{"followUps":[],"exercises":["blocks"]}');
      const reply = await streamed({
        text: 'a game maybe',
        ui: cards({exercises: ['sos', 'orbs']}),
      });

      expect(instructionOf(followUpCalls()[0]!)).toBe(
        followUpPrompt(['orbs', 'sos']),
      );
      expect(reply.ui).toEqual(ONLY('orbs'));
    });

    it('inside a craving the one card is the exercise the reply named', async () => {
      naming('{"followUps":[],"exercises":["orbs","sos"]}');
      const named = await streamed({text: 'still here', ui: cards({craving: true})});
      expect(named.ui).toEqual(ONLY('orbs'));

      // Nothing named: the calm one, as before.
      naming('{"followUps":[],"exercises":[]}');
      const plain = await streamed({text: 'still here', ui: cards({craving: true})});
      expect(plain.ui).toEqual(fixtureUi('panic_default'));
    });

    it('the craving chip keeps its menu, and asks for no names', async () => {
      naming('{"followUps":[],"exercises":["sos"]}');
      const reply = await streamed({chip: 'craving', ui: cards()});

      expect(reply.ui).toEqual(fixtureUi('craving_chip'));
      expect(instructionOf(followUpCalls()[0]!)).toBe(FOLLOW_UP_PROMPT);
    });

    it('a bad answer costs the card, never the reply', async () => {
      for (const junk of [
        'not json',
        '{"followUps":["ok then"]}',
        '{"followUps":["ok then"],"exercises":"breathing"}',
        '{"followUps":["ok then"],"exercises":["teleport",7,null]}',
      ]) {
        naming(junk);
        const reply = await streamed({text: 'hi there', ui: cards()});
        expect(reply.template, junk).toBe('generic1');
        expect(reply.text, junk).toBe('That wave breaks.');
        expect(reply.ui, junk).toBeUndefined();
      }
    });

    it('the follow-up call failing costs the card, never the reply', async () => {
      generateStream.mockImplementation(function* () {
        yield {type: 'text', text: 'That wave breaks.'};
        yield {type: 'usage', inputTokens: 900, outputTokens: 12};
      });
      generate.mockImplementation((request: {systemInstruction: string}) =>
        isFollowUp(request.systemInstruction)
          ? Promise.reject(new Error('suggester exploded'))
          : Promise.resolve({text: 'That wave breaks.', inputTokens: 900, outputTokens: 12}),
      );

      const reply = await streamed({text: 'hi there', ui: cards()});

      expect(reply.text).toBe('That wave breaks.');
      expect(keysOf(reply)).toEqual(REPLY_KEYS);
      expect(await usedToday()).toBe(1);
    });

    it('a call that does not stream names nothing', async () => {
      // No follow-up call is made on the plain call (it would sit in front
      // of the answer), so there is nobody to ask. The craving rules, which
      // need no model, are unchanged on this path.
      naming(NAMED);
      const reply = await run(caller({text: 'lets do it now', ui: cards()}));

      expect(keysOf(reply)).toEqual(REPLY_KEYS);
      expect(followUpCalls()).toHaveLength(0);
    });

    it('follow-ups switched off take the names with them', async () => {
      const off = vi.spyOn(COACH_FOLLOWUPS, 'value').mockReturnValue('false');
      try {
        naming(NAMED);
        const reply = await streamed({text: 'lets do it now', ui: cards()});

        expect(keysOf(reply)).toEqual(REPLY_KEYS);
        expect(followUpCalls()).toHaveLength(0);
        // The cards that need no model are untouched by that switch.
        expect((await streamed({chip: 'craving', ui: cards()})).ui).toEqual(
          fixtureUi('craving_chip'),
        );
      } finally {
        off.mockRestore();
      }
    });

    it('out of messages or with the model down, nothing is named and nothing is asked', async () => {
      naming(NAMED);
      await userDoc('alice').set(
        {aiUsage: {day: dayKeyIn(new Date(), 'UTC'), msgCount: 5}},
        {merge: true},
      );
      vi.spyOn(PREMIUM_DAILY_COACH_MESSAGES, 'value').mockReturnValue(5);

      const capped = await streamed({text: 'lets do it now', ui: cards()});

      expect(capped.template).toBe('capReached');
      expect(keysOf(capped)).toEqual(REFUSAL_KEYS);
      expect(followUpCalls()).toHaveLength(0);
    });
  });
});

/**
 * What Ember is told about cravings, and what the cards do with it
 * (docs/superpowers/plans/2026-11-25-coach-cards.md, task S4).
 *
 * `test/cravingDigest.test.ts` and `test/memoryCard.test.ts` pin the lines.
 * Here it is the handler: that the cravings are read only for somebody the
 * cards are for, that a failed read costs the lines and never the reply,
 * that a panic turn is told none of it, and that the latest tool reaches the
 * card policy.
 */
describe('the craving log', () => {
  // Everything in this block is about the card's context lines, which ship
  // OFF (`COACH_CONTEXT_LINES`, the suite's default above). These cases turn
  // them on, the way the suite turns the audience up or down. With the param
  // left off, five of them fail: the lines they look for are not there.
  beforeEach(() => {
    vi.spyOn(COACH_CONTEXT_LINES, 'value').mockReturnValue('on');
  });

  const ALL_FIVE = ['breathing', 'orbs', 'tiles', 'blocks', 'sos'];
  const cards = (over: Record<string, unknown> = {}): Record<string, unknown> => ({
    v: 1,
    exercises: ALL_FIVE,
    craving: false,
    ...over,
  });

  const fixtureUi = (name: string): unknown => {
    const file = resolve(__dirname, '../fixtures/coach_ui', `${name}.json`);
    const fixture = JSON.parse(readFileSync(file, 'utf8')) as {
      blocks: unknown[];
    };
    return {v: 1, blocks: fixture.blocks};
  };

  const hoursAgo = (hours: number): Date =>
    new Date(Date.now() - hours * 3_600_000);

  /**
   * A craving document as `panicSession` writes one. Seeded straight into
   * the collection, not through the counted `cravingsCol`, so the counter
   * only ever counts the handler's own reads.
   */
  const seedCraving = (
    at: Date,
    over: Record<string, unknown> = {},
    uid = 'alice',
  ): Promise<unknown> =>
    userDoc(uid).collection('cravings').add({
      outcome: 'survived',
      intensity: null,
      intensityAfter: null,
      game: null,
      exercise: null,
      source: null,
      ...over,
      startedAt: Timestamp.fromDate(at),
    });

  /** Orbs with a lower re-rating an hour ago, breathing, then Orbs again. */
  const seedThree = async (): Promise<Date> => {
    const latest = hoursAgo(1);
    await seedCraving(hoursAgo(50), {intensity: 6, game: 'orbs'});
    await seedCraving(latest, {
      intensity: 8,
      intensityAfter: 4,
      game: 'orbs',
      exercise: 'orbs',
      source: 'panic',
    });
    await seedCraving(hoursAgo(26), {exercise: 'breathing', source: 'coach'});
    return latest;
  };

  /** The system instruction of the coach reply on a plain call. */
  const instruction = (): string =>
    (generate.mock.calls[0]![0] as {systemInstruction: string}).systemInstruction;

  const makeFree = (): Promise<unknown> =>
    userDoc('alice').set({entitlement: {tier: 'free'}}, {merge: true});

  const JUST_DID = {exercise: 'breathing', seconds: 60, completed: true, passed: true};
  const JUST_DID_LINE =
    'just before this message, in the app: they used the breathing exercise ' +
    'for about a minute and marked the craving as passed ' +
    '(already counted in "cravings survived" above)';

  it('a subscriber with cravings on record is told about them', async () => {
    const latest = await seedThree();

    const reply = await run(caller({chip: 'craving', ui: cards()}));

    const told = instruction();
    expect(told).toContain(
      'craving log (cravings they marked as passed; a list, not a day count or the streak): ' +
        `latest on ${dayKeyIn(latest, 'UTC')} (`,
    );
    expect(told).toContain(
      'during that one they had open: the Orbs game · their own re-rating afterwards was lower',
    );
    expect(told).toContain(
      'tools they have opened during a craving, most recent first: the Orbs game, the breathing exercise',
    );
    // One query, for this account, beside the journey read.
    expect(cravingsRead).toHaveBeenCalledTimes(1);
    expect(cravingsRead).toHaveBeenCalledWith('alice');
    // And what they used last leads the menu.
    expect(reply.ui).toEqual(fixtureUi('craving_chip_recent'));
  });

  it('mid-craving none of it is read back, and the one card is what they used last', async () => {
    await seedThree();
    await journeyDoc('alice').set({...JOURNEY, lastPuffAt: '2026-08-10T21:05:00.000'});

    const reply = await run(
      caller({panicIntensity: 8, ui: cards(), justDid: JUST_DID}),
    );

    // Somebody at 8/10 gets breath and presence, not their history.
    const told = instruction();
    expect(told).not.toContain('craving log (');
    expect(told).not.toContain('during that one they had open');
    expect(told).not.toContain('last puff:');
    expect(told).not.toContain('just before this message');
    // The digest still chose the card: Orbs, not the calm default.
    expect(reply.ui).toEqual(fixtureUi('panic_recent'));
    expect(cravingsRead).toHaveBeenCalledTimes(1);
  });

  it('the latest tool leads the menu, and somebody to ask stays on it', async () => {
    // Founder decision, Nov 25 2026: a second game used last must not push
    // the SOS card off. Tiles, breathing, SOS; never Tiles, breathing, Orbs.
    await seedCraving(hoursAgo(30), {game: 'orbs', exercise: 'orbs'});
    await seedCraving(hoursAgo(2), {game: 'tiles', exercise: 'tiles'});

    const reply = await run(caller({chip: 'craving', ui: cards()}));

    expect(reply.ui).toEqual(fixtureUi('craving_chip_recent_tiles'));
  });

  it('a free turn makes no cravings read', async () => {
    await seedThree();
    // The control: the same turn from a subscriber reads them.
    await run(caller({chip: 'craving', ui: cards()}));
    expect(cravingsRead).toHaveBeenCalledTimes(1);
    expect(instruction()).toContain('craving log (');

    cravingsRead.mockClear();
    generate.mockClear();
    await makeFree();
    await run(caller({chip: 'craving', ui: cards()}));
    expect(cravingsRead).not.toHaveBeenCalled();
    expect(instruction()).not.toContain('craving log (');
  });

  it('nor does an app that said nothing about cards, or an audience that is off', async () => {
    await seedThree();
    await run(caller({chip: 'craving', ui: cards()}));
    expect(cravingsRead).toHaveBeenCalledTimes(1);

    // An older app, on a subscriber's account.
    cravingsRead.mockClear();
    generate.mockClear();
    await run(caller({chip: 'craving'}));
    expect(cravingsRead).not.toHaveBeenCalled();
    expect(instruction()).not.toContain('craving log (');

    vi.spyOn(COACH_UI_AUDIENCE, 'value').mockReturnValue('off');
    generate.mockClear();
    await run(caller({chip: 'craving', ui: cards()}));
    expect(cravingsRead).not.toHaveBeenCalled();
    expect(instruction()).not.toContain('craving log (');
  });

  it('a cravings read that throws still answers', async () => {
    await seedThree();
    const warn = vi.spyOn(log, 'warn');
    try {
      cravingsRead.mockImplementationOnce(() => {
        throw new Error('firestore down');
      });
      const reply = await run(caller({chip: 'craving', ui: cards()}));

      expect(reply.template).toBe('generic1');
      expect(reply.text).toContain('Fifteen minutes');
      expect(instruction()).not.toContain('craving log (');
      // The cards never depended on the read: the default menu, in order.
      expect(reply.ui).toEqual(fixtureUi('craving_chip'));
      expect(warn.mock.calls.map(([event]) => event)).toContain('coach.cravings_failed');

      // The same for a query that is refused rather than one that throws.
      warn.mockClear();
      generate.mockClear();
      cravingsRead.mockImplementationOnce(() => ({
        orderBy: () => ({
          limit: () => ({get: () => Promise.reject(new Error('unavailable'))}),
        }),
      }));
      const second = await run(caller({panicIntensity: 8, ui: cards()}));
      expect(second.text).toContain('Fifteen minutes');
      expect(second.ui).toEqual(fixtureUi('panic_default'));
      expect(warn.mock.calls.map(([event]) => event)).toContain('coach.cravings_failed');
    } finally {
      warn.mockRestore();
    }
  });

  it('a craving they did not mark as passed is not in the log', async () => {
    // `panicSession` also accepts `slipped`. The line says "marked as
    // passed", so a slip is never the craving it describes.
    const passed = hoursAgo(30);
    await seedCraving(passed, {exercise: 'breathing'});
    await seedCraving(hoursAgo(1), {outcome: 'slipped', exercise: 'tiles', game: 'tiles'});

    const reply = await run(caller({chip: 'craving', ui: cards()}));

    expect(instruction()).toContain(`latest on ${dayKeyIn(passed, 'UTC')} (`);
    expect(instruction()).toContain(
      'during that one they had open: the breathing exercise',
    );
    expect(instruction()).not.toContain('the Tiles game');
    expect(reply.ui).toEqual({
      v: 1,
      blocks: [
        {t: 'launcher', exercise: 'breathing'},
        {t: 'launcher', exercise: 'orbs'},
        {t: 'launcher', exercise: 'sos'},
      ],
    });
  });

  it('Ember is told what they just did, when the turn says so', async () => {
    await run(caller({ui: cards(), justDid: JUST_DID}));
    expect(instruction()).toContain(JUST_DID_LINE);

    // Nothing sent, nothing said.
    generate.mockClear();
    await run(caller({ui: cards()}));
    expect(instruction()).not.toContain('just before this message');

    // A field this server cannot read costs the line, never the turn.
    for (const justDid of [
      'x',
      7,
      null,
      [],
      {exercise: 'teleport', seconds: 60, completed: true, passed: true},
      {exercise: 'orbs', seconds: '60', completed: true, passed: true},
    ]) {
      generate.mockClear();
      const reply = await run(caller({ui: cards(), justDid}));
      expect(reply.template, JSON.stringify(justDid)).toBe('generic1');
      expect(instruction(), JSON.stringify(justDid)).not.toContain(
        'just before this message',
      );
    }
  });

  it('the last puff is said on any turn that is not a craving, whoever asks', async () => {
    // It comes from the journey, not from the cravings read, so it is not
    // behind the card audience: a free account on an older app gets it too.
    await journeyDoc('alice').set({...JOURNEY, lastPuffAt: '2026-08-10T21:05:00.000'});
    await makeFree();

    await run(caller());
    expect(instruction()).toContain(
      'last puff: 2026-08-10 (Monday), about 21:00 their time',
    );
    expect(cravingsRead).not.toHaveBeenCalled();

    generate.mockClear();
    await run(caller({panicIntensity: 8}));
    expect(instruction()).not.toContain('last puff:');
  });
});

/**
 * `COACH_CONTEXT_LINES`: the six context lines are behind a param that is
 * off unless it says exactly `on`.
 *
 * The coach eval's bar for those lines was missed twice
 * (docs/superpowers/evidence/2026-11-25-coach-cards/eval), and without this
 * switch a deploy would have shipped them on every ordinary turn with a
 * green `verify`. What the param does NOT switch is the cards: which card a
 * reply carries is chosen by code from the craving log, was never what the
 * eval judged, and keeps working with the lines off.
 */
describe('the context lines are off until they are turned on', () => {
  const ALL_FIVE = ['breathing', 'orbs', 'tiles', 'blocks', 'sos'];
  const cards = {v: 1, exercises: ALL_FIVE, craving: false};
  const JUST_DID = {exercise: 'breathing', seconds: 60, completed: true, passed: true};

  // 21:10 UTC on a Thursday. Three earlier days of puffs at nine make 21:00
  // a danger hour, the last puff is at half past eight, and the latest
  // craving (Orbs, re-rated lower) is an hour old: a turn with every one of
  // the six lines to say.
  const NOW = new Date('2026-09-10T21:10:00.000Z');
  const dayAt = (puffs: number): Record<string, unknown> => ({
    puffs, limit: 150, hourBuckets: {'21': puffs}, cravingsSurvived: 1,
    mood: null, moodNote: null, vapeFreeConfirmed: false,
    slipTrigger: null, repairTokenUsed: false,
  });
  const FULL_JOURNEY = {
    ...JOURNEY,
    days: {
      '2026-09-07': dayAt(60),
      '2026-09-08': dayAt(50),
      '2026-09-09': dayAt(40),
    },
    lastPuffAt: '2026-09-10T20:30:00.000',
  };

  /** One line of each kind, as the card writes them for this fixture. */
  const SIX = [
    'craving log (cravings they marked as passed; a list, not a day count or the streak): latest on 2026-09-10 (Thursday), about 20:00 their time',
    'during that one they had open: the Orbs game · their own re-rating afterwards was lower',
    'tools they have opened during a craving, most recent first: the Orbs game, the breathing exercise',
    'right now is one of their danger hours',
    'last puff: 2026-09-10 (Thursday), about 20:00 their time',
    'just before this message, in the app: they used the breathing exercise for about a minute and marked the craving as passed (already counted in "cravings survived" above)',
  ];

  const seed = async (): Promise<void> => {
    await journeyDoc('alice').set(FULL_JOURNEY);
    const craving = (iso: string, over: Record<string, unknown>): Promise<unknown> =>
      userDoc('alice').collection('cravings').add({
        outcome: 'survived', intensity: null, intensityAfter: null,
        game: null, exercise: null, source: null,
        ...over,
        startedAt: Timestamp.fromDate(new Date(iso)),
      });
    await craving('2026-09-10T20:10:00.000Z', {
      intensity: 8, intensityAfter: 4, game: 'orbs', exercise: 'orbs', source: 'panic',
    });
    await craving('2026-09-08T19:00:00.000Z', {exercise: 'breathing', source: 'coach'});
  };

  /** The turn, and the system instruction the coach reply was asked with. */
  const turn = async (): Promise<{reply: Envelope; told: string}> => {
    generate.mockClear();
    const reply = await run(caller({chip: 'craving', ui: cards, justDid: JUST_DID}));
    const told = (generate.mock.calls[0]![0] as {systemInstruction: string})
      .systemInstruction;
    return {reply, told};
  };

  /** What the subscriber's cards are when Orbs is what they used last. */
  const ORBS_LEADS = {
    v: 1,
    blocks: [
      {t: 'launcher', exercise: 'orbs'},
      {t: 'launcher', exercise: 'breathing'},
      {t: 'launcher', exercise: 'sos'},
    ],
  };

  beforeEach(async () => {
    // Only `Date`: faking the timers as well freezes the Firestore SDK.
    vi.useFakeTimers({toFake: ['Date']});
    vi.setSystemTime(NOW);
    await seed();
  });

  it('on: this turn has all six lines to say, and says them', async () => {
    // The control for everything below: the fixture really does produce
    // every line, so "none of them" further down is the switch and not an
    // empty fixture.
    vi.spyOn(COACH_CONTEXT_LINES, 'value').mockReturnValue('on');
    const {reply, told} = await turn();
    for (const line of SIX) expect(told).toContain(line);
    expect(reply.ui).toEqual(ORBS_LEADS);
  });

  it('off, and unset: none of the six lines reaches the prompt, and the cards still come', async () => {
    for (const raw of ['off', '']) {
      vi.spyOn(COACH_CONTEXT_LINES, 'value').mockReturnValue(raw);
      cravingsRead.mockClear();
      const {reply, told} = await turn();

      for (const line of SIX) expect(told, JSON.stringify(raw)).not.toContain(line);
      // Not a reworded or partial version of any of them either.
      for (const start of [
        'craving log (',
        'during that one they had open',
        'tools they have opened during a craving',
        'right now is one of their danger hours',
        'last puff:',
        'just before this message',
      ]) {
        expect(told, `${JSON.stringify(raw)}: ${start}`).not.toContain(start);
      }
      // The cards are code, not prompt: the craving log is still read, once,
      // and what they used last still leads the menu.
      expect(reply.template, JSON.stringify(raw)).toBe('generic1');
      expect(reply.ui, JSON.stringify(raw)).toEqual(ORBS_LEADS);
      expect(cravingsRead, JSON.stringify(raw)).toHaveBeenCalledTimes(1);
    }
  });

  it('anything that is not exactly "on" is off', async () => {
    // The opposite of the repo's kill switches, on purpose: `true` does not
    // turn the lines on, and neither does a typo.
    for (const raw of ['true', 'ON!', 'enabled']) {
      vi.spyOn(COACH_CONTEXT_LINES, 'value').mockReturnValue(raw);
      const {told} = await turn();
      expect(told, raw).not.toContain('craving log (');
      expect(told, raw).not.toContain('last puff:');
    }
    vi.spyOn(COACH_CONTEXT_LINES, 'value').mockReturnValue(' ON ');
    expect((await turn()).told).toContain(SIX[0]);
  });

  it("off is today's card: the instruction is the one built with no extras", async () => {
    const {told} = await turn();

    // Built here the way the handler built it before any of this existed:
    // the journey, the clock and the timezone, and nothing else.
    const card = buildMemoryCard(FULL_JOURNEY, NOW, 'UTC');
    const expected = buildCoachInstruction({
      locale: 'en',
      coachName: null,
      panicIntensity: null,
      cardText: card.text,
      day: card.day,
      todayKey: card.todayKey,
      summary: '',
      memories: [],
    });
    expect(told).toBe(expected);

    // And the control: with the lines on, the same turn's instruction is
    // that one plus exactly the six lines.
    vi.spyOn(COACH_CONTEXT_LINES, 'value').mockReturnValue('on');
    const on = (await turn()).told;
    expect(on).not.toBe(expected);
    expect(on.length - expected.length).toBe(SIX.join('\n').length + 1);
  });

  it('a panic turn says none of them whichever way the param is set', async () => {
    for (const raw of ['on', 'off']) {
      vi.spyOn(COACH_CONTEXT_LINES, 'value').mockReturnValue(raw);
      generate.mockClear();
      const reply = await run(
        caller({panicIntensity: 8, ui: cards, justDid: JUST_DID}),
      );
      const told = (generate.mock.calls[0]![0] as {systemInstruction: string})
        .systemInstruction;
      for (const line of SIX) expect(told, raw).not.toContain(line);
      // The one card is still what they used last.
      expect(reply.ui, raw).toEqual({v: 1, blocks: [{t: 'launcher', exercise: 'orbs'}]});
    }
  });
});

describe('parseFollowUps', () => {
  it('takes at most four, deduplicated', () => {
    expect(
      parseFollowUps(
        '{"followUps":["one","two","THREE","three","four","five"]}',
      ),
    ).toEqual(['one', 'two', 'THREE', 'four']);
  });

  it('drops anything that would not fit a chip', () => {
    // The row is one line of horizontally scrolling pills. The bound is wide
    // enough for five words in German and Portuguese — at the 40 it started
    // at, "Ich kann meine Arbeit nicht verlassen" would have been dropped and
    // the feature would have been English-only in practice.
    const long = 'a'.repeat(57);
    expect(
      parseFollowUps(`{"followUps":["ok","${long}","x",7,null,"  spaced  "]}`),
    ).toEqual(['ok', 'spaced']);
  });

  it('collapses a multi-line suggestion onto one line', () => {
    expect(parseFollowUps('{"followUps":["what\\nnow"]}')).toEqual(['what now']);
  });

  it('survives fences, and yields nothing for anything malformed', () => {
    expect(parseFollowUps('```json\n{"followUps":["ok then"]}\n```')).toEqual([
      'ok then',
    ]);
    for (const junk of ['', 'not json', '[]', '{"followUps":"nope"}', 'null']) {
      expect(parseFollowUps(junk), junk).toEqual([]);
    }
  });
});
