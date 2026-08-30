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

/**
 * Which side of a search the text is on.
 *
 * Retrieval embeddings are ASYMMETRIC: a stored fact ("Their sister marries in
 * March") and the question that should find it ("what am I working toward?")
 * are worded nothing alike, and embedding both as if they were the same kind
 * of text puts them further apart than they deserve. Telling the model which
 * role each plays is what closes that gap, and it is free.
 */
export type EmbeddingTask = 'document' | 'query';

export interface GenerateResult {
  readonly text: string;
  readonly inputTokens: number;
  readonly outputTokens: number;
}

/**
 * One event from a streaming generation.
 *
 * A stream yields prose in pieces and its cost exactly once, at the end, so it
 * cannot be a bare string. It used to be, and the consequence was that the
 * streaming branch logged NO token usage at all — the primary path, once the
 * client actually streams, would have had zero cost telemetry on a product
 * whose stated guardrail is AI spend per user.
 */
export type StreamEvent =
  | {readonly type: 'text'; readonly text: string}
  | {readonly type: 'usage'; readonly inputTokens: number; readonly outputTokens: number};

export interface TextModel {
  generate(request: GenerateRequest): Promise<GenerateResult>;
  generateStream(request: GenerateRequest): AsyncIterable<StreamEvent>;

  /**
   * Embeds [texts] for semantic recall.
   *
   * On the seam rather than beside it so swapping providers stays a
   * one-file change — an embedding is as much a model call as a completion,
   * and a vector store keyed to one provider's geometry is not portable
   * anyway: vectors written by one model are meaningless to another.
   */
  embed(
    texts: readonly string[],
    dimensions: number,
    task: EmbeddingTask,
  ): Promise<number[][]>;

  /**
   * Model ids this key can actually call.
   *
   * Exists so a wrong model id diagnoses itself. `MODEL_PREMIUM` was set to a
   * model that does not exist for a month; the provider answered 404 on every
   * request, the coach returned its warm fallback to every user, and nothing
   * anywhere said which ids WOULD have worked. Called only from a failure
   * path, never on the hot path.
   */
  listModels(): Promise<readonly string[]>;
}

/** Raised when the provider fails or times out; handlers map it to warm copy. */
export class ModelUnavailableError extends Error {
  constructor(cause?: unknown) {
    super('model unavailable');
    this.cause = cause;
  }
}
