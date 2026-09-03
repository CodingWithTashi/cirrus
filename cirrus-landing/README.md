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

### Blog posts

Markdown in `src/content/blog/`; the filename is the URL. `src/content.config.ts`
enforces the frontmatter at build time, so a broken post fails `npm run build`
rather than shipping. Beyond `title`/`description`/`publishedAt`:

| Field | What it does |
|---|---|
| `faq` | List of `{q, a}`. Rendered as the visible FAQ **and** as `FAQPage` schema, from this one definition — same anti-drift rule as the landing page FAQ. Never put a post's FAQ in the body. |
| `sources` | List of `{text, id?, url?}`. Renders the citation list. `id` (DOI/PMID/PMC) shows on screen so the citation survives a dead link. |
| `medical` | Adds the standard medical disclaimer. Set it on anything touching health, dependence or medication. |
| `author`, `authorTitle` | Byline. |
| `reviewedBy`, `reviewedByTitle`, `reviewedOn` | Clinical reviewer credit. |
| `standfirst` | The deck: one line under the headline. Distinct from `description`, which is written for a search result. |
| `takeaways` | Bullets for the TL;DR box above the article. Inline HTML allowed, so figures can be `<b>`-set. |
| `image`, `imageAlt` | Per-post card, rendered by `npm run og`. Used **twice** — as `og:image` and as the featured image at the top of the post — so the two can never disagree. Falls back to `/og.png`. |

Reading time is **measured from the post body at 200 wpm**, not typed into
frontmatter — same reason no other number on this site is hand-entered.

Two things that are easy to get wrong:

- **The byline fields are never defaulted, and must never be filled with a
  placeholder.** Google treats nicotine and lung content as "Your Money or Your
  Life" and applies its strictest quality bar; a named author plus a named
  clinical reviewer does more for a health post's ranking than any technical
  tweak. But a fabricated author, or a reviewer who did not review, is worse
  than no byline — so the template renders nothing at all when they are absent.
- **Wide tables need `<div class="table-wrap" tabindex="0">` around them**, which
  means writing that table as HTML rather than a pipe table. Astro 7's default
  Markdown processor takes no rehype plugins, so the wrapper cannot be added
  automatically, and an unwrapped table clips on a phone.

The table of contents and the reading time are both **derived**, never typed: the
TOC comes from `render()`'s `headings` (so it cannot drift from the real H2s) and
the reading time is measured from the body. The progress bar, share row and
end-of-post form come from the template.

#### In-article furniture

Deliberately almost none. An article is for reading, so the only devices are the
ones every publishing platform ships: a pull quote (plain `>` blockquote), a
figure with a caption, and a table. No cards, chips, tinted callouts or coloured
tiles — they read as a dashboard, not a piece of writing.

Article type is set once in `global.css`: **19px / 1.65 line-height / 42rem
measure** (~68 characters), which is where Medium, Squarespace and the default
WordPress themes all land. The rest of the site stays at 16px; only `.prose`
changes.

#### Images

**Never put a content image in `public/`.** Astro only optimizes what it can see
in `src/`, and anything under `public/` is copied through untouched: no WebP, no
`srcset`, no content hash, and therefore no `immutable` cache header either.

Post images live next to the post (`src/content/blog/<slug>/`) and are referenced
with **native Markdown syntax**, which is the only form Astro's Markdown
processor optimizes. Raw `<img src="...">` passes through unchanged, so it is
silently the slow path:

```
<figure>

![Alt text describing the photo](./my-post/photo.jpg)

<figcaption>The caption.</figcaption>
</figure>
```

The **blank lines around the image are load-bearing** — without them CommonMark
emits the `![]()` as literal text. The `<figure>` and its `class` survive, so
`class="figure--phone"` still works for a portrait screenshot (which otherwise
renders taller than the viewport). Markdown wraps the image in a `<p>`; the
`.prose figure p { margin: 0 }` rule strips the inherited paragraph margin.

