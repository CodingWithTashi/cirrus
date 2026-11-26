/**
 * What Ember is told about cravings: a handful of stored facts, in words.
 *
 * `users/{uid}/cravings` was written by `panicSession` and read by nothing
 * but the erasure path, so the coach knew one total and nothing else. This is
 * the reading side, and it is deliberately narrow. Every line is something a
 * document says outright: when the latest craving they marked as passed was,
 * what they had open, whether THEIR OWN second rating was lower than their
 * first, which tools they have opened. Never a count, never a rating written
 * out as a number, and never a strength nobody gave.
 *
 * The strings are asserted exactly. They are prompt text: the eval rolls are
 * run against these words, so a reworded line is a line nobody has graded.
 */
import {describe, expect, it} from 'vitest';
import {
  cravingLines,
  digestCravings,
  justDidLine,
  parseJustDid,
  type CravingDoc,
  type JustDid,
} from '../src/ai/cravingDigest';
import {EXERCISE_IDS, EXERCISE_LABELS} from '../src/domain/exercises';

const TZ = 'America/New_York';

/** 21:20 on Tuesday Nov 24 2026 in New York; already Wednesday in UTC. */
const LATEST = '2026-11-25T02:20:00.000Z';

function doc(iso: string, over: Partial<CravingDoc> = {}): CravingDoc {
  return {
    startedAt: new Date(iso),
    intensity: null,
    intensityAfter: null,
    exercise: null,
    game: null,
    ...over,
  };
}

/** Orbs with a lower re-rating, then breathing, then Orbs again. */
const THREE: readonly CravingDoc[] = [
  doc(LATEST, {intensity: 8, intensityAfter: 4, exercise: 'orbs', game: 'orbs'}),
  doc('2026-11-23T18:05:00.000Z', {exercise: 'breathing'}),
  doc('2026-11-21T01:40:00.000Z', {intensity: 6, game: 'orbs'}),
];

const LINE_1 =
  'craving log (cravings they marked as passed; a list, not a day count or the streak): ' +
  'latest on 2026-11-24 (Tuesday), about 21:00 their time';
const LINE_2 =
  'during that one they had open: the Orbs game · their own re-rating afterwards was lower';
const LINE_3 =
  'tools they have opened during a craving, most recent first: the Orbs game, the breathing exercise';

describe('digestCravings', () => {
  it('orders by startedAt, whatever order the docs arrive in', () => {
    const shuffled = [THREE[1]!, THREE[2]!, THREE[0]!];
    const digest = digestCravings(shuffled, TZ);
    expect(digest.latest).toEqual({
      dayKey: '2026-11-24',
      weekday: 'Tuesday',
      hour: 21,
      tool: 'orbs',
      ratedLower: true,
    });
    expect(digest.tools).toEqual(['orbs', 'breathing']);
  });

  it('reads the day, the weekday and the hour in their timezone', () => {
    // The same instant is 02:20 on Wednesday in UTC. A craving at nine in
    // the evening must not be described as one at two in the morning.
    expect(digestCravings([doc(LATEST)], 'UTC').latest).toEqual({
      dayKey: '2026-11-25',
      weekday: 'Wednesday',
      hour: 2,
      tool: null,
      ratedLower: false,
    });
    expect(digestCravings([doc(LATEST)], TZ).latest?.dayKey).toBe('2026-11-24');
  });

  it('a tool is the exercise, and the game when an older app sent only that', () => {
    expect(digestCravings([doc(LATEST, {game: 'tiles'})], TZ).latest?.tool).toBe('tiles');
    // Both set: the exercise is what they had open.
    expect(
      digestCravings([doc(LATEST, {exercise: 'breathing', game: 'orbs'})], TZ).latest?.tool,
    ).toBe('breathing');
    expect(digestCravings([doc(LATEST)], TZ)).toEqual({
      latest: {dayKey: '2026-11-24', weekday: 'Tuesday', hour: 21, tool: null, ratedLower: false},
      tools: [],
    });
  });

  it('skips a tool id it does not know', () => {
    const digest = digestCravings(
      [
        doc(LATEST, {exercise: 'teleport'}),
        doc('2026-11-23T18:05:00.000Z', {exercise: 'sos'}),
        doc('2026-11-22T18:05:00.000Z', {game: 'hexes'}),
      ],
      TZ,
    );
    // The latest craving is still the latest; it just names no tool.
    expect(digest.latest?.dayKey).toBe('2026-11-24');
    expect(digest.latest?.tool).toBeNull();
    expect(digest.tools).toEqual(['sos']);
  });

  it('lists each tool once, most recent first', () => {
    const digest = digestCravings(
      [
        doc('2026-11-20T18:00:00.000Z', {exercise: 'tiles'}),
        doc('2026-11-24T18:00:00.000Z', {exercise: 'sos'}),
        doc('2026-11-22T18:00:00.000Z', {exercise: 'tiles'}),
        doc('2026-11-23T18:00:00.000Z', {game: 'orbs'}),
        doc('2026-11-21T18:00:00.000Z', {exercise: 'sos'}),
      ],
      TZ,
    );
    expect(digest.tools).toEqual(['sos', 'orbs', 'tiles']);
  });

  it('a re-rating was lower only when both ratings exist and the second is below the first', () => {
    const lower = (intensity: number | null, intensityAfter: number | null): boolean =>
      digestCravings([doc(LATEST, {intensity, intensityAfter})], TZ).latest!.ratedLower;
    expect(lower(8, 4)).toBe(true);
    expect(lower(8, 8)).toBe(false);
    expect(lower(4, 8)).toBe(false);
    // A strength nobody gave is not a strength that dropped.
    expect(lower(null, 3)).toBe(false);
    expect(lower(8, null)).toBe(false);
    expect(lower(null, null)).toBe(false);
  });

  it('no cravings is an empty digest, not a guess', () => {
    expect(digestCravings([], TZ)).toEqual({latest: null, tools: []});
  });
});

