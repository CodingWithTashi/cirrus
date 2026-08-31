---
title: Welcome to the Cirrus blog
description: A sample post that proves the blog pipeline works end to end — delete it and write your own once you are ready to publish.
publishedAt: 2026-08-30
tags: ['meta']
draft: true
---

This is a sample post. It exists so the blog route, the sitemap, the RSS feed and
the structured data all have something real to render — delete the file once you
publish your first real piece.

## How to add a post

Drop a Markdown file in `src/content/blog/`. The filename becomes the URL, so
`quitting-vaping-week-one.md` publishes at `/blog/quitting-vaping-week-one`.

Every post needs frontmatter:

```yaml
---
title: Your title, under 70 characters
description: 50–160 characters. This is the meta description Google shows.
publishedAt: 2026-09-01
tags: ['research']
draft: false
---
```

The schema is enforced at build time. If a description is too long or a date is
missing, `npm run build` fails with the offending file named — a post can't ship
with a broken `<title>` or an empty meta description.

## Drafts

Set `draft: true` and the post stays visible in `npm run dev` but is excluded
from the blog index, the sitemap and the RSS feed, and carries a `noindex` tag
if reached directly.
