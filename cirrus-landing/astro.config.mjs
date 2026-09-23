// @ts-check
import { readFileSync, readdirSync } from 'node:fs';
import { defineConfig, fontProviders } from 'astro/config';
import sitemap from '@astrojs/sitemap';
import { DEFAULT_LOCALE, HREFLANG, LIVE_LOCALES, LOCALES } from './src/i18n/locales.mjs';

// Blog post dates, read straight from frontmatter, so the sitemap can carry a
// real <lastmod>. Google uses it to decide what to re-crawl; without it every
// URL looks equally stale. Read here rather than through astro:content because
// the config runs in plain Node, before the content layer exists.
//
// Keyed by "<locale>/<slug>". English posts sit at the top of the folder and a
// translation sits in a folder named for its locale (src/content/blog/es/<slug>.md);
// any other folder holds a post's images and is skipped. Two details that were
// wrong before there was a second language, and would have bitten the first
// translated post: the dates are read from the FRONTMATTER BLOCK only (a post
// that shows frontmatter inside a code fence has a second `publishedAt:` line),
// and the lookup below is anchored to the whole path, so /es/blog/<slug> can
// never be handed the English post's date.
const POSTS_DIR = new URL('./src/content/blog/', import.meta.url);
const postDates = new Map();
/** @type {readonly string[]} */
const localeFolders = LOCALES;
/**
 * @param {URL} dir
 * @param {string} locale
 */
function readPosts(dir, locale) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (locale === DEFAULT_LOCALE && localeFolders.includes(entry.name)) readPosts(new URL(`${entry.name}/`, dir), entry.name);
      continue;
    }
    if (!/\.mdx?$/.test(entry.name)) continue;
    const frontmatter = readFileSync(new URL(entry.name, dir), 'utf8').match(/^---\r?\n([\s\S]*?)\r?\n---/)?.[1] ?? '';
    const published = frontmatter.match(/^publishedAt:\s*(\S+)/m)?.[1];
    const updated = frontmatter.match(/^updatedAt:\s*(\S+)/m)?.[1];
    const date = updated ?? published;
    if (date) postDates.set(`${locale}/${entry.name.replace(/\.mdx?$/, '')}`, new Date(date).toISOString());
  }
}
readPosts(POSTS_DIR, DEFAULT_LOCALE);

const otherLocales = LOCALES.filter((l) => l !== DEFAULT_LOCALE).join('|');
const POST_PATH = new RegExp(`^/(?:(${otherLocales})/)?blog/([^/]+)/?$`);

// https://astro.build/config
export default defineConfig({
  // The ONE place the canonical origin lives — canonical tags, Open Graph URLs,
  // JSON-LD, robots.txt and the sitemap all derive from it.
  site: 'https://cirrusquit.com',

  // Emit /blog/my-post rather than /blog/my-post/ and keep the canonical tag
  // agreeing with it, so Google never sees two URLs for one page.
  trailingSlash: 'never',
  build: { format: 'file' },

  // `constrained` makes Astro emit a real srcset and a sizes attribute for every
  // optimized image, so a phone downloads a phone-sized file. Output lands in
  // /_astro/* with a content hash, which the immutable cache rule in
  // public/_headers already covers.
  //
  // Leave `responsiveStyles` at its default of false. Turning it on injects
  // Astro's own image CSS, which would start fighting the sizing rules in
  // global.css (`.phone img` sets its own aspect-ratio and object-fit).
  image: { layout: 'constrained' },

  // Self-hosted, preloaded — no third-party request at runtime. docs/07 §3
  // locks these two faces: Space Grotesk for display and all numbers, Inter for
  // body. Never a serif.
  fonts: [
    {
      name: 'Space Grotesk',
      cssVariable: '--font-space-grotesk',
      provider: fontProviders.google(),
      weights: [700],
      styles: ['normal'],
      subsets: ['latin'],
    },
    {
      name: 'Inter',
      cssVariable: '--font-inter',
      provider: fontProviders.google(),
      weights: [400, 600],
      styles: ['normal'],
      subsets: ['latin'],
    },
  ],

  integrations: [
    sitemap({
      // Both carry noindex; the sitemap must agree with the tag or Google sees
      // a page it is told to index and told not to. RSS is not a page at all.
      filter: (page) => !/\/(404|thanks)\/?$/.test(page),

      // hreflang in the sitemap, for whichever languages THIS build serves. The
      // integration pairs URLs that are the same path under different locale
      // prefixes, and only among pages that were actually built — so an
      // English-only page gets no alternates, by construction. Omitted entirely
      // while one language is live, which keeps that sitemap byte-identical.
      ...(LIVE_LOCALES.length > 1
        ? {
            i18n: {
              defaultLocale: DEFAULT_LOCALE,
              locales: Object.fromEntries(LIVE_LOCALES.map((l) => [l, HREFLANG[l]])),
            },
          }
        : {}),

      serialize(item) {
        // x-default → the English version. The integration emits one link per
        // language and no x-default, while BaseLayout's <head> does emit one; the
        // two have to say the same thing.
        const english = item.links?.find((l) => l.lang === HREFLANG[DEFAULT_LOCALE]);
        if (english) item.links = [...(item.links ?? []), { lang: 'x-default', url: english.url }];

        const [, locale = DEFAULT_LOCALE, slug] = new URL(item.url).pathname.match(POST_PATH) ?? [];
        const lastmod = slug && postDates.get(`${locale}/${slug}`);
        // Only posts get a lastmod. Stamping the static pages with build time
        // would claim they changed on every deploy, which is how a sitemap
        // teaches Google to stop trusting the field.
        return lastmod ? { ...item, lastmod } : item;
      },
    }),
  ],
});
