/**
 * Wire vocabulary mirrored from `lib/domain/models/enums.dart` and
 * `models.dart`. Enums encode by their Dart `.name`, so these string unions
 * ARE the wire format — renaming one here silently breaks the app.
 *
 * Parity rule: any field added to `JourneyCodec` in Dart must be added here
 * and to `test/journeyCodec.test.ts`.
 */

export const QUIT_METHODS = ['taper', 'coldTurkey'] as const;
export type QuitMethod = (typeof QUIT_METHODS)[number];

export const SUBSCRIPTION_TIERS = ['free', 'trial', 'premium'] as const;
export type SubscriptionTier = (typeof SUBSCRIPTION_TIERS)[number];

export const NIC_STRENGTHS = ['mg20', 'mg35', 'mg50', 'notSure'] as const;
export type NicStrength = (typeof NIC_STRENGTHS)[number];

/** Estimated absorbed mg per puff (docs/03 §2). "Not sure" defaults to 50mg. */
export const MG_PER_PUFF: Readonly<Record<NicStrength, number>> = {
  mg20: 0.28,
  mg35: 0.49,
  mg50: 0.7,
  notSure: 0.7,
};

export const WHY_CHIPS = [
  'health', 'money', 'freedom', 'family', 'fitness', 'appearance',
] as const;
export type WhyChip = (typeof WHY_CHIPS)[number];

export const WORRY_CHIPS = [
  'cravings', 'stress', 'social', 'failing', 'weight', 'breaks',
] as const;
export type WorryChip = (typeof WORRY_CHIPS)[number];

export const FIRST_PUFF_WINDOWS = [
  'withinFive', 'fiveToThirty', 'thirtyToSixty', 'hourPlus',
] as const;
export type FirstPuffWindow = (typeof FIRST_PUFF_WINDOWS)[number];

export const MOODS = ['rough', 'meh', 'okay', 'good', 'great'] as const;
export type Mood = (typeof MOODS)[number];

export const POST_TAGS = ['win', 'sos', 'day1', 'milestone', 'vent'] as const;
export type PostTag = (typeof POST_TAGS)[number];

export const COACH_CHIPS = ['craving', 'roughDay', 'slipped', 'progress'] as const;
export type CoachChip = (typeof COACH_CHIPS)[number];

/**
 * Ember's template repertoire (`CoachTemplate` in models.dart). The server
 * only ever emits the deterministic ones — `capReached` and
 * `connectionLost` — free-form AI answers travel in `CoachReply.text`.
 */
export const COACH_TEMPLATES = [
  'greeting', 'craving1', 'craving2', 'craving3', 'rough1', 'rough2',
  'slip1', 'slip2', 'progress1', 'progress2', 'generic1', 'generic2',
  'generic3', 'generic4', 'party', 'capReached', 'connectionLost',
] as const;
export type CoachTemplate = (typeof COACH_TEMPLATES)[number];

export const FLAME_STATES = ['spark', 'flicker', 'flame', 'blaze', 'inferno'] as const;
export type FlameState = (typeof FLAME_STATES)[number];

// ---------------------------------------------------------------------------
// Journey aggregate (read-only on the server — see lib/collections.ts).
// ---------------------------------------------------------------------------

export interface QuitPlan {
  readonly method: QuitMethod;
  readonly paceDays: number;
  /** Local date of day 1, `yyyy-MM-dd`. */
  readonly startDate: string;
  readonly baselinePuffsPerDay: number;
  readonly weeklySpend: number;
  readonly strength: NicStrength;
  /** Extra days added by slip recovery (docs/03 §3.3, cap +50% of pace). */
  readonly stretchDays: number;
}

export interface UserProfile {
  readonly alias: string;
  readonly avatarEmoji: string;
  readonly tier: SubscriptionTier;
  readonly email: string | null;
  readonly birthYear: number | null;
  readonly whys: readonly WhyChip[];
  readonly worries: readonly WorryChip[];
  readonly firstPuff: FirstPuffWindow | null;
}

export interface DayLog {
  /** `yyyy-MM-dd`, re-derived from the map key (one source of truth). */
  readonly date: string;
  readonly puffs: number;
  readonly limit: number;
  /** Hour 0–23 → puffs. Fuels the danger-hour engine. */
  readonly hourBuckets: Readonly<Record<number, number>>;
  readonly cravingsSurvived: number;
  readonly mood: Mood | null;
  readonly vapeFreeConfirmed: boolean;
  readonly repairTokenUsed: boolean;
}

export interface Journey {
  readonly profile: UserProfile;
  readonly plan: QuitPlan;
  /** `yyyy-MM-dd` → log, ascending order not guaranteed. */
  readonly days: Readonly<Record<string, DayLog>>;
  readonly cravingsSurvivedTotal: number;
  readonly repairTokens: number;
  readonly longestStreak: number;
  readonly lastPuffAt: string | null;
  readonly moodCheckIns: number;
}

/** Total plan length including slip stretch. */
export const totalDays = (plan: QuitPlan): number =>
  plan.paceDays + plan.stretchDays;

export const isPremium = (profile: UserProfile): boolean =>
  profile.tier !== 'free';
