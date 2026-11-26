/**
 * `COACH_CONTEXT_LINES`: whether the coach's user card carries the six
 * context lines (the craving log, the danger hour, the last puff, what they
 * just did).
 *
 * The lines changed what the model says, and the coach eval's bar for them
 * was missed twice (docs/superpowers/evidence/2026-11-25-coach-cards/eval).
 * So they ship OFF, and this param is what keeps a deploy from turning them
 * on by accident.
 *
 * It is read the OPPOSITE way round from every other switch in `config.ts`.
 * Those are kill switches for things that should be on: they read
 * `!== 'false'`, so a param nobody set leaves the feature running. Here the
 * safe state is off and a param nobody set is the empty string, so only the
 * exact word `on` turns the lines on. The last case pins that the two
 * readings really do differ, so nobody "fixes" this one to match.
 */
import {describe, expect, it} from 'vitest';
import {
  COACH_CONTEXT_LINES,
  coachContextLines,
  enforceAppCheckFrom,
} from '../src/config';

describe('coachContextLines', () => {
  it('is off for an unset param, for the word, and for anything it does not know', () => {
    // '' is what a deploy-time param resolves to when no .env supplies it.
    for (const raw of ['', 'off', 'true', 'nonsense', 'yes', '1', 'enabled', 'o n']) {
      expect(coachContextLines(raw), JSON.stringify(raw)).toBe(false);
    }
  });

  it('is on for exactly that word, whatever its case or padding', () => {
    for (const raw of ['on', ' ON ', 'On', '\ton\n']) {
      expect(coachContextLines(raw), JSON.stringify(raw)).toBe(true);
    }
  });

  it('the param is COACH_CONTEXT_LINES, and it defaults to off', () => {
    expect(COACH_CONTEXT_LINES.name).toBe('COACH_CONTEXT_LINES');
    expect(COACH_CONTEXT_LINES.options.default).toBe('off');
    expect(coachContextLines(COACH_CONTEXT_LINES.options.default as string)).toBe(false);
    // The state this very process is in: no .env loaded.
    expect(coachContextLines(COACH_CONTEXT_LINES.value())).toBe(
      coachContextLines(process.env[COACH_CONTEXT_LINES.name] ?? ''),
    );
  });

  it('fails the other way from a kill switch, on purpose', () => {
    // The same unset value, read by this repo's two rules: the App Check
    // switch stays armed, and the context lines stay off. Each fails toward
    // its own safe state. A change that makes this one read `!== 'false'`
    // turns the lines on for every project whose .env never named them.
    expect(enforceAppCheckFrom('')).toBe(true);
    expect(coachContextLines('')).toBe(false);
    expect(coachContextLines('true')).toBe(false);
  });
});
