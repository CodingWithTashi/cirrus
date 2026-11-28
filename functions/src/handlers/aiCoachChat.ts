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
 *
 * The coach cards are additive the same way, in both directions: a request
 * may carry `ui: {v, exercises, craving}` (what the app can draw) and a reply
 * may carry `ui: {v, blocks}`. A request without the field gets a reply
 * without it. A request may also carry `justDid: {exercise, seconds,
 * completed, passed}`, the exercise they finished just before this message;
 * it becomes one line of the user card and changes nothing in the envelope.
 * That line, and the other context lines of the card, are added only while
 * `COACH_CONTEXT_LINES` is `on`; it ships off (`config.ts` says why).
 */
import {onCall} from 'firebase-functions/v2/https';
import type {CallableRequest, CallableResponse} from 'firebase-functions/v2/https';
import {
  AI_COST_PANIC,
  COACH_CONTEXT_LINES,
  COACH_CONTEXT_TURNS,
  COACH_FOLLOWUPS,
  COACH_MIN_INSTANCES,
  COACH_SUMMARY_EVERY,
  COACH_SUMMARY_MAX_CHARS,
  COACH_UI_AUDIENCE,
  coachContextLines,
  enforceAppCheck,
  GEMINI_API_KEY,
  MAX_OUTPUT_TOKENS,
  MODEL_FREE,
  MODEL_PREMIUM,
  readAllowance,
  REGION,
} from '../config';
import {
  audienceAdmits,
  coachUiAudience,
  nameableExercises,
  parseSuggestedExercises,
  parseUiCapabilities,
  planBlocks,
  uiEnvelope,
  type Block,
} from '../ai/coachUi';
import {
  digestCravings,
  parseJustDid,
  type CravingDoc,
} from '../ai/cravingDigest';
import {geminiModel} from '../ai/gemini';
import {buildMemoryCard} from '../ai/memoryCard';
import {ModelUnavailableError, type TextModel, type Turn} from '../ai/model';
import {
  COACH_SUMMARY_PROMPT,
  MEMORY_EXTRACTION_PROMPT,
  buildCoachInstruction,
  followUpRequest,
} from '../ai/prompts';
import {
  EMBEDDING_DIMENSIONS,
  MEMORY_KINDS,
  recallRelevant,
  remember,
  worthExtracting,
  type MemoryKind,
} from '../lib/memories';
import {
  coachMessages,
  cravingsCol,
  FieldValue,
  journeyDoc,
  Timestamp,
  userDoc,
} from '../lib/firestore';
import {asEnum, requireCaller, requireText} from '../lib/guards';
import {log, safeMeta} from '../lib/logger';
import {
  claimCoachMessage,
  claimPanicMessage,
  refundCoachMessage,
  refundPanicMessage,
  tierFor,
} from '../lib/usage';
import type {ExerciseId} from '../domain/exercises';
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
  /**
   * Three or four things the user might tap to say next, in their own voice.
   *
   * Its own top-level field rather than an entry in `args`, which is typed
   * `Record<string, string | number>` — and it could not ride the stream
   * either: `CallableResponse<string>` carries plain text chunks that the app
   * appends straight into the visible bubble, so anything structured has to
   * arrive with this envelope.
   *
   * Additive and always optional. A client built before the field ignores it
   * and keeps showing its four static chips, which is also what happens when
   * the model returns nothing useful.
   */
  followUps?: string[];
  /**
   * The cards under this reply: exercises one tap away (`ai/coachUi.ts`).
   *
   * Rides this envelope for the reason `followUps` does, and is absent rather
   * than empty when there is nothing to show — so a request that says nothing
   * about cards (an older app), a free account while the audience is
   * `premium`, and a reply that was about no exercise all get the keys they
   * get today and no others. A block is an id and nothing else; the app draws
   * the rest.
   *
   * Unlike `followUps` it is on `capReached` and `connectionLost` too. Those
   * are the two replies where Ember has nothing to say, and an exercise needs
   * neither a message nor the model. What they carry is the craving rules'
   * cards: the card for what a reply was about needs a reply.
   */
  ui?: {v: 1; blocks: readonly Block[]};
}

