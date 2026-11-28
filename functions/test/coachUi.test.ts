/**
 * Coach cards, server side: what the app said it can draw, who may see a
 * card, and which cards a reply carries.
 *
 * The eighteen files in `test/fixtures/coach_ui/` are the contract with the
 * app. The Dart suite `test/fixtures/coach_ui_fixtures_test.dart` feeds the
 * same `blocks` through the app's codec and its real card renderer, and pins
 * the fake backend to them; this suite pins the policy that produces them. A
 * fixture is never edited to make one side pass.
 *
 * No model is involved anywhere in here. The one thing a model contributes
 * is `suggested`: the exercises the follow-up call said the reply is about.
 * Here that is a plain list of ids like any other input, and the suite's
 * point is that code still decides: a name the app cannot draw, the tier
 * cannot open or the audience does not admit never becomes a card.
 */
import {readdirSync, readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {describe, expect, it} from 'vitest';
import {
  coachUiAudience,
  nameableExercises,
  parseSuggestedExercises,
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
    suggested: [],
    ...over,
  };
}

const launchers = (blocks: readonly Block[]): string[] =>
  blocks.map((b) => b.exercise);

/**
 * Every combination the handler can hand the policy: tier × audience × chip
 * × panic × the app's craving flag × three capability lists × three craving
 * histories × three things the reply might have been about. 4,860 inputs;
 * the policy is pure, so this costs milliseconds.
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
  const namings: readonly (readonly ExerciseId[])[] = [
    [],
    ['orbs'],
    // Two games, a repeat, and more names than a menu holds.
    ['tiles', 'blocks', 'sos', 'breathing', 'tiles'],
  ];
  const out: PlanInput[] = [];
  for (const tier of SUBSCRIPTION_TIERS) {
    for (const audience of ['off', 'premium', 'all'] as const) {
      for (const chip of [...COACH_CHIPS, null]) {
        for (const panicIntensity of [null, 8]) {
          for (const craving of [false, true]) {
            for (const exercises of capabilityLists) {
              for (const recentTools of histories) {
                for (const suggested of namings) {
                  out.push({
                    audience,
                    tier,
                    chip,
                    panicIntensity,
                    caps: {exercises, craving},
                    recentTools,
                    suggested,
                  });
                }
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
    // Eighteen is the set the Dart suite pins by name. Fewer here means a
    // file went missing on this side only, and the two would stop agreeing
    // without either suite saying so.
    expect(names.length).toBeGreaterThanOrEqual(18);
    for (const name of names) {
      const fixture = readFixture(name);
      expect(planBlocks(fixture.input), name).toEqual(fixture.blocks);
    }
  });

  it('never more than one card in a craving, never more than three otherwise', () => {
    const inputs = everyInput();
    expect(inputs).toHaveLength(4860);
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

  it('an ordinary message gets the exercise its reply was about', () => {
    // The turn this exists for: the coach offers a breath, the person says
    // "let's do it now", and the breathing exercise is one tap away.
    expect(launchers(planBlocks(input({suggested: ['breathing']})))).toEqual([
      'breathing',
    ]);
    expect(launchers(planBlocks(input({chip: 'roughDay', suggested: ['sos']})))).toEqual([
      'sos',
    ]);
    // And still nothing when the reply was about none of them.
    expect(planBlocks(input())).toEqual([]);
  });

  it('several named: one of each kind, at most three, laid out calm first', () => {
    // The model says which; the order is the registry's, as it is for the
    // craving menu. Of two games the one named first is kept.
    expect(
      launchers(planBlocks(input({suggested: ['orbs', 'tiles', 'sos', 'breathing']}))),
    ).toEqual(['breathing', 'orbs', 'sos']);
    expect(
      launchers(planBlocks(input({suggested: ['tiles', 'orbs', 'sos']}))),
    ).toEqual(['tiles', 'sos']);
    // Somebody about to vape: the breath comes before the post, whichever
    // the model thought of first.
    expect(
      launchers(planBlocks(input({suggested: ['sos', 'sos', 'breathing']}))),
    ).toEqual(['breathing', 'sos']);
  });

  it('a name the tier cannot open, or the app did not list, becomes one of its kind that it can', () => {
    // A free account is never handed a lock: "a game" is the free game.
    expect(
      launchers(planBlocks(input({audience: 'all', tier: 'free', suggested: ['tiles']}))),
    ).toEqual(['orbs']);
    // A subscriber on a build that only draws Orbs.
    expect(
      launchers(
        planBlocks(
          input({caps: {exercises: ['orbs'], craving: false}, suggested: ['blocks']}),
        ),
      ),
    ).toEqual(['orbs']);
    // Nothing of that kind on offer is no card, never a different kind.
    expect(
      planBlocks(
        input({caps: {exercises: ['sos', 'orbs'], craving: false}, suggested: ['breathing']}),
      ),
    ).toEqual([]);
  });

  it('a name the registry does not hold is ignored', () => {
    const suggested = ['teleport', 7, null, 'sos'] as unknown as ExerciseId[];
    expect(launchers(planBlocks(input({suggested})))).toEqual(['sos']);
    expect(
      planBlocks(input({suggested: ['teleport'] as unknown as ExerciseId[]})),
    ).toEqual([]);
  });

  it('in a craving the one card is the exercise the reply named', () => {
    const inCraving = {exercises: ALL_FIVE, craving: true};
    // "Open Orbs with me" beside a breathing card is two different next
    // steps. The reply's own exercise leads; still exactly one.
    expect(
      launchers(
        planBlocks(
          input({caps: inCraving, recentTools: ['breathing'], suggested: ['orbs', 'sos']}),
        ),
      ),
    ).toEqual(['orbs']);
    // Nothing named: what they used last, as before.
    expect(
      launchers(planBlocks(input({caps: inCraving, recentTools: ['orbs']}))),
    ).toEqual(['orbs']);
  });

  it('the craving chip is the same menu whatever the reply named', () => {
    expect(
      launchers(planBlocks(input({chip: 'craving', suggested: ['sos']}))),
    ).toEqual(['breathing', 'orbs', 'sos']);
  });

  it('a name never gets a card past the audience, the tier or an app that said nothing', () => {
    const suggested: ExerciseId[] = ['breathing'];
    expect(planBlocks(input({audience: 'off', suggested}))).toEqual([]);
    expect(planBlocks(input({tier: 'free', suggested}))).toEqual([]);
    expect(planBlocks(input({caps: null, suggested}))).toEqual([]);
  });
});

describe('nameableExercises', () => {
  it('is what this person could be shown, in registry order', () => {
    expect(nameableExercises(input())).toEqual(ALL_FIVE);
    expect(nameableExercises(input({audience: 'all', tier: 'free'}))).toEqual([
      'breathing', 'orbs', 'sos',
    ]);
    expect(
      nameableExercises(input({caps: {exercises: ['sos', 'orbs'], craving: false}})),
    ).toEqual(['orbs', 'sos']);
  });

  it('is nothing when no card could come of a name', () => {
    // Nobody is asked to name an exercise the reply cannot carry: the
    // follow-up call then goes out exactly as it did before cards existed.
    expect(nameableExercises(input({caps: null}))).toEqual([]);
    expect(nameableExercises(input({audience: 'off'}))).toEqual([]);
    expect(nameableExercises(input({tier: 'free'}))).toEqual([]);
    expect(
      nameableExercises(input({caps: {exercises: [], craving: false}})),
    ).toEqual([]);
    // The craving chip's menu is fixed, so a name would change nothing.
    expect(nameableExercises(input({chip: 'craving'}))).toEqual([]);
  });

  it('is still asked inside a craving, where the name picks the one card', () => {
    expect(
      nameableExercises(
        input({chip: 'craving', caps: {exercises: ALL_FIVE, craving: true}}),
      ),
    ).toEqual(ALL_FIVE);
  });

  it('agrees with the policy: a name outside it never shows, a name inside it does', () => {
    for (const i of everyInput()) {
      const nameable = nameableExercises(i);
      if (nameable.length === 0) {
        // Whatever was named, the answer is what it would have been anyway.
        expect(planBlocks(i), JSON.stringify(i)).toEqual(
          planBlocks({...i, suggested: []}),
        );
        continue;
      }
      for (const id of nameable) {
        expect(
          launchers(planBlocks({...i, suggested: [id]})),
          JSON.stringify(i),
        ).toEqual([id]);
      }
    }
  });
});

describe('parseSuggestedExercises', () => {
  it('reads the ids the follow-up call named', () => {
    expect(
      parseSuggestedExercises('{"followUps":["that helped"],"exercises":["breathing"]}'),
    ).toEqual(['breathing']);
    expect(
      parseSuggestedExercises('```json\n{"exercises":["orbs","sos"]}\n```'),
    ).toEqual(['orbs', 'sos']);
  });

  it('keeps only ids the registry holds, once each, whatever their case', () => {
    expect(
      parseSuggestedExercises(
        '{"exercises":[" Breathing","teleport",7,"breathing","orbs","sos","tiles"]}',
      ),
    ).toEqual(['breathing', 'orbs', 'sos', 'tiles']);
  });

  it('does not cut the list to a menu: the policy does, after one per kind', () => {
    // Two games first. Stopping at three names here would hand the policy
    // Orbs, Tiles and SOS, and the breathing card would be lost to a second
    // game the policy drops anyway.
    const named = parseSuggestedExercises(
      '{"exercises":["orbs","tiles","sos","breathing"]}',
    );
    expect(named).toEqual(['orbs', 'tiles', 'sos', 'breathing']);
    expect(launchers(planBlocks(input({suggested: named})))).toEqual([
      'breathing', 'orbs', 'sos',
    ]);
  });

  it('reads only the first eight entries of a longer list', () => {
    const exercises = [...Array<string>(8).fill('teleport'), 'breathing'];
    expect(parseSuggestedExercises(JSON.stringify({exercises}))).toEqual([]);
  });

  it('is nothing for anything that is not a list of ids', () => {
    for (const raw of [
      '',
      'not json',
      'null',
      '[]',
      '["breathing"]',
      '{"followUps":["ok"]}',
      '{"exercises":null}',
      '{"exercises":"breathing"}',
      '{"exercises":{"id":"breathing"}}',
      '{"exercise":"breathing"}',
    ]) {
      expect(parseSuggestedExercises(raw), raw).toEqual([]);
    }
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
