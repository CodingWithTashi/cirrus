/**
 * What Ember is told about cravings, and about the exercise somebody just
 * did: stored facts, in words (docs/superpowers/plans/2026-11-25-coach-cards.md,
 * task S4).
 *
 * `users/{uid}/cravings` holds one document per craving the person marked as
 * passed (`panicSession`). Until this file the coach read none of it and knew
 * a single total. The digest below is the reading side, and three rules keep
 * it honest:
 *
 * 1. **No counts.** How many cravings, how many times a tool was opened,
 *    how many days: none of it is stated. A count is a number the model can
 *    quote back wrongly ("your 9 cravings") or fuse with the plan day, and
 *    the card's own rule is that every counter that is not the day must not
 *    read like one. The only digits in these lines are a date and an hour.
 * 2. **No rating the person did not give.** The two 1–10 ratings are never
 *    written out. The one thing said about them is that their OWN second
 *    rating was lower than their first, and only when both exist. A craving
 *    met from outside the panic flow has no first rating at all.
 * 3. **Nothing typed reaches the prompt.** A tool is named through
 *    `EXERCISE_LABELS`, by registry id; an id the registry does not hold is
 *    skipped. No stored string is ever copied into a line.
 *
 * Pure: no Firestore, no clock. The handler reads the documents and hands
 * them in, and passes NONE of this to the card on a panic turn.
 */
import {dayKeyIn, hourIn} from '../domain/dateKey';
import {EXERCISE_LABELS, exerciseById, type ExerciseId} from '../domain/exercises';

/** One craving document, as much of it as the digest reads. */
export interface CravingDoc {
  /** When the outcome was reported: the moment they said it had passed. */
  readonly startedAt: Date;
  readonly intensity: number | null;
  readonly intensityAfter: number | null;
  /** Raw ids off the document; looked up in the registry before use. */
  readonly exercise: string | null;
  readonly game: string | null;
}

export interface CravingDigest {
  /** The most recent craving, or null when there is none on record. */
  readonly latest: {
    /** `yyyy-MM-dd` in the person's own timezone. */
    readonly dayKey: string;
    readonly weekday: string;
    /** 0–23, in their timezone. */
    readonly hour: number;
    /** What they had open, when the registry knows it. */
    readonly tool: ExerciseId | null;
    /** Both ratings exist and the second is below the first. */
    readonly ratedLower: boolean;
  } | null;
  /** Every tool on record, once each, most recent first. */
  readonly tools: readonly ExerciseId[];
}

/**
 * What a craving document says they had open: the exercise, or the game for
 * a document an older app wrote before exercises were reported. Null for an
 * id this registry does not hold.
 */
function toolOf(doc: CravingDoc): ExerciseId | null {
  return exerciseById(doc.exercise ?? doc.game)?.id ?? null;
}

/**
 * Digests craving documents into what the card and the card policy read.
 * Sorts by `startedAt` itself, so the caller's order does not matter.
 */
export function digestCravings(
  docs: readonly CravingDoc[],
  timeZone: string,
): CravingDigest {
  const newestFirst = [...docs].sort(
    (a, b) => b.startedAt.getTime() - a.startedAt.getTime(),
  );
  const tools: ExerciseId[] = [];
  for (const doc of newestFirst) {
    const tool = toolOf(doc);
    if (tool !== null && !tools.includes(tool)) tools.push(tool);
  }

  const newest = newestFirst[0];
  if (newest === undefined) return {latest: null, tools};
  return {
    latest: {
      dayKey: dayKeyIn(newest.startedAt, timeZone),
      weekday: new Intl.DateTimeFormat('en-US', {
        timeZone,
        weekday: 'long',
      }).format(newest.startedAt),
      hour: hourIn(newest.startedAt, timeZone),
      tool: toolOf(newest),
      ratedLower:
        newest.intensity !== null &&
        newest.intensityAfter !== null &&
        newest.intensityAfter < newest.intensity,
    },
    tools,
  };
}

