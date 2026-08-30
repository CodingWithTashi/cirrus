import rss from '@astrojs/rss';
import type { APIContext } from 'astro';
import { SITE_TITLE, SITE_DESCRIPTION } from '../consts';
import { getPublishedPosts } from '../lib/posts';

export async function GET(context: APIContext) {
  const posts = await getPublishedPosts();

  return rss({
    title: `${SITE_TITLE} blog`,
    description: SITE_DESCRIPTION,
    site: context.site!,
    // Match `trailingSlash: 'never'`; the default appends one, so every feed
    // link would 308-redirect on the way in.
    trailingSlash: false,
    items: posts.map((post) => ({
      title: post.data.title,
      description: post.data.description,
      pubDate: post.data.publishedAt,
      // No trailing slash — matches `trailingSlash: 'never'` and the sitemap.
      link: `/blog/${post.id}`,
      categories: post.data.tags,
    })),
  });
}