export const aiCoachChat = onCall(
  {
    region: REGION,
    secrets: [GEMINI_API_KEY],
    enforceAppCheck, // the one setting standing between us and a public Gemini proxy
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
    // What the app says it can draw. Null for an older app and for anything
    // malformed, and null means no cards; it never refuses the turn.
    const caps = parseUiCapabilities(data['ui']);

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
    // Who the cards are for, read once. It also decides whether the craving
    // log is read at all: that is one more Firestore query, made beside the
    // journey read (so it adds no wait of its own) and only for a turn that
    // can show a card — an app that said what it can draw, on a tier the
    // audience admits. Everybody else costs exactly the reads they cost
    // before.
    const audience = coachUiAudience(COACH_UI_AUDIENCE.value());
    const [journeySnap, cravingDocs] = await Promise.all([
      journeyDoc(caller.uid).get(),
      caps !== null && audienceAdmits(audience, tier)
        ? readCravings(caller.uid)
        : Promise.resolve(null),
    ]);
    if (!journeySnap.exists) {
      // No journey yet = not onboarded. Greet rather than burn a model call.
      return {template: 'greeting', args: {}, showWeekCard: false};
    }

    // Null when no read was made or the read failed; never a reason to fail.
    const cravings =
      cravingDocs === null
        ? null
        : digestCravings(cravingDocs, caller.timeZone);

    // The card's context lines (the craving log, the danger hour, the last
    // puff, what they just did) are behind `COACH_CONTEXT_LINES`, which is
    // OFF unless it says exactly `on`: the coach eval's bar for them has not
    // been met, and with no extras the card is, character for character, the
    // one production has always sent. This switches prompt text only. The
    // digest above still chooses the cards below whichever way it is set.
    //
    // With the lines on they go to every turn EXCEPT a panic one, which
    // passes no extras at all. Somebody at 8/10 gets breath and presence in
    // thirty words; their history read back to them is the opposite of that.
    const contextLines = coachContextLines(COACH_CONTEXT_LINES.value());
    const card = buildMemoryCard(
      journeySnap.data(),
      new Date(),
      caller.timeZone,
      !contextLines || panicIntensity !== null
        ? undefined
        : {cravings, justDid: parseJustDid(data['justDid'])},
    );

    // Coach cards, decided by code: no model call is added for them, so
    // they cost nothing and are there on the turns the model is not (the
    // cap, an outage). Planned after the greeting above on purpose — with no
    // journey there is nothing to open — and before the quota, so every
    // refusal below carries the same answer. `tier` is the server's own
    // read; the app's list only ever narrows what may be offered.
    //
    // This first plan is the one that needs no model: the craving rules. A
    // reply that gets written can add to it once, at the end, with the
    // exercises the follow-up call said the reply was about (`suggested`).
    const planInput = {
      audience,
      tier,
      chip,
      panicIntensity,
      caps,
      // What they have opened during a craving, most recent first: the
      // latest one leads the menu, and is the one card mid-craving.
      recentTools: cravings?.tools ?? [],
    };
    const planned = planBlocks({...planInput, suggested: []});
    const ui = uiEnvelope(planned);
    // One line a turn, written where the turn ends, with the cards that
    // actually went out. `advertised` and `named` are what tell the three
    // kinds of "no card" apart in `firebase functions:log`: an app that
    // never said what it can draw, a reply that was about no exercise, and
    // an account the audience does not admit.
    const logUi = (sent: readonly Block[], named: number): void => {
      log.info('coach.ui', safeMeta({
        uid: caller.uid,
        blocks: sent.length,
        craving: panicIntensity !== null || caps?.craving === true,
        advertised: caps !== null,
        named,
      }));
    };

    // Through `readAllowance`, never the param's `.value()` directly: a param
    // that resolves to 0 — no `.env` for the active project, a typo'd key —
    // would answer EVERY user `capReached` before the model is ever called,
    // which is a total coach outage wearing the costume of a policy decision.
    const limit =
      tier === 'free'
        ? readAllowance.freeCoachMessages()
        : readAllowance.premiumCoachMessages();

    // A panic turn spends the PANIC allowance first — docs/04 §7's "5 coach
    // msgs/day + 1 panic session/day". That second allowance was specified,
    // counted (`panicUsage`) and then read by nothing, so every panic turn
    // came out of the ordinary five and somebody at 9/10 intensity who had
    // spent them was told to come back tomorrow. The loop screen had just
    // offered them Ember.
    //
    // Free tier only: a subscriber's 100 is not a wall anyone reaches
    // mid-craving, and metering them twice would only complicate the count
    // they are shown. On exhaustion this falls THROUGH to the ordinary
    // allowance rather than refusing — nobody is turned away while they still
    // have a message left, whichever pot it comes from.
    const panicTurn = panicIntensity !== null && tier === 'free';
    const onPanicAllowance =
      panicTurn &&
      (await claimPanicMessage(
        caller.uid,
        card.todayKey,
        readAllowance.freePanicMessages(),
      ));

    const quota = onPanicAllowance
      ? {allowed: true as const, used: 0, limit}
      : await claimCoachMessage(caller.uid, card.todayKey, limit);
    // Refund whichever pot this turn actually spent from. Refunding a coach
    // message for a panic turn would hand out a message nobody paid for.
    const refundTurn = (): Promise<void> =>
      onPanicAllowance
        ? refundPanicMessage(caller.uid, card.todayKey)
        : refundCoachMessage(caller.uid, card.todayKey);
    if (!quota.allowed) {
      // docs/04 §7 — kind cap copy, and zero model spend.
      logUi(planned, 0);
      return {
        template: 'capReached',
        args: {limit},
        showWeekCard: false,
        messagesLeft: 0,
        tier,
        ...ui,
      };
    }
    // A panic turn left the coach counter alone, so its remaining count comes
    // from the snapshot already in hand rather than from this claim — reporting
    // `limit` would tell someone who has spent four of five that they have five.
    const coachUsedToday = (() => {
      const usage = userSnap.get('aiUsage') as
        | {day?: string; msgCount?: number}
        | undefined;
      return usage?.day === card.todayKey ? (usage.msgCount ?? 0) : 0;
    })();
    const messagesLeft = Math.max(
      0,
      limit - (onPanicAllowance ? coachUsedToday : quota.used),
    );

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
      day: card.day,
      todayKey: card.todayKey,
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
        await refundTurn();
        logUi(planned, 0);
        // Refunded, so the allowance is one higher than the claim left it.
        return {
          template: 'connectionLost',
          args: {},
          showWeekCard: false,
          messagesLeft: messagesLeft + 1,
          tier,
          ...ui,
        };
      }
      throw error;
    }

    reply = reply.trim();
    if (reply.length === 0) {
      await refundTurn();
      logUi(planned, 0);
      return {
        template: 'connectionLost',
        args: {},
        showWeekCard: false,
        messagesLeft: messagesLeft + 1,
        tier,
        ...ui,
      };
    }

    await persistTurns(caller.uid, userText, reply);

    // Learn from the turn and keep the rolling summary fresh — after the
    // reply is built and, on the streaming path, after the user already has
    // it, so neither delays an answer. Both swallow their own failures; a
    // lost memory or a stale summary must never turn a delivered reply into
    // an error.
    //
    // The follow-up suggestions join them here rather than running before the
    // return, because all three are independent of each other and of the
    // reply the user already has. On a turn where extraction runs, the
    // suggestions cost roughly no extra wall-clock at all; on a turn where it
    // does not, they delay the ENVELOPE (never the first token, which left
    // long ago on the streaming path).
    const [, , suggestions] = await Promise.all([
      learnFrom(model, caller.uid, userText, reply, card.todayKey),
      maybeUpdateSummary(model, caller.uid, summary, [
        ...history,
        {role: 'user', text: userText},
        {role: 'model', text: reply},
      ]),
      // Streaming only. On the streaming path the user has had the whole
      // reply for a while and this just decides when the chips appear; on the
      // unary path NOTHING has been delivered yet, so the same call would sit
      // on the critical path of every answer and add a full model round-trip
      // to it — the exact cost the kill switch exists to avoid, paid by
      // everyone. A client that cannot stream gets the static chips.
      //
      // In practice that is ONE path: `FirebaseCoachRepository` re-asks over
      // the plain `call` when a stream ends without a result (the
      // platform-specific stream-error gotcha in CLAUDE.md). So the turns that
      // lose their chips are exactly the turns already recovering from a
      // failed stream — which is where an extra round-trip would hurt most.
      //
      // The same call says which exercise, if any, the reply was about, for
      // a turn where that can become a card (`nameableExercises`). No call
      // of its own, so a plain call names nothing, like it suggests nothing.
      streaming
        ? suggestFollowUps(
            model,
            caller.uid,
            userText,
            reply,
            panicIntensity,
            nameableExercises(planInput),
          )
        : Promise.resolve(NO_SUGGESTIONS),
    ]);
    const {followUps, named} = suggestions;
    // A name is model output and a suggestion: the policy looks it up
    // against the registry, the tier, the audience and the app's own list
    // before it is a card, and the craving rules still come first.
    const blocks =
      named.length === 0
        ? planned
        : planBlocks({...planInput, suggested: named});
    logUi(blocks, named.length);

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
      // Omitted when empty rather than sent as `[]`: the app treats an empty
      // list and an absent field identically (both fall back to the static
      // chips), and not sending it keeps the payload honest about whether
      // anything was actually suggested.
      ...(followUps.length > 0 ? {followUps} : {}),
      // The craving rules' cards on both paths; on a streamed turn, also the
      // exercise the reply was about. `{}` when there are none: the key is
      // absent.
      ...uiEnvelope(blocks),
    };
  },
);

