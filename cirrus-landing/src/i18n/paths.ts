// Locale-aware URLs that know which pages actually exist.
//
// Astro's own i18n helpers build `/es/privacy` without asking whether there is
// one, and this site deliberately has none: the legal pages are English-only
// (their URLs are frozen by the stores and the apps), and the blog is translated
// a few posts at a time. So every internal link on a localized page goes through
// `link()`, which answers with the localized URL when that page exists and the
// English one — flagged `hreflang="en"` — when it does not. A guessed URL is a
// 404 in somebody else's language.
import { DEFAULT_LOCALE, LIVE_LOCALES, LOCALES } from './locales.mjs';

export type Locale = import('./locales.mjs').Locale;

/**
 * English paths that have a version in every live locale. Phase 1 of the plan
 * (docs/10 §43.4): the home page and /download. The blog joins this through
 * lib/posts.ts, post by post, once its plumbing exists.
 *
 * /404 is served per locale too, but it is `noindex`, so it never takes part in
 * hreflang and is not listed here.
 */
const LOCALIZED: readonly string[] = ['/', '/download'];

/** `/download` in Spanish is `/es/download`; the Spanish home is `/es`, never `/es/`. */
export function localePath(lang: Locale, path: string): string {
  if (lang === DEFAULT_LOCALE) return path;
  return path === '/' ? `/${lang}` : `/${lang}${path}`;
}

const isLive = (lang: Locale) => LIVE_LOCALES.includes(lang);

/** Whether `path` (an English path) has a page in `lang`. */
function existsIn(lang: Locale, path: string): boolean {
  if (lang === DEFAULT_LOCALE) return true;
  return isLive(lang) && LOCALIZED.includes(path);
}

/**
 * An internal link from a page in `lang` to the English path `path`.
 *
 * `hreflang` is set only when the link leaves the reader's language, so the
 * markup says so (`<a hreflang="en">`) and scripts/check-dist.mjs can tell a
 * deliberate hand-off from a forgotten translation.
 */
export function link(lang: Locale, path: string): { href: string; hreflang?: string } {
  const [clean, hash = ''] = path.split('#');
  const suffix = hash ? `#${hash}` : '';
  if (existsIn(lang, clean)) return { href: `${localePath(lang, clean)}${suffix}` };
  // Only a non-English page can get here: every path exists in English.
  return { href: `${clean}${suffix}`, hreflang: DEFAULT_LOCALE };
}

/**
 * Every live version of a localizable page, keyed by locale, self included —
 * what BaseLayout turns into `<link rel="alternate" hreflang>`.
 *
 * Undefined when the page exists in one language only: hreflang on a page with
 * no alternates is noise, and BaseLayout emits nothing for it.
 */
export function alternatesFor(path: string): Partial<Record<Locale, string>> | undefined {
  if (!LOCALIZED.includes(path)) return undefined;
  const live = LOCALES.filter(isLive);
  if (live.length < 2) return undefined;
  return Object.fromEntries(live.map((l) => [l, localePath(l, path)]));
}
