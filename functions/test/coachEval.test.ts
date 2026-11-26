/**
 * The eval harness's own wiring, tested without a model.
 *
 * `npm run eval:coach` costs money and is one noisy roll, so what CAN be
 * known for free is pinned here: that each scenario is graded against the
 * card production would build for that turn, that the 22 established cases
 * were not touched when two were added, and that the two new cases'
 * mechanical checks fail the replies they are meant to fail and pass the
 * ones they are not. A regex that flags the approved "15-20 minutes" fact
 * would read, five rolls later, as the model getting worse.
 */
import {createHash} from 'node:crypto';
import {describe, expect, it} from 'vitest';
import {digestCravings} from '../src/ai/cravingDigest';
import {buildMemoryCard} from '../src/ai/memoryCard';
import {cardFor, scenarios, type Scenario} from '../tools/coachEval';
import {dayKeyIn, hourIn} from '../src/domain/dateKey';
import {
  EVAL_DANGER_NOW,
  EVAL_NOW,
  EVAL_TZ,
  evalCravings,
  evalJourney,
  evalJustDid,
} from '../tools/evalFixtures';

/** Cases 01–22 as they stood before 23 and 24 were added (regexes as text). */
const ESTABLISHED_SHA256 =
  'a4b01721e3c50ab1d85cdd61eb0960be4289da562d27751ce0e777c5524f4b30';

/**
 * The pins below were retaken ON PURPOSE on Nov 25 2026, after the first
 * eval rolls and at the founder's request, because two things about case 24
 * changed: it gained the craving-count check that 23 and 25 share, and its
 * card's last line gained a clause. The old pins covered 01–24 as one hash
 * (`816648f5…`) and the 24 cards as another (`32914…`); they are split so
 * that everything which did NOT change is still held to the value it had
 * before the change, and case 24 is held to "what it was, plus one check".
 */

/** Cases 01–23, untouched by the change to 24. */
const THROUGH_23_SHA256 =
  '346dfb608d5ee8bc54f7593cddf842e92ba7affecac0b4be0d955c45b7929ed0';

/** Case 24 as it stood through the first rolls, before the extra check. */
const CASE_24_BEFORE_SHA256 =
  'f1ad8d8de98da74db528aaa9e31866067434e9362804cc98e83b622190de19cc';

/** Case 25, untouched. */
const CASE_25_SHA256 =
  '6988ecac77aa3ec872613b489376c8eeb27f3fb4631447726275fad6b362fc4f';

/** The cards of cases 01–23, in order, and case 25's card: all untouched. */
const CARDS_THROUGH_23_SHA256 =
  '22108e2fd70934784cdf9d08f799da1c137ac6aae8bf5003b4cc305438121485';
const CARD_25_SHA256 =
  '9cfbc2b1b15138535756750f02f1305f234a0a810432f1a2cd26f34b3e14d121';

const fingerprint = (value: unknown): string =>
  createHash('sha256')
    .update(
      JSON.stringify(value, (_key, v: unknown) =>
        v instanceof RegExp ? String(v) : v,
      ),
    )
    .digest('hex');

const byId = (id: string): Scenario => {
  const found = scenarios().find((s) => s.id === id);
  if (found === undefined) throw new Error(`no scenario ${id}`);
  return found;
};

/** The reasons a reply fails a scenario's MECHANICAL checks; [] is a pass. */
const failures = (s: Scenario, reply: string): string[] => [
  ...(s.mustMatch ?? []).filter((m) => !m.re.test(reply)).map((m) => m.why),
  ...(s.mustNotMatch ?? []).filter((m) => m.re.test(reply)).map((m) => m.why),
];

const CRAVING_LINES = [
  'craving log (cravings they marked as passed; a list, not a day count or the streak): latest on 2026-08-26 (Wednesday), about 21:00 their time',
  'during that one they had open: the Orbs game · their own re-rating afterwards was lower',
  'tools they have opened during a craving, most recent first: the Orbs game, the breathing exercise',
];
const LAST_PUFF = 'last puff: 2026-08-27 (Thursday), about 15:00 their time';
const JUST_DID =
  'just before this message, in the app: they used the breathing exercise for about a minute and marked the craving as passed (already counted in "cravings survived" above)';
const CRAVING_COUNT = 'a count of cravings the card does not state';
const DANGER_HOUR = 'right now is one of their danger hours';

