/**
 * The exercise registry, server side. Row parity with
 * `lib/domain/logic/exercises/exercise.dart` is pinned from the Dart side
 * (`test/domain/exercises_test.dart` reads `src/domain/exercises.ts` with a
 * regex); this suite pins what the server itself leans on: the id list, the
 * free first row, the lookup that refuses what it does not know, and a label
 * for every id.
 */
import {describe, expect, it} from 'vitest';
import {
  EXERCISE_IDS,
  EXERCISE_LABELS,
  EXERCISES,
  exerciseById,
} from '../src/domain/exercises';

describe('the exercise registry', () => {
  it('names the five exercises the app does, in order', () => {
    expect([...EXERCISE_IDS]).toEqual(['breathing', 'orbs', 'tiles', 'blocks', 'sos']);
  });

  it('the first exercise is free', () => {
    // Where the card policy lands when nothing else is available.
    expect(EXERCISES[0].premium).toBe(false);
  });

  it('looks an exercise up by id', () => {
    expect(exerciseById('orbs')?.kind).toBe('focus');
  });

  it('refuses an id it does not know, and anything that is not a string', () => {
    expect(exerciseById('nope')).toBeNull();
    expect(exerciseById(7)).toBeNull();
    expect(exerciseById(null)).toBeNull();
  });

  it('every id has words the user card can use', () => {
    for (const id of EXERCISE_IDS) {
      expect(EXERCISE_LABELS[id].trim().length, id).toBeGreaterThan(0);
    }
  });
});
