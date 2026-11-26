/**
 * Coach cards, server side: what the app said it can draw, who may see a
 * card, and which cards a reply carries.
 *
 * The fourteen files in `test/fixtures/coach_ui/` are the contract with the
 * app. The Dart suite `test/fixtures/coach_ui_fixtures_test.dart` feeds the
 * same `blocks` through the app's codec and its real card renderer, and pins
 * the fake backend to them; this suite pins the policy that produces them. A
 * fixture is never edited to make one side pass.
 *
 * No model is involved anywhere in here, which is the point: the cards are
 * decided by code, so they cost nothing and cannot be talked out of a rule.
 */
import {readdirSync, readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {describe, expect, it} from 'vitest';
import {
  coachUiAudience,
  parseUiCapabilities,
  planBlocks,
  uiEnvelope,
  type Block,
  type PlanInput,
} from '../src/ai/coachUi';
import {COACH_UI_AUDIENCE} from '../src/config';
import {EXERCISE_IDS, exerciseById, type ExerciseId} from '../src/domain/exercises';
import {COACH_CHIPS, SUBSCRIPTION_TIERS} from '../src/domain/types';

const FIXTURES = resolve(__dirname, 'fixtures/coach_ui');

interface Fixture {
  input: PlanInput;
  blocks: Block[];
}

/** The folder also holds `README.md`; only `*.json` is a fixture. */
function fixtureNames(): string[] {
  return readdirSync(FIXTURES)
    .filter((name) => name.endsWith('.json'))
    .sort();
}

function readFixture(name: string): Fixture {
  return JSON.parse(readFileSync(resolve(FIXTURES, name), 'utf8')) as Fixture;
}

const ALL_FIVE: readonly ExerciseId[] = [...EXERCISE_IDS];

/** A subscriber on a current app, saying nothing in particular. */
function input(over: Partial<PlanInput> = {}): PlanInput {
  return {
    audience: 'premium',
    tier: 'premium',
    chip: null,
    panicIntensity: null,
    caps: {exercises: ALL_FIVE, craving: false},
    recentTools: [],
    ...over,
  };
}

const launchers = (blocks: readonly Block[]): string[] =>
  blocks.map((b) => b.exercise);

/**
 * Every combination the handler can hand the policy: tier × audience × chip
 * × panic × the app's craving flag × three capability lists × three craving
 * histories. 1,620 inputs; the policy is pure, so this costs milliseconds.
 */
function everyInput(): PlanInput[] {
  const capabilityLists: readonly (readonly ExerciseId[])[] = [
    ALL_FIVE,
    // Only the locked games: a free account is left with nothing to offer.
    ['tiles', 'blocks'],
    // Listed out of registry order, and without the calm row.
    ['sos', 'orbs'],
  ];
  const histories: readonly (readonly ExerciseId[])[] = [
    [],
    // A second game used most recently. Before the menu skipped the kind
    // the latest tool already covers, this was Tiles, breathing and Orbs:
    // two games, and nobody to ask.
    ['tiles'],
    ['orbs', 'breathing'],
  ];
  const out: PlanInput[] = [];
  for (const tier of SUBSCRIPTION_TIERS) {
    for (const audience of ['off', 'premium', 'all'] as const) {
      for (const chip of [...COACH_CHIPS, null]) {
        for (const panicIntensity of [null, 8]) {
          for (const craving of [false, true]) {
            for (const exercises of capabilityLists) {
              for (const recentTools of histories) {
                out.push({
                  audience,
                  tier,
                  chip,
                  panicIntensity,
                  caps: {exercises, craving},
                  recentTools,
                });
              }
            }
          }
        }
      }
    }
  }
  return out;
}

describe('planBlocks', () => {
  it('every fixture', () => {
    const names = fixtureNames();
    // Fourteen is the set the Dart suite pins by name. Fewer here means a
    // file went missing on this side only, and the two would stop agreeing
    // without either suite saying so.
    expect(names.length).toBeGreaterThanOrEqual(14);
    for (const name of names) {
      const fixture = readFixture(name);
      expect(planBlocks(fixture.input), name).toEqual(fixture.blocks);
    }
  });

  it('never more than one card in a craving, never more than three otherwise', () => {
    const inputs = everyInput();
    expect(inputs).toHaveLength(1620);
    let craving = 0;
    let menus = 0;
    for (const i of inputs) {
      const blocks = planBlocks(i);
      const inCraving = i.panicIntensity !== null || i.caps?.craving === true;
      if (inCraving) {
        expect(blocks.length, JSON.stringify(i)).toBeLessThanOrEqual(1);
        craving += blocks.length;
      } else {
        expect(blocks.length, JSON.stringify(i)).toBeLessThanOrEqual(3);
        if (blocks.length > 1) menus += 1;
      }
    }
    // The bounds above are met by a policy that returns nothing at all, so
    // prove both branches actually produced cards.
    expect(craving).toBeGreaterThan(0);
    expect(menus).toBeGreaterThan(0);
  });

  it('a card is something the app listed, the tier can open, and an id and nothing else', () => {
    let seen = 0;
    for (const i of everyInput()) {
      const blocks = planBlocks(i);
      const ids = launchers(blocks);
      expect(new Set(ids).size, JSON.stringify(i)).toBe(ids.length);
      // One card per kind: a menu is something calm, something to do with
      // your hands and somebody to ask, never two of one.
      const kinds = ids.map((id) => exerciseById(id)?.kind);
      expect(new Set(kinds).size, JSON.stringify(i)).toBe(kinds.length);
      for (const block of blocks) {
        seen += 1;
        // Never a route, a URL, a number, a label or a colour.
        expect(Object.keys(block).sort()).toEqual(['exercise', 't']);
        expect(block.t).toBe('launcher');
        expect(i.caps?.exercises, JSON.stringify(i)).toContain(block.exercise);
        // Nobody lands on a lock: a free account is never handed a Premium
        // exercise, whatever the audience says and whatever they used before.
        if (i.tier === 'free') {
          expect(exerciseById(block.exercise)?.premium, JSON.stringify(i)).toBe(false);
        }
      }
    }
    expect(seen).toBeGreaterThan(0);
  });

  it('the audience decides who sees a card at all', () => {
    for (const i of everyInput()) {
      const blocks = planBlocks(i);
      if (i.audience === 'off') expect(blocks, JSON.stringify(i)).toEqual([]);
      if (i.audience === 'premium' && i.tier === 'free') {
        expect(blocks, JSON.stringify(i)).toEqual([]);
      }
    }
    // And `all` really does reach a free account, with the free exercises.
    expect(
      launchers(planBlocks(input({audience: 'all', tier: 'free', chip: 'craving'}))),
    ).toEqual(['breathing', 'orbs', 'sos']);
  });

  it('a craving chip tapped inside a craving is still one card', () => {
    // The second and third message of a craving chat: one next step each
    // time, never the three-card menu again.
    expect(
      launchers(
        planBlocks(
          input({chip: 'craving', caps: {exercises: ALL_FIVE, craving: true}}),
        ),
      ),
    ).toEqual(['breathing']);
    expect(
      launchers(planBlocks(input({chip: 'craving', panicIntensity: 8}))),
    ).toEqual(['breathing']);
  });

  it('the menu keeps somebody to ask when the latest tool is a second game', () => {
    // Founder decision, Nov 25 2026: the latest tool leads, and its kind is
    // then skipped, so the people card is not pushed off by a second game.
    expect(
      launchers(planBlocks(input({chip: 'craving', recentTools: ['blocks']}))),
    ).toEqual(['blocks', 'breathing', 'sos']);
    expect(
      launchers(planBlocks(input({chip: 'craving', recentTools: ['tiles', 'orbs']}))),
    ).toEqual(['tiles', 'breathing', 'sos']);
    // The latest tool covering the calm or the people kind works the same.
    expect(
      launchers(planBlocks(input({chip: 'craving', recentTools: ['sos']}))),
    ).toEqual(['sos', 'breathing', 'orbs']);
    expect(
      launchers(planBlocks(input({chip: 'craving', recentTools: ['breathing']}))),
    ).toEqual(['breathing', 'orbs', 'sos']);
  });

  it('offers cards in registry order, whatever order the app listed them in', () => {
    expect(
      launchers(
        planBlocks(
          input({
            chip: 'craving',
            caps: {
              exercises: ['sos', 'blocks', 'tiles', 'orbs', 'breathing'],
              craving: false,
            },
          }),
        ),
      ),
    ).toEqual(['breathing', 'orbs', 'sos']);
  });

  it('in a craving with no calm exercise on offer, the first one the app can draw', () => {
    expect(
      launchers(
        planBlocks(
          input({panicIntensity: 8, caps: {exercises: ['sos', 'orbs'], craving: false}}),
        ),
      ),
    ).toEqual(['orbs']);
  });

  it('ignores a recent tool this app cannot draw or this tier cannot open', () => {
    // Raw strings off a craving doc, not a typed list: an id from a newer
    // build must be skipped, never offered.
    const recentTools = ['teleport', 'tiles', 'orbs'] as unknown as ExerciseId[];
    expect(
      launchers(
        planBlocks(input({audience: 'all', tier: 'free', panicIntensity: 8, recentTools})),
      ),
    ).toEqual(['orbs']);
  });
});

describe('parseUiCapabilities', () => {
  it('reads nothing from an app that said nothing it can use', () => {
    for (const raw of [undefined, null, 'x', [], {exercises: 'x'}, {v: 1}]) {
      expect(parseUiCapabilities(raw), JSON.stringify(raw)).toBeNull();
    }
  });

  it('keeps the ids the registry knows, once each, and a craving only when it is exactly true', () => {
    expect(
      parseUiCapabilities({
        v: 1,
        exercises: ['orbs', 'teleport', 7, 'orbs'],
        craving: 'yes',
      }),
    ).toEqual({exercises: ['orbs'], craving: false});
  });

  it('reads the craving flag when the app set it', () => {
    expect(
      parseUiCapabilities({v: 1, exercises: [...ALL_FIVE], craving: true}),
    ).toEqual({exercises: [...ALL_FIVE], craving: true});
  });

  it('reads only the first 32 ids of a longer list', () => {
    // Forty entries. The 32nd is `orbs`; `breathing` is the 33rd and `sos`
    // fills the rest, so anything past the bound would show up by name.
    const exercises: unknown[] = [
      ...Array<string>(31).fill('teleport'),
      'orbs',
      'breathing',
      ...Array<string>(7).fill('sos'),
    ];
    expect(exercises).toHaveLength(40);
    expect(parseUiCapabilities({v: 1, exercises, craving: false})).toEqual({
      exercises: ['orbs'],
      craving: false,
    });
  });

  it('still reads a list from a newer version of the wire', () => {
    expect(
      parseUiCapabilities({v: 2, exercises: ['orbs', 'sos'], craving: false, later: {x: 1}}),
    ).toEqual({exercises: ['orbs', 'sos'], craving: false});
  });
});

describe('coachUiAudience', () => {
  it('is premium for the word, for an unset param, and for anything it does not know', () => {
    // '' is what a deploy-time param resolves to when nothing supplies it. A
    // switch that read that as `off` would take the feature away from every
    // project whose .env never named it; one that read it as `all` would
    // give a Premium feature to everybody.
    for (const raw of ['', 'premium', 'true', 'nonsense']) {
      expect(coachUiAudience(raw), JSON.stringify(raw)).toBe('premium');
    }
  });

  it('is off for exactly that word, whatever its case or padding', () => {
    for (const raw of ['off', ' OFF ']) {
      expect(coachUiAudience(raw), JSON.stringify(raw)).toBe('off');
    }
  });

  it('is all for exactly that word, whatever its case', () => {
    for (const raw of ['all', 'All']) {
      expect(coachUiAudience(raw), JSON.stringify(raw)).toBe('all');
    }
  });

  it('the param is COACH_UI_AUDIENCE, and it defaults to premium', () => {
    expect(COACH_UI_AUDIENCE.name).toBe('COACH_UI_AUDIENCE');
    expect(COACH_UI_AUDIENCE.options.default).toBe('premium');
    // The state this very process is in: no .env loaded.
    expect(
      coachUiAudience(process.env[COACH_UI_AUDIENCE.name] ?? ''),
    ).toBe(coachUiAudience(COACH_UI_AUDIENCE.value()));
  });
});

describe('uiEnvelope', () => {
  it('is nothing at all when there are no cards', () => {
    // Spread into the reply, so an empty list adds no key: the envelope an
    // older app, a free account and an ordinary message get is today's.
    expect(uiEnvelope([])).toEqual({});
    expect(Object.keys(uiEnvelope([]))).toEqual([]);
  });

  it('wraps the cards with the version the app reads', () => {
    const blocks: Block[] = [{t: 'launcher', exercise: 'orbs'}];
    expect(uiEnvelope(blocks)).toEqual({
      ui: {v: 1, blocks: [{t: 'launcher', exercise: 'orbs'}]},
    });
  });

  it('never sends more than four', () => {
    // K3's bound, which the app's decoder also applies. The policy stops at
    // three; this is the guarantee standing behind it.
    const five: Block[] = EXERCISE_IDS.map((exercise) => ({t: 'launcher', exercise}));
    expect(five).toHaveLength(5);
    expect(uiEnvelope(five)).toEqual({ui: {v: 1, blocks: five.slice(0, 4)}});
  });
});