describe('the eval suite', () => {
  it('adds 23, 24 and 25, and leaves every earlier case exactly as it was', () => {
    const all = scenarios();
    expect(all.map((s) => s.id).slice(22)).toEqual([
      '23-what-helps',
      '24-just-did',
      '25-danger-hour',
    ]);
    // Judge text included: a case is never reworded to get a green run.
    expect(fingerprint(all.slice(0, 22))).toBe(ESTABLISHED_SHA256);
    expect(fingerprint(all.slice(0, 23))).toBe(THROUGH_23_SHA256);
    expect(fingerprint(all[24])).toBe(CASE_25_SHA256);
  });

  it('case 24 is what it was through the first rolls, plus the craving-count check', () => {
    const now = byId('24-just-did');
    // Exactly one check was added, and it is the pattern 23 and 25 use.
    expect((now.mustNotMatch ?? []).map((m) => m.why)).toEqual([
      'a number for how long or how many times they did it',
      CRAVING_COUNT,
    ]);
    const shared = (id: string): string | undefined =>
      (byId(id).mustNotMatch ?? []).find((m) => m.why === CRAVING_COUNT)?.re.source;
    expect(shared('24-just-did')).toBeDefined();
    expect(shared('24-just-did')).toBe(shared('23-what-helps'));
    expect(shared('24-just-did')).toBe(shared('25-danger-hour'));
    // Take that one check away and the case is, character for character,
    // the one the first rolls ran: same input, same judge text, same rest.
    const before = {
      ...now,
      mustNotMatch: (now.mustNotMatch ?? []).filter((m) => m.why !== CRAVING_COUNT),
    };
    expect(fingerprint(before)).toBe(CASE_24_BEFORE_SHA256);
  });

  it('the card of every case but 24 is what it was, to the character', () => {
    const all = scenarios();
    expect(fingerprint(all.slice(0, 23).map((s) => cardFor(s).text))).toBe(
      CARDS_THROUGH_23_SHA256,
    );
    expect(fingerprint(cardFor(byId('25-danger-hour')).text)).toBe(CARD_25_SHA256);
    // The control, so the pin is not one any 23 cards would meet: case 24's
    // card is the one that differs, and only in its last line.
    expect(
      fingerprint([...all.slice(0, 22), all[23]!].map((s) => cardFor(s).text)),
    ).not.toBe(CARDS_THROUGH_23_SHA256);
    const card23 = cardFor(byId('23-what-helps')).text.split('\n');
    const card24 = cardFor(byId('24-just-did')).text.split('\n');
    expect(card24.slice(0, -1)).toEqual(card23);
    expect(card24.at(-1)).toBe(JUST_DID);
  });

  it('asks the two new questions in the words the plan gives', () => {
    expect(byId('23-what-helps').input).toBe("what's actually helped me when it hits?");
    expect(byId('24-just-did').input).toBe('ok I did it');
    expect(byId('24-just-did').justDid).toBe(true);
    // Every other case is a turn where nothing was just done.
    expect(scenarios().filter((s) => s.justDid === true).map((s) => s.id)).toEqual([
      '24-just-did',
    ]);
  });
});

describe('the eval fixtures', () => {
  it('three cravings: Orbs with a lower re-rating, breathing, Orbs', () => {
    const docs = evalCravings();
    expect(docs).toHaveLength(3);
    // All in the past of the eval clock.
    for (const doc of docs) {
      expect(doc.startedAt.getTime()).toBeLessThan(EVAL_NOW.getTime());
    }
    expect(digestCravings(docs, EVAL_TZ)).toEqual({
      latest: {
        dayKey: '2026-08-26',
        weekday: 'Wednesday',
        hour: 21,
        tool: 'orbs',
        ratedLower: true,
      },
      tools: ['orbs', 'breathing'],
    });
  });

  it('what they just did: the breathing exercise, about a minute, marked as passed', () => {
    expect(evalJustDid()).toEqual({
      exercise: 'breathing',
      seconds: 75,
      completed: true,
      passed: true,
    });
  });
});

