/**
 * The two pure pieces of Ember's long-term memory: what is worth a model call,
 * and what a model's answer is allowed to become.
 *
 * `parseMemories` is the boundary where generated text turns into stored
 * state, so it is the one place worth pinning against the shapes a model
 * actually emits when it improvises — fences, prose, the wrong key, a
 * paragraph where a sentence was asked for.
 */
import {describe, expect, it} from 'vitest';
import {parseMemories} from '../src/handlers/aiCoachChat';
import {worthExtracting} from '../src/lib/memories';

describe('worthExtracting — the gate before the model call', () => {
  it('skips chips, which carry no new information by construction', () => {
    expect(worthExtracting('[craving]')).toBe(false);
    expect(worthExtracting('[roughDay]')).toBe(false);
  });

  it('skips one-liners', () => {
    for (const text of ['ok', 'thanks', 'yeah ok', 'i did it', 'no']) {
      expect(worthExtracting(text), text).toBe(false);
    }
  });

  it('accepts a message long enough to hold a fact', () => {
    expect(
      worthExtracting("my sister's wedding is in March and I want to be done by then"),
    ).toBe(true);
  });
});

describe('parseMemories', () => {
  it('reads the documented shape', () => {
    const facts = parseMemories(
      '{"memories":[{"text":"Their sister Maya marries in March.","kind":"person"}]}',
    );
    expect(facts).toEqual([
      {text: 'Their sister Maya marries in March.', kind: 'person'},
    ]);
  });

  it('strips code fences, which models add unprompted', () => {
    const facts = parseMemories(
      '```json\n{"memories":[{"text":"Work deadlines trigger them.","kind":"trigger"}]}\n```',
    );
    expect(facts).toHaveLength(1);
    expect(facts[0]!.kind).toBe('trigger');
  });

  it('treats an empty list as the normal answer, not a failure', () => {
    expect(parseMemories('{"memories":[]}')).toEqual([]);
  });

  it('yields nothing for prose, a refusal, or malformed JSON', () => {
    for (const raw of [
      'I could not find anything to remember.',
      '{"memories": ',
      'null',
      '{"notMemories":[{"text":"x","kind":"person"}]}',
      '',
    ]) {
      expect(parseMemories(raw), raw).toEqual([]);
    }
  });

  it('caps at two, whatever the model returns', () => {
    const many = {
      memories: Array.from({length: 9}, (_, i) => ({
        text: `A durable fact number ${i}.`,
        kind: 'context',
      })),
    };
    expect(parseMemories(JSON.stringify(many))).toHaveLength(2);
  });

  it('drops a paragraph — that is a summary, not a fact', () => {
    // A long vector matches everything, so one of these would quietly occupy a
    // recall slot on every future turn.
    const long = 'x'.repeat(300);
    expect(
      parseMemories(`{"memories":[{"text":"${long}","kind":"context"}]}`),
    ).toEqual([]);
  });

  it('drops a fragment too short to mean anything alone', () => {
    expect(parseMemories('{"memories":[{"text":"sister","kind":"person"}]}')).toEqual(
      [],
    );
  });

  it('falls back to `context` for an unknown kind rather than dropping it', () => {
    // The fact is still worth keeping; only our label for it was wrong.
    const facts = parseMemories(
      '{"memories":[{"text":"They run every Sunday morning.","kind":"hobbies"}]}',
    );
    expect(facts).toEqual([
      {text: 'They run every Sunday morning.', kind: 'context'},
    ]);
  });

  it('ignores non-object entries mixed into the list', () => {
    const facts = parseMemories(
      '{"memories":["just a string",{"text":"They have a dog named Rufus.","kind":"person"}]}',
    );
    expect(facts).toEqual([
      {text: 'They have a dog named Rufus.', kind: 'person'},
    ]);
  });
});
