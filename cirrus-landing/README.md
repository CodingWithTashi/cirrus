# cirrus-landing

Landing page for the app at **https://cirrusquit.com**. Default Astro (minimal
template), static output, deployed to Cloudflare Pages.

It lives in the Flutter repo but is completely separate from it — nothing in the
Flutter build touches this folder, and this deploy never touches the app.

## Local

```
npm install
npm run dev        # http://localhost:4321
npm run build      # -> dist/
npm run preview
npm run deploy     # build + wrangler pages deploy (needs local `wrangler login`)
```

Node 22 (`.nvmrc`).

## Deploy

Manual only, from GitHub: **Actions → "Deploy cirrus-landing" → Run workflow →**
pick `preview` or `production`. Nothing deploys on push.

- `production` publishes on the `main` branch → serves cirrusquit.com
- `preview` publishes on `preview-<branch>` → a throwaway *.pages.dev preview URL

### One-time setup

1. Cloudflare dashboard → Workers & Pages → Create → Pages → **Direct Upload**,
   name the project `cirrus-landing` (must match `name` in `wrangler.jsonc`).
2. Repo → Settings → Secrets and variables → Actions, add:
   - `CLOUDFLARE_API_TOKEN` — API token with *Account → Cloudflare Pages → Edit*
   - `CLOUDFLARE_ACCOUNT_ID`
3. After the first production run: Pages project → **Custom domains** → add
   `cirrusquit.com` (and `www`). The domain is attached in the dashboard, not
   from `wrangler.jsonc`, so it survives deploys.

## Waitlist

The hero and footer forms post to `functions/api/subscribe.ts` — a **Cloudflare
Pages Function**, not an Astro route. Config is in `wrangler.jsonc` `vars`:
`LISTMONK_URL` and `LISTMONK_LIST_UUID`. Neither is a secret; Listmonk's public
subscription endpoint takes no API key, the list just has to be public.

Two things worth knowing before changing this:

- **Do not reach for `@astrojs/cloudflare`.** It targets Workers: it restructures
  `dist/` into `client/` + `server/` and injects an `ASSETS` binding whose name
  Pages reserves, which breaks `wrangler pages deploy`. A Pages Function sits
  beside the static build instead, so every page stays prerendered.
- **The server hop is not optional.** Listmonk needs no key, but sends no CORS
  headers, so a browser cannot post to it directly.

The endpoint rejects cross-origin posts, drops honeypot submissions without
calling Listmonk, validates, and rate-limits per IP (8/min). The form is a real
`<form>` with a real `action`, so it still works with JavaScript off.

Test it locally against the real Pages runtime:

```
npm run build
npx wrangler pages dev dist --binding LISTMONK_URL=... --binding LISTMONK_LIST_UUID=...
```

Use invalid addresses when testing anything that fires repeatedly — valid ones
reach the live list and have to be cleaned out of Listmonk by hand.

## Content rules

`src/lib/content.ts` holds the FAQ and the approved statistics. Both are rendered
into visible markup *and* structured data from that one source, so the two can
never drift — FAQ schema describing content a visitor cannot see is a manual-action
risk.

Per docs/02 §8, **no number appears on this site unless it is the visitor's own
arithmetic or carries a citation.** The cost calculator is the visitor's own
arithmetic; the stats block cites every figure. Adding a statistic means adding
its source in the same change.

## SEO notes

The `<head>` is owned by `src/layouts/BaseLayout.astro` — canonical, Open Graph,
Twitter card and JSON-LD all derive from `src/consts.ts` and the page's props.
`public/_headers` sets edge caching and security headers; the fingerprinted
`/_astro/*` assets are `immutable` for a year.

Verified live: `http`→`https` 301, `/page.html` and `/page/` both 308 to the
clean URL, Googlebot and Bingbot unblocked, Brotli active, sitemap carries
`<lastmod>` for posts.

### Canonical host

`www.cirrusquit.com` 301s to the apex via a zone-level **Redirect Rule** ("www to
apex", matching `https://www.cirrusquit.com/*` → `https://cirrusquit.com/${1}`,
preserve query string). It lives in the Cloudflare dashboard, not in this repo.

Two things to know if you ever touch it:

- Pages `_redirects` **cannot** do this. It matches on path only, so a rule whose
  source is a full URL is parsed and ignored with no error — the redirect simply
  never fires.
- Keep `www.cirrusquit.com` attached to the Pages project under Custom domains.
  The TLS handshake happens before the redirect, so detaching it breaks
  `https://www` with a certificate error instead of redirecting.

### Cloudflare managed robots.txt

The zone injects its own `robots.txt` block above the generated one, blocking
GPTBot, ClaudeBot, Google-Extended, CCBot and others (`ai-train=no`). Search
crawlers are explicitly allowed, so indexing is unaffected — but posts will not
be usable as AI training data or cited in AI answers. Toggle in AI Crawl Control.
