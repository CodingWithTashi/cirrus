/**
 * The exercise registry: everything a person can do during a craving, by id.
 * Mirrors `lib/domain/logic/exercises/exercise.dart` row for row; the Dart
 * suite `test/domain/exercises_test.dart` READS THIS FILE with a regex and
 * fails when the two lists differ.
 *
 * Which is why the rows below keep one per line, in exactly this key order
 * (`id`, `kind`, `premium`, `game`): a reformatted row is a row that test
 * cannot see. An id is a wire value (callable payloads, craving docs,
 * analytics) and is never renamed.
 *
 * Adding an exercise: the same row here and in the Dart file, and its entry
 * in `EXERCISE_LABELS` (typecheck fails without it).
 */

export const EXERCISE_KINDS = ['calm', 'focus', 'people'] as const;
export const EXERCISE_SOURCES = ['panic', 'coach', 'plan', 'home'] as const;

/** Row order is the order cards are offered in. The first row is free. */
export const EXERCISES = [
  {id: 'breathing', kind: 'calm', premium: false, game: false},
  {id: 'orbs', kind: 'focus', premium: false, game: true},
  {id: 'tiles', kind: 'focus', premium: true, game: true},
  {id: 'blocks', kind: 'focus', premium: true, game: true},
  {id: 'sos', kind: 'people', premium: false, game: false},
] as const;

export type ExerciseId = (typeof EXERCISES)[number]['id'];
export type ExerciseKind = (typeof EXERCISE_KINDS)[number];
export type ExerciseSource = (typeof EXERCISE_SOURCES)[number];

export const EXERCISE_IDS: readonly ExerciseId[] = EXERCISES.map((e) => e.id);

/**
 * The row an id names, or null for anything the registry does not hold: an
 * id from a newer app, a non-string, nothing at all.
 */
export function exerciseById(id: unknown): (typeof EXERCISES)[number] | null {
  return EXERCISES.find((e) => e.id === id) ?? null;
}

/** How the user card names each one. Typed exhaustively: a new id fails typecheck until it has a label. */
export const EXERCISE_LABELS: Record<ExerciseId, string> = {
  breathing: 'the breathing exercise',
  orbs: 'the Orbs game',
  tiles: 'the Tiles game',
  blocks: 'the Blocks game',
  sos: 'an SOS post to the community',
};
