// @ts-check
import { readFileSync, readdirSync } from 'node:fs';
import { defineConfig, fontProviders } from 'astro/config';
import sitemap from '@astrojs/sitemap';

// Blog post dates, read straight from frontmatter, so the sitemap can carry a
// real <lastmod>. Google uses it to decide what to re-crawl; without it every
// URL looks equally stale. Read here rather than through astro:content because
// the config runs in plain Node, before the content layer exists.
const POSTS_DIR = new URL('./src/content/blog/', import.meta.url);
const postDates = new Map();
for (const file of readdirSync(POSTS_DIR)) {
  if (!/\.mdx?$/.test(file)) continue;
  const src = readFileSync(new URL(file, POSTS_DIR), 'utf8');
  const published = src.match(/^publishedAt:\s*(\S+)/m)?.[1];
  const updated = src.match(/^updatedAt:\s*(\S+)/m)?.[1];
  const date = updated ?? published;
  if (date) postDates.set(file.replace(/\.mdx?$/, ''), new Date(date).toISOString());
}

// https://astro.build/config
export default defineConfig({
  // The ONE place the canonical origin lives — canonical tags, Open Graph URLs,
  // JSON-LD, robots.txt and the sitemap all derive from it.
  site: 'https://cirrusquit.com',

  // Emit /blog/my-post rather than /blog/my-post/ and keep the canonical tag
  // agreeing with it, so Google never sees two URLs for one page.
  trailingSlash: 'never',
  build: { format: 'file' },

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
      // 404 has noindex; the RSS route is not a page.
      filter: (page) => !/\/404\/?$/.test(page),
      serialize(item) {
        const slug = item.url.match(/\/blog\/([^/]+)\/?$/)?.[1];
        const lastmod = slug && postDates.get(slug);
        // Only posts get a lastmod. Stamping the static pages with build time
        // would claim they changed on every deploy, which is how a sitemap
        // teaches Google to stop trusting the field.
        return lastmod ? { ...item, lastmod } : item;
      },
    }),
  ],
});
