/**
 * Which two beta-tester quotes to show a particular person on D3.
 *
 * Pure and side-effect free so the ranking can be tested without an emulator —
 * the same split `reactionDelta.ts` uses for `onReaction`.
 *
 * These are real people's words. Nothing here invents a persona, and nothing
 * here fabricates a name or an age: docs/02 §3 D3 names the competitor's
 * "Sarah, 29" as the review-bomb risk we are deliberately not taking. A row
 * carries the quote, its tags, and a consent reference — never an identity.
 */
import type {Gender, QuitAttempts, WhyChip, WorryChip} from './types';

export const DEPENDENCE_LEVELS = ['light', 'moderate', 'heavy', 'severe'] as const;
export type DependenceLevel = (typeof DEPENDENCE_LEVELS)[number];

/** A stored testimonial, already narrowed to the caller's locale. */
export interface Testimonial {
  readonly id: string;
  readonly text: string;
  /** Empty means "applies to everyone" — it scores zero, never negative. */
  readonly whys: readonly WhyChip[];
  readonly worries: readonly WorryChip[];
  readonly attempts: readonly QuitAttempts[];
  readonly gender: readonly Gender[];
  readonly dependence: readonly DependenceLevel[];
  /** Manual editorial nudge, 0..1. Defaults to 0.5 on read. */
  readonly weight: number;
}

/** What the app knows about the person at step 18. */
export interface TestimonialAudience {
  readonly whys: readonly WhyChip[];
  readonly worries: readonly WorryChip[];
  readonly attempts: QuitAttempts | null;
  readonly gender: Gender | null;
  readonly dependence: DependenceLevel | null;
}

/**
 * The fear they just named is the strongest hook, so it outweighs everything
 * else; gender is last because it is an attribute rather than something they
 * chose to tell us about this quit.
 */
const WEIGHTS = {
  worries: 2.0,
  whys: 1.5,
  attempts: 1.0,
  dependence: 0.75,
  gender: 0.5,
} as const;

/**
 * Once a quote has covered a tag, a second quote covering the same tag adds
 * only half as much — otherwise both slots come back about cravings.
 */
const DIVERSITY_DECAY = 0.5;

/**
 * A row that declares tags in a dimension and matches none of them is a worse
 * fit than a row that declares nothing at all: the untagged quote genuinely
 * applies to everyone, while the mismatched one is visibly about somebody
 * else's quit. Without this they scored identically and the mismatch won on
 * the id tie-break.
 */
const MISMATCH_PENALTY = 0.25;

/** One single-valued dimension: matched, mismatched, or nothing to say. */
function single<T>(rowTags: readonly T[], theirs: T | null, weight: number): number {
  // Untagged applies to everyone; an unknown answer is not evidence either way.
  if (rowTags.length === 0 || theirs === null) return 0;
  return rowTags.includes(theirs) ? weight : -weight * MISMATCH_PENALTY;
}

function scoreOne(
  t: Testimonial,
  audience: TestimonialAudience,
  covered: ReadonlySet<string>,
): number {
  let score = 0;

  if (t.worries.length > 0) {
    const hits = t.worries.filter((w) => audience.worries.includes(w));
    if (hits.length === 0) score -= WEIGHTS.worries * MISMATCH_PENALTY;
    for (const worry of hits) {
      score += WEIGHTS.worries * (covered.has(`worry:${worry}`) ? DIVERSITY_DECAY : 1);
    }
  }

  if (t.whys.length > 0) {
    const hits = t.whys.filter((w) => audience.whys.includes(w));
    if (hits.length === 0) score -= WEIGHTS.whys * MISMATCH_PENALTY;
    for (const why of hits) {
      score += WEIGHTS.whys * (covered.has(`why:${why}`) ? DIVERSITY_DECAY : 1);
    }
  }

  score += single(t.attempts, audience.attempts, WEIGHTS.attempts);
  score += single(t.dependence, audience.dependence, WEIGHTS.dependence);
  score += single(t.gender, audience.gender, WEIGHTS.gender);

  return score + t.weight * 0.25;
}

function tagsOf(t: Testimonial): string[] {
  return [
    ...t.worries.map((w) => `worry:${w}`),
    ...t.whys.map((w) => `why:${w}`),
  ];
}

/**
 * The [limit] best-fitting quotes, most relevant first.
 *
 * Deterministic: ties break on `id`, so a retried call cannot come back with
 * the pair swapped and the screen cannot flicker between two orders.
 */
export function rank(
  pool: readonly Testimonial[],
  audience: TestimonialAudience,
  limit: number,
): Testimonial[] {
  const remaining = [...pool];
  const chosen: Testimonial[] = [];
  const covered = new Set<string>();

  while (chosen.length < limit && remaining.length > 0) {
    // Seeded from index 0 rather than -Infinity, so the id tie-break below
    // never indexes a bestIndex that does not exist yet.
    let bestIndex = 0;
    let bestScore = scoreOne(remaining[0]!, audience, covered);
    for (let i = 1; i < remaining.length; i++) {
      const score = scoreOne(remaining[i]!, audience, covered);
      // A tie breaks on id, so a retried call cannot return the pair in the
      // other order and make the screen flicker between two arrangements.
      const wins =
        score > bestScore ||
        (score === bestScore && remaining[i]!.id < remaining[bestIndex]!.id);
      if (!wins) continue;
      bestScore = score;
      bestIndex = i;
    }
    const [picked] = remaining.splice(bestIndex, 1);
    if (picked === undefined) break;
    chosen.push(picked);
    for (const tag of tagsOf(picked)) covered.add(tag);
  }

  return chosen;
}
