/**
 * `TextModel` over the Google GenAI SDK. The ONLY file that imports a vendor
 * SDK — see `model.ts` for why.
 */
import {GoogleGenAI, JobState, ThinkingLevel} from '@google/genai';
import type {GenerateContentResponse} from '@google/genai';
import {ModelUnavailableError} from './model';
import type {
  BatchModel,
  BatchOutcome,
  EmbeddingTask,
  GenerateRequest,
  GenerateResult,
  StreamEvent,
  TextModel,
} from './model';

/** docs/04 §8: 20s then fall back to warm copy rather than hang the thread. */
const TIMEOUT_MS = 20_000;

/**
 * Pinned, and deliberately NOT a param like the chat models.
 *
 * Changing an embedding model invalidates every vector already stored — the
 * geometry is model-specific, so old and new vectors are not comparable and
 * recall silently degrades into nonsense rather than failing. A swap needs a
 * re-embed migration, which is a code change, so it lives in code.
 */
const EMBEDDING_MODEL = 'gemini-embedding-001';

/**
 * Turn thinking OFF wherever the model accepts the knob. Nothing this seam
 * serves needs reasoning — 80-word coach replies, strict-JSON extraction,
 * moderation, insight — and mid-craving, a silent thinking pass before the
 * first streamed token is a product failure.
 *
 * The capability matrix, probed LIVE against the real API (Aug 30 2026),
 * because none of it is in the docs you'd want it in:
 *
 * - gemini-3.5-flash / gemini-3.6-flash: `thinkingLevel: MINIMAL` → zero
 *   thought tokens, full replies. This is why MODEL_PREMIUM pins 3.6-flash.
 * - gemini-3.7-flash: CANNOT stop thinking. `thinkingBudget: 0` is accepted
 *   and ignored, `MINIMAL` is "not supported for this model", the floor is
 *   LOW at a VARIABLE 400-2000 thought tokens — spent INSIDE
 *   `maxOutputTokens`, which cut premium replies off mid-word ("15 to 2")
 *   until the first automated eval run caught it. Unfit for this seam.
 * - gemini-3.5-flash-lite: rejects `thinkingConfig` outright
 *   (INVALID_ARGUMENT on every call) — the lite tier does not think and
 *   will not take the knob, hence the gate below.
 *
 * A wrong pairing for a future id is loud — `npm run eval:coach` 400s or
 * truncates immediately — one more reason `.env.alastpuff` says to re-run
 * the evals whenever a MODEL_* id moves.
 */
const wantsThinkingToggle = (model: string): boolean => !model.includes('-lite');

// Module-level so the batch door below sends a request configured exactly
// as the live one is. An eval that graded replies made under different
// settings would be grading a different product.
const buildConfig = (request: GenerateRequest) => ({
  systemInstruction: request.systemInstruction,
  maxOutputTokens: request.maxOutputTokens,
  temperature: request.temperature ?? 0.8,
  ...(wantsThinkingToggle(request.model)
    ? {thinkingConfig: {thinkingLevel: ThinkingLevel.MINIMAL}}
    : {}),
  ...(request.json ? {responseMimeType: 'application/json'} : {}),
});

const buildContents = (request: GenerateRequest) =>
  request.turns.map((turn) => ({
    role: turn.role,
    parts: [{text: turn.text}],
  }));

/**
 * The reply's own words.
 *
 * A live response is a class instance whose `text` getter joins the first
 * candidate's text parts. A row of a batch job is the SAME data as a plain
 * object, with no getter: `response.text` is simply undefined there. The
 * first real batch job (Nov 27 2026) came back with its token counts intact
 * and every reply empty for exactly that reason. So when the getter has
 * nothing, read the parts the way it would have: first candidate, text
 * parts only, thinking left out.
 */
const textOf = (response: GenerateContentResponse): string => {
  if (typeof response.text === 'string') return response.text;
  let text = '';
  for (const part of response.candidates?.[0]?.content?.parts ?? []) {
    if (typeof part.text === 'string' && part.thought !== true) text += part.text;
  }
  return text;
};

export const toResult = (response: GenerateContentResponse): GenerateResult => {
  const usage = response.usageMetadata;
  return {
    text: textOf(response),
    inputTokens: usage?.promptTokenCount ?? 0,
    outputTokens: usage?.candidatesTokenCount ?? 0,
    thoughtTokens: usage?.thoughtsTokenCount ?? 0,
  };
};

