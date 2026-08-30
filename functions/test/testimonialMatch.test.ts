/**
 * Which two quotes a person sees on D3.
 *
 * Pure, so no emulator — the same split `reactionDelta.test.ts` uses. What
 * matters here is that the pick is *stable* (a retried call must not swap the
 * pair) and *varied* (two quotes about cravings read as a bug, not as social
 * proof).
 */
import {describe, expect, it} from 'vitest';
import {rank, type Testimonial, type TestimonialAudience} from '../src/domain/testimonialMatch';

function quote(id: string, over: Partial<Testimonial> = {}): Testimonial {
  return {
    id,
    text: `quote ${id}`,
    whys: [],
    worries: [],
    attempts: [],
    gender: [],
    dependence: [],
    weight: 0.5,
    ...over,
  };
}

const nobody: TestimonialAudience = {
  whys: [],
  worries: [],
  attempts: null,
  gender: null,
  dependence: null,
};

describe('rank', () => {
  it('puts the fear they named first', () => {
    const pool = [
      quote('a', {whys: ['money']}),
      quote('b', {worries: ['cravings']}),
      quote('c'),
    ];
    const picked = rank(pool, {...nobody, whys: ['money'], worries: ['cravings']}, 2);
    expect(picked[0]!.id).toBe('b');
  });

  it('does not return two quotes about the same thing', () => {
    // Without the diversity decay both slots come back about cravings, which
    // reads as a bug rather than as social proof.
    const pool = [
      quote('a', {worries: ['cravings']}),
      quote('b', {worries: ['cravings']}),
      quote('c', {worries: ['stress']}),
    ];
    const picked = rank(
      pool,
      {...nobody, worries: ['cravings', 'stress']},
      2,
    );
    expect(picked.map((t) => t.id)).toEqual(['a', 'c']);
  });

  it('is stable across repeated calls and input order', () => {
    const pool = [
      quote('zed', {worries: ['stress']}),
      quote('abe', {worries: ['stress']}),
      quote('mid', {worries: ['stress']}),
    ];
    const audience = {...nobody, worries: ['stress'] as const};
    const first = rank(pool, audience, 2).map((t) => t.id);
    expect(rank(pool, audience, 2).map((t) => t.id)).toEqual(first);
    expect(rank([...pool].reverse(), audience, 2).map((t) => t.id)).toEqual(first);
  });

  it('treats an untagged quote as applying to everyone, never as a penalty', () => {
    const pool = [quote('universal'), quote('mismatch', {worries: ['weight']})];
    const picked = rank(pool, {...nobody, worries: ['cravings']}, 1);
    expect(picked[0]!.id).toBe('universal');
  });

  it('still fills both slots when nothing matches at all', () => {
    // A person who answered nothing tailorable still gets social proof.
    const pool = [quote('a'), quote('b'), quote('c')];
    expect(rank(pool, nobody, 2)).toHaveLength(2);
  });

  it('never returns more than the pool holds', () => {
    expect(rank([quote('a')], nobody, 2)).toHaveLength(1);
    expect(rank([], nobody, 2)).toHaveLength(0);
  });

  it('weighs the signals in the documented order', () => {
    // worries (2.0) > whys (1.5) > attempts (1.0) > dependence (.75) > gender (.5)
    const audience: TestimonialAudience = {
      whys: ['money'],
      worries: ['cravings'],
      attempts: 'twoToFive',
      gender: 'woman',
      dependence: 'heavy',
    };
    const pool = [
      quote('gender', {gender: ['woman']}),
      quote('dependence', {dependence: ['heavy']}),
      quote('attempts', {attempts: ['twoToFive']}),
      quote('why', {whys: ['money']}),
      quote('worry', {worries: ['cravings']}),
    ];
    expect(rank(pool, audience, 5).map((t) => t.id)).toEqual([
      'worry', 'why', 'attempts', 'dependence', 'gender',
    ]);
  });

  it('lets the editorial weight break a tie between equals', () => {
    const pool = [
      quote('zzz', {worries: ['cravings'], weight: 1}),
      quote('aaa', {worries: ['cravings'], weight: 0}),
    ];
    // 'aaa' would win on id alone; the weight is what overrides that.
    const picked = rank(pool, {...nobody, worries: ['cravings']}, 1);
    expect(picked[0]!.id).toBe('zzz');
  });
});
