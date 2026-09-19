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

## Store links

Both stores are live — Google Play, and the App Store since Sep 12 2026 — so
the site has no waitlist and no "coming soon". The URLs live in `src/consts.ts`
and only `src/lib/store.ts` turns them into hrefs; every download CTA on the site
is `src/components/StoreBadges.astro`.

- **Official badge artwork only** (`src/assets/badges/`), never redrawn or
  recoloured. Apple's SVG is inlined. Google's PNG carries its own clear space,
  so `.store--play img` scales it by 250/168 and pulls the margin back in until
  both badges share one visible height.
- **Play links carry a campaign tag** (`playUrl('hero')`, `blog-<slug>`, …) for
  Play Console's acquisition report. **App Store links carry none**: Apple only
  attributes `ct` together with a `pt` provider token, and the privacy policy
  says only Play links are tagged — change both together or neither.
- **The reader's store goes first.** BaseLayout stamps `data-os` on `<html>`
  before first paint; CSS moves Play first on Android, and the hero demo's
  Continue button opens that phone's store. With JS off both badges still show.
- **`/download` never redirects.** It is a real, indexable page, and the
  Android app claims that path through App Links (see below).
- iPhone Safari shows Apple's own Smart App Banner from the `apple-itunes-app`
  meta tag in BaseLayout.

The waitlist is gone: the form, its `/api/subscribe` Pages Function and the
Listmonk vars were removed at launch. The signups themselves are still in
Listmonk, which is why the privacy policy still describes them. `/thanks`
survives as a noindex "it's out" page in case an old confirmation link points
there.

If a form ever comes back, the old lessons still apply: **do not reach for
`@astrojs/cloudflare`** (it restructures `dist/` for Workers and breaks
`wrangler pages deploy`); put a Pages Function beside the static build instead.

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
  automatically, and an unwrapped table clips on a phone. Three posts shipped as
  pipe tables anyway and did exactly that: the table kept its 30rem min-width,
  ran past a 375px viewport, and `body { overflow-x: hidden }` cut the last
  column off with no scrollbar and no clue anything was missing. All three are
  converted, and `.prose > table` in global.css is now a safety net that lets an
  unwrapped table reflow instead of clip — write the wrapper anyway, because it
  is the version that scrolls and takes a tabindex for keyboard users.

The table of contents and the reading time are both **derived**, never typed: the
TOC comes from `render()`'s `headings` (so it cannot drift from the real H2s) and
the reading time is measured from the body. The progress bar, share row and
end-of-post store badges come from the template.

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
styling. `src/content/blog/disposables/*` is the live example.

Source files should be no wider than **2× their display size**. The prose column
is 672px, so 1344 is the ceiling; an 1800px source only makes Astro generate
variants nothing can display, and `sizes` then over-selects them on desktop.

A slot with no file yet gets a `.imgslot` placeholder carrying the intended
path, pixel size and a note on what to shoot. It reserves the real aspect ratio
via `--ratio`, so the layout under review is the layout that ships. Replace it
with a `<figure>` when the file lands — it is styled to look obviously
unfinished so it cannot be published by accident.

`public/og/` is written by `npm run og` and holds **generated** cards only. Photos
go beside the posts in `src/content/blog/<folder>/` and are referenced relatively
(`./disposables/quit-vaping.jpeg`), which is also what lets Astro optimise them —
put one in `public/og/` and the next `npm run og` leaves you unable to tell which
files are authored and which are output.

**`.prose` is the shell width; the reading measure is applied to its children,
left-aligned.** Left, not centred: the site header, the breadcrumb and the
article all start on the same axis, and a column centred inside the shell sits
about 200px right of the breadcrumb above it and reads as detached from the
page.

Images stay inside the reading measure like everything else. If a figure ever
needs to break out, give it `max-width: none` — never a `100vw` width, because
`vw` includes the scrollbar and the figure ends up a few pixels wider than the
viewport, then gets silently clipped by `body { overflow-x: hidden }`.

**Post CTAs in Markdown go to `/download`, never to a store.** Markdown cannot
read the store URLs, so a store link written into a post goes stale silently —
two of them already did, pointing at the Play listing before it was public.
`/download` is the indirection. The post template's own CTAs (the sidebar card
and the end-of-post band) are `StoreBadges`, tagged `blog-<slug>` and
`blog-<slug>-end`, which is how Play Console tells you which post converts. A
listing URL in a post's `sources` frontmatter is a citation, not a CTA.

## /get — the platform-aware download link

