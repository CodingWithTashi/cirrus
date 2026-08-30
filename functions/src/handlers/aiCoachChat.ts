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
import {ModelUnavailableError, type TextModel, type Turn} from '../ai/model';
import {
  EMBER_SYSTEM_PROMPT,
  MEMORY_EXTRACTION_PROMPT,
  localeInstruction,
  memorySection,
  panicAddendum,
} from '../ai/prompts';
import {
  EMBEDDING_DIMENSIONS,
  MEMORY_KINDS,
  recallRelevant,
  remember,
  worthExtracting,
  type MemoryKind,
} from '../lib/memories';
import {coachMessages, FieldValue, journeyDoc} from '../lib/firestore';
import {asEnum, requireCaller, requireText} from '../lib/guards';
import {log, safeMeta} from '../lib/logger';
import {claimCoachMessage, refundCoachMessage, tierFor} from '../lib/usage';
import {COACH_CHIPS, type CoachChip, type CoachTemplate, type SubscriptionTier} from '../domain/types';

const MAX_MESSAGE_CHARS = 1000;

interface CoachReplyEnvelope {
  template: CoachTemplate;
  args: Record<string, string | number>;
  showWeekCard: boolean;
  text?: string;
  /**
   * Messages left today, and the tier that number belongs to.
   *
   * The client used to count this itself: an in-memory int, reset on every
   * launch, with no midnight rollover, derived from a `profile.tier` the
   * client wrote into its own journey doc. It could disagree with the server
   * in both directions — greying the composer while the server would happily
   * answer, or promising messages the server would refuse. The only side that
   * knows is the side that enforces it.
   */
  messagesLeft?: number;
  tier?: SubscriptionTier;
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
      return {
        template: 'capReached',
        args: {limit},
        showWeekCard: false,
        messagesLeft: 0,
        tier,
      };
    }
    const messagesLeft = Math.max(0, limit - quota.used);

    const history = await recentTurns(caller.uid);
    const userText = text ?? `[${chip ?? 'craving'}]`;
    const model = geminiModel(GEMINI_API_KEY.value());

    // Long-term recall. One embedding of what they just said, then a vector
    // search over what they have told us before (`lib/memories.ts`).
    //
    // Deliberately best-effort: a null vector means the embedding call failed,
    // and the turn proceeds on the user card alone. A coach without its memory
    // is a worse coach; a coach that refuses to answer is a broken product, and
    // this path runs while someone is mid-craving.
    const queryVector = await embedOrNull(model, userText);
    const memories =
      queryVector === null ? [] : await recallRelevant(caller.uid, queryVector);

    const systemInstruction =
      EMBER_SYSTEM_PROMPT +
      localeInstruction(caller.locale) +
      (panicIntensity !== null ? panicAddendum(panicIntensity) : '') +
      `\n\n${card.text}` +
      memorySection(memories);

    const modelName =
      AI_COST_PANIC.value() === 'true' || tier === 'free'
        ? MODEL_FREE.value()
        : MODEL_PREMIUM.value();

    const turns: Turn[] = [...history, {role: 'user', text: userText}];
    let reply = '';
    // Logged once, from whichever path ran. Cost telemetry that only works on
    // the branch nobody takes is not telemetry.
    let inputTokens = 0;
    let outputTokens = 0;
    const streaming = request.acceptsStreaming && response !== undefined;

    try {
      if (streaming && response) {
        for await (const event of model.generateStream({
          model: modelName,
          systemInstruction,
          turns,
          maxOutputTokens: MAX_OUTPUT_TOKENS,
        })) {
          if (event.type === 'text') {
            reply += event.text;
            await response.sendChunk(event.text);
          } else {
            inputTokens = event.inputTokens;
            outputTokens = event.outputTokens;
          }
        }
      } else {
        const result = await model.generate({
          model: modelName,
          systemInstruction,
          turns,
          maxOutputTokens: MAX_OUTPUT_TOKENS,
        });
        reply = result.text;
        inputTokens = result.inputTokens;
        outputTokens = result.outputTokens;
      }
      log.info('coach.turn', safeMeta({
        uid: caller.uid, tier, model: modelName,
        streaming, inputTokens, outputTokens,
      }));
    } catch (error) {
      if (error instanceof ModelUnavailableError) {
        // Log the CAUSE, not just the fact.
        //
        // This branch used to return silently, which meant a coach that was
        // down for everyone — a wrong model id, an expired key, a quota wall —
        // looked identical in the logs to a coach nobody had used. The
        // end-to-end run found exactly that: every reply came back
        // `connectionLost` and the logs said nothing at all.
        // The SDK's error is usually an Error; anything else is coerced
        // rather than stringified into "[object Object]".
        const cause = error.cause instanceof Error
          ? `${error.cause.name}: ${error.cause.message}`
          : JSON.stringify(error.cause ?? null);
        log.warn('coach.model_unavailable', {
          uid: caller.uid,
          model: modelName,
          cause,
        });
        // A 404 means the configured id does not exist, which is a config
        // mistake rather than an outage — and the one failure where the fix
        // is knowable. Log what this key CAN call so the answer is in the
        // logs instead of requiring a separate investigation. Failure-path
        // only, so it costs nothing while the coach is healthy.
        if (/not found|NOT_FOUND|404/.test(cause)) {
          try {
            log.warn('coach.models_available', {
              configured: modelName,
              available: (await model.listModels()).join(', '),
            });
          } catch (listError) {
            log.warn('coach.models_list_failed', {error: String(listError)});
          }
        }
        // docs/03: the coach fails IN-THREAD, never as a dialog. The client
        // already knows this template. The message was not delivered, so give
        // the quota unit back — nobody pays for our outage.
        await refundCoachMessage(caller.uid, card.todayKey);
        // Refunded, so the allowance is one higher than the claim left it.
        return {
          template: 'connectionLost',
          args: {},
          showWeekCard: false,
          messagesLeft: messagesLeft + 1,
          tier,
        };
      }
      throw error;
    }

    reply = reply.trim();
    if (reply.length === 0) {
      await refundCoachMessage(caller.uid, card.todayKey);
      return {
        template: 'connectionLost',
        args: {},
        showWeekCard: false,
        messagesLeft: messagesLeft + 1,
        tier,
      };
    }

    await persistTurns(caller.uid, userText, reply);

    // Learn from the turn. After the reply is built — and, on the streaming
    // path, after the user already has it — so nothing here delays an answer.
    await learnFrom(model, caller.uid, userText, reply);

    return {
      // `generic1` is the graceful degradation for a client that predates the
      // `text` field — never send a template that contradicts the words.
      template: 'generic1',
      args: {day: card.streak},
      showWeekCard: chip === 'progress',
      text: reply,
      messagesLeft,
      tier,
    };
  },
);