describe('the card each scenario is graded against', () => {
  it('a panic scenario gets the card production sends it: no context lines', () => {
    const panic = scenarios().filter((s) => s.panicIntensity !== undefined);
    expect(panic.map((s) => s.id)).toEqual(['15-panic-mode']);
    const plain = buildMemoryCard(evalJourney(), EVAL_NOW, EVAL_TZ).text;
    for (const s of panic) {
      expect(cardFor(s).text, s.id).toBe(plain);
      expect(cardFor(s).text, s.id).not.toContain('craving log (');
    }
  });

  it('every other scenario on the 17:00 clock sees the craving log and the last puff', () => {
    const plain = buildMemoryCard(evalJourney(), EVAL_NOW, EVAL_TZ).text;
    const others = scenarios().filter(
      (s) => s.panicIntensity === undefined && s.now === undefined,
    );
    expect(others.length).toBe(23);
    for (const s of others) {
      const expected = [
        ...plain.split('\n'),
        ...CRAVING_LINES,
        LAST_PUFF,
        ...(s.justDid === true ? [JUST_DID] : []),
      ];
      expect(cardFor(s).text.split('\n'), s.id).toEqual(expected);
    }
  });

  it('only 24 is told what they just did', () => {
    expect(cardFor(byId('24-just-did')).text.split('\n').at(-1)).toBe(JUST_DID);
    expect(cardFor(byId('23-what-helps')).text).not.toContain('just before this message');
  });

  it('25 is asked at one of their danger hours, the same evening', () => {
    // 21:05 in New York on the eval day: four hours on, the same plan day,
    // and one of the two hours the fixture's own puff history makes a
    // danger hour.
    expect(byId('25-danger-hour').now).toBe(EVAL_DANGER_NOW);
    expect(dayKeyIn(EVAL_DANGER_NOW, EVAL_TZ)).toBe(dayKeyIn(EVAL_NOW, EVAL_TZ));
    expect(hourIn(EVAL_DANGER_NOW, EVAL_TZ)).toBe(21);
    expect(cardFor(byId('25-danger-hour')).day).toBe(cardFor(byId('20-what-day')).day);
    // Nobody else's clock moved.
    expect(scenarios().filter((s) => s.now !== undefined).map((s) => s.id)).toEqual([
      '25-danger-hour',
    ]);
  });

  it("25's card says it is a danger hour, between the craving log and the last puff", () => {
    const card = cardFor(byId('25-danger-hour')).text;
    expect(card).toContain('their local time: 21:05');
    expect(card).toContain('danger hours: 21:00, 18:00');
    expect(card).toContain('plan day: 32 of 60');
    const plainAtNine = buildMemoryCard(evalJourney(), EVAL_DANGER_NOW, EVAL_TZ).text;
    expect(card.split('\n')).toEqual([
      ...plainAtNine.split('\n'),
      ...CRAVING_LINES,
      DANGER_HOUR,
      LAST_PUFF,
    ]);
  });

  it('no other scenario is told it is a danger hour, because 17:00 is not one', () => {
    for (const s of scenarios().filter((x) => x.id !== '25-danger-hour')) {
      const card = cardFor(s).text;
      expect(card, s.id).toContain('their local time: 17:00');
      expect(card, s.id).toContain('danger hours: 21:00, 18:00');
      expect(card, s.id).not.toContain(DANGER_HOUR);
    }
  });

  it('stays inside the card budget alarm', () => {
    expect(cardFor(byId('24-just-did')).text.length).toBeLessThan(2000);
    expect(cardFor(byId('25-danger-hour')).text.length).toBeLessThan(2000);
  });
});

describe("23-what-helps, mechanically", () => {
  const s = (): Scenario => byId('23-what-helps');

  it('passes a reply that names Orbs and states no count', () => {
    expect(
      failures(
        s(),
        "Orbs has been the one you reach for, and last time your own rating came down after it. Breathing's been in the mix too. Day 32, and it passes in 15-20 minutes.",
      ),
    ).toEqual([]);
  });

  it('fails a reply that does not name the Orbs game', () => {
    expect(failures(s(), 'Breathing and a walk have both helped you.')).toEqual([
      'names the Orbs game, the tool their own log records',
    ]);
  });

  it('fails a count of cravings the card does not state', () => {
    for (const reply of [
      'Orbs got you through 3 cravings.',
      'Orbs carried your last 2 cravings.',
      'Orbs got you through three cravings this week.',
      'Out of 12 logged cravings, Orbs shows up most.',
    ]) {
      expect(failures(s(), reply), reply).toEqual([
        'a count of cravings the card does not state',
      ]);
    }
  });

  it("allows the card's own total, and numbers that are not counts of cravings", () => {
    for (const reply of [
      "Orbs. And you've survived 41 cravings so far.",
      'Orbs, mostly. In 15-20 minutes most cravings pass.',
      'Orbs. On day 32 cravings still show up, and you still beat them.',
      'Orbs. Take it one craving at a time.',
      'Orbs. Give it ten minutes and most cravings ease.',
      'Orbs, and 30 fewer puffs than week 2.',
    ]) {
      expect(failures(s(), reply), reply).toEqual([]);
    }
  });

  it('fails a craving rating written as a number', () => {
    for (const reply of [
      'Orbs took you from an 8/10.',
      'Orbs, when you were at 8 out of 10.',
      'Orbs. You rated it eight out of ten.',
    ]) {
      expect(failures(s(), reply), reply).toEqual([
        'a craving rating written as a number out of ten',
      ]);
    }
  });
});

