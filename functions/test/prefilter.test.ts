/**
 * The deterministic wordlist gate. Two properties matter and both are pinned:
 * a slur blocks with no model involved (the guarantee that survives a model
 * outage), and an innocent word containing a listed term as a substring never
 * matches (the Scunthorpe problem — the client's `contains` blocklist shows
 * how that goes wrong).
 */
import {describe, expect, it} from 'vitest';
import {PROFANITY_ACTION, prefilter} from '../src/ai/prefilter';

describe('prefilter', () => {
  it('blocks a slur outright', () => {
    expect(prefilter('you are a kike')).toEqual({
      action: 'block',
      reason: 'prefilter: slur',
    });
  });

  it('blocks regardless of case and position', () => {
    expect(prefilter('KIKE')?.action).toBe('block');
    expect(prefilter('what a wetback, honestly.')?.action).toBe('block');
  });

  it('defeats leetspeak and diacritic obfuscation', () => {
    expect(prefilter('k1ke')?.action).toBe('block');
    expect(prefilter('kìké')?.action).toBe('block');
  });

  it('never matches inside an innocent word (Scunthorpe)', () => {
    // "spic" inside "conspicuous"/"spice", "gook" inside "gobbledygook".
    expect(prefilter('a conspicuous amount of spice')).toBeNull();
    expect(prefilter('that spec sheet is gobbledygook')).toBeNull();
  });

  it('does not match a word an accent-fold turns into a longer one', () => {
    // Normalization folds é → e BEFORE matching, so this reads "spice" and
    // the trailing-letter lookahead keeps "spic" from matching inside it.
    expect(prefilter('spicé')).toBeNull();
  });

  it('lets clean and empty text through to the model', () => {
    expect(prefilter('day 5 and still going strong')).toBeNull();
    expect(prefilter('')).toBeNull();
  });

  it('routes profanity per the policy knob', () => {
    // Founder decision Aug 31 2026: contextual — profanity goes to the model,
    // whose prompt holds hostile rants and allows self-directed venting. If
    // the knob is ever flipped to 'hold', this pins the other behavior.
    const verdict = prefilter('fuck this app');
    if (PROFANITY_ACTION === null) {
      expect(verdict).toBeNull();
    } else {
      expect(verdict).toEqual({action: 'hold', reason: 'prefilter: profanity'});
    }
  });

  it('slur beats profanity when both appear', () => {
    expect(prefilter('fuck you, kike')?.action).toBe('block');
  });
});
