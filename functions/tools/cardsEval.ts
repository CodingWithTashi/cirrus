/* eslint-disable no-console */
/**
 * The gate for any change to `followUpPrompt`: does the follow-up call name
 * the right exercise for an exchange, and nothing for an exchange that is
 * about none?
 *
 * Why it exists. Since Nov 28 2026 an ordinary coach reply can carry a card
 * for the exercise it was about, and the one who says which is the cheap
 * model behind the follow-up chips (`src/ai/prompts.ts`). The code after it
 * (`planBlocks`) is pinned by unit tests and cannot be talked into a locked
 * exercise. What code cannot pin is the judgment itself: a breathing card
 * under "your lungs are clearing out" is a wrong button, and no card under
 * "in for four, hold for seven" is the bug this was built to fix. Both are
 * only visible by asking the real model.
 *
 * Every case is one exchange, sent exactly as `aiCoachChat` sends it
 * (`followUpRequest`), and graded on the CARDS a subscriber would see: the
 * answer goes through the production parser and the production policy.
 *
 * Usage (from `functions/`):
 *
 *   npm run eval:cards -- --dry-run      # what it would cost; sends nothing
 *   GEMINI_API_KEY="$(firebase functions:secrets:access GEMINI_API_KEY)" npm run eval:cards
 *   npm run eval:cards -- --rolls 5      # more samples per case
 *
 * The bar, written down before the first roll: no case fails more than half
 * of its rolls, and no more than one roll in ten fails overall. The model
 * runs at the production temperature (0.6), so one roll is a draw, never a
 * verdict. Exit code 0 when the bar is met, 1 when it is not, 2 when the run
 * did not finish (budget, billing wall, a failed call): that run is not an
 * answer. Transcripts land in `functions/evals/cards-<stamp>.json`
 * (gitignored); read every failing answer before believing a count.
 *
 * Cost: a few cents at most on flash-lite, and counted. Every call goes
 * through `evalExec.ts`, so it shares the day's spend cap and the cache with
 * the other evals (`--budget`, `--batch`, `--no-cache` mean the same here).
 * It spends on the production Gemini project, like they do: no roll without
 * the founder's word that the balance has room.
 */
