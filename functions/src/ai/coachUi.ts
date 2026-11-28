/**
 * Coach cards: which tappable cards an Ember reply carries (K3, K6 and K8 in
 * docs/superpowers/plans/2026-11-25-coach-cards.md).
 *
 * Decided here by plain code. A model has ONE say, and it is a suggestion:
 * the follow-up call that already runs after a reply may name the exercises
 * that reply was about (`suggested`, founder decision Nov 28 2026: a coach
 * that says "breathe with me" and shows no way to do it is a coach whose
 * cards nobody finds). Everything a name has to pass is still code — the
 * registry, what the app can draw, the tier, the audience — so a card adds
 * no model call of its own, and no wording of a message can talk the policy
 * into showing a locked exercise or a menu mid-craving.
 *
 * **A block carries an id and nothing else.** Never a route, a URL, a number,
 * a label or a colour: the app owns everything it draws (its strings, its
 * palette, its routes), so the server can only choose among things that build
 * already knows how to draw. A client skips a block it does not know and
 * keeps the rest.
 *
 * Pure: no Firestore, no params, no clock, no model. The handler reads the
 * tier, the param, the request and the follow-up call's answer, and hands
 * them in; `test/coachUi.test.ts` pins the policy to the eighteen files in
 * `test/fixtures/coach_ui/`, which the app's own suite reads too.
 */
import {
  EXERCISE_KINDS,
  EXERCISES,
  exerciseById,
  type ExerciseId,
} from '../domain/exercises';
import type {CoachChip, SubscriptionTier} from '../domain/types';

/** What the app said it can draw on this turn. */
export interface UiCapabilities {
  /** The ids this build knows AND the registry holds, once each. */
  readonly exercises: readonly ExerciseId[];
  /** The message was sent from inside a craving: one next step, never a menu. */
  readonly craving: boolean;
}

/** One card under a reply. `launcher` is the only kind there is. */
export type Block = {readonly t: 'launcher'; readonly exercise: ExerciseId};

/** Everything the policy reads. The fixtures carry all seven, so none defaults. */
export interface PlanInput {
  /** `COACH_UI_AUDIENCE`, already through [coachUiAudience]. */
  readonly audience: 'off' | 'premium' | 'all';
  /** The server's own read of the tier (`tierFor`), never the client's. */
  readonly tier: SubscriptionTier;
  readonly chip: CoachChip | null;
  /** Set when the turn came from the panic flow. */
  readonly panicIntensity: number | null;
  /** Null when the app said nothing about cards: an older build. */
  readonly caps: UiCapabilities | null;
  /** From the craving digest, most recent first; `[]` when there is none. */
  readonly recentTools: readonly ExerciseId[];
  /**
   * The exercises the follow-up call said this reply is about, best first
   * ([parseSuggestedExercises]); `[]` when it named none or did not run (a
   * panic turn, a plain call, the cap, an outage, `COACH_FOLLOWUPS` off).
   * Model output: every id is looked up before it is believed.
   */
  readonly suggested: readonly ExerciseId[];
}

/**
 * How many entries of the app's list are looked at. The registry holds five;
 * this is a bound on work a caller can choose for us, not a feature.
 */
const MAX_ADVERTISED = 32;

/** K3's ceiling on a reply, which the app's decoder applies as well. */
const MAX_BLOCKS = 4;

/** The most cards a menu shows. */
const MAX_MENU = 3;

/**
 * Reads the request's `ui` field. Null means the app said nothing usable —
 * an older build, the Day-1 walkthrough's coach step, or junk — and null is
 * "no cards", which is exactly today's reply. Never throws: a malformed
 * field must not fail a turn somebody is waiting on.
 *
 * Only ids the registry holds are kept, once each, from the first
 * [MAX_ADVERTISED] entries. `craving` is true only for the boolean `true`.
 * `v` is not checked, to match the app's own decoder: a later version that
 * still sends a readable list is still read.
 */
export function parseUiCapabilities(raw: unknown): UiCapabilities | null {
  if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const fields = raw as Record<string, unknown>;
  const list = fields['exercises'];
  if (!Array.isArray(list)) return null;

  const exercises: ExerciseId[] = [];
  for (const item of list.slice(0, MAX_ADVERTISED) as unknown[]) {
    const id = exerciseById(item)?.id;
    if (id !== undefined && !exercises.includes(id)) exercises.push(id);
  }
  return {exercises, craving: fields['craving'] === true};
}