/** Embeds one string, or null when the provider is unhappy. Never throws. */
async function embedOrNull(
  model: TextModel,
  text: string,
): Promise<number[] | null> {
  try {
    // 'query': this is the question side of the search.
    const [vector] = await model.embed([text], EMBEDDING_DIMENSIONS, 'query');
    return vector ?? null;
  } catch (error) {
    log.warn('coach.embed_failed', {error: String(error)});
    return null;
  }
}

/**
 * Extracts anything durable the user just said and files it for later.
 *
 * Gated three ways, because this is the one part of the loop that costs money
 * without producing anything the user sees today:
 *
 *   1. `worthExtracting` skips chips and one-liners outright — no model call
 *      at all for "[craving]" or "ok thanks".
 *   2. It runs on the CHEAP model regardless of tier. Pulling a fact out of two
 *      sentences into fixed JSON is a structured-output task, not a
 *      conversational one, and the premium model buys nothing here.
 *   3. At most two memories per exchange, enforced in `parseMemories` as well
 *      as in the prompt — a prompt is a request, code is a guarantee.
 *
 * Every failure is swallowed. The reply already exists and, when streaming, has
 * already been delivered; losing a memory must never turn a successful turn
 * into an error the user sees.
 */
async function learnFrom(
  model: TextModel,
  uid: string,
  userText: string,
  reply: string,
): Promise<void> {
  if (!worthExtracting(userText)) return;
  try {
    const result = await model.generate({
      model: MODEL_FREE.value(),
      systemInstruction: MEMORY_EXTRACTION_PROMPT,
      turns: [{role: 'user', text: `USER: ${userText}\nCOACH: ${reply}`}],
      maxOutputTokens: 200,
      temperature: 0,
      json: true,
    });
    const facts = parseMemories(result.text);
    if (facts.length === 0) return;

    // 'document': these are the facts being filed, not a search for them.
    const vectors = await model.embed(
      facts.map((f) => f.text),
      EMBEDDING_DIMENSIONS,
      'document',
    );
    for (const [i, fact] of facts.entries()) {
      const vector = vectors[i];
      if (vector !== undefined) await remember(uid, fact.text, fact.kind, vector);
    }
    log.info('coach.remembered', {uid, count: facts.length});
  } catch (error) {
    log.warn('coach.extract_failed', {uid, error: String(error)});
  }
}

/**
 * Strips code fences and validates shape. Anything malformed yields [].
 *
 * Exported for `test/memoryExtraction.test.ts`: this is the boundary where
 * model output becomes stored state, so it is the one place worth pinning
 * against the shapes a model actually emits when it improvises.
 */
export function parseMemories(raw: string): {text: string; kind: MemoryKind}[] {
  const cleaned = raw
    .trim()
    .replace(/^```(?:json)?/i, '')
    .replace(/```$/, '')
    .trim();
  let parsed: unknown;
  try {
    parsed = JSON.parse(cleaned);
  } catch {
    return [];
  }
  if (parsed === null || typeof parsed !== 'object') return [];
  const list = (parsed as Record<string, unknown>)['memories'];
  if (!Array.isArray(list)) return [];

  const out: {text: string; kind: MemoryKind}[] = [];
  for (const item of list.slice(0, 2)) {
    if (item === null || typeof item !== 'object') continue;
    const m = item as Record<string, unknown>;
    const text = typeof m['text'] === 'string' ? m['text'].trim() : '';
    // Too short to be a fact; too long means the model summarized the whole
    // conversation instead of isolating one, and a paragraph-length vector
    // matches everything.
    if (text.length < 8 || text.length > 240) continue;
    const kind = MEMORY_KINDS.find((k) => k === m['kind']) ?? 'context';
    out.push({text, kind});
  }
  return out;
}

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