describe('cravingLines', () => {
  it('all three lines, exactly', () => {
    expect(cravingLines(digestCravings(THREE, TZ))).toEqual([LINE_1, LINE_2, LINE_3]);
  });

  it('says nothing at all when there is no craving on record', () => {
    expect(cravingLines(digestCravings([], TZ))).toEqual([]);
  });

  it('the first line needs one craving and nothing else', () => {
    expect(cravingLines(digestCravings([doc(LATEST)], TZ))).toEqual([LINE_1]);
  });

  it('the second line needs the latest craving to name a tool', () => {
    // Without a tool there is no line 2, even when their re-rating was lower:
    // the clause hangs off the tool and is never stated alone.
    expect(
      cravingLines(digestCravings([doc(LATEST, {intensity: 8, intensityAfter: 4})], TZ)),
    ).toEqual([LINE_1]);
    // A tool on an OLDER craving does not put words in the latest one's mouth.
    expect(
      cravingLines(
        digestCravings(
          [doc(LATEST), doc('2026-11-23T18:05:00.000Z', {exercise: 'orbs'})],
          TZ,
        ),
      ),
    ).toEqual([LINE_1]);
  });

  it('the re-rating clause is there only when their own second rating was lower', () => {
    expect(
      cravingLines(digestCravings([doc(LATEST, {exercise: 'orbs'})], TZ)),
    ).toEqual([LINE_1, 'during that one they had open: the Orbs game']);
    expect(
      cravingLines(
        digestCravings([doc(LATEST, {exercise: 'orbs', intensity: 5, intensityAfter: 5})], TZ),
      ),
    ).toEqual([LINE_1, 'during that one they had open: the Orbs game']);
    expect(
      cravingLines(
        digestCravings([doc(LATEST, {exercise: 'orbs', intensity: 8, intensityAfter: 4})], TZ),
      ),
    ).toEqual([LINE_1, LINE_2]);
  });

  it('the third line needs two different tools', () => {
    const once = [
      doc(LATEST, {exercise: 'orbs'}),
      doc('2026-11-23T18:05:00.000Z', {game: 'orbs'}),
    ];
    expect(cravingLines(digestCravings(once, TZ))).toEqual([
      LINE_1,
      'during that one they had open: the Orbs game',
    ]);
    expect(
      cravingLines(
        digestCravings([...once, doc('2026-11-22T18:05:00.000Z', {exercise: 'breathing'})], TZ),
      ),
    ).toEqual([LINE_1, 'during that one they had open: the Orbs game', LINE_3]);
  });

  it('names every tool through the registry labels', () => {
    for (const id of EXERCISE_IDS) {
      expect(
        cravingLines(digestCravings([doc(LATEST, {exercise: id})], TZ))[1],
        id,
      ).toBe(`during that one they had open: ${EXERCISE_LABELS[id]}`);
    }
  });

  it('no craving line carries a count', () => {
    // Ten histories, one craving to twelve. However many there are, the
    // lines must read the same: a number here is one the model can quote
    // back as "your 9 cravings", or mistake for the day.
    const tools = ['orbs', 'breathing', 'tiles', 'sos', 'blocks'];
    const seconds = [0, 12, 44, 45, 60, 90, 91, 600, 3599, 3600];
    const sizes = [1, 2, 3, 4, 5, 6, 7, 8, 10, 12];
    expect(sizes).toHaveLength(10);
    for (const [n, size] of sizes.entries()) {
      const docs = Array.from({length: size}, (_, i) =>
        doc(new Date(Date.parse(LATEST) - i * 26 * 3_600_000).toISOString(), {
          intensity: 10 - (i % 4),
          intensityAfter: 3 + (i % 3),
          exercise: tools[(i + n) % tools.length]!,
        }),
      );
      const justDid: JustDid = {
        exercise: EXERCISE_IDS[n % EXERCISE_IDS.length]!,
        seconds: seconds[n]!,
        completed: n % 2 === 0,
        passed: n % 3 !== 0,
      };
      const lines = [...cravingLines(digestCravings(docs, TZ)), justDidLine(justDid)];
      expect(lines.length, `${size} docs`).toBeGreaterThanOrEqual(3);
      for (const line of lines) {
        const bare = line
          .replace(/\d{4}-\d{2}-\d{2}/g, '')
          .replace(/\d{1,2}:00/g, '');
        expect(bare, `${size} docs: ${line}`).not.toMatch(/\d/);
      }
    }
  });
});

