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

  it('FLAGS rather than allows when the response is unparseable', () => {
    // Fail-closed: an unreadable verdict is not consent. Allowing here would
    // publish unmoderated UGC on every model hiccup.
    expect(parseVerdict('I think this is fine!').action).toBe('flag');
    expect(parseVerdict('{"action":"approve"}').action).toBe('flag');
    expect(parseVerdict('').action).toBe('flag');
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
