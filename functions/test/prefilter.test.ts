/**
 * The deterministic wordlist gate. Two properties matter and both are pinned:
 * a slur blocks with no model involved (the guarantee that survives a model
 * outage), and an innocent word containing a listed term as a substring never
 * matches (the Scunthorpe problem — the client's `contains` blocklist shows
 * how that goes wrong).
 */
import {describe, expect, it} from 'vitest';
import {
  POST_QUALITY,
  PROFANITY_ACTION,
  postQuality,
  prefilter,
  replyQuality,
} from '../src/ai/prefilter';

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

/**
 * The floor under the composer's own "was anything said?" check.
 *
 * Mirrors `PostQuality` in `lib/domain/logic/community_rules.dart`;
 * `test/domain/post_quality_test.dart` on the Dart side reads THIS file and
 * fails if the constants drift. The direction that matters is loose: a client
 * that lets more through than the server does turns a refusal-while-editing
 * into a "not published" after the composer has already closed.
 */
describe('postQuality', () => {
  it('refuses what is not a message', () => {
    for (const junk of ['', ' ', 'a', 'asdf', '...', '!!!!!!!!!!!!!!', '😭😭😭', '12345678 90 12']) {
      expect(postQuality(junk), junk).not.toBeNull();
    }
  });

  it('refuses one thing repeated, however long', () => {
    expect(postQuality('aaaaaaaaaaaaaa')).toBe('tooShort');
    expect(postQuality('help help help help')).toBe('repetitive');
    expect(postQuality('aaaa bbb aaaa')).toBe('repetitive');
  });

  it('an SOS clears a lower bar than an ordinary post', () => {
    // Reached from the composer the panic flow opens pre-tagged `sos`, by
    // somebody at high craving intensity. A wrongly refused cry for help is
    // the most expensive false positive in the app.
    for (const cry of ['i need help', 'help me now', 'talk to me']) {
      expect(postQuality(cry, true), cry).toBeNull();
      expect(postQuality(cry), cry).not.toBeNull();
    }
    // Only the character floor moves.
    expect(postQuality('a', true)).not.toBeNull();
    expect(postQuality('help help help', true)).toBe('repetitive');
    expect(POST_QUALITY.minSosChars).toBeLessThan(POST_QUALITY.minPostChars);
  });

  it('lets a real cry for help through', () => {
    // The whole point of a LOW bar: the panic flow opens the composer
    // pre-tagged `sos`, and somebody mid-craving is not composing a
    // paragraph. Every one of these must reach the feed.
    for (const real of [
      'help me please',
      'i want to vape',
      "day 3 and i'm done",
      'i cant i cant i cant',
      'about to cave at work',
    ]) {
      expect(postQuality(real), real).toBeNull();
    }
  });

  it('counts accented letters as letters', () => {
    expect(postQuality('estoy fatal ahora')).toBeNull();
    expect(postQuality('ça va très mal là')).toBeNull();
  });
});

describe('replyQuality', () => {
  it('accepts the short, real ones', () => {
    for (const real of ['thanks', 'yes yes', 'you got this', 'proud of you']) {
      expect(replyQuality(real), real).toBeNull();
    }
  });

  it('still refuses noise', () => {
    for (const junk of ['ok', '👍👍👍', 'aaaaaa', 'abababab', '....']) {
      expect(replyQuality(junk), junk).not.toBeNull();
    }
  });

  it('is looser than a post', () => {
    // "thanks" is a perfectly good reply and a non-post. If these two ever
    // converge, one of them is wrong.
    expect(postQuality('thanks')).not.toBeNull();
    expect(replyQuality('thanks')).toBeNull();
    expect(POST_QUALITY.minReplyChars).toBeLessThan(POST_QUALITY.minPostChars);
  });
});
