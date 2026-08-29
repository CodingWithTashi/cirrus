/**
 * Provider-agnostic model seam.
 *
 * docs/05 §1 locks "Gemini via Genkit" and wants the model swappable without
 * an app update. This interface is that seam: handlers depend on it, and the
 * only file that knows a vendor SDK is `gemini.ts`. Dropping in Genkit (or
 * Claude, or GPT) means writing one more implementation of `TextModel` — no
 * handler changes, no client release.
 */

export interface Turn {
  readonly role: 'user' | 'model';
  readonly text: string;
}

export interface GenerateRequest {
  readonly model: string;
  readonly systemInstruction: string;
  readonly turns: readonly Turn[];
  readonly maxOutputTokens: number;
  /** Ember is warm, not random; moderation and JSON flows want 0. */
  readonly temperature?: number;
  /** Ask the provider for `application/json` where it supports it. */
  readonly json?: boolean;
}

export interface GenerateResult {
  readonly text: string;
  readonly inputTokens: number;
  readonly outputTokens: number;
}

export interface TextModel {
  generate(request: GenerateRequest): Promise<GenerateResult>;
  generateStream(request: GenerateRequest): AsyncIterable<string>;
}

/** Raised when the provider fails or times out; handlers map it to warm copy. */
export class ModelUnavailableError extends Error {
  constructor(cause?: unknown) {
    super('model unavailable');
    this.cause = cause;
  }
}