export function geminiModel(apiKey: string): TextModel {
  const ai = new GoogleGenAI({apiKey});

  return {
    async embed(
      texts: readonly string[],
      dimensions: number,
      task: EmbeddingTask,
    ): Promise<number[][]> {
      if (texts.length === 0) return [];
      try {
        const response = await withTimeout(
          ai.models.embedContent({
            model: EMBEDDING_MODEL,
            contents: texts.map((text) => ({parts: [{text}]})),
            config: {
              outputDimensionality: dimensions,
              taskType:
                task === 'query' ? 'RETRIEVAL_QUERY' : 'RETRIEVAL_DOCUMENT',
            },
          }),
        );
        const vectors = response.embeddings ?? [];
        if (vectors.length !== texts.length) {
          throw new ModelUnavailableError(
            `embedded ${vectors.length} of ${texts.length}`,
          );
        }
        return vectors.map((v) => v.values ?? []);
      } catch (error) {
        if (error instanceof ModelUnavailableError) throw error;
        throw new ModelUnavailableError(error);
      }
    },

    async listModels(): Promise<readonly string[]> {
      const names: string[] = [];
      for await (const model of await ai.models.list()) {
        // The API returns `models/gemini-2.5-flash`; config uses the bare id.
        if (model.name) names.push(model.name.replace(/^models\//, ''));
      }
      return names;
    },

    async generate(request: GenerateRequest): Promise<GenerateResult> {
      try {
        const response = await withTimeout(
          ai.models.generateContent({
            model: request.model,
            contents: buildContents(request),
            config: buildConfig(request),
          }),
        );
        return toResult(response);
      } catch (error) {
        throw new ModelUnavailableError(error);
      }
    },

    async *generateStream(request: GenerateRequest): AsyncIterable<StreamEvent> {
      let stream;
      try {
        stream = await withTimeout(
          ai.models.generateContentStream({
            model: request.model,
            contents: buildContents(request),
            config: buildConfig(request),
          }),
        );
      } catch (error) {
        throw new ModelUnavailableError(error);
      }

      // Mid-stream failures are wrapped like every other provider failure.
      // Left raw, they escaped the handler's `instanceof ModelUnavailableError`
      // check and surfaced as an unhandled `internal` — so a connection that
      // dropped halfway through a sentence became a red error instead of
      // Ember's warm fallback, and burned the user's message with it.
      let usage: {inputTokens: number; outputTokens: number} | null = null;
      try {
        for await (const chunk of stream) {
          const text = chunk.text;
          if (text) yield {type: 'text', text};
          // Usage arrives on the final chunks; keep the last one we see.
          const meta = chunk.usageMetadata;
          if (meta) {
            usage = {
              inputTokens: meta.promptTokenCount ?? 0,
              outputTokens: meta.candidatesTokenCount ?? 0,
            };
          }
        }
      } catch (error) {
        throw new ModelUnavailableError(error);
      }
      if (usage) yield {type: 'usage', ...usage};
    },
  };
}

/**
 * `BatchModel` over the Gemini batch API, with the requests sent inline.
 *
 * For the eval tools only (see `model.ts`). Half the standard price, and a
 * job is one model: the caller groups its requests before it gets here.
 */
export function geminiBatch(apiKey: string): BatchModel {
  const ai = new GoogleGenAI({apiKey});

  return {
    async submit(requests: readonly GenerateRequest[], label: string): Promise<string> {
      const model = requests[0]?.model;
      if (model === undefined || requests.some((r) => r.model !== model)) {
        throw new Error('a batch job is one model: group the requests first');
      }
      try {
        const job = await ai.batches.create({
          model,
          src: requests.map((request) => ({
            contents: buildContents(request),
            config: buildConfig(request),
          })),
          config: {displayName: label},
        });
        if (!job.name) throw new Error('the batch job came back without a name');
        return job.name;
      } catch (error) {
        throw new ModelUnavailableError(error);
      }
    },

    async collect(name: string): Promise<readonly BatchOutcome[] | null> {
      let job;
      try {
        job = await ai.batches.get({name});
      } catch (error) {
        throw new ModelUnavailableError(error);
      }
      switch (job.state) {
        case JobState.JOB_STATE_SUCCEEDED:
        case JobState.JOB_STATE_PARTIALLY_SUCCEEDED:
          return (job.dest?.inlinedResponses ?? []).map((item): BatchOutcome =>
            item.response !== undefined
              ? {ok: true, result: toResult(item.response)}
              : {ok: false, error: JSON.stringify(item.error ?? 'no response')},
          );
        case JobState.JOB_STATE_FAILED:
        case JobState.JOB_STATE_CANCELLED:
        case JobState.JOB_STATE_EXPIRED:
          throw new ModelUnavailableError(
            `batch job ${name} ended ${job.state}: ${JSON.stringify(job.error ?? null)}`,
          );
        default:
          return null;
      }
    },
  };
}

function withTimeout<T>(promise: Promise<T>): Promise<T> {
  return Promise.race([
    promise,
    new Promise<never>((_, reject) =>
      setTimeout(() => reject(new ModelUnavailableError('timeout')), TIMEOUT_MS),
    ),
  ]);
}