describe('parseJustDid', () => {
  it('reads what the app reports about the exercise they just finished', () => {
    expect(
      parseJustDid({exercise: 'breathing', seconds: 62, completed: true, passed: true}),
    ).toEqual({exercise: 'breathing', seconds: 62, completed: true, passed: true});
  });

  it('refuses an exercise the registry does not hold', () => {
    for (const exercise of ['teleport', '', 7, null, undefined, ['orbs']]) {
      expect(
        parseJustDid({exercise, seconds: 60, completed: true, passed: true}),
        JSON.stringify(exercise),
      ).toBeNull();
    }
  });

  it('refuses seconds that are not a number', () => {
    for (const seconds of ['60', null, undefined, Number.NaN, Number.POSITIVE_INFINITY, {}]) {
      expect(
        parseJustDid({exercise: 'orbs', seconds, completed: true, passed: true}),
        typeof seconds,
      ).toBeNull();
    }
  });

  it('clamps seconds to between nothing and an hour', () => {
    const secondsOf = (seconds: number): number | undefined =>
      parseJustDid({exercise: 'orbs', seconds, completed: false, passed: false})?.seconds;
    expect(secondsOf(-5)).toBe(0);
    expect(secondsOf(0)).toBe(0);
    expect(secondsOf(3600)).toBe(3600);
    expect(secondsOf(999_999)).toBe(3600);
    // A whole number of seconds, whatever was sent.
    expect(secondsOf(61.9)).toBe(61);
  });

  it('counts completed and passed only when they are exactly true', () => {
    expect(
      parseJustDid({exercise: 'orbs', seconds: 60, completed: 'yes', passed: 1}),
    ).toEqual({exercise: 'orbs', seconds: 60, completed: false, passed: false});
    expect(parseJustDid({exercise: 'orbs', seconds: 60})).toEqual({
      exercise: 'orbs',
      seconds: 60,
      completed: false,
      passed: false,
    });
  });

  it('reads nothing from anything that is not that shape', () => {
    for (const raw of [undefined, null, 'x', 7, [], {}]) {
      expect(parseJustDid(raw), JSON.stringify(raw)).toBeNull();
    }
  });
});

describe('justDidLine', () => {
  const line = (over: Partial<JustDid> = {}): string =>
    justDidLine({exercise: 'breathing', seconds: 60, completed: true, passed: true, ...over});

  it('the line, exactly', () => {
    expect(line()).toBe(
      'just before this message, in the app: they used the breathing exercise ' +
        'for about a minute and marked the craving as passed ' +
        '(already counted in "cravings survived" above)',
    );
  });

  it('says the craving is already in the total, in the card\'s own words for it', () => {
    // The first eval rolls: with "marked the craving as passed" a few lines
    // under `cravings survived: 41`, the premium model answered "That is 42
    // cravings you have beaten now". The app raises the total when "It
    // passed" is tapped, so the number on the card already has this one in
    // it. The label in quotes is the card's own, character for character.
    expect(line()).toMatch(/passed \(already counted in "cravings survived" above\)$/);
    expect(line({exercise: 'orbs', seconds: 600})).toBe(
      'just before this message, in the app: they used the Orbs game ' +
        'for a few minutes and marked the craving as passed ' +
        '(already counted in "cravings survived" above)',
    );
  });

  it('says they marked it as passed only when they did', () => {
    expect(line({passed: false})).toBe(
      'just before this message, in the app: they used the breathing exercise for about a minute',
    );
    // Running it to the end is not the same as saying the craving passed,
    // and with nothing passed there is nothing to say was counted.
    expect(line({passed: false, completed: true})).not.toContain('passed');
    expect(line({passed: false, completed: true})).not.toContain('counted');
  });

  it('puts the time in words: under 45 s, 45 to 90 s, longer', () => {
    const duration = (seconds: number): string =>
      line({seconds, passed: false}).replace(
        'just before this message, in the app: they used the breathing exercise ',
        '',
      );
    expect(duration(0)).toBe('for less than a minute');
    expect(duration(44)).toBe('for less than a minute');
    expect(duration(45)).toBe('for about a minute');
    expect(duration(90)).toBe('for about a minute');
    expect(duration(91)).toBe('for a few minutes');
    expect(duration(3600)).toBe('for a few minutes');
  });

  it('names the exercise through the registry labels', () => {
    expect(line({exercise: 'orbs', passed: false})).toBe(
      'just before this message, in the app: they used the Orbs game for about a minute',
    );
  });
});
