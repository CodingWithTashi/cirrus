/**
 * The coach eval's judge (tools/evalJudge.ts), Nov 13 2026.
 *
 * Three facts motivated it, all read off real runs of `npm run eval:coach`:
 *  - the judge never saw the user's message, so it failed correct replies for
 *    "assuming" the user had smoked (they had said so) and for claiming "the
 *    criteria state the user chose the vape";
 *  - it never saw the card, so it could not tell an invented number from a real
 *    one ("19-honest-gap", "16-week-comparison");
 *  - it ran on the smallest model, at temperature 0, so voting would not have
 *    helped: its errors were systematic, not sampling noise.
 * None of this edits a case's own criteria text.
 */
import {describe, expect, it} from 'vitest';
import {
  JUDGE_PROMPT,
  buildJudgeInput,
  parseVerdict,
  resolveJudgeModel,
} from '../tools/evalJudge';

describe('buildJudgeInput', () => {
  const input = buildJudgeInput({
    criteria: 'Zero shame. Asks one question.',
    userMessage: 'I had a cigarette instead of vaping today',
    cardText: 'plan day: 32\nstreak: 23d',
    summary: '',
    reply: 'No shame in it. What pushed you toward a cigarette today?',
  });

  it('shows the judge what the person actually wrote', () => {
    expect(input).toContain("USER'S MESSAGE:\nI had a cigarette instead of vaping today");
  });

  it('shows the card, so a number can be checked against it', () => {
    expect(input).toContain('USER CARD:\nplan day: 32\nstreak: 23d');
  });

  it('carries the criteria and the reply verbatim, in that order', () => {
    const c = input.indexOf('CRITERIA:\nZero shame. Asks one question.');
    const r = input.indexOf('REPLY TO JUDGE:\nNo shame in it.');
    expect(c).toBeGreaterThan(-1);
    expect(r).toBeGreaterThan(c);
  });

  it('shows the conversation summary the coach was given, so recall is not called invented', () => {
    // 18-long-range-continuity: 22 of 24 correct answers ("walk Rufus") were failed
    // as invented because the judge saw the card but not the summary.
    const withSummary = buildJudgeInput({
      criteria: 'c',
      userMessage: 'm',
      cardText: 'card',
      summary: 'They committed to walking their dog Rufus.',
      reply: 'r',
    });
    expect(withSummary).toContain('CONVERSATION SUMMARY');
    expect(withSummary).toContain('They committed to walking their dog Rufus.');
    expect(withSummary.indexOf('CONVERSATION SUMMARY')).toBeLessThan(withSummary.indexOf('CRITERIA:'));
  });

  it('omits the summary section when there is none', () => {
    expect(
      buildJudgeInput({criteria: 'c', userMessage: 'm', cardText: 'card', summary: '', reply: 'r'}),
    ).not.toContain('CONVERSATION SUMMARY');
  });

  it('omits the card section when there is no card', () => {
    const none = buildJudgeInput({
      criteria: 'c',
      userMessage: 'm',
      cardText: '',
      summary: '',
      reply: 'r',
    });
    expect(none).not.toContain('USER CARD');
  });
});

describe('the judge prompt', () => {
  it('keeps the strict stance: judge only against the criteria', () => {
    expect(JUDGE_PROMPT).toContain('ONLY against the criteria');
  });

  it('says how to use the message and the card', () => {
    expect(JUDGE_PROMPT).toContain("USER'S MESSAGE");
    expect(JUDGE_PROMPT).toContain('USER CARD');
    expect(JUDGE_PROMPT).toMatch(/invented only if/i);
  });

  it('reads tone criteria strictly, but a mention of their why is not pressure', () => {
    // v1 said "family ... as pressure fail", and the judge then failed ordinary
    // anchoring to the person's why (09, 4 of 24 held-out answers) — which the
    // coach is told to do. Guilt and threats fail; a mention does not.
    expect(JUDGE_PROMPT).toMatch(/criteria ask for tone/i);
    expect(JUDGE_PROMPT).toMatch(/fear/i);
    expect(JUDGE_PROMPT).toMatch(/guilt/i);
    expect(JUDGE_PROMPT).toMatch(/mentioning .* is fine/i);
  });

  it('adds no tone requirement a case does not state (09 is about statistics only)', () => {
    expect(JUDGE_PROMPT).toMatch(/do not add\s+requirements the criteria do not state/i);
  });

  it('treats the conversation summary as real', () => {
    expect(JUDGE_PROMPT).toContain('CONVERSATION SUMMARY');
  });

  it('still asks for JSON with no quotation marks inside the reason', () => {
    expect(JUDGE_PROMPT).toContain('{"pass": true|false');
    expect(JUDGE_PROMPT).toContain('WITHOUT quotation marks');
  });
});

describe('parseVerdict', () => {
  it('reads clean JSON', () => {
    expect(parseVerdict('{"pass": true, "reason": "fine"}')).toEqual({
      name: 'judge',
      pass: true,
      detail: 'fine',
    });
  });

  it('reads fenced JSON', () => {
    expect(parseVerdict('```json\n{"pass": false, "reason": "no"}\n```').pass).toBe(false);
  });

  it('takes the first balanced object when commentary with braces trails it', () => {
    const v = parseVerdict('{"pass": true, "reason": "ok"} Note: {see above}');
    expect(v.pass).toBe(true);
    expect(v.detail).toBe('ok');
  });

  it('recovers the verdict bit from JSON the judge broke with a quote', () => {
    const v = parseVerdict('{"pass": false, "reason": "said "hi" twice"}');
    expect(v.pass).toBe(false);
    expect(v.detail).toContain('verdict recovered');
  });

  it('fails closed on anything it cannot read', () => {
    expect(parseVerdict('looks good to me').pass).toBe(false);
    expect(parseVerdict('looks good to me').detail).toBe('malformed judge verdict');
    expect(parseVerdict('{"reason": "no pass field"}').pass).toBe(false);
  });
});

describe('resolveJudgeModel', () => {
  it('defaults to the premium model, not the smallest one', () => {
    expect(resolveJudgeModel({})).toBe('gemini-3.6-flash');
  });

  it('follows MODEL_PREMIUM, then lets JUDGE_MODEL override it', () => {
    expect(resolveJudgeModel({MODEL_PREMIUM: 'gemini-x'})).toBe('gemini-x');
    expect(resolveJudgeModel({MODEL_PREMIUM: 'gemini-x', JUDGE_MODEL: 'gemini-y'})).toBe('gemini-y');
  });
});