/** What the follow-up call adds to a reply that is already written. */
interface Suggestions {
  /** What the person might tap to say next. */
  readonly followUps: string[];
  /** The exercises the reply was about, as the model named them. */
  readonly named: ExerciseId[];
}

const NO_SUGGESTIONS: Suggestions = {followUps: [], named: []};

/** How far back the craving log is read. Enough to list every tool they use. */
const CRAVING_DOCS = 12;

/**
 * The cravings this person marked as passed, newest first, or null when the
 * read failed. Never throws: the log is context for a reply, and losing it
 * must cost the lines, not the turn somebody is waiting on mid-craving.
 *
 * `panicSession` also accepts a `slipped` outcome. The card calls this list
 * "cravings they marked as passed", so only `survived` documents are read
 * into it — filtered here rather than in the query, which would need a
 * composite index for a field no shipped app writes any other value of.
 */
async function readCravings(uid: string): Promise<CravingDoc[] | null> {
  try {
    const snap = await cravingsCol(uid)
      .orderBy('startedAt', 'desc')
      .limit(CRAVING_DOCS)
      .get();
    const docs: CravingDoc[] = [];
    for (const doc of snap.docs) {
      const d = doc.data();
      const startedAt: unknown = d['startedAt'];
      if (d['outcome'] !== 'survived' || !(startedAt instanceof Timestamp)) {
        continue;
      }
      docs.push({
        startedAt: startedAt.toDate(),
        intensity: numberOrNull(d['intensity']),
        intensityAfter: numberOrNull(d['intensityAfter']),
        exercise: stringOrNull(d['exercise']),
        game: stringOrNull(d['game']),
      });
    }
    return docs;
  } catch (error) {
    log.warn('coach.cravings_failed', safeMeta({uid, error: String(error)}));
    return null;
  }
}

