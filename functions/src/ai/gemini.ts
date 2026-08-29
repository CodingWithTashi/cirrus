/**
 * `TextModel` over the Google GenAI SDK. The ONLY file that imports a vendor
 * SDK — see `model.ts` for why.
 */
import {GoogleGenAI} from '@google/genai';
import {ModelUnavailableError} from './model';
import type {
  EmbeddingTask,
  GenerateRequest,
  GenerateResult,
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

export function geminiModel(apiKey: string): TextModel {
  const ai = new GoogleGenAI({apiKey});

  const buildConfig = (request: GenerateRequest) => ({
    systemInstruction: request.systemInstruction,
    maxOutputTokens: request.maxOutputTokens,
    temperature: request.temperature ?? 0.8,
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

    async *generateStream(request: GenerateRequest): AsyncIterable<string> {
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
      // Errors mid-stream surface to the handler, which has already sent a
      // typing indicator — it swaps in the fallback line.
      for await (const chunk of stream) {
        const text = chunk.text;
        if (text) yield text;
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
