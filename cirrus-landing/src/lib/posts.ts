import { getCollection, type CollectionEntry } from 'astro:content';

/**
 * The one place "which posts are public" is decided — the blog index, the
 * sitemap filter and the RSS feed all call this, so a draft can never leak
 * into one surface while being hidden from another.
 *
 * Drafts stay visible in `astro dev` so you can preview them locally.
 */
export async function getPublishedPosts(): Promise<CollectionEntry<'blog'>[]> {
  const posts = await getCollection('blog', ({ data }) => import.meta.env.DEV || !data.draft);
  return posts.sort((a, b) => b.data.publishedAt.getTime() - a.data.publishedAt.getTime());
}

/**
 * Reading time in whole minutes, measured rather than claimed — the same rule
 * the rest of the site follows for numbers. 200 wpm is the usual figure for
 * screen reading of non-fiction.
 *
 * Strips inline HTML before counting. A post carrying a few figures and image
 * placeholders has a lot of markup in its body, and counting `<figcaption>` as
 * a word pushed the estimate a whole minute over what anyone actually reads.
 */
export function readingTime(body: string): number {
  const prose = body
    .replace(/<[^>]+>/g, ' ')
    .replace(/[#*_`>|-]/g, ' ')
    .trim();
  const words = prose ? prose.split(/\s+/).length : 0;
  return Math.max(1, Math.round(words / 200));
}

export function formatDate(date: Date): string {
  // Frontmatter dates are plain calendar dates, which z.coerce.date() parses as
  // UTC midnight. Formatting those in the local zone renders the previous day
  // anywhere west of UTC — a post dated 2026-08-30 displayed as August 29.
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    timeZone: 'UTC',
  });
}
