/**
 * `TextModel` over the Google GenAI SDK. The ONLY file that imports a vendor
 * SDK — see `model.ts` for why.
 */
import {GoogleGenAI, ThinkingLevel} from '@google/genai';
import {ModelUnavailableError} from './model';
import type {
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

export function geminiModel(apiKey: string): TextModel {
  const ai = new GoogleGenAI({apiKey});

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
        const usage = response.usageMetadata;
        return {
          text: response.text ?? '',
          inputTokens: usage?.promptTokenCount ?? 0,
          outputTokens: usage?.candidatesTokenCount ?? 0,
        };
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

function withTimeout<T>(promise: Promise<T>): Promise<T> {
  return Promise.race([
    promise,
    new Promise<never>((_, reject) =>
      setTimeout(() => reject(new ModelUnavailableError('timeout')), TIMEOUT_MS),
    ),
  ]);
}
