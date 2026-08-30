import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
// Imported from zod directly — the `z` re-export from astro:content is deprecated in Astro 7.
import { z } from 'zod';

// Blog posts are Markdown files in src/content/blog/. The filename becomes the
// URL slug (src/content/blog/my-post.md -> /blog/my-post), so name files the way
// you want them to read in Google.
//
// The schema is enforced at build time: a post missing `title`, `description` or
// `publishedAt` fails the build instead of shipping a page with an empty <title>
// or no meta description.
const blog = defineCollection({
  loader: glob({ base: './src/content/blog', pattern: '**/*.{md,mdx}' }),
  schema: z.object({
    title: z.string().max(70, 'Keep titles under ~70 chars or Google truncates them'),
    description: z.string().min(50).max(160, 'Meta descriptions over 160 chars get cut off'),
    publishedAt: z.coerce.date(),
    updatedAt: z.coerce.date().optional(),
    tags: z.array(z.string()).default([]),
    /** Drafts build locally but are excluded from the index, sitemap and RSS. */
    draft: z.boolean().default(false),
  }),
});

export const collections = { blog };
