// @ts-check
import { defineConfig, fontProviders } from 'astro/config';
import sitemap from '@astrojs/sitemap';

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
    }),
  ],
});
