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
      moodNote:
        typeof day['moodNote'] === 'string' && day['moodNote'].trim().length > 0
          ? day['moodNote'].trim().slice(0, 280)
          : null,
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