`/get` is the short URL to hand out: a bio, a QR code, a printed card, a reply to
someone asking what the app is called. It reads the `User-Agent` and sends
Android to Play and iPhone to the App Store, and lands everyone else on
`/download`. It is `functions/get.ts`, a Cloudflare Pages Function — **not** a
`_redirects` rule, because `_redirects` matches on path only and platform is a
header.

It was a `/get  /download  301` rule until 2026-09-12. That rule was committed in
`4964d7b` and never deployed, so `/get` answered **404 in production** for as
long as four published posts pointed their promo card at it.

- **The decision lives in `src/lib/platform.ts`, not in the Function.** The Astro
  dev middleware runs the same module, so there is one implementation and two
  adapters. Two copies of this would drift, exactly as two copies of the streak
  engine did in the app.
- **`astro dev` cannot do the real thing.** The site is `output: 'static'`, so
  Astro hands middleware an empty `Headers` — there is no User-Agent to read. The
  dev shim therefore redirects to `/download` for everyone and says so once in
  the terminal. **Test the real redirect with `npm run preview:edge`**, which
  builds and serves it under the Cloudflare runtime.
- **302, never 301.** The destination is one flag away from changing, and a 301
  is cached by the browser effectively forever — every iPhone that tapped `/get`
  before the App Store opened would keep going to `/download` afterwards, with
  nothing on the server able to reach it.
- **Bots are checked before devices.** Googlebot Smartphone identifies as a Nexus
  5X and bingbot's legacy variant as an iPhone, so a naive test redirects your
  primary indexing crawler into the Play Store. Link unfurlers are caught for the
  opposite reason: `/get` is the link under the promo card, and a bot followed to
  a store unfurls the store's card instead of ours.
- **Windows Phone is eliminated first.** Its UA spoofed *both* platforms at once
  ("Windows Phone 8.1; Android 4.0 ... like iPhone OS 7_0_3"), so excluding it
  from only one test silently makes it the other.
- **iPad Safari and desktop-mode Android tablets are undecidable** from headers —
  both report a desktop UA and Safari sends no client hints. They fall through to
  `/download`, which is why that page must always carry every open store's button
  and must never become a stub that forwards back to `/get`.
- **`public/_headers` does not apply to Function responses.** Cloudflare is
  explicit about this, so the `/*` block's HSTS and `nosniff` are restated inside
  `redirectTo()`. Without that, `/get` would be the one URL on the site served
  without them.
- **`?c=<slug>`** tags the Play referrer, same `blog-<slug>` vocabulary the post
  CTAs use. Validated against an allow-list; anything else falls back to `get`.
- Each redirect logs one `get_redirect` line (platform, campaign, destination
  host, country, referer host) — same no-vendor, no-cookie story as
  `waitlist_submit`.

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

## Languages

The app ships en, es, fr, de and pt; the site is being brought up to match (docs/10
§43–44). **Today only English is live** — what exists is the structure every other
language drops into, and it was landed as a refactor whose built output is
structurally identical to the English-only site before it.

**One list decides everything: `LIVE_LOCALES` in `src/i18n/locales.mjs`.** Routes,
hreflang, the sitemap and the language switcher all derive from it and from nothing
else, so a language goes live by being added there — one at a time if need be, after
the founder's spot-check — and a half-finished one cannot leak a URL.

| File | What it is |
|---|---|
| `src/i18n/locales.mjs` | The registry: locales, hreflang / `og:locale` / `Intl` tags, the calculator's currency. Plain `.mjs` so `astro.config.mjs`, `scripts/`, `functions/` and TypeScript can all import the same list |
| `src/i18n/en.ts` | English, **and the shape**. Every other locale is declared `: Dictionary`, so a missing key (TS2741) or an extra one (TS2353) fails `npm run check` — the site's `l10n_parity_test` |
| `src/i18n/index.ts` | `useT(lang)`, `fmt()` for `{placeholders}` (throws on a missing one), `clock()` for the example day |
| `src/i18n/paths.ts` | `localePath()`, `link()`, `alternatesFor()` — URLs that know which pages exist |
| `src/lib/content.ts` | Everything about the content that is **not** language: ids, order, tiers, tones, clock times. Words are keyed by these ids, so a locale cannot ship six timeline steps or a statistic without its `source` |
| `src/components/pages/*.astro` | The page bodies. `src/pages/index.astro`, `download.astro` and `404.astro` are five-line wrappers and **do not move** — App Links claims `/download` |

