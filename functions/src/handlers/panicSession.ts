/**
 * `panicSession` — records a craving session and reports whether AI panic
 * mode is available (docs/03 §7, docs/04 §7).
 *
 * The 3-step script itself runs on-device: a craving must not wait on a
 * network round-trip. This exists for the parts the client can't be trusted
 * with — the server-side session count and the tier read.
 *
 * It NEVER blocks. Past the free cap the client still shows the breathing
 * screen and the static reframe card; only the AI layer drops away. We do not
 * paywall someone mid-crisis (docs/04 §7).
 *
 * NOTE: docs/03 §7's buddy-ping branch is intentionally absent — Quit Buddies
 * is descoped (founder decision, Aug 2026).
 */
import {onCall} from 'firebase-functions/v2/https';
import {enforceAppCheck, REGION} from '../config';
import {dayKeyIn} from '../domain/dateKey';
import {
  EXERCISE_SOURCES,
  EXERCISES,
  exerciseById,
  type ExerciseId,
  type ExerciseSource,
} from '../domain/exercises';
import {cravingsCol, FieldValue} from '../lib/firestore';
import {asEnum, requireCaller} from '../lib/guards';
import {countPanicSession, tierFor} from '../lib/usage';

/** docs/04 §7 — free tier gets one AI-backed panic session per day. */
const FREE_DAILY_PANIC_SESSIONS = 1;

type GameRow = Extract<(typeof EXERCISES)[number], {readonly game: true}>;

/**
 * The panic games, by the ids the client's `GameId.name` uses.
 *
 * Read off the exercise registry rather than listed a second time: a game is
 * the registry's row with `game: true`, so one added there is accepted here
 * with no edit to this file. Registry order, which nothing depends on.
 */
export type PanicGame = GameRow['id'];
export const PANIC_GAMES: readonly PanicGame[] = EXERCISES.filter(
  (row): row is GameRow => row.game,
).map((row) => row.id);

/**
 * What a craving document records beyond its outcome: the two 1–10 ratings,
 * the game on screen when it passed, the exercise they used and where they
 * opened it from (`panic`, `coach`, …). Anything off the scale or unknown to
 * the registry is stored as null, never trusted.
 *
 * Every field is optional on the wire and independent of the others. In
 * particular a missing `intensity` stays null: a craving met from outside the
 * panic flow was never rated, and a default here would be a number Ember
 * could later quote back as theirs. `game` and `exercise` are kept as sent
 * and neither fills in the other — an older app sends only `game`.
 */
export function cravingFields(data: Record<string, unknown>): {
  intensity: number | null;
  intensityAfter: number | null;
  game: PanicGame | null;
  exercise: ExerciseId | null;
  source: ExerciseSource | null;
} {
  const rating = (v: unknown): number | null =>
    typeof v === 'number' && Number.isInteger(v) && v >= 1 && v <= 10 ? v : null;
  return {
    intensity: rating(data['intensity']),
    intensityAfter: rating(data['intensityAfter']),
    // Against the games, not the whole registry: `breathing` is an exercise
    // and was never on screen in the arena.
    game: asEnum<PanicGame>(data['game'], PANIC_GAMES),
    exercise: exerciseById(data['exercise'])?.id ?? null,
    source: asEnum<ExerciseSource>(data['source'], EXERCISE_SOURCES),
  };
}

export const panicSession = onCall(
  {region: REGION, enforceAppCheck, memory: '256MiB'},
  async (request): Promise<{aiAvailable: boolean; sessionsToday: number}> => {
    const caller = requireCaller(request);
    const data = (request.data ?? {}) as Record<string, unknown>;
    const today = dayKeyIn(new Date(), caller.timeZone);

    const [tier, sessionsToday] = await Promise.all([
      tierFor(caller.uid),
      countPanicSession(caller.uid, today),
    ]);

    // Outcome is optional: the client posts it when the session ends, and a
    // session that ends with the app killed simply never reports one.
    const outcome = data['outcome'];
    if (outcome === 'survived' || outcome === 'slipped') {
      await cravingsCol(caller.uid).add({
        outcome,
        ...cravingFields(data),
        startedAt: FieldValue.serverTimestamp(),
      });
    }

    return {
      aiAvailable: tier !== 'free' || sessionsToday <= FREE_DAILY_PANIC_SESSIONS,
      sessionsToday,
    };
  },
);
