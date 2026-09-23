// Checks the TRANSLATIONS, from source. Part of `npm run check`, so it runs in
// the deploy workflow's Typecheck step, before anything is built.
//
// `astro check` already guarantees every locale has exactly English's keys (each
// dictionary is declared `: Dictionary`). This covers what a type cannot see —
// the ways a translation goes wrong while still compiling:
//
//   1. KEYS, again, both directions. Belt and braces: it costs nothing, and it
//      keeps this script honest if a dictionary is ever loosened to `any`.
//   2. PLACEHOLDERS. A translator who renames {site} to {sitio} ships the braces.
//   3. DIGITS. Every run of digits in a translation must also be in the English,
//      and vice versa. This is the honest-numbers rule (docs/02 §8) applied to a
//      translator: "76%" cannot quietly become "78%", and a figure English spells
//      out ("five messages") cannot become a numeral that looks like a claim.
//      Separators are ignored, so 2,588 = 2.588 = 2 588 and $2.99 = 2,99 $.
//   4. EMPTY and UNTRANSLATED. No empty string; nothing identical to English
//      unless it is a name, a source or a symbol (see SAME_OK).
//   5. LENGTHS. Dictionary-sourced <title> and meta descriptions bypass the
//      content collection's Zod limits, and German runs long.
//   6. ONE QUERY, ONE PAGE, per language: no FAQ question twice in a locale.
//   7. No U+202F (Space Grotesk has no glyph for it — a box on the OG cards) and
//      no markup in a string (sentences that need markup are split instead).
//
// The dictionaries are TypeScript and are imported as-is through Node's type
// stripping (on by default from Node 22.18 — see `engines`), which is why their
// own imports carry a `.ts` extension and use `import type` for types.
import { dictionaries } from '../src/i18n/index.ts';
import { DEFAULT_LOCALE, LOCALES } from '../src/i18n/locales.mjs';
import { SITE_TITLE } from '../src/consts.ts';

const errors = [];
const fail = (lang, key, message) => errors.push(`${lang}  ${key}  ${message}`);

/** { 'home.hero.sub': '…', 'home.hero.trust.0': '…' } */
function flatten(node, prefix = '', out = {}) {
  for (const [k, v] of Object.entries(node)) {
    const key = prefix ? `${prefix}.${k}` : k;
    if (typeof v === 'string') out[key] = v;
    else if (v && typeof v === 'object') flatten(v, key, out);
    else fail('-', key, `is a ${typeof v}; a dictionary holds strings only`);
  }
  return out;
}