/**
 * `COACH_UI_AUDIENCE` as the policy reads it: trimmed and lower-cased,
 * exactly `off` is off, exactly `all` is all, and ANYTHING else is `premium`.
 *
 * "Anything else" includes the empty string, which is what a deploy-time
 * param resolves to when no `.env` supplies it. Both other readings of that
 * case are wrong in a way that looks like a decision somebody made: `off`
 * takes the feature from every subscriber on a project that never named the
 * param, and `all` hands a Premium feature to everybody.
 */
export function coachUiAudience(raw: string): 'off' | 'premium' | 'all' {
  const word = raw.trim().toLowerCase();
  return word === 'off' || word === 'all' ? word : 'premium';
}

/**
 * Whether the audience lets this tier see cards at all: never when it is
 * `off`, and not a free account while it is `premium`.
 *
 * Its own function because the coach handler asks the same question before
 * it reads the craving log, which is a Firestore query worth making only for
 * a turn that can show a card. One rule, so the two can never disagree.
 */
export function audienceAdmits(
  audience: PlanInput['audience'],
  tier: SubscriptionTier,
): boolean {
  if (audience === 'off') return false;
  return !(audience === 'premium' && tier === 'free');
}

const launcher = (exercise: ExerciseId): Block => ({t: 'launcher', exercise});

type Row = (typeof EXERCISES)[number];

/**
 * Step 1 of the policy, on its own because two callers need it: the rows
 * the app listed, minus Premium rows for a free account, in registry order.
 * Empty when the audience does not admit the tier or the app said nothing.
 */
function availableRows(
  input: Pick<PlanInput, 'audience' | 'tier' | 'caps'>,
): readonly Row[] {
  const {audience, tier, caps} = input;
  if (caps === null || !audienceAdmits(audience, tier)) return [];
  const advertised = new Set<string>(caps.exercises);
  return EXERCISES.filter(
    (row) => advertised.has(row.id) && !(row.premium && tier === 'free'),
  );
}

const inCraving = (
  input: Pick<PlanInput, 'panicIntensity' | 'caps'>,
): boolean => input.panicIntensity !== null || input.caps?.craving === true;

/** How many names are looked at. A bound on model output, not a feature. */
const MAX_SUGGESTED = 8;

/**
 * The exercises the follow-up call may name on this turn, in registry order;
 * `[]` means do not ask. It is asked only where a name can change the cards:
 * somebody the audience admits, on an app that listed something, and not on
 * the craving chip outside a craving, whose menu is fixed. Everybody else's
 * follow-up call goes out exactly as it did before a reply could carry cards.
 */
export function nameableExercises(
  input: Omit<PlanInput, 'suggested'>,
): ExerciseId[] {
  if (input.chip === 'craving' && !inCraving(input)) return [];
  return availableRows(input).map((row) => row.id);
}

/**
 * Reads `exercises` out of the follow-up call's JSON: registry ids, once
 * each, in the order given, from the first [MAX_SUGGESTED] entries. Anything
 * else — no JSON, no such key, not a list, an id nobody registered — is
 * `[]`, which is "no card". Never throws: this is where model output becomes
 * something a person can tap, and a malformed answer must cost the card, not
 * the reply.
 *
 * It does NOT stop at three. How many become cards is the policy's to say,
 * after it has kept one per kind: cut to three here, "Orbs, Tiles, SOS,
 * breathing" would lose the breathing card to a second game the policy then
 * drops anyway.
 */
export function parseSuggestedExercises(raw: string): ExerciseId[] {
  const cleaned = raw
    .trim()
    .replace(/^```(?:json)?/i, '')
    .replace(/```$/, '')
    .trim();
  let parsed: unknown;
  try {
    parsed = JSON.parse(cleaned);
  } catch {
    return [];
  }
  if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
    return [];
  }
  const list = (parsed as Record<string, unknown>)['exercises'];
  if (!Array.isArray(list)) return [];

  const out: ExerciseId[] = [];
  for (const item of list.slice(0, MAX_SUGGESTED) as unknown[]) {
    const id =
      typeof item === 'string'
        ? exerciseById(item.trim().toLowerCase())?.id
        : undefined;
    if (id !== undefined && !out.includes(id)) out.push(id);
  }
  return out;
}