const numberOrNull = (v: unknown): number | null =>
  typeof v === 'number' && Number.isFinite(v) ? v : null;

const stringOrNull = (v: unknown): string | null =>
  typeof v === 'string' ? v : null;

/**
 * Three or four things the user might tap to say next, and, where a card
 * could come of it, which exercises the reply was about ([followUpRequest]).
 * Never throws, never blocks a reply that is already written.
 *
 * Gated four ways, because this is the second thing in the loop that costs
 * money without producing anything the user asked for:
 *
 *   1. `COACH_FOLLOWUPS` turns it off entirely, without a deploy.
 *   2. **Never mid-craving.** The panic rider is breath and presence only —
 *      thirty words, one step at a time — and a menu of four things to say
 *      next is the exact opposite of that. Somebody at 9/10 does not need
 *      options; they need the next breath.
 *   3. It runs on the CHEAP model regardless of tier. Producing four short
 *      strings in fixed JSON is a structured-output task, not a
 *      conversational one, and the premium model buys nothing here.
 *   4. It sees only the last exchange — about 250 input tokens, not the
 *      1.4-2.2K the reply itself needed. The whole card, summary and memory
 *      stack would tell it nothing extra about what comes next in THIS
 *      exchange.
 */
async function suggestFollowUps(
  model: TextModel,
  uid: string,
  userText: string,
  reply: string,
  panicIntensity: number | null,
  nameable: readonly ExerciseId[],
): Promise<Suggestions> {
  // Read as "off only when explicitly off". A deploy-time param resolves to
  // the EMPTY STRING when nothing supplies a value — no `.env` for the active
  // project, a typo'd key, a test harness — and `!== 'true'` would turn the
  // feature off in exactly those cases while looking like a policy decision.
  // Same lesson as `allowance()` in `config.ts`, pointed the same way: the
  // unresolved case has to fail toward the intended default.
  if (COACH_FOLLOWUPS.value().trim().toLowerCase() === 'false') {
    return NO_SUGGESTIONS;
  }
  if (panicIntensity !== null) return NO_SUGGESTIONS;
  const asksForNames = nameable.length > 0;
  try {
    const result = await model.generate(
      followUpRequest({
        model: MODEL_FREE.value(),
        userText,
        reply,
        exercises: nameable,
      }),
    );
    return {
      followUps: parseFollowUps(result.text),
      // Read only when it was asked for: a name volunteered to the plain
      // prompt answers a question nobody put.
      named: asksForNames ? parseSuggestedExercises(result.text) : [],
    };
  } catch (error) {
    log.warn('coach.followups_failed', {uid, error: String(error)});
    return NO_SUGGESTIONS;
  }
}

