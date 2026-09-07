import {describe, expect, it} from 'vitest';
import {
  MAX_MENTIONS,
  parseMentions,
  resolveMentions,
  stripMentions,
  type ThreadParticipant,
} from '../src/domain/mentions';

const thread: ThreadParticipant[] = [
  {alias: '@quietfox42', uid: 'author'},
  {alias: '@brightmoth17', uid: 'moth'},
  {alias: '@calmotter9', uid: 'otter'},
];

describe('parseMentions', () => {
  it('finds an alias in ordinary prose', () => {
    expect(parseMentions('@quietfox42 that line got me')).toEqual(['@quietfox42']);
  });

  it('finds several', () => {
    expect(parseMentions('thanks @quietfox42 and @calmotter9')).toEqual([
      '@quietfox42',
      '@calmotter9',
    ]);
  });

  it('dedupes case-insensitively, keeping the first spelling', () => {
    expect(parseMentions('@QuietFox42 hey @quietfox42')).toEqual(['@QuietFox42']);
  });

  it('ignores text that is not alias-shaped', () => {
    expect(parseMentions('email me@example.com or @x or @nodigits')).toEqual([]);
  });

  it('caps how many it will honour', () => {
    const many = Array.from({length: 12}, (_, i) => `@aliasname${i}`).join(' ');
    expect(parseMentions(many)).toHaveLength(MAX_MENTIONS);
  });

  it('does not carry regex state between calls', () => {
    // A module-level /g pattern would make the second call skip the start.
    expect(parseMentions('@quietfox42 hi')).toEqual(['@quietfox42']);
    expect(parseMentions('@quietfox42 hi')).toEqual(['@quietfox42']);
  });

  it('returns nothing for empty text', () => {
    expect(parseMentions('')).toEqual([]);
  });
});

describe('stripMentions', () => {
  it('takes the addresses out and leaves the message', () => {
    expect(stripMentions('@quietfox42 that line got me').trim()).toBe(
      'that line got me',
    );
  });

  it('leaves nothing behind for a reply that is only a tag', () => {
    expect(stripMentions('@quietfox42').trim()).toBe('');
    expect(stripMentions('@quietfox42 @calmotter9').trim()).toBe('');
  });

  it('is UNCAPPED, unlike parseMentions', () => {
    // The two answer different questions. The cap is "how many will we
    // honour"; this is "what is left once the addresses come out", and a
    // sixth address is still an address — so a reply of nothing but eight
    // tags must strip to nothing, not to three leftover tags.
    const many = Array.from({length: 8}, (_, i) => `@aliasname${i}`).join(' ');
    expect(parseMentions(many)).toHaveLength(MAX_MENTIONS);
    expect(stripMentions(many).trim()).toBe('');
  });

  it('does not carry regex state between calls', () => {
    // A module-level /g pattern would make the second call skip the start.
    expect(stripMentions('@quietfox42 hi').trim()).toBe('hi');
    expect(stripMentions('@quietfox42 hi').trim()).toBe('hi');
  });

  it('leaves text that is not alias-shaped alone', () => {
    expect(stripMentions('email me@example.com')).toBe('email me@example.com');
  });
});

describe('resolveMentions', () => {
  it('resolves a mention to the participant who owns it', () => {
    expect(resolveMentions('@calmotter9 thank you', thread, 'moth')).toEqual([
      'otter',
    ]);
  });

  it('never notifies the person doing the mentioning', () => {
    expect(resolveMentions('@brightmoth17 talking to myself', thread, 'moth')).toEqual(
      [],
    );
  });

  it('ignores an alias nobody in the thread is using', () => {
    expect(resolveMentions('@ghostwolf88 hello', thread, 'moth')).toEqual([]);
  });

  it('matches regardless of case', () => {
    expect(resolveMentions('@CALMOTTER9 hi', thread, 'moth')).toEqual(['otter']);
  });

  it('gives a duplicated alias to whoever used it FIRST', () => {
    // The squatting attack: someone replies under the author's alias so that
    // mentions of the author go to them, or go nowhere. The incumbent wins.
    const squatted: ThreadParticipant[] = [
      ...thread,
      {alias: '@quietfox42', uid: 'impostor'},
    ];
    expect(resolveMentions('@quietfox42 you ok?', squatted, 'moth')).toEqual([
      'author',
    ]);
  });

  it('does not let a squatter suppress the mention entirely', () => {
    const squatted: ThreadParticipant[] = [
      ...thread,
      {alias: '@quietfox42', uid: 'impostor'},
    ];
    expect(resolveMentions('@quietfox42 hi', squatted, 'moth')).not.toEqual([]);
  });

  it('resolves several mentions to several people, without duplicates', () => {
    const uids = resolveMentions(
      '@quietfox42 and @calmotter9 and @quietfox42 again',
      thread,
      'moth',
    );
    expect(uids.sort()).toEqual(['author', 'otter']);
  });

  it('is unbothered by an alias that would be a bad regex', () => {
    const nasty: ThreadParticipant[] = [{alias: '(a+)+$', uid: 'weird'}];
    expect(resolveMentions('@quietfox42 hi', nasty, 'me')).toEqual([]);
  });

  it('does not match a one-letter alias against every reply', () => {
    const nasty: ThreadParticipant[] = [{alias: 'a', uid: 'weird'}];
    expect(resolveMentions('a perfectly ordinary sentence', nasty, 'me')).toEqual(
      [],
    );
  });
});
