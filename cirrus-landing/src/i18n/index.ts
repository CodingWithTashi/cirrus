// The one door to the dictionaries: `useT(lang)` for the strings, `fmt()` for
// placeholders, `clock()` for the example day's times.
import { de } from './de.ts';
import { en, type Dictionary } from './en.ts';
import { es } from './es.ts';
import { fr } from './fr.ts';
import { pt } from './pt.ts';
import { DEFAULT_LOCALE, INTL } from './locales.mjs';
import type { Locale } from './paths.ts';

export type { Dictionary } from './en.ts';
export type { Locale } from './paths.ts';

/**
 * Every dictionary. `satisfies Record<Locale, …>` means a locale added to the
 * registry without a file here stops compiling. Whether a locale is PUBLISHED is
 * a separate question, answered by `LIVE_LOCALES` in locales.mjs — so a
 * translation can be built, previewed and spot-checked long before a single URL
 * of it is public.
 */
const DICTS = { en, es, fr, de, pt } satisfies Record<Locale, Dictionary>;

/** The dictionary for `lang`. There is no fallback to English, by construction:
    a page that silently renders in the wrong language is duplicate content with
    a foreign URL, and it would pass every check that only looks for a 200. */
export function useT(lang: Locale = DEFAULT_LOCALE): Dictionary {
  return DICTS[lang];
}

/** All of them, for scripts/check-i18n.mjs. */
export const dictionaries: Record<Locale, Dictionary> = DICTS;

/**
 * Fills `{name}` placeholders. Throws on a placeholder with no value — a
 * translator who renames `{site}` to `{sitio}` would otherwise ship the braces.
 * scripts/check-i18n.mjs checks the same thing without rendering anything.
 */
export function fmt(template: string, vars: Record<string, string | number>): string {
  return template.replace(/\{(\w+)\}/g, (_, name: string) => {
    if (!(name in vars)) throw new Error(`i18n: no value for {${name}} in "${template}"`);
    return String(vars[name]);
  });
}

/**
 * A 24-hour "HH:MM" as the reader's clock shows it, at build time.
 *
 * English keeps the look it launched with — "7:40" with a small lowercase "am"
 * beside it — and every other locale gets a 24-hour time and no period, which is
 * what French, German, Portuguese and Spanish readers actually see on a phone.
 */
export function clock(at: string, lang: Locale = DEFAULT_LOCALE): { time: string; period?: string } {
  const [h, m] = at.split(':').map(Number);
  // A fixed UTC date: only the clock matters, and the build machine's zone must
  // not be able to move it.
  const date = new Date(Date.UTC(2026, 0, 1, h, m));
  const twelveHour = lang === 'en';
  const parts = new Intl.DateTimeFormat(INTL[lang], {
    hour: twelveHour ? 'numeric' : '2-digit',
    minute: '2-digit',
    hourCycle: twelveHour ? 'h12' : 'h23',
    timeZone: 'UTC',
  }).formatToParts(date);
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? '';
  const time = `${get('hour')}:${get('minute')}`;
  return twelveHour ? { time, period: get('dayPeriod').toLowerCase() } : { time };
}
