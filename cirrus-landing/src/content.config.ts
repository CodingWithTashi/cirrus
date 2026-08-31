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

    /**
     * Per-post social card, rendered by `npm run og`. Used twice: as the
     * og:image and as the featured image at the top of the article, so the two
     * can never disagree. Falls back to the site default when absent.
     */
    image: z.string().optional(),
    imageAlt: z.string().optional(),

    /**
     * The deck: one sentence under the headline that says what the piece is.
     * Distinct from `description`, which is written for a search result.
     */
    standfirst: z.string().optional(),

    /**
     * Key takeaways, rendered as the TL;DR box above the article. Long research
     * posts get skimmed before they get read, and this is what a skimmer takes
     * away — so it carries the conclusions, not a summary of the structure.
     */
    takeaways: z.array(z.string()).default([]),

    // ---- E-E-A-T ----
    //
    // Google classes anything about nicotine, lungs or medication as "Your Money
    // or Your Life" and applies its strictest quality bar to it. An anonymous
    // byline is the single most common reason a health page fails to rank, so
    // these are the fields that matter most on this site — but they are optional
    // and NEVER defaulted, because a fabricated author or a reviewer who did not
    // review is worse than no byline at all. Fill them with real people.
    author: z.string().optional(),
    authorTitle: z.string().optional(),
    reviewedBy: z.string().optional(),
    reviewedByTitle: z.string().optional(),
    reviewedOn: z.coerce.date().optional(),

    /**
     * Renders the standard medical disclaimer under the post. Set it on anything
     * that touches health, dependence or medication.
     */
    medical: z.boolean().default(false),

    /**
     * Post FAQ. Rendered as visible markup AND as FAQPage structured data from
     * this one definition — same rule as the landing page's FAQ in
     * src/lib/content.ts. Schema describing content a visitor cannot see is a
     * manual-action risk, so the FAQ never lives in the post body.
     */
    faq: z.array(z.object({ q: z.string(), a: z.string() })).default([]),

    /**
     * Citations, rendered as the post's source list. Per the site's honest-stats
     * rule every figure in a post traces to a row here; `id` is the DOI, PMID or
     * PMC number, shown on screen so the citation survives a dead link.
     */
    sources: z
      .array(z.object({ text: z.string(), id: z.string().optional(), url: z.url().optional() }))
      .default([]),
  }),
});

export const collections = { blog };
