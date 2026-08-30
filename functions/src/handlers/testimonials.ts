/**
 * `matchedTestimonials` — the two beta-tester quotes shown on D3.
 *
 * The rating ask used to render two hardcoded ARB strings, identical for every
 * person on earth, on the screen immediately before the paywall. These are the
 * same real quotes, picked for the fear the user named four screens earlier.
 *
 * **The answers arrive in the request rather than from `journeys/{uid}`,** and
 * that is not laziness: at step 18 the journey document does not exist yet —
 * `completeWithTier` runs after the paywall. It is safe for the same reason
 * `guards.ts` gives about timezone and locale: none of these is a privilege,
 * so the worst a lying client achieves is a less relevant quote for itself.
 *
 * The collection is server-only. Rows carry a consent reference and locale
 * provenance; this returns the two fields the screen renders and nothing else.
 */
import {onCall} from 'firebase-functions/v2/https';
import {REGION} from '../config';
import {testimonialsCol} from '../lib/firestore';
import {asEnum, requireCaller} from '../lib/guards';
import {log} from '../lib/logger';
import {
  DEPENDENCE_LEVELS,
  rank,
  type DependenceLevel,
  type Testimonial,
} from '../domain/testimonialMatch';
import {
  GENDERS,
  QUIT_ATTEMPTS,
  WHY_CHIPS,
  WORRY_CHIPS,
  type Gender,
  type QuitAttempts,
  type WhyChip,
  type WorryChip,
} from '../domain/types';

/** Two cards, as the frame draws it. */
const LIMIT = 2;

/**
 * Matches the client's `maxLines: 3` and the bundled fallbacks' length, so a
 * server row can never make the card taller than the one it replaces.
 */
const MAX_CHARS = 220;

/** Narrows an untrusted array to the known vocabulary, dropping the rest. */
function enumList<T extends string>(
  value: unknown,
  allowed: readonly string[],
): T[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((v) => asEnum<T>(v, allowed))
    .filter((v): v is T => v !== null);
}

function toTestimonial(
  id: string,
  data: Record<string, unknown>,
): Testimonial | null {
  const text = typeof data['text'] === 'string' ? data['text'].trim() : '';
  if (text.length === 0) return null;
  return {
    id,
    text: text.slice(0, MAX_CHARS),
    whys: enumList<WhyChip>(data['whys'], WHY_CHIPS),
    worries: enumList<WorryChip>(data['worries'], WORRY_CHIPS),
    attempts: enumList<QuitAttempts>(data['attempts'], QUIT_ATTEMPTS),
    gender: enumList<Gender>(data['gender'], GENDERS),
    dependence: enumList<DependenceLevel>(data['dependence'], DEPENDENCE_LEVELS),
    weight: typeof data['weight'] === 'number' ? data['weight'] : 0.5,
  };
}

async function poolFor(language: string): Promise<Testimonial[]> {
  const snap = await testimonialsCol()
    .where('status', '==', 'live')
    .where('locale', '==', language)
    .get();
  return snap.docs
    .map((d) => toTestimonial(d.id, d.data()))
    .filter((t): t is Testimonial => t !== null);
}

export const matchedTestimonials = onCall(
  {region: REGION, enforceAppCheck: true, memory: '256MiB'},
  async (
    request,
  ): Promise<{testimonials: {id: string; text: string}[]}> => {
    const caller = requireCaller(request);
    const data = (request.data ?? {}) as Record<string, unknown>;

    // 'pt-BR' and 'pt' draw on the same rows; region does not change the quote.
    const language = caller.locale.split('-')[0] ?? 'en';

    let pool = await poolFor(language);
    // Fewer than two in their language reads as a bug on screen — one tailored
    // card beside one generic one looks broken — so fall back wholesale.
    if (pool.length < LIMIT && language !== 'en') {
      pool = await poolFor('en');
    }
    if (pool.length < LIMIT) {
      // The client keeps its bundled quotes. Better two honest generic ones
      // than a half-filled screen.
      log.info('testimonials.pool_too_small', {size: pool.length, language});
      return {testimonials: []};
    }

    const picked = rank(
      pool,
      {
        whys: enumList<WhyChip>(data['whys'], WHY_CHIPS),
        worries: enumList<WorryChip>(data['worries'], WORRY_CHIPS),
        attempts: asEnum<QuitAttempts>(data['attempts'], QUIT_ATTEMPTS),
        gender: asEnum<Gender>(data['gender'], GENDERS),
        dependence: asEnum<DependenceLevel>(
          data['dependence'],
          DEPENDENCE_LEVELS,
        ),
      },
      LIMIT,
    );

    return {
      testimonials: picked.map((t) => ({id: t.id, text: t.text})),
    };
  },
);