import {existsSync, mkdirSync, writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {parseSuggestedExercises, planBlocks} from '../src/ai/coachUi';
import {followUpRequest} from '../src/ai/prompts';
import {
  EXERCISE_IDS,
  exerciseById,
  type ExerciseId,
  type ExerciseKind,
} from '../src/domain/exercises';
import {BudgetExceededError, usd} from './evalBudget';
import {
  checkArgs,
  commonFlags,
  estimateCalls,
  openDeps,
  openLedger,
  runCalls,
  spendLine,
  type EvalCall,
} from './evalExec';

// Env-overridable, defaulting to the id `.env.alastpuff` pins for
// `MODEL_FREE`, which is the model the follow-up call always runs on. Never
// `defineString(...).value()` here: params only resolve inside the Functions
// runtime.
export const MODEL_ID = process.env['MODEL_FREE'] ?? 'gemini-3.5-flash-lite';

export type Expect =
  /** An ordinary exchange: any card here is a wrong button. */
  | {readonly cards: 'none'}
  /** A judgment call: no card, or exactly one card from [only]. */
  | {readonly cards: 'optional'; readonly only: readonly ExerciseId[]}
  /** [lead] is the first card; any card after it must be in [also]. */
  | {
      readonly cards: 'lead';
      readonly lead: ExerciseId;
      readonly also?: readonly ExerciseId[];
    }
  /** A menu: exactly one card of each of these kinds, in any order. */
  | {readonly cards: 'kinds'; readonly kinds: readonly ExerciseKind[]};

export interface Case {
  readonly id: string;
  /** What the person sent. */
  readonly user: string;
  /** What the coach answered. */
  readonly coach: string;
  /** What this person could be shown. Every exercise when omitted. */
  readonly nameable?: readonly ExerciseId[];
  readonly expect: Expect;
  readonly why: string;
}

export const CASES: readonly Case[] = [
  // ── A card belongs under these ──────────────────────────────────────────
  {
    id: 'accept-breath',
    user: "Let's do it now",
    coach:
      "Awesome, let's do it right now.\n\nBreathe in deep through your nose for 4 seconds... " +
      'hold it for 7... then blow it all out slow through your mouth for 8 seconds.\n\n' +
      'Repeat that three times and tell me how your chest feels right now.',
    expect: {cards: 'lead', lead: 'breathing'},
    why: 'the exchange this was built for: a yes to an offered breath, counted out in words (Nov 28 2026)',
  },
  {
    id: 'offer-breath',
    user: 'work is stressing me out and i want to hit my vape so bad',
    coach:
      "That's a solid plan. Breathing exercises give your lungs that same deep hit feeling without " +
      'any of the nicotine, and it takes the edge off fast.\n\n' +
      'Want to try a quick 4-7-8 breath with me right now to clear the work stress out?',
    expect: {cards: 'lead', lead: 'breathing'},
    why: 'the coach offers it: the card is the yes',
  },
  {
    id: 'typed-craving',
    user: 'im craving so bad right now what do i do',
    coach:
      "Okay, I'm right here. This one peaks and passes in a few minutes. Breathe with me: in for " +
      "four, out for six. You've done harder things than this.",
    expect: {cards: 'lead', lead: 'breathing', also: ['orbs', 'tiles', 'blocks', 'sos']},
    why: 'a craving typed out, not tapped on the chip: nobody should need the exact words',
  },
  {
    id: 'ask-suggestion',
    user: 'im so restless tonight, any suggestion?',
    coach:
      "Restless is your body looking for its old routine. Let's slow it down: one long breath in, " +
      'hold it, and let it all the way out. Do that five times with me.',
    expect: {cards: 'lead', lead: 'breathing'},
    why: 'they asked for a suggestion and got one the app can open',
  },
  {
    id: 'ask-breathing',
    user: "let's do breathing exercises",
    coach:
      "Let's do it right now.\n\nInhale through your nose for 4... hold it gentle for 7... then " +
      'blow it all out slow through your mouth for 8.\n\nDo that two more times, and let me know ' +
      'how that heavy feeling in your chest is doing.',
    expect: {cards: 'lead', lead: 'breathing'},
    why: 'asked for by name, word for word from the founder\'s phone (Nov 28 2026)',
  },
  {
    id: 'stress-statement',
    user: 'work is stressing me out',
    coach:
      "Work stress is such a heavy trigger, but you're doing the right thing by pausing instead " +
      "of reaching for a puff.\n\nThat urge is just a spike, and it's going to fade in 15 to 20 " +
      'minutes.\n\nCan you step away from your desk for a quick walk or grab some cold water?',
    expect: {cards: 'lead', lead: 'breathing', also: ['orbs', 'tiles', 'blocks', 'sos']},
    why:
      'stress said out loud, and a reply that suggests a walk: the person still gets a tool the ' +
      'app can open (the founder\'s second message that day)',
  },
  {
    id: 'about-to-vape',
    user: 'i am about to hit the vape i cant take it',
    coach:
      "Hold on. You've gone seven days and this wave is the loudest it will get. Put the vape in " +
      'another room and drink a full glass of cold water first.',
    expect: {cards: 'lead', lead: 'breathing', also: ['orbs', 'tiles', 'blocks', 'sos']},
    why: 'about to vape, right now, and the reply names nothing the app can open',
  },
  {
    id: 'game-offer',
    user: 'my hands dont know what to do without it',
    coach:
      "That's the habit talking, not the nicotine. Give your hands a job for a minute: try a quick " +
      '60-second game and see where the urge is after.',
    expect: {cards: 'lead', lead: 'orbs'},
    why: 'a game with no name is the first game listed',
  },
  {
    id: 'named-game',
    user: 'can i play blocks for a bit',
    coach: 'Yes. Sixty seconds of Blocks, eyes and thumbs busy, then tell me how the craving feels.',
    expect: {cards: 'lead', lead: 'blocks'},
    why: 'a game asked for by name is that game',
  },
  {
    id: 'game-free-list',
    user: 'any game i can play to get my mind off it',
    coach: 'Good call. Sixty seconds of a game: hands busy, eyes busy, and the urge has to wait.',
    nameable: ['breathing', 'orbs', 'sos'],
    expect: {cards: 'lead', lead: 'orbs'},
    why: 'shown only the free exercises, as a free account would be',
  },
  {
    id: 'lonely-sos',
    user: 'i feel like nobody gets how hard this is',
    coach:
      'A lot of people in the community are in exactly this spot tonight. Post an SOS and let them ' +
      "show up for you. You don't have to carry this one alone.",
    expect: {cards: 'lead', lead: 'sos'},
    why: 'the coach points at the community',
  },
  {
    id: 'options',
    user: 'what are my options when a craving hits',
    coach:
      'Three that work: slow breathing to ride it out, a quick game to keep your hands busy, or an ' +
      'SOS to the community so someone answers. Which one feels right?',
    expect: {cards: 'kinds', kinds: ['calm', 'focus', 'people']},
    why: 'they asked what their options are and the coach listed all three kinds',
  },
  {
    id: 'spanish-breath',
    user: 'tengo muchas ganas de vapear ahora mismo',
    coach:
      'Estoy aquí contigo. Respira conmigo: inhala cuatro segundos, mantén siete, suelta en ocho. ' +
      'Esta ola pasa.',
    expect: {cards: 'lead', lead: 'breathing'},
    why: 'the app ships six languages and the ids stay English',
  },
  {
    id: 'german-yes',
    user: 'ja, machen wir das',
    coach:
      'Super. Atme vier Sekunden ein, halte sieben, atme acht Sekunden aus. Dreimal, dann sag mir, ' +
      'wie es sich anfühlt.',
    expect: {cards: 'lead', lead: 'breathing'},
    why: 'a yes in German to a breath counted out in German',
  },

  // ── No card belongs under these ─────────────────────────────────────────
  {
    id: 'progress',
    user: 'how much money have i saved',
    coach:
      "You've kept $42 in your pocket so far, and it grows every day you stay under your line.",
    expect: {cards: 'none'},
    why: 'a question about numbers',
  },
  {
    id: 'plan-question',
    user: 'when is my freedom day',
    coach: "You're on plan day 7, and Freedom Day is 23 days out. Today's line is 48 puffs.",
    expect: {cards: 'none'},
    why: 'a question about the plan',
  },
  {
    id: 'slip',
    user: 'i slipped last night, 3 puffs',
    coach:
      "Thanks for telling me. Three puffs after six days isn't starting over, it's information. " +
      'What was happening right before?',
    expect: {cards: 'none'},
    why: 'a slip being talked through, with no exercise in play',
  },
  {
    id: 'vent',
    user: 'my boss yelled at me in front of everyone today',
    coach:
      "That's humiliating, and I'm sorry. Of course the vape is calling after that. What do you " +
      "need most right now: to vent, or to plan what you'll say tomorrow?",
    expect: {cards: 'optional', only: ['breathing']},
    why:
      'something that happened, told while still upset: a calm card is fair and so is none. ' +
      'It was "none" until the rule for stress said right now was added (Nov 28 2026)',
  },
  {
    id: 'cough',
    user: 'is it normal to cough more after quitting',
    coach:
      "Yes, and it's a good sign: your lungs are clearing out what the vapor left behind. It usually " +
      'settles within a few weeks. If it gets worse or you feel short of breath, check with a doctor.',
    expect: {cards: 'none'},
    why: 'the words lungs and breath, in a reply that is about neither exercise',
  },
  {
    id: 'walk-thanks',
    user: 'thanks, that actually helped',
    coach: 'Anytime. Go drink some water and take that walk, you earned it.',
    expect: {cards: 'none'},
    why: 'a walk and water are not exercises the app can open',
  },
  {
    id: 'tell-roommate',
    user: 'should i tell my roommate im quitting',
    coach:
      "Tell them. Text them right now: I'm quitting, call me out if you see me with it. People want " +
      'to help more than you think.',
    expect: {cards: 'none'},
    why: 'texting a friend is not an SOS post to the community',
  },
  {
    id: 'small-talk',
    user: 'whats your favorite season',
    coach: "Fall, easy. Crisp air, and you can actually smell it now. How's your day going?",
    expect: {cards: 'none'},
    why: 'small talk',
  },
];

/** The call production makes for [c]. */
export function callFor(c: Case, roll: number): EvalCall {
  return {
    request: followUpRequest({
      model: MODEL_ID,
      userText: c.user,
      reply: c.coach,
      exercises: c.nameable ?? EXERCISE_IDS,
    }),
    // The temperature is 0.6: each roll is its own draw.
    sample: roll,
    expectOutputTokens: 45,
  };
}

/**
 * The cards a subscriber would see under [c]'s reply for the model's answer
 * [text]: the production parser, then the production policy, on an ordinary
 * message from an app that can draw what the case lists.
 */
export function cardsFor(c: Case, text: string): ExerciseId[] {
  return planBlocks({
    audience: 'premium',
    tier: 'premium',
    chip: null,
    panicIntensity: null,
    caps: {exercises: c.nameable ?? EXERCISE_IDS, craving: false},
    recentTools: [],
    suggested: parseSuggestedExercises(text),
  }).map((block) => block.exercise);
}

/** Whether [cards] is an answer [c] accepts. */
export function grade(c: Case, cards: readonly ExerciseId[]): boolean {
  const {expect} = c;
  switch (expect.cards) {
    case 'none':
      return cards.length === 0;
    case 'optional':
      return (
        cards.length === 0 ||
        (cards.length === 1 && expect.only.includes(cards[0] as ExerciseId))
      );
    case 'lead': {
      const also = expect.also ?? [];
      return (
        cards[0] === expect.lead && cards.slice(1).every((id) => also.includes(id))
      );
    }
    case 'kinds': {
      const kinds = cards.map((id) => exerciseById(id)?.kind);
      return (
        kinds.length === expect.kinds.length &&
        expect.kinds.every((kind) => kinds.includes(kind))
      );
    }
  }
}

/**
 * The bar: no case fails more than half of its rolls, and at most one roll
 * in ten fails overall. `failing` lists every case that failed at all, worst
 * first, for the line the run prints.
 */
export function judgeRun(
  results: readonly {readonly case: string; readonly pass: boolean}[],
  rolls: number,
): {met: boolean; failed: number; failing: [string, number][]} {
  const byCase = new Map<string, number>();
  for (const r of results) {
    if (!r.pass) byCase.set(r.case, (byCase.get(r.case) ?? 0) + 1);
  }
  const failing = [...byCase.entries()].sort((a, b) => b[1] - a[1]);
  const failed = results.filter((r) => !r.pass).length;
  const met =
    results.length > 0 &&
    failing.every(([, n]) => n <= rolls / 2) &&
    failed <= results.length / 10;
  return {met, failed, failing};
}

interface Roll {
  readonly case: string;
  readonly roll: number;
  readonly expected: Expect;
  readonly cards: readonly ExerciseId[];
  readonly pass: boolean;
  /** The model's own words, so a failure can be read and not guessed at. */
  readonly answer: string;
}

/** How many follow-up chips [text] carries; -1 when it is not the JSON asked for. */
function chipCount(text: string): number {
  try {
    const parsed: unknown = JSON.parse(
      text.trim().replace(/^```(?:json)?/i, '').replace(/```$/, '').trim(),
    );
    const list =
      parsed !== null && typeof parsed === 'object'
        ? (parsed as Record<string, unknown>)['followUps']
        : undefined;
    return Array.isArray(list) ? list.length : -1;
  } catch {
    return -1;
  }
}

const describeExpect = (expect: Expect): string => {
  switch (expect.cards) {
    case 'none':
      return 'no card';
    case 'optional':
      return `no card, or ${expect.only.join('/')}`;
    case 'lead':
      return expect.also === undefined ? expect.lead : `${expect.lead} first`;
    case 'kinds':
      return `one each of ${expect.kinds.join('/')}`;
  }
};

async function main(): Promise<void> {
  const argv = process.argv.slice(2);
  checkArgs(argv, ['--rolls'], []);
  const flags = commonFlags(argv, process.env);
  const rollsArg = argv.indexOf('--rolls');
  const rolls = rollsArg === -1 ? 3 : Number.parseInt(argv[rollsArg + 1] ?? '3', 10);
  if (!Number.isInteger(rolls) || rolls < 1 || rolls > 20) {
    throw new Error('--rolls takes a whole number from 1 to 20, for example --rolls 5');
  }

  const jobs = CASES.flatMap((c) =>
    Array.from({length: rolls}, (_, i) => ({c, roll: i + 1, call: callFor(c, i + 1)})),
  );
  const calls = jobs.map((job) => job.call);

  const {budget, cache} = openLedger(flags, process.env);
  const estimate = estimateCalls(calls, cache, {batch: flags.batch, at: new Date()});
  console.log(
    `eval:cards: ${CASES.length} cases × ${rolls} rolls on ${MODEL_ID}, ${calls.length} model calls, ` +
      `${estimate.cacheHits} already in the cache. To buy: ${estimate.paidCalls} calls, about ` +
      `${usd(estimate.usd)}. Today so far: ${usd(budget.spentToday())} of ${usd(budget.limitUsd)}.`,
  );
  if (flags.dryRun) {
    console.log('--dry-run: nothing was sent.');
    return;
  }
  try {
    budget.require(estimate.usd, 'this run');
  } catch (error) {
    if (!(error instanceof BudgetExceededError)) throw error;
    console.error(error.message);
    process.exit(2);
  }

  const apiKey = process.env['GEMINI_API_KEY'];
  if (!apiKey) {
    console.error(
      'GEMINI_API_KEY is not set. Run:\n' +
        '  GEMINI_API_KEY="$(firebase functions:secrets:access GEMINI_API_KEY)" npm run eval:cards',
    );
    process.exit(2);
  }

  const report = await runCalls(
    calls,
    openDeps({apiKey, flags, env: process.env, tool: 'cards', log: (line) => console.log(line)}),
  );

  const results: Roll[] = [];
  let unanswered = 0;
  let withChips = 0;
  let malformed = 0;
  jobs.forEach((job, index) => {
    const {c, roll} = job;
    const outcome = report.outcomes[index];
    if (outcome === undefined || !outcome.ok) {
      unanswered++;
      console.log(`----  ${c.id.padEnd(16)} roll ${roll}  no answer: ${outcome?.error ?? 'no outcome'}`);
      return;
    }
    const cards = cardsFor(c, outcome.text);
    const pass = grade(c, cards);
    const chips = chipCount(outcome.text);
    if (chips > 0) withChips++;
    if (chips < 0) malformed++;
    results.push({case: c.id, roll, expected: c.expect, cards, pass, answer: outcome.text});
    console.log(
      `${pass ? 'PASS' : 'FAIL'}  ${c.id.padEnd(16)} roll ${roll}  expected ${describeExpect(c.expect).padEnd(28)} ` +
        `got ${cards.length === 0 ? 'no card' : cards.join(', ')}`,
    );
  });

  const dir = join(__dirname, '..', '..', 'evals');
  if (!existsSync(dir)) mkdirSync(dir, {recursive: true});
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const file = join(dir, `cards-${stamp}-${MODEL_ID}.json`);
  const complete = unanswered === 0 && report.stoppedBy === null;
  writeFileSync(file, JSON.stringify({model: MODEL_ID, rolls, complete, results}, null, 2));

  const verdict = judgeRun(results, rolls);
  const total = results.length;
  console.log(
    `\n${total - verdict.failed}/${total} rolls passed on ${MODEL_ID} (${CASES.length} cases × ${rolls}). Transcript: ${file}`,
  );
  // The second key must not cost the first: the chips are why this call runs.
  console.log(
    `Follow-up chips: ${withChips}/${total} answers carried some, ${malformed} were not the JSON asked for.`,
  );
  console.log(spendLine([report], budget));
  if (verdict.failing.length > 0) {
    console.log(
      'Failing cases: ' + verdict.failing.map(([id, n]) => `${id} (${n}/${rolls})`).join(', '),
    );
  }
  if (!complete) {
    console.log(
      `INCOMPLETE: ${unanswered} roll(s) got no answer. ${report.note}\n` +
        'This run is not an answer: do not read it as a pass or as a fail.',
    );
    process.exit(2);
  }
  console.log(
    verdict.met
      ? 'Bar met: no case failed most of its rolls, and at most one roll in ten failed.'
      : 'Bar NOT met. Read the failing answers in the transcript before changing the prompt or a case.',
  );
  if (!verdict.met) process.exit(1);
}

if (require.main === module) {
  main().catch((error: unknown) => {
    console.error(error);
    process.exit(1);
  });
}
