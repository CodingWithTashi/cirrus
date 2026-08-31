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

export const GENDERS = ['woman', 'man', 'nonBinary'] as const;
export type Gender = (typeof GENDERS)[number];

export const QUIT_ATTEMPTS = ['never', 'once', 'twoToFive', 'moreThanFive'] as const;
export type QuitAttempts = (typeof QUIT_ATTEMPTS)[number];

export const VAPE_FREQUENCIES = ['daily', 'often', 'always'] as const;
export type VapeFrequency = (typeof VAPE_FREQUENCIES)[number];

/** What the user blamed a slip on (docs/03 §5). Their answer, not ours. */
export const SLIP_TRIGGERS = [
  'party', 'stress', 'boredom', 'drinking', 'friends', 'justHappened',
] as const;
export type SlipTrigger = (typeof SLIP_TRIGGERS)[number];

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
  /**
   * What this person renamed their coach to, or null if they never did.
   *
   * Read from the CLIENT-owned journey, so it is untrusted input and is
   * sanitized on decode. The version that reaches the model comes from the
   * server-owned `users/{uid}.coachName`, written only by `setCoachName`.
   */
  readonly coachName: string | null;
  /**
   * Why they are doing this, in their own words. Null when they skipped.
   *
   * The only free text onboarding collects, and the only onboarding answer
   * that belongs in the vector memory — everything else is a chip or an enum
   * and reaches the model exactly, and for free, through the user card.
   */
  readonly whyWords: string | null;
  // The rest of the 19-step quiz. The server used to drop these, so the coach
  // could not tell a first-time quitter from someone on their sixth attempt,
  // or an all-day vaper from a social one — the two facts that most change
  // what is worth saying to them.
  readonly gender: Gender | null;
  readonly attempts: QuitAttempts | null;
  readonly frequency: VapeFrequency | null;
}

/** What the user is saving toward (docs/03 §4). Their words, their price. */
export interface SavingsGoal {
  readonly id: string;
  readonly emoji: string;
  readonly name: string;
  readonly price: number;
  readonly fromOnboarding: boolean;
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
  /** Free text the user wrote with their mood. Their own words — rare, and
   *  the single most personal thing in the whole journey document. */
  readonly moodNote: string | null;
  readonly slipTrigger: SlipTrigger | null;
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
  readonly goals: readonly SavingsGoal[];
  readonly earnedBadges: readonly string[];
}

/** Total plan length including slip stretch. */
export const totalDays = (plan: QuitPlan): number =>
  plan.paceDays + plan.stretchDays;

export const isPremium = (profile: UserProfile): boolean =>
  profile.tier !== 'free';