**Proving a refactor changed nothing.** `npm run compare -- <baseline dist> <new dist>`
(`scripts/compare-dist.mjs`) reduces every page of two builds to what a browser, a reader
and a crawler actually get — tags and attributes, decoded text, parsed JSON-LD — and fails
on any difference. It is how the language structure was landed with English untouched, and
it is the gate for the next change of that kind (the blog's language plumbing).

Rules that are easy to get wrong:

- **Locale homes are `/es`, never `/es/`.** `build.format: 'file'` writes `dist/es.html`
  beside a `dist/es/` directory — the shape `/blog` already has — and Pages 308s the
  slashed form. Every canonical, hreflang, sitemap entry and switcher href is slashless.
- **Astro's own `i18n` config stays off.** Its URL helpers return `/es/privacy` without
  checking there is one. The legal pages are English-only on purpose (their URLs are
  frozen by the stores and the apps, and a translated policy is a second legal text), and
  the blog is translated a few posts at a time. `link()` answers with the localized URL
  when the page exists and the English one, flagged `hreflang="en"`, when it does not.
  **Never set `fallback`**: it publishes English bodies under `/es/…`.
- **No Accept-Language redirect.** Googlebot sends none and crawls from the US, so it
  would only ever see English and every hreflang target would look like a redirect.
  hreflang plus `x-default` is the supported mechanism.
- **The hreflang self-reference is a build error, not a warning.** `BaseLayout` throws if
  `alternates[lang]` is not the page's own canonical path.
- **No HTML in a dictionary string, ever.** A sentence that needs markup is split
  (`{ pre, accent, post }`), which also survives a language that moves the emphasis.
- **Strings the calculator swaps at runtime travel in a JSON data island**
  (`#demo-i18n`). Astro bundles a component's `<script>` once for every page, so it has
  no `lang`; and `define:vars` would force it inline and unbundled.
- **es and pt are written for the wider audience** — neutral international Spanish and
  Brazilian Portuguese (founder decision, Sep 19 2026). That is *not* the app's dialect:
  `app_es.arb` is Peninsular and `app_pt.arb` is European. fr and de copy the ARB wording
  verbatim. In every language, reuse the app's feature **names** and never its allowance
  **claims** — the ARB says "Unlimited AI coach"; the server enforces 100 a day and this
  site says what the server does.
- **Play campaigns take the locale as a prefix**: `es-hero`, `fr-blog-<slug>-end`
  (`campaignFor()` in `src/lib/store.ts`). English names are untouched, because installs
  already attributed to them cannot be re-attributed. Frozen at the first tagged install.
- **The calculator's currency is config, not copy** (`DEMO_CURRENCY`). `/es` and `/pt`
  serve two continents each, so they show a bare, locale-grouped number: the arithmetic
  is the visitor's own, and a symbol would be a guess about where they live.

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

**Two different things are called `.post-cta`:** the sidebar card
(`PostCta.astro`, scoped styles) and the end-of-post band (`[...slug].astro`).
The band's rules in global.css are scoped to **`.post-cta--end`** for that
reason. They were not, and every property the band declared that the card did
not leaked into the sidebar — a 42rem max-width on a 14rem column, and
`margin: 0.7rem 0 0` on `.post-cta__line` overriding the card's own
`margin-bottom` so the Play button sat flush against the text above it. Keep new
band rules on `--end`.

Two more things that were wrong in the same card and are worth not repeating:
`.btn` centres its label with `align-items`/`justify-content`, so overriding it
to `display: block` silently turns both off and the label sits at the top of the
54px min-height; and `.micro` is an 11px/800-weight/uppercase **label** device,
not body copy — a wrapping sentence set in it is unreadable.

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

`npm run verify` (`scripts/check-dist.mjs`) enforces it: it parses the JSON-LD on every
built page and fails if a `FAQPage` question string appears on two pages, or appears in
the schema without a visible `<summary>` carrying the same words. Done by hand, that check
caught a real duplicate ("How much nicotine is in a Geek Bar Pulse?") across two posts. The
same script checks canonicals, internal links and `#anchors`, and that the sitemap agrees
with which pages are indexable; the deploy workflow runs it between Build and Deploy.

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

### robots.txt and AI crawlers

`src/pages/robots.txt.ts` is the whole file crawlers see. Cloudflare's managed
`robots.txt` prepend (AI Crawl Control → Signals) is **off** — verified against the
live file on Sep 19 2026, which is byte-for-byte the generated one. If that toggle
is ever switched back on, the zone injects its own block above ours and the two
can disagree.

The generated file says `ai-train=no` and disallows the bulk training crawlers
(GPTBot, ClaudeBot, CCBot, Bytespider and others). It deliberately does **not**
block the AI *search* and assistant crawlers (OAI-SearchBot, ChatGPT-User,
PerplexityBot, Applebot) or Google-Extended: being cited in an answer is
distribution, and it is how a new app gets found.
