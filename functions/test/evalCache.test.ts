/**
 * The eval's answer cache: the same request, asked for the same roll, is
 * never bought twice. It is what makes the unchanged side of an old-versus-new
 * comparison free the second time, and it must never hand back an answer to
 * a different question.
 */
import {mkdtempSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {describe, expect, it} from 'vitest';
import type {GenerateRequest} from '../src/ai/model';
import {EvalCache} from '../tools/evalCache';

function cacheDir(): string {
  return mkdtempSync(join(tmpdir(), 'eval-cache-'));
}

const request: GenerateRequest = {
  model: 'gemini-3.5-flash-lite',
  systemInstruction: 'You are Ember.',
  turns: [{role: 'user', text: 'craving so bad rn'}],
  maxOutputTokens: 500,
};
const answer = {text: 'Breathe with me.', inputTokens: 1800, outputTokens: 12};
const at = (iso: string) => () => new Date(iso);

describe('the eval cache', () => {
  it('misses, then hits once the answer is stored', () => {
    const cache = new EvalCache(cacheDir());
    const key = cache.key(request, 1);
    expect(cache.get(key)).toBeNull();
    cache.put(key, answer);
    expect(cache.get(key)).toEqual(answer);
  });

  it('is shared by every working copy that points at the same folder', () => {
    const dir = cacheDir();
    const a = new EvalCache(dir);
    a.put(a.key(request, 1), answer);
    const b = new EvalCache(dir);
    expect(b.get(b.key(request, 1))).toEqual(answer);
  });

  it('keeps each roll of a sampled call apart', () => {
    const cache = new EvalCache(cacheDir());
    expect(cache.key(request, 1)).not.toBe(cache.key(request, 2));
    expect(cache.key(request, 1)).toBe(cache.key({...request}, 1));
  });

  it('gives one answer to a call that is not sampled', () => {
    const cache = new EvalCache(cacheDir());
    expect(cache.key(request, null)).toBe(cache.key(request, null));
    expect(cache.key(request, null)).not.toBe(cache.key(request, 1));
  });

  it('treats any change to the request as a different question', () => {
    const cache = new EvalCache(cacheDir());
    const base = cache.key(request, 1);
    expect(cache.key({...request, systemInstruction: 'You are Ember!'}, 1)).not.toBe(base);
    expect(cache.key({...request, model: 'gemini-3.6-flash'}, 1)).not.toBe(base);
    expect(cache.key({...request, maxOutputTokens: 200}, 1)).not.toBe(base);
    expect(cache.key({...request, temperature: 0}, 1)).not.toBe(base);
    expect(cache.key({...request, json: true}, 1)).not.toBe(base);
    expect(
      cache.key({...request, turns: [{role: 'user', text: 'craving so bad rn!'}]}, 1),
    ).not.toBe(base);
  });

  it('never hits when it is switched off, and stores nothing', () => {
    const cache = new EvalCache(null);
    const key = cache.key(request, 1);
    cache.put(key, answer);
    expect(cache.get(key)).toBeNull();
  });

  it('forgets an answer older than thirty days, so a model that drifted is asked again', () => {
    const dir = cacheDir();
    const then = new EvalCache(dir, at('2026-11-01T00:00:00Z'));
    const key = then.key(request, 1);
    then.put(key, answer);
    expect(new EvalCache(dir, at('2026-11-30T00:00:00Z')).get(key)).toEqual(answer);
    expect(new EvalCache(dir, at('2026-12-02T00:00:00Z')).get(key)).toBeNull();
  });

  it('reads a damaged entry as a miss', () => {
    const dir = cacheDir();
    const cache = new EvalCache(dir);
    const key = cache.key(request, 1);
    cache.put(key, {text: 42 as unknown as string, inputTokens: 1, outputTokens: 1});
    expect(cache.get(key)).toBeNull();
  });
});
