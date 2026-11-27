/**
 * Reading a provider response into a `GenerateResult`.
 *
 * Nov 27 2026: the first real batch job came back with its token counts and
 * with EMPTY replies. A live response is a class instance with a `text`
 * getter; a row of a batch job is the same data as a plain object, with no
 * getter at all. Every reply was graded as blank, at full price. The reader
 * has to work on both shapes.
 */
import {GenerateContentResponse} from '@google/genai';
import {describe, expect, it} from 'vitest';
import {toResult} from '../src/ai/gemini';

const usage = {promptTokenCount: 1918, candidatesTokenCount: 22, thoughtsTokenCount: 0};

describe('toResult', () => {
  it('reads a batch row, which is a plain object with no text getter', () => {
    const row = {
      candidates: [{content: {role: 'model', parts: [{text: 'In for four.'}, {text: ' Hold.'}]}}],
      usageMetadata: usage,
    } as unknown as GenerateContentResponse;
    expect(toResult(row)).toEqual({
      text: 'In for four. Hold.',
      inputTokens: 1918,
      outputTokens: 22,
      thoughtTokens: 0,
    });
  });

  it('leaves the thinking out of a batch row, as the live reader does', () => {
    const row = {
      candidates: [
        {content: {parts: [{text: 'They sound panicked.', thought: true}, {text: 'Still with me?'}]}},
      ],
      usageMetadata: {...usage, thoughtsTokenCount: 6},
    } as unknown as GenerateContentResponse;
    expect(toResult(row)).toMatchObject({text: 'Still with me?', thoughtTokens: 6});
  });

  it('reads a live response exactly as before', () => {
    const live = new GenerateContentResponse();
    live.candidates = [{content: {role: 'model', parts: [{text: 'You are on day 32.'}]}}];
    live.usageMetadata = usage;
    expect(toResult(live)).toEqual({
      text: 'You are on day 32.',
      inputTokens: 1918,
      outputTokens: 22,
      thoughtTokens: 0,
    });
  });

  it('is an empty reply when nothing came back, never a crash', () => {
    expect(toResult({} as unknown as GenerateContentResponse)).toEqual({
      text: '',
      inputTokens: 0,
      outputTokens: 0,
      thoughtTokens: 0,
    });
  });
});