/**
 * The cards for one turn. Seven steps, in this order:
 *
 * 1. `available` is the registry rows the app listed, minus Premium rows for
 *    a free account, in REGISTRY order (the app's order is not a preference).
 * 2. Nothing when the audience is `off`, when the app said nothing, when
 *    nothing is available, or when the audience is `premium` and the tier is
 *    `free`.
 * 3. `recent` is what they have used during a craving, narrowed to
 *    `available` — so a game they used while subscribed is never offered once
 *    it is locked, and nobody lands on a lock.
 * 4. `named` is what the reply was about (`suggested`), narrowed the same
 *    way: a name that is not available becomes the first available exercise
 *    of its kind ("a game" is the free game for a free account), or is
 *    dropped when there is none. One per kind, at most three.
 * 5. In a craving (the turn came from the panic flow, or the app says the
 *    chat is mid-craving): exactly ONE card. The exercise the reply named,
 *    else what they used last, else the first calm exercise, else the first
 *    available. Somebody at 8/10 gets a next step, not a menu; this is
 *    checked BEFORE the chip, so the craving chip tapped inside a craving is
 *    still one card.
 * 6. Otherwise, on the `craving` chip: a menu of at most three. What they
 *    used last if anything, then the first available exercise of each kind
 *    in `EXERCISE_KINDS` order, SKIPPING the kind the latest tool already
 *    covers. The skip is what keeps the SOS card for somebody whose latest
 *    tool is a second game: without it the menu is Tiles, breathing and
 *    Orbs, and nobody to ask (founder decision, Nov 25 2026). The menu is
 *    fixed: what the reply named does not change it.
 * 7. Otherwise `named`, laid out in REGISTRY order: an ordinary message
 *    whose reply offered an exercise carries that exercise, and one whose
 *    reply offered none carries nothing. The model says which; the order is
 *    the registry's, calm first, like the menu's. Asked what fits somebody
 *    about to vape, the cheap model answered "SOS, breathing" two times in
 *    three: both right, and in the wrong order for a person who needs the
 *    next breath before a post (`npm run eval:cards`, Nov 28 2026).
 */
export function planBlocks(input: PlanInput): Block[] {
  const available = availableRows(input);
  const first = available[0];
  if (first === undefined) return [];

  // The most recent tool that is also available, as its registry row.
  // `recentTools` is typed, but its values come off stored craving docs:
  // looking each one up in `available` is what makes an unknown id, or a
  // game that has since been locked, harmless.
  const latest = input.recentTools
    .map((id) => available.find((row) => row.id === id))
    .find((row) => row !== undefined);

  // What the reply was about, as rows this person can open. Model output:
  // an id is looked up in the registry before anything is done with it.
  const named: Row[] = [];
  for (const id of input.suggested.slice(0, MAX_SUGGESTED)) {
    const asked = exerciseById(id);
    if (asked === null) continue;
    const row =
      available.find((r) => r.id === asked.id) ??
      available.find((r) => r.kind === asked.kind);
    if (row === undefined || named.some((n) => n.kind === row.kind)) continue;
    named.push(row);
    if (named.length === MAX_MENU) break;
  }

  if (inCraving(input)) {
    const calm = available.find((row) => row.kind === 'calm');
    return [launcher((named[0] ?? latest ?? calm ?? first).id)];
  }

  if (input.chip === 'craving') {
    const ids: ExerciseId[] = latest === undefined ? [] : [latest.id];
    for (const kind of EXERCISE_KINDS) {
      // The latest tool stands for its whole kind, so each kind appears once.
      if (kind === latest?.kind) continue;
      const row = available.find((r) => r.kind === kind);
      if (row !== undefined) ids.push(row.id);
    }
    return ids.slice(0, MAX_MENU).map(launcher);
  }

  return [...named]
    .sort((a, b) => EXERCISES.indexOf(a) - EXERCISES.indexOf(b))
    .map((row) => launcher(row.id));
}

/**
 * The reply's `ui` field, ready to spread into an envelope: `{}` when there
 * are no cards, so the key is ABSENT rather than an empty list — the reply an
 * older app, a free account and an ordinary message get keeps exactly the
 * keys it has today.
 */
export function uiEnvelope(
  blocks: readonly Block[],
): {ui: {v: 1; blocks: readonly Block[]}} | Record<string, never> {
  if (blocks.length === 0) return {};
  return {ui: {v: 1, blocks: blocks.slice(0, MAX_BLOCKS)}};
}
