/**
 * `aiCoachChat` — Ember's turn (docs/04, docs/05 §7).
 *
 * Order of operations is deliberate: auth → App Check → trusted tier → quota
 * claim → model. Everything that can reject a request happens BEFORE the only
 * step that costs money, so an abusive client is cheap to say no to.
 *
 * Wire contract matches `lib/data/dto/coach_codec.dart`:
 *   { template: string, args: {...}, showWeekCard: bool, text?: string }
 * `text` is the AI's actual words and is additive — a client built before the
 * field existed ignores it and renders `template`, so this deploys safely
 * ahead of the app release. ALWAYS send a sensible `template` alongside
 * `text` for exactly that reason.
 */
import {onCall} from 'firebase-functions/v2/https';
import type {CallableRequest, CallableResponse} from 'firebase-functions/v2/https';
import {
  AI_COST_PANIC,
  COACH_CONTEXT_TURNS,
  COACH_MIN_INSTANCES,
  FREE_DAILY_COACH_MESSAGES,
  GEMINI_API_KEY,
  MAX_OUTPUT_TOKENS,
  MODEL_FREE,
  MODEL_PREMIUM,
  PREMIUM_DAILY_COACH_MESSAGES,
  REGION,
} from '../config';
import {geminiModel} from '../ai/gemini';
import {buildMemoryCard} from '../ai/memoryCard';
import {ModelUnavailableError, type Turn} from '../ai/model';
import {
  EMBER_SYSTEM_PROMPT,
  localeInstruction,
  panicAddendum,
} from '../ai/prompts';
import {coachMessages, db, FieldValue, journeyDoc, userDoc} from '../lib/firestore';
import {asEnum, requireCaller, requireText} from '../lib/guards';
import {log, safeMeta} from '../lib/logger';
import {claimCoachMessage, tierFor} from '../lib/usage';
import {COACH_CHIPS, type CoachChip, type CoachTemplate} from '../domain/types';

const MAX_MESSAGE_CHARS = 1000;

interface CoachReplyEnvelope {
  template: CoachTemplate;
  args: Record<string, string | number>;
  showWeekCard: boolean;
  text?: string;
}