const NBSP = '\u00a0';
const placeholders = (s) => [...s.matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort().join(',');

// A run of digits, swallowing the separators a locale puts INSIDE one number:
// "2,588", "2.588", "2 588" (ordinary, no-break or narrow space) and "39,99".
const digitRuns = (s) =>
  [...s.matchAll(/\d+(?:[.,\u00a0\u202f ]\d{3})*(?:[.,]\d+)?/g)].map((m) => m[0].replace(/\D/g, '')).sort().join(' ');

// Keys whose digits legitimately differ, each with its reason. Keep this short:
// every entry is a place a wrong number could hide.
const DIGITS_DIFFER = {
  // English writes "3pm"; French and German readers use the 24-hour clock the
  // timeline beside this sentence already shows them, so they read "15 h" / "15 Uhr".
  'home.day.steps.headsUp.body': ['fr', 'de'],
  // The sentence names the app's own button. In French that label is "TAFFE +1"
  // (homeLogPuff in app_fr.arb); in English it is "LOG PUFF". The 1 is a label.
  'home.day.steps.first.body': ['fr'],
};

// Values that are rightly the same in every language.
const SAME_OK = new Set([
  'Blog', 'Premium', 'iPhone', 'Android', 'Apple Watch', '404', '≈ ',
  'This is Quitting RCT, Truth Initiative / JMIR', 'JAMA Network Open',
  '76%', '28% → 53%', '15–20 min', '24% vs. 19%',
  'Principal', // es and pt share the word; neither is English
]);
// …and keys that are the same BETWEEN two locales for a good reason are not
// compared at all: only "identical to English" is suspicious.
const EMPTY_OK = { 'chrome.inEnglish': [DEFAULT_LOCALE] };

const en = flatten(dictionaries[DEFAULT_LOCALE]);
const enKeys = Object.keys(en);

for (const lang of LOCALES) {
  const dict = flatten(dictionaries[lang]);

  // 1. keys
  for (const k of enKeys) if (!(k in dict)) fail(lang, k, 'is missing');
  for (const k of Object.keys(dict)) if (!(k in en)) fail(lang, k, 'is not in the English dictionary');

  const questions = new Map();

  for (const [key, value] of Object.entries(dict)) {
    if (!(key in en)) continue;

    // 4. empty / untranslated
    if (value.trim() === '') {
      if (!EMPTY_OK[key]?.includes(lang)) fail(lang, key, 'is empty');
      continue;
    }
    if (lang !== DEFAULT_LOCALE && value === en[key] && /\p{L}/u.test(value) && !SAME_OK.has(value)) {
      fail(lang, key, `is identical to English ("${value.slice(0, 40)}") — translate it, or add it to SAME_OK with a reason`);
    }

    // 2. placeholders
    if (placeholders(value) !== placeholders(en[key])) {
      fail(lang, key, `placeholders {${placeholders(value)}} differ from English {${placeholders(en[key])}}`);
    }

    // 3. digits
    if (lang !== DEFAULT_LOCALE && digitRuns(value) !== digitRuns(en[key]) && !DIGITS_DIFFER[key]?.includes(lang)) {
      fail(lang, key, `digits [${digitRuns(value)}] differ from English [${digitRuns(en[key])}]`);
    }

    // 7. characters
    if (value.includes('\u202f')) fail(lang, key, `contains U+202F (narrow no-break space); use U+00A0 — Space Grotesk has no glyph for it`);
    if (/<[a-z/!]/i.test(value)) fail(lang, key, 'contains markup; split the sentence into parts instead');
    if (value.includes('\u00ad')) fail(lang, key, 'contains a soft hyphen; it would show up in <title>, og tags and JSON-LD');

    // 6. collect questions
    if (/^faq\.\w+\.q$/.test(key)) {
      const q = value.replaceAll(NBSP, ' ').replace(/\s+/g, ' ').trim().toLowerCase();
      if (questions.has(q)) fail(lang, key, `asks the same question as ${questions.get(q)}`);
      questions.set(q, key);
    }
  }

  // 5. lengths — the same limits the blog's content schema enforces on posts.
  const title = (t) => `${t} · ${SITE_TITLE}`;
  const checks = [
    ['meta.tagline', `${SITE_TITLE} · ${dict['meta.tagline'] ?? ''}`, 0, 70],
    ['meta.title', title(dict['meta.title'] ?? ''), 0, 70],
    ['download.title', title(dict['download.title'] ?? ''), 0, 70],
    ['notFound.title', title(dict['notFound.title'] ?? ''), 0, 70],
    ['meta.description', dict['meta.description'] ?? '', 50, 160],
    ['download.description', dict['download.description'] ?? '', 50, 160],
  ];
  for (const [key, text, min, max] of checks) {
    if (text.length < min || text.length > max) fail(lang, key, `renders ${text.length} characters; the limit is ${min}–${max}`);
  }
}

if (errors.length > 0) {
  console.error(`check-i18n: ${errors.length} problem${errors.length === 1 ? '' : 's'} in src/i18n/\n`);
  for (const e of errors) console.error(`  ${e}`);
  process.exit(1);
}

console.log(`check-i18n: ${LOCALES.length} locales × ${enKeys.length} strings — keys, placeholders, digits, lengths and questions all consistent.`);
