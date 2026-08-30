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

export function formatDate(date: Date): string {
  return date.toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
}
