/**
 * The coach-name guard.
 *
 * Its honest job is narrow — `coachName` is private, rendered only to the
 * person who typed it — so what is worth pinning is that impersonation is
 * blocked through obfuscation, and that ordinary names are NOT refused. A
 * guard that rejects "Cass" because it contains letters is worse than none.
 */
import {describe, expect, it} from 'vitest';
import {isAllowedAgainst, isAllowedCoachName, skeleton} from '../src/lib/nameGuard';

describe('skeleton', () => {
  it('folds case, accents, leetspeak and repeats to one form', () => {
    for (const variant of ['admin', 'ADMIN', 'Ãdmin', '@dm1n', 'aaadmiiin', 'a.d-m.i.n']) {
      expect(skeleton(variant)).toBe('admin');
    }
  });

  it('leaves an ordinary name recognisable', () => {
    expect(skeleton('Wren')).toBe('wren');
    expect(skeleton('Élodie')).toBe('elodie');
  });
});

describe('isAllowedCoachName', () => {
  it('blocks someone impersonating the app or its staff', () => {
    for (const name of ['Cirrus', 'admin', 'ADMIN', '@dm1n', 'Support', 'M0derator']) {
      expect(isAllowedCoachName(name)).toBe(false);
    }
  });

  it('allows the names people will actually pick', () => {
    // Including the docs/04 §10 alternates the step offers as suggestions.
    for (const name of ['Ember', 'Pip', 'Fin', 'Koda', 'Wren', 'Élodie', "O'Brien", 'Mary-Jane', 'Sam 2']) {
      expect(isAllowedCoachName(name)).toBe(true);
    }
  });

  it('does not refuse a name merely for containing a blocked one', () => {
    // The Scunthorpe rule: impersonation matches the WHOLE skeleton, so a
    // longer name that happens to contain those letters is fine.
    for (const name of ['Adminka', 'Cirrusa', 'Rooted']) {
      expect(isAllowedCoachName(name)).toBe(true);
    }
  });

  it('refuses something that folds away to nothing', () => {
    expect(isAllowedCoachName('...')).toBe(false);
    expect(isAllowedCoachName('   ')).toBe(false);
  });
});

describe('isAllowedAgainst — the Scunthorpe rule', () => {
  // Skeletonizing collapses repeats, so "ass" folds to "as" and "hell" to
  // "hel". Substring-matching those would refuse four real names. A guard that
  // blocks somebody's own name is worse than no guard, because it refuses to
  // say why.
  const short = ['ass', 'hell', 'cum'];

  it('never blocks a real name for containing a short term', () => {
    for (const name of ['Cassie', 'Cass', 'Bassam', 'Shelly', 'Michelle', 'Cumberbatch']) {
      expect(isAllowedAgainst(name, short)).toBe(true);
    }
  });

  it('still blocks a short term used on its own', () => {
    for (const name of ['ass', 'Ass', '@$$', 'hell', 'H3LL']) {
      expect(isAllowedAgainst(name, short)).toBe(false);
    }
  });

  it('blocks a long term even when it is padded out', () => {
    const long = ['bastard', 'motherfucker'];
    for (const name of ['bastard', 'xxbastardxx', 'B4st4rd', 'mother-fucker']) {
      expect(isAllowedAgainst(name, long)).toBe(false);
    }
    // And leaves an innocent long name alone.
    expect(isAllowedAgainst('Sebastian', long)).toBe(true);
  });

  it('ignores blank and whitespace-only terms', () => {
    expect(isAllowedAgainst('Wren', ['', '   ', '!!!'])).toBe(true);
  });
});

describe('the shipped denylist', () => {
  // The file is gitignored, so this only asserts when one is present locally.
  it('refuses nothing a person would reasonably be called', () => {
    for (const name of [
      'Ember', 'Pip', 'Fin', 'Koda', 'Wren', 'Cassie', 'Cass', 'Shelly',
      'Bassam', 'Michelle', 'Sebastian', 'Élodie', "O'Brien", 'Mary-Jane',
      'Hunter', 'Dick', 'Bill', 'Analise', 'Cockburn',
    ]) {
      expect(isAllowedCoachName(name)).toBe(true);
    }
  });
});