/**
 * Strips code fences and validates shape. Anything malformed yields [].
 *
 * Same discipline as [parseMemories], and exported for the same reason: this
 * is a boundary where model output becomes something a user can tap, so it is
 * worth pinning against the shapes a model actually emits when it improvises.
 *
 * The length bound is a layout constraint, not a taste one — the chips render
 * in a single-line horizontally scrolling row, and a suggestion much longer
 * than a chip is a sentence wearing one's clothes.
 *
 * It is [MAX_CHIP_CHARS] rather than the 40 it started at because the app
 * ships five languages and the prompt asks for five words: five German or
 * Portuguese words pass 40 routinely ("Ich kann meine Arbeit nicht verlassen"
 * is 37 before any compound), so the tighter bound would have quietly made
 * this an English-only feature. The row scrolls, so a longer chip costs a
 * little swiping; a dropped one costs the whole suggestion. Drops are logged
 * with a reason now, so the ratio is visible rather than inferred.
 */
export function parseFollowUps(raw: string): string[] {
  const cleaned = raw
    .trim()
    .replace(/^```(?:json)?/i, '')
    .replace(/```$/, '')
    .trim();
  let parsed: unknown;
  try {
    parsed = JSON.parse(cleaned);
  } catch {
    log.warn('coach.followups_dropped', {
      reason: 'not json',
      sample: cleaned.slice(0, 120),
    });
    return [];
  }
  if (parsed === null || typeof parsed !== 'object') {
    log.warn('coach.followups_dropped', {
      reason: 'not an object',
      sample: cleaned.slice(0, 120),
    });
    return [];
  }
  const list = (parsed as Record<string, unknown>)['followUps'];
  if (!Array.isArray(list)) {
    log.warn('coach.followups_dropped', {
      reason: 'followUps not an array',
      sample: cleaned.slice(0, 120),
    });
    return [];
  }

  const out: string[] = [];
  const seen = new Set<string>();
  for (const item of list) {
    if (typeof item !== 'string') continue;
    // Collapse newlines too: a chip is one line by construction, and a model
    // that returns a two-line suggestion means the second line to be read.
    const text = item.replace(/\s+/gu, ' ').trim();
    if (text.length < 2 || text.length > MAX_CHIP_CHARS) {
      // Logged, because a silent length filter on a five-language feature is
      // indistinguishable from a model that returned nothing.
      log.warn('coach.followups_dropped', {
        reason: 'length',
        chars: text.length,
      });
      continue;
    }
    const key = text.toLowerCase();
    // Four chips that say the same thing are one chip and three wasted taps.
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(text);
    if (out.length === MAX_FOLLOW_UPS) break;
  }
  return out;
}

/** As many as the chip row can show without the first one scrolling away. */
const MAX_FOLLOW_UPS = 4;

/**
 * The longest a suggestion may be and still read as a chip.
 *
 * Wide enough for five words in German and Portuguese, which is what the
 * prompt asks for — a 40-character bound made the feature English-only in
 * practice.
 */
const MAX_CHIP_CHARS = 56;

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

