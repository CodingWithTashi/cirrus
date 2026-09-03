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
  COACH_SUMMARY_EVERY,
  COACH_SUMMARY_MAX_CHARS,
  GEMINI_API_KEY,
  MAX_OUTPUT_TOKENS,
  MODEL_FREE,
  MODEL_PREMIUM,
  readAllowance,
  REGION,
} from '../config';
import {geminiModel} from '../ai/gemini';
import {buildMemoryCard} from '../ai/memoryCard';
import {ModelUnavailableError, type TextModel, type Turn} from '../ai/model';
import {
  COACH_SUMMARY_PROMPT,
  MEMORY_EXTRACTION_PROMPT,
  buildCoachInstruction,
} from '../ai/prompts';
import {
  EMBEDDING_DIMENSIONS,
  MEMORY_KINDS,
  recallRelevant,
  remember,
  worthExtracting,
  type MemoryKind,
} from '../lib/memories';
import {coachMessages, FieldValue, journeyDoc, userDoc} from '../lib/firestore';
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
    // The server-owned copy, written only by the validated `setCoachName`.
    // The journey has one too, but that document is client-written, so the
    // name from it is untrusted text and must never reach the prompt.
    const userSnap = await userDoc(caller.uid).get();
    const storedName: unknown = userSnap.get('coachName');
    const coachName =
      typeof storedName === 'string' && storedName.trim().length > 0
        ? storedName.trim()
        : null;
    // The rolling summary rides the read we already paid for. It lives on
    // `users/{uid}` and NOT in `coachMessages`, because the app renders every
    // non-user doc of that collection as a visible chat bubble.
    const summary = parseCoachSummary(userSnap.get('coachSummary'));
    const journeySnap = await journeyDoc(caller.uid).get();
    if (!journeySnap.exists) {
      // No journey yet = not onboarded. Greet rather than burn a model call.
      return {template: 'greeting', args: {}, showWeekCard: false};
    }

    const card = buildMemoryCard(journeySnap.data(), new Date(), caller.timeZone);

    // Through `readAllowance`, never the param's `.value()` directly: a param
    // that resolves to 0 — no `.env` for the active project, a typo'd key —
    // would answer EVERY user `capReached` before the model is ever called,
    // which is a total coach outage wearing the costume of a policy decision.
    const limit =
      tier === 'free'
        ? readAllowance.freeCoachMessages()
        : readAllowance.premiumCoachMessages();
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

    // Assembled by the ONE shared function the eval harness also calls, so
    // what the evals grade can never drift from what production sends. The
    // coach name comes from the SERVER-owned document, never from the journey:
    // that one is client-written, so a name taken from it would be unvalidated
    // text going straight into a system prompt.
    const systemInstruction = buildCoachInstruction({
      locale: caller.locale,
      coachName,
      panicIntensity,
      cardText: card.text,
      summary: summary.text,
      memories,
    });

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

    // Learn from the turn and keep the rolling summary fresh — after the
    // reply is built and, on the streaming path, after the user already has
    // it, so neither delays an answer. Both swallow their own failures; a
    // lost memory or a stale summary must never turn a delivered reply into
    // an error.
    await Promise.all([
      learnFrom(model, caller.uid, userText, reply, card.todayKey),
      maybeUpdateSummary(model, caller.uid, summary, [
        ...history,
        {role: 'user', text: userText},
        {role: 'model', text: reply},
      ]),
    ]);

    return {
      // `generic1` is the graceful degradation for a client that predates the
      // `text` field — never send a template that contradicts the words.
      template: 'generic1',
      // The plan day, not the streak: a fallback client renders this as
      // "you're on day {day}", and it must match the Home header.
      args: {day: card.day},
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
  todayKey: string,
): Promise<void> {
  if (!worthExtracting(userText)) return;
  try {
    const result = await model.generate({
      model: MODEL_FREE.value(),
      systemInstruction: MEMORY_EXTRACTION_PROMPT,
      // The DATE line lets the extractor anchor "next Friday" to an absolute
      // date — a relative phrase stored as-is means nothing months later.
      turns: [
        {role: 'user', text: `DATE: ${todayKey}\nUSER: ${userText}\nCOACH: ${reply}`},
      ],
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
    // A malformed answer must be distinguishable in the logs from an honest
    // `{"memories":[]}` — without this, "extraction is broken" and "nothing
    // durable was said" produce identical silence.
    log.warn('coach.extract_dropped', {reason: 'not json', sample: cleaned.slice(0, 120)});
    return [];
  }
  if (parsed === null || typeof parsed !== 'object') {
    log.warn('coach.extract_dropped', {reason: 'not an object', sample: cleaned.slice(0, 120)});
    return [];
  }
  const list = (parsed as Record<string, unknown>)['memories'];
  if (!Array.isArray(list)) {
    log.warn('coach.extract_dropped', {reason: 'memories not an array', sample: cleaned.slice(0, 120)});
    return [];
  }

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

/** What `users/{uid}.coachSummary` decodes to. */
export interface CoachSummary {
  text: string;
  /** Successful exchanges since the summary was last rebuilt. */
  turnsSince: number;
}

/**
 * Shape-guards the stored rolling summary. Anything missing or malformed
 * reads as "no summary yet" — the coach degrades to the verbatim window, it
 * never fails a turn over its own bookkeeping.
 */
export function parseCoachSummary(raw: unknown): CoachSummary {
  if (raw === null || typeof raw !== 'object') return {text: '', turnsSince: 0};
  const m = raw as Record<string, unknown>;
  const turns = m['turnsSince'];
  return {
    text: typeof m['text'] === 'string' ? m['text'] : '',
    turnsSince:
      typeof turns === 'number' && Number.isFinite(turns)
        ? Math.max(0, Math.floor(turns))
        : 0,
  };
}

/**
 * Keeps the rolling summary current: counts successful exchanges, and every
 * `COACH_SUMMARY_EVERY`th folds the previous summary plus the recent turns
 * into a replacement (`COACH_SUMMARY_PROMPT`, cheap model — distilling a few
 * turns is a structured task the premium model buys nothing on).
 *
 * The cadence is what makes this cover the long range: a rebuild sees the
 * last `COACH_CONTEXT_TURNS` (10) message docs plus the current exchange,
 * and rebuilds land every 4 exchanges (8 docs), so no message can scroll out
 * of the verbatim window before a summary has folded it in.
 *
 * Failure discipline mirrors [learnFrom]: everything is swallowed, and on a
 * failed or empty rebuild the counter deliberately does NOT move — it sits at
 * the threshold so the next successful turn retries the rebuild.
 */
async function maybeUpdateSummary(
  model: TextModel,
  uid: string,
  previous: CoachSummary,
  turns: readonly Turn[],
): Promise<void> {
  try {
    if (previous.turnsSince < COACH_SUMMARY_EVERY - 1) {
      // Not due yet — just count the exchange. `set` + merge deep-merges, so
      // `text`/`updatedAt` are untouched, and increment-on-missing starts a
      // brand-new user at 1.
      await userDoc(uid).set(
        {coachSummary: {turnsSince: FieldValue.increment(1)}},
        {merge: true},
      );
      return;
    }

    const transcript = turns
      .map((t) => `${t.role === 'user' ? 'USER' : 'COACH'}: ${t.text}`)
      .join('\n');
    const result = await model.generate({
      model: MODEL_FREE.value(),
      systemInstruction: COACH_SUMMARY_PROMPT,
      turns: [
        {
          role: 'user',
          text:
            `PREVIOUS SUMMARY:\n${previous.text || '(none)'}\n\n` +
            `MOST RECENT TURNS:\n${transcript}`,
        },
      ],
      maxOutputTokens: 300,
      temperature: 0.2,
    });
    const text = result.text.trim().slice(0, COACH_SUMMARY_MAX_CHARS);
    if (text.length === 0) return;

    await userDoc(uid).set(
      {
        coachSummary: {
          text,
          turnsSince: 0,
          updatedAt: FieldValue.serverTimestamp(),
        },
      },
      {merge: true},
    );
    log.info('coach.summarized', {uid, chars: text.length});
  } catch (error) {
    log.warn('coach.summary_failed', {uid, error: String(error)});
  }
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

