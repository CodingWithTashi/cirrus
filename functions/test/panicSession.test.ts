/**
 * What a survived craving records beyond its outcome — the two 1–10 ratings
 * and the game on screen — and what it refuses to trust. The client is the
 * app, but a number on a server document is still typed here.
 */
import {describe, expect, it} from 'vitest';
import {cravingFields, PANIC_GAMES} from '../src/handlers/panicSession';

describe('cravingFields', () => {
  it('keeps the two ratings and the game the arena named', () => {
    expect(
      cravingFields({intensity: 8, intensityAfter: 3, game: 'blocks'}),
    ).toEqual({intensity: 8, intensityAfter: 3, game: 'blocks'});
  });

  it('a session with no game and no re-rating stores nulls, not guesses', () => {
    expect(cravingFields({intensity: 7})).toEqual({
      intensity: 7,
      intensityAfter: null,
      game: null,
    });
    expect(cravingFields({})).toEqual({
      intensity: null,
      intensityAfter: null,
      game: null,
    });
  });

  it('refuses ratings off the scale and games this build does not know', () => {
    expect(cravingFields({intensity: 0, intensityAfter: 11, game: 'hexes'})).toEqual({
      intensity: null,
      intensityAfter: null,
      game: null,
    });
    expect(cravingFields({intensity: '8', intensityAfter: 2.5, game: 7})).toEqual({
      intensity: null,
      intensityAfter: null,
      game: null,
    });
  });

  it('names the three games the client does', () => {
    expect([...PANIC_GAMES]).toEqual(['tiles', 'blocks', 'orbs']);
  });
});
