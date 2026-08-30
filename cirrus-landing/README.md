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

## SEO notes

The `<head>` is owned by `src/layouts/BaseLayout.astro` — canonical, Open Graph,
Twitter card and JSON-LD all derive from `src/consts.ts` and the page's props.
`public/_headers` sets edge caching and security headers; the fingerprinted
`/_astro/*` assets are `immutable` for a year.

Verified live: `http`→`https` 301, `/page.html` and `/page/` both 308 to the
clean URL, Googlebot and Bingbot unblocked, Brotli active, sitemap carries
`<lastmod>` for posts.

### Known gap: www does not redirect

`www.cirrusquit.com` serves the site rather than 301-ing to the apex. Every page
canonicalises to the apex, so Google consolidates them and this is not costing
rankings — but a redirect is the stronger signal.

Cloudflare Pages `_redirects` cannot fix it: it matches on path only, so a rule
whose source is a full URL is parsed and ignored with no error. It needs a
zone-level **Redirect Rule** (dashboard → cirrusquit.com → Rules → Redirect
Rules → Create):

- If: `hostname` equals `www.cirrusquit.com`
- Then: dynamic redirect to `concat("https://cirrusquit.com", http.request.uri.path)`, status 301, preserve query string

### Cloudflare managed robots.txt

The zone injects its own `robots.txt` block above the generated one, blocking
GPTBot, ClaudeBot, Google-Extended, CCBot and others (`ai-train=no`). Search
crawlers are explicitly allowed, so indexing is unaffected — but posts will not
be usable as AI training data or cited in AI answers. Toggle in AI Crawl Control.