export const aiCoachChat = onCall(
  {
    region: REGION,
    secrets: [GEMINI_API_KEY],
    enforceAppCheck: true, // the one setting standing between us and a public Gemini proxy
    minInstances: COACH_MIN_INSTANCES,
    memory: '512MiB',
    timeoutSeconds: 60,
    cors: false, // callable from the app only; no browser origin is legitimate
  },
  async (
    request: CallableRequest<unknown>,
    response?: CallableResponse<string>,
  ): Promise<CoachReplyEnvelope> => {
    const caller = requireCaller(request);
    const data = (request.data ?? {}) as Record<string, unknown>;

    const chip = asEnum<CoachChip>(data['chip'], COACH_CHIPS);
    const text = chip === null ? requireText(data['text'], 'text', MAX_MESSAGE_CHARS) : null;
    const panicIntensity =
      typeof data['panicIntensity'] === 'number' ? data['panicIntensity'] : null;

    const tier = await tierFor(caller.uid);
    const journeySnap = await journeyDoc(caller.uid).get();
    if (!journeySnap.exists) {
      // No journey yet = not onboarded. Greet rather than burn a model call.
      return {template: 'greeting', args: {}, showWeekCard: false};
    }

    const card = buildMemoryCard(journeySnap.data(), new Date(), caller.timeZone);

    const limit =
      tier === 'free'
        ? FREE_DAILY_COACH_MESSAGES.value()
        : PREMIUM_DAILY_COACH_MESSAGES.value();
    const quota = await claimCoachMessage(caller.uid, card.todayKey, limit);
    if (!quota.allowed) {
      // docs/04 §7 — kind cap copy, and zero model spend.
      return {template: 'capReached', args: {limit}, showWeekCard: false};
    }

    const history = await recentTurns(caller.uid);
    const userText = text ?? `[${chip ?? 'craving'}]`;
    const systemInstruction =
      EMBER_SYSTEM_PROMPT +
      localeInstruction(caller.locale) +
      (panicIntensity !== null ? panicAddendum(panicIntensity) : '') +
      `\n\n${card.text}`;

    const model = geminiModel(GEMINI_API_KEY.value());
    const modelName =
      AI_COST_PANIC.value() === 'true' || tier === 'free'
        ? MODEL_FREE.value()
        : MODEL_PREMIUM.value();

    const turns: Turn[] = [...history, {role: 'user', text: userText}];
    let reply = '';

    try {
      if (request.acceptsStreaming && response) {
        for await (const chunk of model.generateStream({
          model: modelName,
          systemInstruction,
          turns,
          maxOutputTokens: MAX_OUTPUT_TOKENS,
        })) {
          reply += chunk;
          await response.sendChunk(chunk);
        }
      } else {
        const result = await model.generate({
          model: modelName,
          systemInstruction,
          turns,
          maxOutputTokens: MAX_OUTPUT_TOKENS,
        });
        reply = result.text;
        log.info('coach.turn', safeMeta({
          uid: caller.uid, tier, model: modelName,
          inputTokens: result.inputTokens, outputTokens: result.outputTokens,
        }));
      }
    } catch (error) {
      if (error instanceof ModelUnavailableError) {
        // docs/03: the coach fails IN-THREAD, never as a dialog. The client
        // already knows this template. The message was not delivered, so give
        // the quota unit back — nobody pays for our outage.
        await refundCoachMessage(caller.uid, card.todayKey);
        return {template: 'connectionLost', args: {}, showWeekCard: false};
      }
      throw error;
    }

    reply = reply.trim();
    if (reply.length === 0) {
      await refundCoachMessage(caller.uid, card.todayKey);
      return {template: 'connectionLost', args: {}, showWeekCard: false};
    }

    await persistTurns(caller.uid, userText, reply);

    return {
      // `generic1` is the graceful degradation for a client that predates the
      // `text` field — never send a template that contradicts the words.
      template: 'generic1',
      args: {day: card.streak},
      showWeekCard: chip === 'progress',
      text: reply,
    };
  },
);

/** Last N turns, oldest → newest. Never the full history (docs/05 §8). */
async function recentTurns(uid: string): Promise<Turn[]> {
  const snap = await coachMessages(uid)
    .orderBy('ts', 'desc')
    .limit(COACH_CONTEXT_TURNS)
    .get();
  return snap.docs
    .reverse()
    .map((doc) => {
      const d = doc.data();
      const role: 'user' | 'model' = d['role'] === 'user' ? 'user' : 'model';
      return {role, text: typeof d['text'] === 'string' ? d['text'] : ''};
    })
    .filter((turn) => turn.text.length > 0);
}

/** Both turns are server-written so the transcript can't be forged (docs/05 §6). */
async function persistTurns(uid: string, userText: string, reply: string): Promise<void> {
  const col = coachMessages(uid);
  const batch = col.firestore.batch();
  batch.set(col.doc(), {role: 'user', text: userText, ts: FieldValue.serverTimestamp()});
  batch.set(col.doc(), {role: 'model', text: reply, ts: FieldValue.serverTimestamp()});
  await batch.commit();
}

/** Mirrors the coach's "refund the free message on failure" rule (CLAUDE.md). */
async function refundCoachMessage(uid: string, today: string): Promise<void> {
  await db.runTransaction(async (tx) => {
    const ref = userDoc(uid);
    const snap = await tx.get(ref);
    const usage = (snap.data() as {aiUsage?: {day: string; msgCount: number}} | undefined)
      ?.aiUsage;
    if (usage?.day !== today || usage.msgCount <= 0) return;
    tx.set(ref, {aiUsage: {...usage, msgCount: usage.msgCount - 1}}, {merge: true});
  });
}