Images used in `.astro` files use `<Image>` from `astro:assets` with imports from
`src/assets/`. Pass **width only, never width and height**, for the phone
screenshots: `.phone img` crops from the top via `object-position`, while sharp's
default `cover` fit crops from the centre, so a mismatched height visibly
reframes them.

`public/logo.png` stays where it is despite being unrendered — it is the
`Organization.logo` URL in the JSON-LD, which must be a stable, unhashed raster
PNG that crawlers can fetch. Do not point structured data at `/_astro/`.

**An illustration must say so, in the caption.** A mock-up of branded packaging
carrying invented figures, sitting in a post about how those figures are
misleading, reads as evidence unless it is labelled — which is the honest-numbers
rule (docs/02 §8) failing through a picture instead of a sentence. Where an image
is not a photograph of a real thing, the caption opens with **Illustration only.**
and the alt text says the same, since a screen-reader user never sees the caption
styling. `public/blog/disposables/*` is the live example.

Source files should be no wider than **2× their display size**. The prose column
is 672px, so 1344 is the ceiling; an 1800px source only makes Astro generate
variants nothing can display, and `sizes` then over-selects them on desktop.

A slot with no file yet gets a `.imgslot` placeholder carrying the intended
path, pixel size and a note on what to shoot. It reserves the real aspect ratio
via `--ratio`, so the layout under review is the layout that ships. Replace it
with a `<figure>` when the file lands — it is styled to look obviously
unfinished so it cannot be published by accident.

`public/og/` is written by `npm run og` and holds **generated** cards only. Photos
go in `public/blog/<slug>/`, or the next `npm run og` leaves you unable to tell
which files are authored and which are output.

**`.prose` is the shell width; the reading measure is applied to its children,
left-aligned.** Left, not centred: the site header, the breadcrumb and the
article all start on the same axis, and a column centred inside the shell sits
about 200px right of the breadcrumb above it and reads as detached from the
page.

Images stay inside the reading measure like everything else. If a figure ever
needs to break out, give it `max-width: none` — never a `100vw` width, because
`vw` includes the scrollbar and the figure ends up a few pixels wider than the
viewport, then gets silently clipped by `body { overflow-x: hidden }`.

**Post CTAs go to `/download`, never to `play.google.com`.** Markdown cannot read
`PLAY_STORE_URL`, so a store link written into a post goes stale silently — two
of them already did, pointing at the listing before it was public. `/download`
is the indirection: one page that stays correct whether the store is open or
not, and the only place besides `src/lib/store.ts` that knows the store URL.
The end-of-post form tags its signups `blog-<slug>`, which is what tells you a
post is converting.

**The waitlist did not retire when Android shipped — it became the iPhone list.**
About half of this site's readers are on iOS and that build is months away.
`/download` shows the Play button *and* an iOS signup; the home hero
deliberately still leads with the waitlist.

## App Links

`public/.well-known/assetlinks.json` is what lets `cirrusquit.com` links open the
Android app. It carries two SHA-256 fingerprints — the Play App Signing key
(what Play-installed builds are signed with) and the upload key (what internal
testing and local release builds are signed with) — both from Play Console →
Test and release → Setup → App signing.

Four things this depends on, none of which fail loudly:

- **`Content-Type: application/json`.** Set in `public/_headers`. Google's
  verifier rejects anything else, and Pages would otherwise guess a type for a
  file in a dot-directory.
- **The apex host only.** `www` 301s here, and the Digital Asset Links verifier
  does not follow redirects — declaring both hosts fails the whole set.
- **The app claims `/download` and nothing else.** (`/go/*` is reserved for the deferred-context links but is NOT claimed until the site serves it and `LpDeepLinks` routes it — a claimed path with no destination 404s the very people who do not have the app.) An unscoped claim
  would make the in-app "Privacy policy" link re-open the app instead of showing
  the policy, and would pull every shared blog URL away from the site. The
  manifest carries the same note; `test/android_manifest_test.dart` pins it, and
  cross-checks the claimed prefixes against the URLs `LpLinks` opens in a browser.
