/**
 * Decoder for the `journeys/{uid}` document — the exact JSON
 * `lib/data/dto/journey_codec.dart` writes.
 *
 * Decode-only by design: the server never writes this document (see
 * `lib/firestore.ts` for why). Unknown enum members fall back rather than
 * throw, matching Dart's `enumByName` forward-compatibility contract — a
 * server that hard-fails on a value shipped by a newer app is a server that
 * takes the coach down during a staged rollout.
 */
import {
  FIRST_PUFF_WINDOWS,
  GENDERS,
  MOODS,
  NIC_STRENGTHS,
  QUIT_ATTEMPTS,
  QUIT_METHODS,
  SLIP_TRIGGERS,
  SUBSCRIPTION_TIERS,
  VAPE_FREQUENCIES,
  WHY_CHIPS,
  WORRY_CHIPS,
  type DayLog,
  type Journey,
  type QuitPlan,
  type SavingsGoal,
  type UserProfile,
} from './types';
import {isDayKey} from './dateKey';

/** Thrown when a document cannot be read as a journey at all. */
export class JourneyDecodeError extends Error {}

export function decodeJourney(raw: unknown): Journey {
  const json = asRecord(raw, 'journey');
  return {
    profile: decodeProfile(asRecord(json['profile'], 'profile')),
    plan: decodePlan(asRecord(json['plan'], 'plan')),
    days: decodeDays(json['days']),
    cravingsSurvivedTotal: asInt(json['cravingsSurvivedTotal'], 0),
    repairTokens: asInt(json['repairTokens'], 0),
    longestStreak: asInt(json['longestStreak'], 0),
    lastPuffAt: typeof json['lastPuffAt'] === 'string' ? json['lastPuffAt'] : null,
    moodCheckIns: asInt(json['moodCheckIns'], 0),
    goals: decodeGoals(json['goals']),
    earnedBadges: Array.isArray(json['earnedBadges'])
      ? json['earnedBadges'].filter((b): b is string => typeof b === 'string')
      : [],
  };
}

function decodeGoals(raw: unknown): SavingsGoal[] {
  if (!Array.isArray(raw)) return [];
  const out: SavingsGoal[] = [];
  for (const item of raw) {
    if (item === null || typeof item !== 'object') continue;
    const g = item as Record<string, unknown>;
    if (typeof g['id'] !== 'string' || typeof g['name'] !== 'string') continue;
    out.push({
      id: g['id'],
      emoji: typeof g['emoji'] === 'string' ? g['emoji'] : '🎯',
      name: g['name'],
      price: typeof g['price'] === 'number' ? g['price'] : 0,
      fromOnboarding: g['fromOnboarding'] === true,
    });
  }
  return out;
}

/** Sentence-length free text bound for a prompt. See [sanitizeName]. */
const MAX_WHY_WORDS = 200;
const MAX_MOOD_NOTE = 280;

/**
 * Client-written prose destined for a prompt: fold whitespace, drop the
 * invisibles, cap, trim.
 *
 * Longer and more permissive than [sanitizeName] because a sentence is
 * allowed to look like one — punctuation and emoji stay. What does not stay
 * is structure: newlines become spaces, because a blank line is how a piece
 * of user text pretends to start a new section of the prompt, and control
 * characters go entirely.
 *
 * This is a containment measure, not a filter. Nothing here can stop somebody
 * writing "ignore all prior instructions" in a box that asks why they are
 * quitting, and refusing it would be refusing an answer. What it guarantees is
 * that whatever they wrote arrives as ONE line of prose of bounded length,
 * which the prompt then fences as background rather than instruction — the
 * same arrangement `memorySection()` and `coachNameInstruction()` already use.
 */
function sanitizeProse(value: unknown, max: number): string | null {
  if (typeof value !== 'string') return null;
  const cleaned = value
    .replace(/\s/g, ' ')
    // eslint-disable-next-line no-control-regex
    .replace(/[\u0000-\u001F\u007F\u200B-\u200F\u2028\u2029\u202A-\u202E\uFEFF]/g, '')
    .replace(/ {2,}/g, ' ')
    .trim();
  return cleaned.length === 0 ? null : cleaned.slice(0, max);
}

function decodeProfile(json: Record<string, unknown>): UserProfile {
  return {
    alias: typeof json['alias'] === 'string' ? json['alias'] : 'quitter',
    avatarEmoji: typeof json['avatarEmoji'] === 'string' ? json['avatarEmoji'] : '🔥',
    // NOTE: this is the CLIENT's claim about its tier and is not trusted for
    // gating — `usage.tierFor()` reads the webhook-written mirror instead.
    tier: asEnumOr(json['tier'], SUBSCRIPTION_TIERS, 'free'),
    email: typeof json['email'] === 'string' ? json['email'] : null,
    birthYear: typeof json['birthYear'] === 'number' ? json['birthYear'] : null,
    whys: asEnumList(json['whys'], WHY_CHIPS),
    worries: asEnumList(json['worries'], WORRY_CHIPS),
    firstPuff: asEnumOrNull(json['firstPuff'], FIRST_PUFF_WINDOWS),
    // Same reasoning as moodNote below: it is client-written free text that
    // ends up near a prompt, so it is trimmed, stripped of control characters
    // and capped. This is a backstop — the name the model is actually told
    // comes from the server-owned document, never from here.
    coachName: sanitizeName(json['coachName']),
    // Sentence-length free text on the same journey — same treatment, longer
    // cap. Folding the newlines matters more here than it does for a name: a
    // blank line is how you fake a new section inside a prompt.
    whyWords: sanitizeProse(json['whyWords'], MAX_WHY_WORDS),
    gender: asEnumOrNull(json['gender'], GENDERS),
    attempts: asEnumOrNull(json['attempts'], QUIT_ATTEMPTS),
    frequency: asEnumOrNull(json['frequency'], VAPE_FREQUENCIES),
  };
}

