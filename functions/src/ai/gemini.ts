/**
 * `TextModel` over the Google GenAI SDK. The ONLY file that imports a vendor
 * SDK — see `model.ts` for why.
 */
import {GoogleGenAI} from '@google/genai';
import {ModelUnavailableError} from './model';
import type {GenerateRequest, GenerateResult, TextModel} from './model';

/** docs/04 §8: 20s then fall back to warm copy rather than hang the thread. */
const TIMEOUT_MS = 20_000;

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