- **A new signing key means a new fingerprint here.** It is an array, so adding
  one needs no app release.

Check it end to end with Google's own resolver rather than a browser:

```
curl -sI https://cirrusquit.com/.well-known/assetlinks.json   # 200, application/json, no redirect
https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://cirrusquit.com&relation=delegate_permission/common.handle_all_urls
adb shell pm get-app-links com.quitvape.last_puff             # on device
```

## SEO notes

The `<head>` is owned by `src/layouts/BaseLayout.astro` — canonical, Open Graph,
Twitter card and JSON-LD all derive from `src/consts.ts` and the page's props.
`public/_headers` sets edge caching and security headers; the fingerprinted
`/_astro/*` assets are `immutable` for a year.

Verified live: `http`→`https` 301, `/page.html` and `/page/` both 308 to the
clean URL, Googlebot and Bingbot unblocked, Brotli active, sitemap carries
`<lastmod>` for posts.

### Post layout

A blog post is a two-column grid (`.post-layout`): the article at the reading
measure, and a **sticky sidebar** of related posts beside it. Below 58rem it
collapses to one column and the sidebar stacks under the article — the same
element either way, because rendering it twice would put every link on the page
twice.

`.prose` owns the 42rem measure so any page can use it standalone (the legal
pages do). Inside a post that is a no-op, since `.post-main` is the same width.

### Legal pages

`/privacy` and `/terms` are real pages here (`src/pages/*.astro`), not links to
another host. The copy was transferred **verbatim** from the versions previously
on Firebase Hosting — it is legal text, so it gets moved, never paraphrased.
`LEGAL_LAST_UPDATED` in `consts.ts` dates both; bump it when either changes.

`PRIVACY_URL` / `TERMS_URL` are now site-relative, so the footer, the JSON-LD
and anything else pointing at them follows automatically.

**The Firebase copies still exist** at `alastpuff.web.app/privacy` and `/terms`.
Two live copies of the same text on two domains is duplicate content: redirect
those to the apex, or delete them, once the Flutter app stops linking to them.

### Structured data

One `@graph` per page, built in `BaseLayout.astro`. Three things in it are load-bearing
and easy to break:

- **`publisher.logo` must be an `ImageObject` with dimensions.** A bare URL string is
  silently ignored and the article loses publisher attribution in rich results.
- **`BlogPosting.author` is never absent.** A named `Person` when a post has a byline,
  the `Organization` otherwise. Health content with no author at all is the most common
  reason a page fails Google's quality bar.
- **`mainEntityOfPage`** pins the article to its canonical URL, which starts mattering
  the moment a post is syndicated.

`SOCIAL_PROFILES` in `consts.ts` feeds `Organization.sameAs` and is deliberately empty:
that is how Google ties a domain to a known entity, so fill it when real accounts exist.
A `sameAs` pointing at a profile that does not exist is worse than none.

### Keyword targeting

One page targets one query. The blog index is not a filing cabinet — it carries its own
title and copy for "quitting vaping" rather than spending a title tag on the word "Blog".

Internal links are the main way relevance moves between pages here, and the anchor text
is most of that signal, so links read "knowing your real puff count", never "click here"
or a bare URL. Two or three per post; a page stuffed with self-links reads as spam to
readers and to Google alike. Each post also gets three automatic onward links from the
"Keep reading" block, which prefers posts sharing a tag.

**ONE QUERY, ONE PAGE.** Two pages answering the same question compete, and Google
usually resolves that by ranking neither. The trap here is `FAQS` in `src/lib/content.ts`:
those questions are real search queries, they render on the home page as copy *and* as
`FAQPage` schema, and several are now owned by a post. Where that is true the home answer
is cut to two sentences plus a `more` link to the post. `more` is visible markup only and
is deliberately absent from the schema.

Check for collisions after adding any post — parse the JSON-LD on every built page and
assert no `FAQPage` question string appears twice. That check caught a real duplicate
("How much nicotine is in a Geek Bar Pulse?") across two posts.

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
