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
