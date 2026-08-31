import {describe, expect, it} from 'vitest';
import {parseVerdict} from '../src/handlers/moderatePost';
import {parseInsight} from '../src/handlers/weeklyInsight';

describe('parseVerdict', () => {
  it('reads a clean verdict', () => {
    expect(parseVerdict('{"action":"block","reason":"selling"}')).toEqual({
      action: 'block', reason: 'selling',
    });
  });

  it('strips the code fence models add despite being told not to', () => {
    const raw = '```json\n{"action":"allow","reason":"venting"}\n```';
    expect(parseVerdict(raw).action).toBe('allow');
  });

  it('reads the hold verdict', () => {
    expect(parseVerdict('{"action":"hold","reason":"hostile rant"}')).toEqual({
      action: 'hold', reason: 'hostile rant',
    });
  });

  it('HOLDS rather than allows when the response is unparseable', () => {
    // Fail-closed: an unreadable verdict is not consent — and since the
    // triggers map `flag` to live, it must not be `flag` either. `hold`
    // keeps the content pending and queues it for a human.
    expect(parseVerdict('I think this is fine!').action).toBe('hold');
    expect(parseVerdict('{"action":"approve"}').action).toBe('hold');
    expect(parseVerdict('').action).toBe('hold');
  });
});

describe('parseInsight', () => {
  const full = {
    headline: 'Your quietest week yet',
    pattern: 'evenings are your spike',
    win: 'Thursday: 88 puffs, lowest ever',
    watchout: 'Friday nights',
    move: 'plan a 9pm walk',
  };

  it('reads a complete report', () => {
    expect(parseInsight(JSON.stringify(full))).toEqual(full);
  });

  it('returns null on a partial report so the week is skipped silently', () => {
    // docs/04 §5 — half a report is worse than none.
    const {move: _move, ...partial} = full;
    expect(parseInsight(JSON.stringify(partial))).toBeNull();
  });

  it('returns null on garbage', () => {
    expect(parseInsight('sure! here is your week:')).toBeNull();
  });
});