/**
 * The craving lines of the user card: none without a craving on record, then
 * up to three.
 *
 * The first line carries its own warning, because "latest on <date>" sits a
 * few lines from the plan day and the streak: this is a list of cravings,
 * not a count of days. The second is there only when the latest craving
 * names a tool, and its re-rating clause only when their second rating was
 * lower. The third needs two different tools, since one tool is already
 * named by the line above it.
 */
export function cravingLines(digest: CravingDigest): string[] {
  const latest = digest.latest;
  if (latest === null) return [];
  const lines = [
    'craving log (cravings they marked as passed; a list, not a day count or the streak): ' +
      `latest on ${latest.dayKey} (${latest.weekday}), about ${latest.hour}:00 their time`,
  ];
  if (latest.tool !== null) {
    lines.push(
      `during that one they had open: ${EXERCISE_LABELS[latest.tool]}` +
        (latest.ratedLower ? ' · their own re-rating afterwards was lower' : ''),
    );
  }
  if (digest.tools.length >= 2) {
    lines.push(
      'tools they have opened during a craving, most recent first: ' +
        digest.tools.map((id) => EXERCISE_LABELS[id]).join(', '),
    );
  }
  return lines;
}

/** The exercise they finished just before this message, as the app reports it. */
export interface JustDid {
  readonly exercise: ExerciseId;
  /** Whole seconds, 0 to [MAX_SECONDS]. */
  readonly seconds: number;
  /** Ran long enough to count as done. */
  readonly completed: boolean;
  /** Ended on "It passed". */
  readonly passed: boolean;
}

/** An hour. Nothing in the app runs longer; past it the number is noise. */
const MAX_SECONDS = 3600;

/**
 * Reads the request's `justDid` field. Null for anything that is not that
 * shape, for an exercise the registry does not hold and for seconds that are
 * not a finite number; never throws, so a malformed field costs the line and
 * not the turn. Seconds are floored and clamped to 0..3600. `completed` and
 * `passed` count only as the boolean `true`.
 */
export function parseJustDid(raw: unknown): JustDid | null {
  if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const fields = raw as Record<string, unknown>;
  const exercise = exerciseById(fields['exercise'])?.id;
  if (exercise === undefined) return null;
  const seconds = fields['seconds'];
  if (typeof seconds !== 'number' || !Number.isFinite(seconds)) return null;
  return {
    exercise,
    seconds: Math.min(MAX_SECONDS, Math.max(0, Math.floor(seconds))),
    completed: fields['completed'] === true,
    passed: fields['passed'] === true,
  };
}

/**
 * The card line for what they just did. The time is in words (a number of
 * seconds is one more digit string beside the day), and "marked the craving
 * as passed" is said only when they pressed it: finishing an exercise is not
 * the same claim.
 *
 * **The closing clause is there because a model adds one.** The card prints
 * `cravings survived: N` a few lines above this one, and on the first eval
 * rolls (Nov 25 2026) the premium model read "marked the craving as passed"
 * beside "41" and answered "That is 42 cravings you have beaten now". The
 * app raises that total the moment "It passed" is tapped, so by the time
 * they type, N already has this craving in it and a +1 contradicts the Home
 * screen. The clause says so, naming the total by the label the card's own
 * line uses (`memoryCard.test.ts` fails if the two ever differ). It is a
 * stated fact, not an instruction: the lite model inverts instructions.
 */
export function justDidLine(j: JustDid): string {
  const duration =
    j.seconds < 45
      ? 'less than a minute'
      : j.seconds <= 90
        ? 'about a minute'
        : 'a few minutes';
  return (
    `just before this message, in the app: they used ${EXERCISE_LABELS[j.exercise]} ` +
    `for ${duration}` +
    (j.passed
      ? ` and marked the craving as passed (already counted in "${SURVIVED_LABEL}" above)`
      : '')
  );
}

/** The label of the user card's own total (`memoryCard.ts`, "cravings survived: N"). */
const SURVIVED_LABEL = 'cravings survived';
