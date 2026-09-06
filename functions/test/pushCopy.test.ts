import {describe, expect, it} from 'vitest';
import {PUSH_LOCALES, pushCopy, type PushKey} from '../src/lib/pushCopy';
import {PUSH_KINDS, allowedByPrefs, type PushKind} from '../src/lib/pushKinds';

const KEYS: readonly PushKey[] = [
  'communityReply',
  'communityMention',
  'sosReply',
  'insightReady',
];

describe('pushCopy', () => {
  it('has non-empty copy for every key in every shipped language', () => {
    for (const key of KEYS) {
      for (const locale of PUSH_LOCALES) {
        const copy = pushCopy(key, locale);
        expect(copy.title.length, `${key}/${locale} title`).toBeGreaterThan(0);
        expect(copy.body.length, `${key}/${locale} body`).toBeGreaterThan(0);
      }
    }
  });

  it('interpolates the count into every plural body, in every language', () => {
    for (const locale of PUSH_LOCALES) {
      const copy = pushCopy('communityReply', locale, 7);
      expect(copy.body, `${locale}`).toContain('7');
      // A translator dropping the placeholder is the failure this catches:
      // it compiles fine and renders a sentence with a hole in it.
      expect(copy.body).not.toContain('{count}');
    }
  });

  it('uses the singular form for one', () => {
    const one = pushCopy('communityReply', 'en', 1);
    const many = pushCopy('communityReply', 'en', 2);
    expect(one.title).not.toEqual(many.title);
    expect(one.body).not.toContain('1');
  });

  it('leaves a count-free key alone whatever the count', () => {
    expect(pushCopy('sosReply', 'en', 9)).toEqual(pushCopy('sosReply', 'en', 1));
  });

  it('matches on the language subtag', () => {
    expect(pushCopy('sosReply', 'pt-BR')).toEqual(pushCopy('sosReply', 'pt'));
    expect(pushCopy('sosReply', 'fr_CA')).toEqual(pushCopy('sosReply', 'fr'));
  });

  it('falls back to English rather than sending nothing', () => {
    expect(pushCopy('sosReply', 'ja')).toEqual(pushCopy('sosReply', 'en'));
    expect(pushCopy('sosReply', undefined)).toEqual(pushCopy('sosReply', 'en'));
  });
});

describe('push kinds', () => {
  it('gives every kind a channel', () => {
    for (const kind of Object.keys(PUSH_KINDS) as PushKind[]) {
      expect(PUSH_KINDS[kind].channelId.length).toBeGreaterThan(0);
      expect(PUSH_KINDS[kind].quietChannelId.length).toBeGreaterThan(0);
    }
  });

  it('never lets a quiet twin share its channel importance slot', () => {
    // The pair only works if they are genuinely two channels. A kind whose
    // quiet id equals its loud id silently rings at 3am.
    for (const kind of ['communityReply', 'communityMention', 'insightReady'] as const) {
      const spec = PUSH_KINDS[kind];
      if (!spec.respectsQuietHours) continue;
      expect(spec.quietChannelId, kind).not.toEqual(spec.channelId);
    }
  });

  it('keeps SOS loud and uncollapsed', () => {
    expect(PUSH_KINDS.sosReply.respectsQuietHours).toBe(false);
    expect(PUSH_KINDS.sosReply.collapses).toBe(false);
  });

  it('treats an absent preference as enabled, so nothing needs migrating', () => {
    expect(allowedByPrefs('communityReply', undefined)).toBe(true);
    expect(allowedByPrefs('communityReply', {})).toBe(true);
  });

  it('honours the master switch over every individual preference', () => {
    expect(allowedByPrefs('communityReply', {all: false, communityReply: true})).toBe(
      false,
    );
    expect(allowedByPrefs('sosReply', {all: false})).toBe(false);
  });

  it('silences a kind whose own preference is off', () => {
    expect(allowedByPrefs('communityMention', {communityMention: false})).toBe(false);
    expect(allowedByPrefs('communityMention', {communityReply: false})).toBe(true);
  });

  it('requires promotional push to be opted INTO', () => {
    expect(allowedByPrefs('promo', {})).toBe(false);
    expect(allowedByPrefs('promo', {promo: true})).toBe(true);
  });
});