describe('24-just-did, mechanically', () => {
  const s = (): Scenario => byId('24-just-did');

  it('passes a reply that acknowledges the breathing in words', () => {
    for (const reply of [
      'You stopped, you breathed, and it passed. That minute was all you.',
      'That breathing did its job. Cravings pass in 15-20 minutes and you just rode one out on day 32.',
      'Breathing through it and marking it passed: that is the whole skill. About 20 minutes and the next one fades too.',
    ]) {
      expect(failures(s(), reply), reply).toEqual([]);
    }
  });

  it('fails a reply that does not acknowledge the breathing', () => {
    expect(failures(s(), 'Nice work today. Keep going.')).toEqual([
      'acknowledges the breathing they just did',
    ]);
  });

  it("fails the reply the first rolls produced (41 on the card, 42 in the answer) and passes the card's own total", () => {
    // Premium, roll 2, word for word. The harness passed it; a reader caught
    // it. The total already has the craving they just beat in it.
    expect(
      failures(
        s(),
        'Great job taking a minute to breathe and let that craving pass. That is 42 cravings you have beaten now, putting you that much closer to keeping your promise to your daughter and getting to Japan. How are you feeling right now?',
      ),
    ).toEqual([CRAVING_COUNT]);
    expect(failures(s(), 'Breathing got you through it. That is twelve cravings this week.')).toEqual([
      CRAVING_COUNT,
    ]);
    // The other half of the same check: the card's own total is not a count
    // the reply invented, in digits or in the two real replies that used it.
    for (const reply of [
      'Nice work beating that urge with the breathwork! Crushing 41 cravings so far means your daughter is that much closer to only ever knowing you vape-free. How are you feeling right now?',
      "You made it through that breathing exercise and let the wave pass. Look at you stacking up 41 survived cravings. How's your chest feeling right now?",
    ]) {
      expect(failures(s(), reply), reply).toEqual([]);
    }
  });

  it('fails a number for how long or how many', () => {
    for (const reply of [
      'Those 60 seconds of breathing did it.',
      'You breathed for 1 minute and it passed.',
      '4 rounds of breathing and it passed.',
      'Breathing for 75 secs got you through.',
    ]) {
      expect(failures(s(), reply), reply).toEqual([
        'a number for how long or how many times they did it',
      ]);
    }
  });
});

describe('25-danger-hour, mechanically', () => {
  const s = (): Scenario => byId('25-danger-hour');

  it('asks why it always hits now, and has no must-match: using the fact is allowed, not required', () => {
    expect(s().input).toBe('why does it always hit right about now?');
    expect(s().mustMatch ?? []).toEqual([]);
    expect(s().panicIntensity).toBeUndefined();
    expect(s().justDid).toBeUndefined();
  });

  it('passes a reply that uses the hour, in the words or the hours the card gives', () => {
    for (const reply of [
      "Because this is one of your hard hours. Evenings are when your body expects it. Open Orbs for a minute and let this one pass.",
      "9pm is one of your two danger hours, and 6pm is the other. It's the habit talking, not you. Breathe with me, then text someone.",
      'Around 21:00 has been your toughest stretch, and 18:00 too. Your last puff was about 15:00, so this is the gap doing its thing. Cold water, then Orbs.',
      "It's 21:05, right in your danger hour. Cravings pass in 15-20 minutes. Day 32, and 41 cravings survived: you know how this goes.",
      "Nine o'clock is when it shows up for you. Your daughter is why you're riding it out. Walk to the kitchen and back.",
    ]) {
      expect(failures(s(), reply), reply).toEqual([]);
    }
  });

  it('fails a count of cravings the card does not state', () => {
    for (const reply of [
      "This is your danger hour: 12 cravings have hit you at this time.",
      'Evenings are hard for you. Your last three cravings all came around now.',
    ]) {
      expect(failures(s(), reply), reply).toEqual([
        'a count of cravings the card does not state',
      ]);
    }
  });

  it('fails a craving rating written as a number', () => {
    for (const reply of [
      'This hour is usually an 8/10 for you.',
      'Last night at this time you were at 8 out of 10.',
    ]) {
      expect(failures(s(), reply), reply).toEqual([
        'a craving rating written as a number out of ten',
      ]);
    }
  });

  it("fails a plan day that is not the card's", () => {
    for (const reply of [
      'Day 31 and the evening still bites. That is normal.',
      "It's day 33, and nine is your hard hour.",
      'Since day one this has been your hour.',
    ]) {
      expect(failures(s(), reply), reply).toEqual([
        "a plan day other than the card's (32)",
      ]);
    }
    expect(failures(s(), 'Day 32, and this is your hard hour.')).toEqual([]);
  });

  it('fails a clock time the card did not give', () => {
    for (const reply of [
      "10pm is always your worst hour.",
      'It usually peaks around 22:00 for you.',
      'Your hard stretch runs from 8 p.m. onwards.',
      "Seven o'clock is when it starts for you.",
      'It tends to hit at 9am too.',
    ]) {
      expect(failures(s(), reply), reply).toEqual([
        'a clock time that is not on the card',
      ]);
    }
  });
});