function decodePlan(json: Record<string, unknown>): QuitPlan {
  const startDate = json['startDate'];
  if (!isDayKey(startDate)) {
    throw new JourneyDecodeError('plan.startDate is not a yyyy-MM-dd key');
  }
  return {
    method: asEnumOr(json['method'], QUIT_METHODS, 'taper'),
    paceDays: asInt(json['paceDays'], 30),
    startDate,
    baselinePuffsPerDay: asInt(json['baselinePuffsPerDay'], 0),
    weeklySpend: typeof json['weeklySpend'] === 'number' ? json['weeklySpend'] : 0,
    strength: asEnumOr(json['strength'], NIC_STRENGTHS, 'notSure'),
    stretchDays: asInt(json['stretchDays'], 0),
    ...restartOf(json),
  };
}

/** No taper has ever started above this; anything larger is not a level. */
const MAX_TAPER_FROM = 5000;

/**
 * The two fields a restarted plan adds, read defensively: this document is
 * client-written, and `taperFrom` sets a limit the coach will quote. Anything
 * that is not a positive whole number in range reads as a first plan — the
 * same answer the Dart codec gives for an absent key.
 */
function restartOf(
  json: Record<string, unknown>,
): Pick<QuitPlan, 'taperFrom' | 'planNumber'> {
  const whole = (v: unknown, max: number): number | undefined =>
    typeof v === 'number' && Number.isInteger(v) && v >= 1 && v <= max
      ? v
      : undefined;
  const taperFrom = whole(json['taperFrom'], MAX_TAPER_FROM);
  return {
    ...(taperFrom === undefined ? {} : {taperFrom}),
    planNumber: whole(json['planNumber'], 1000) ?? 1,
  };
}

function decodeDays(raw: unknown): Record<string, DayLog> {
  if (raw === null || typeof raw !== 'object') return {};
  const out: Record<string, DayLog> = {};
  for (const [key, value] of Object.entries(raw as Record<string, unknown>)) {
    // A malformed key would become a bad Firestore path or a NaN date; skip it
    // rather than fail the whole read.
    if (!isDayKey(key) || value === null || typeof value !== 'object') continue;
    const day = value as Record<string, unknown>;
    out[key] = {
      date: key,
      puffs: asInt(day['puffs'], 0),
      limit: asInt(day['limit'], 0),
      hourBuckets: decodeHourBuckets(day['hourBuckets']),
      cravingsSurvived: asInt(day['cravingsSurvived'], 0),
      mood: asEnumOrNull(day['mood'], MOODS),
      // Trimmed and capped: it goes into a prompt, and an unbounded free-text
      // field is both a cost and an injection surface.
      // Was trimmed and capped but never de-controlled, unlike every other
      // client string that reaches a prompt — and it reaches one, through
      // `ownWords()` in the user card.
      moodNote: sanitizeProse(day['moodNote'], MAX_MOOD_NOTE),
      slipTrigger: asEnumOrNull(day['slipTrigger'], SLIP_TRIGGERS),
      vapeFreeConfirmed: day['vapeFreeConfirmed'] === true,
      repairTokenUsed: day['repairTokenUsed'] === true,
    };
  }
  return out;
}

/** Dart encodes hour keys as strings ('0'..'23'); values are puff counts. */
function decodeHourBuckets(raw: unknown): Record<number, number> {
  if (raw === null || typeof raw !== 'object') return {};
  const out: Record<number, number> = {};
  for (const [key, value] of Object.entries(raw as Record<string, unknown>)) {
    const hour = Number.parseInt(key, 10);
    if (Number.isInteger(hour) && hour >= 0 && hour <= 23 && typeof value === 'number') {
      out[hour] = value;
    }
  }
  return out;
}

// --- primitives ------------------------------------------------------------

function asRecord(value: unknown, what: string): Record<string, unknown> {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new JourneyDecodeError(`${what} is not an object`);
  }
  return value as Record<string, unknown>;
}

function asInt(value: unknown, fallback: number): number {
  return typeof value === 'number' && Number.isFinite(value)
    ? Math.trunc(value)
    : fallback;
}

function asEnumOr<T extends string>(
  value: unknown,
  allowed: readonly T[],
  fallback: T,
): T {
  return asEnumOrNull(value, allowed) ?? fallback;
}

function asEnumOrNull<T extends string>(
  value: unknown,
  allowed: readonly T[],
): T | null {
  return typeof value === 'string' && (allowed as readonly string[]).includes(value)
    ? (value as T)
    : null;
}

function asEnumList<T extends string>(
  value: unknown,
  allowed: readonly T[],
): T[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((v) => asEnumOrNull(v, allowed))
    .filter((v): v is T => v !== null);
}

/** Client-written free text destined for a prompt: trim, de-control, cap. */
function sanitizeName(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  // eslint-disable-next-line no-control-regex
  const cleaned = value.replace(/[ --]/g, '').trim();
  return cleaned.length === 0 ? null : cleaned.slice(0, 20);
}
