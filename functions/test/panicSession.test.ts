/**
 * What a survived craving records beyond its outcome — the two 1–10 ratings,
 * the game on screen, the exercise used and where it was opened from — and
 * what it refuses to trust. The client is the app, but a value on a server
 * document is still typed here.
 */
import {describe, expect, it} from 'vitest';
import {EXERCISES} from '../src/domain/exercises';
import {cravingFields, PANIC_GAMES} from '../src/handlers/panicSession';

describe('cravingFields', () => {
  it('keeps the two ratings and the game the arena named', () => {
    expect(
      cravingFields({intensity: 8, intensityAfter: 3, game: 'blocks'}),
    ).toEqual({
      intensity: 8,
      intensityAfter: 3,
      game: 'blocks',
      exercise: null,
      source: null,
    });
  });

  it('a session with no game and no re-rating stores nulls, not guesses', () => {
    expect(cravingFields({intensity: 7})).toEqual({
      intensity: 7,
      intensityAfter: null,
      game: null,
      exercise: null,
      source: null,
    });
    expect(cravingFields({})).toEqual({
      intensity: null,
      intensityAfter: null,
      game: null,
      exercise: null,
      source: null,
    });
  });

  it('refuses ratings off the scale and games this build does not know', () => {
    expect(cravingFields({intensity: 0, intensityAfter: 11, game: 'hexes'})).toEqual({
      intensity: null,
      intensityAfter: null,
      game: null,
      exercise: null,
      source: null,
    });
    expect(cravingFields({intensity: '8', intensityAfter: 2.5, game: 7})).toEqual({
      intensity: null,
      intensityAfter: null,
      game: null,
      exercise: null,
      source: null,
    });
  });

  it('keeps the exercise and where it was opened from', () => {
    // A craving met from a coach card. Nobody was asked how strong it was, so
    // the app sends no strength, and none is invented here: null, never the
    // slider's default.
    expect(cravingFields({exercise: 'breathing', source: 'coach'})).toEqual({
      intensity: null,
      intensityAfter: null,
      game: null,
      exercise: 'breathing',
      source: 'coach',
    });
    // An arena game is both a game and an exercise; each field is kept as
    // sent, and neither is filled in from the other.
    expect(
      cravingFields({intensity: 6, game: 'orbs', exercise: 'orbs', source: 'panic'}),
    ).toEqual({
      intensity: 6,
      intensityAfter: null,
      game: 'orbs',
      exercise: 'orbs',
      source: 'panic',
    });
  });

  it('refuses an exercise and a source the registry does not hold', () => {
    expect(cravingFields({exercise: 'teleport', source: 'email'})).toEqual({
      intensity: null,
      intensityAfter: null,
      game: null,
      exercise: null,
      source: null,
    });
    expect(cravingFields({exercise: 7, source: ['coach']})).toEqual({
      intensity: null,
      intensityAfter: null,
      game: null,
      exercise: null,
      source: null,
    });
  });

  it('names the games the registry does, and stores only those as a game', () => {
    expect(new Set(PANIC_GAMES)).toEqual(new Set(['orbs', 'tiles', 'blocks']));
    // Read off the registry rather than listed a second time, so a game
    // added there is accepted here without an edit to this handler.
    expect([...PANIC_GAMES]).toEqual(
      EXERCISES.filter((e) => e.game).map((e) => e.id),
    );
    // Every game is an exercise; not every exercise is a game. `game` is
    // checked against the games, never against the whole registry.
    for (const row of EXERCISES) {
      expect(cravingFields({game: row.id}).game, row.id).toBe(
        row.game ? row.id : null,
      );
    }
  });
});
