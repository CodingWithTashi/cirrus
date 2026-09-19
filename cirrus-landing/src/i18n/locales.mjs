// The locale registry — the ONE list every part of the site derives from.
//
// Plain JavaScript on purpose. astro.config.mjs (the sitemap), scripts/*.mjs
// (the OG cards and the checks), functions/ (the /get fallback) and the
// TypeScript in src/ all need the same list, and only a .mjs file is importable
// from all four without a build step. Types come from the JSDoc below.
//
// URL SHAPE. English is unprefixed; every other locale lives under /<code>. With
// `build.format: 'file'` the locale home is `/es`, NOT `/es/` — dist/es.html
// beside a dist/es/ directory, the same shape /blog already has — so every
// canonical, hreflang, sitemap entry and switcher href is written slashless.
//
// Astro's own `i18n` config is deliberately OFF. Its URL helpers return
// `/es/privacy` without checking the page exists, and this site has English-only
// legal pages and a partly translated blog, so an existence-aware helper
// (src/i18n/paths.ts) is needed anyway. And never a `fallback`: it would publish
// English bodies under /es/… — duplicate content with a Spanish URL.

/** @typedef {'en' | 'es' | 'fr' | 'de' | 'pt'} Locale */

/** Every locale the site is BUILT to support. @type {readonly Locale[]} */
export const LOCALES = /** @type {const} */ (['en', 'es', 'fr', 'de', 'pt']);

/** @type {Locale} */
export const DEFAULT_LOCALE = 'en';

/**
 * The locales that are PUBLISHED. Routes, hreflang, the sitemap and the language
 * switcher all read this and nothing else, so a locale goes live by being added
 * here once the founder has spot-checked it — one at a time if need be — and a
 * half-translated locale cannot leak a single URL before then.
 * @type {readonly Locale[]}
 */
export const LIVE_LOCALES = ['en'];

/**
 * hreflang values. Language-only, no region: /es is served to every Spanish
 * speaker, and a region code would tell Google to withhold it from the rest.
 * @type {Record<Locale, string>}
 */
export const HREFLANG = { en: 'en', es: 'es', fr: 'fr', de: 'de', pt: 'pt' };

/**
 * og:locale, from Facebook's own list (which is why Spanish is es_LA, not
 * es_419). es and pt name the WIDER audience the copy is written for — founder
 * decision Sep 19 2026, docs/10 §43.3 — which is not the app's dialect.
 * @type {Record<Locale, string>}
 */
export const OG_LOCALE = { en: 'en_US', es: 'es_LA', fr: 'fr_FR', de: 'de_DE', pt: 'pt_BR' };

/**
 * BCP 47 tags for Intl (dates, number grouping). Same audience decision.
 * @type {Record<Locale, string>}
 */
export const INTL = { en: 'en-US', es: 'es-419', fr: 'fr-FR', de: 'de-DE', pt: 'pt-BR' };

/**
 * The currency the live calculator shows, or null for a bare number.
 *
 * The amounts are the visitor's own arithmetic, so a bare number is always
 * honest; a symbol is a guess about where they live. English keeps the dollar it
 * launched with, French and German readers are overwhelmingly in the euro area,
 * and /es and /pt serve two continents each — so they guess nothing.
 * @type {Record<Locale, string | null>}
 */
export const DEMO_CURRENCY = { en: 'USD', es: null, fr: 'EUR', de: 'EUR', pt: null };
