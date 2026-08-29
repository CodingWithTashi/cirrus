/**
 * The pure half of `onReaction`. Reaction counts are derived from these
 * deltas, so a wrong answer here shows up as a post whose popularity drifts
 * away from reality and never comes back.
 */
import {describe, expect, it} from 'vitest';
import {reactionDelta} from '../src/handlers/onReaction';

describe('reactionDelta', () => {
  it('counts a first reaction as an addition', () => {
    expect(reactionDelta(null, 'fire')).toEqual({added: 'fire', removed: null});
  });

  it('counts taking a reaction back as a removal', () => {
    expect(reactionDelta('fire', null)).toEqual({added: null, removed: 'fire'});
  });

  it('moves the count when someone changes their emoji', () => {
    expect(reactionDelta('fire', 'heart')).toEqual({
      added: 'heart',
      removed: 'fire',
    });
  });

  // The one that keeps counts honest. A double tap, or a write the client
  // retried after a flaky response, must not inflate anything.
  it('is a no-op when the same emoji is written again', () => {
    expect(reactionDelta('fire', 'fire')).toEqual({added: null, removed: null});
  });

  it('is a no-op when nothing was there and nothing arrived', () => {
    expect(reactionDelta(null, null)).toEqual({added: null, removed: null});
  });
});
