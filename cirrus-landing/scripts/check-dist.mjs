// Checks the BUILT site (dist/), not the source. Run with `npm run verify`,
// after `npm run build` — the deploy workflow runs it between Build and Deploy.
//
// `astro check` reads source, so it cannot see the four things that only exist
// once the pages are rendered, and each of them fails silently in production:
//
//   A. CANONICALS. Exactly one per page, equal to the URL the file is served
//      at. `build.format: 'file'` writes /blog/post.html, and a canonical that
//      keeps the .html or a trailing slash names a URL the sitemap never
//      mentions — Google then sees two pages.
//   B. ONE QUERY, ONE PAGE (README, "Keyword targeting"). A question emitted as
//      FAQPage schema on two pages makes them compete for the same result. The
//      README asked for this check; nothing implemented it. It also asserts the
//      question is VISIBLE on the page, because FAQ markup for content a reader
//      cannot see is what gets a site's rich results withdrawn.
//   C. INTERNAL LINKS. Every internal href resolves to a file in dist, and
//      every #fragment to an id on the page it points at. Markdown posts link
//      by hand, and a renamed slug breaks them without a build error.
//   D. SITEMAP. Every indexable page is listed and no noindex page is.
//
// No dependencies and no HTML parser: the pages are our own build output, so a
// tag regex plus an attribute reader is enough, and a check that needs an
// install step is a check that gets skipped.
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = (p) => fileURLToPath(new URL(p, import.meta.url));
const DIST = here('../dist');

// Served by something other than a file in dist: /get is the Pages Function.
const NOT_FILES = new Set(['/get']);

if (!existsSync(DIST)) {
  console.error('check-dist: dist/ does not exist. Run `npm run build` first.');
  process.exit(1);
}

// The one canonical origin, read from the same place Astro reads it.
const SITE = (() => {
  const config = readFileSync(here('../astro.config.mjs'), 'utf8');
  const m = config.match(/\bsite:\s*['"]([^'"]+)['"]/);
  if (!m) throw new Error('check-dist: could not read `site` from astro.config.mjs');
  return m[1].replace(/\/$/, '');
})();

const errors = [];
const fail = (page, message) => errors.push(`${page}  ${message}`);

// ---------- reading dist ----------

function walk(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) out.push(...walk(full));
    else out.push(full);
  }
  return out;
}

// dist-relative, forward slashes: dev is on Windows and CI is on Linux.
const rel = (file) => relative(DIST, file).split(sep).join('/');

/** The clean URL path a built file is served at: index.html → /, blog/x.html → /blog/x. */
function urlPathOf(file) {
  const p = '/' + rel(file);
  if (p === '/index.html') return '/';
  return p.replace(/\/index\.html$/, '').replace(/\.html$/, '');
}

const files = walk(DIST);
const fileSet = new Set(files.map((f) => '/' + rel(f)));
const htmlFiles = files.filter((f) => f.endsWith('.html'));

// ---------- reading HTML ----------

const ENTITIES = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ' };
const decode = (s) =>
  s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (whole, body) => {
    if (body[0] !== '#') return ENTITIES[body.toLowerCase()] ?? whole;
    const code = body[1].toLowerCase() === 'x' ? parseInt(body.slice(2), 16) : parseInt(body.slice(1), 10);
    return Number.isFinite(code) ? String.fromCodePoint(code) : whole;
  });

/** Attributes of one tag, in any order, quoted either way. */
function attrs(tag) {
  const out = {};
  const re = /([\w:-]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g;
  // Skip the tag name itself.
  const body = tag.replace(/^<\s*[\w-]+/, '');
  for (const m of body.matchAll(re)) out[m[1].toLowerCase()] = decode(m[2] ?? m[3] ?? m[4] ?? '');
  return out;
}

const tags = (html, name) => [...html.matchAll(new RegExp(`<${name}\\b[^>]*>`, 'gi'))].map((m) => attrs(m[0]));

// Compared, never displayed: case, quote style and spacing must not let two
// copies of one question slip past as "different".
const normalize = (s) =>
  s
    .replace(/[‘’]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();

const typesOf = (node) => [].concat(node?.['@type'] ?? []);

/** Every FAQPage question in the page's JSON-LD, whether or not it sits in a @graph. */
function faqQuestions(html, page) {
  const out = [];
  const blocks = html.matchAll(/<script\b[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi);
  for (const [, raw] of blocks) {
    let data;
    try {
      data = JSON.parse(raw);
    } catch (e) {
      fail(page, `JSON-LD does not parse: ${e.message}`);
      continue;
    }
    const nodes = [].concat(data?.['@graph'] ?? data);
    for (const node of nodes) {
      if (!typesOf(node).includes('FAQPage')) continue;
      for (const q of [].concat(node.mainEntity ?? [])) if (q?.name) out.push(String(q.name));
    }
  }
  return out;
}

const pages = htmlFiles.map((file) => {
  const html = readFileSync(file, 'utf8');
  const path = urlPathOf(file);
  const robots = tags(html, 'meta').find((m) => m.name === 'robots')?.content ?? '';
  return {
    path,
    html,
    noindex: /\bnoindex\b/i.test(robots),
    ids: new Set([...html.matchAll(/\sid\s*=\s*(?:"([^"]*)"|'([^']*)')/gi)].map((m) => decode(m[1] ?? m[2]))),
  };
});
const pageByPath = new Map(pages.map((p) => [p.path, p]));

// ---------- A. canonicals ----------

const urlOf = (path) => (path === '/' ? `${SITE}/` : `${SITE}${path}`);

for (const page of pages) {
  const canonicals = tags(page.html, 'link').filter((l) => l.rel === 'canonical');
  if (canonicals.length !== 1) {
    fail(page.path, `expected exactly one canonical, found ${canonicals.length}`);
    continue;
  }
  const expected = urlOf(page.path);
  if (canonicals[0].href !== expected) fail(page.path, `canonical is ${canonicals[0].href}, expected ${expected}`);
}

// ---------- B. one query, one page ----------

const owners = new Map(); // normalized question → [page paths]
let questionCount = 0;

for (const page of pages) {
  const questions = faqQuestions(page.html, page.path);
  if (questions.length === 0) continue;

  const visible = new Set(
    [...page.html.matchAll(/<summary\b[^>]*>([\s\S]*?)<\/summary>/gi)].map((m) =>
      normalize(decode(m[1].replace(/<[^>]+>/g, ' '))),
    ),
  );

  const seenHere = new Set();
  for (const q of questions) {
    questionCount += 1;
    const key = normalize(q);
    if (seenHere.has(key)) fail(page.path, `FAQ question appears twice in this page's schema: "${q}"`);
    seenHere.add(key);
    if (!visible.has(key)) fail(page.path, `FAQ question is in the schema but not in a visible <summary>: "${q}"`);
    owners.set(key, [...(owners.get(key) ?? []), page.path]);
  }
}

for (const [question, paths] of owners) {
  if (paths.length > 1) fail(paths.join(' + '), `same FAQ question emitted as FAQPage schema on ${paths.length} pages: "${question}"`);
}

// ---------- C. internal links ----------

/** The page (or file) an internal path resolves to, or null. */
function resolve(path) {
  const clean = path.length > 1 ? path.replace(/\/$/, '') : path;
  if (NOT_FILES.has(clean)) return { file: true };
  if (pageByPath.has(clean)) return { page: pageByPath.get(clean) };
  if (fileSet.has(clean)) return { file: true };
  return null;
}

let linkCount = 0;

for (const page of pages) {
  for (const a of tags(page.html, 'a')) {
    const href = a.href;
    if (!href) continue;

    let url;
    try {
      url = new URL(href, urlOf(page.path));
    } catch {
      fail(page.path, `unparseable href "${href}"`);
      continue;
    }
    if (url.origin !== SITE) continue; // external, mailto:, tel: — not ours to check
    linkCount += 1;

    const target = resolve(decodeURIComponent(url.pathname));
    if (!target) {
      fail(page.path, `link to ${url.pathname} resolves to nothing in dist`);
      continue;
    }
    const fragment = decodeURIComponent(url.hash.slice(1));
    if (fragment && target.page && !target.page.ids.has(fragment)) {
      fail(page.path, `link to ${url.pathname}#${fragment}: no element with that id on ${target.page.path}`);
    }
  }
}

// ---------- D. sitemap ----------

const sitemapFiles = files.filter((f) => /\/sitemap-\d+\.xml$/.test('/' + rel(f)));
if (sitemapFiles.length === 0) {
  fail('sitemap', 'no sitemap-N.xml in dist');
} else {
  // The sitemap writes the root without a trailing slash; the canonical writes it
  // with one. Same URL, so compare both with the slash removed.
  const bare = (u) => u.replace(/\/$/, '');
  const listed = new Set();
  for (const file of sitemapFiles) {
    for (const [, loc] of readFileSync(file, 'utf8').matchAll(/<loc>([^<]+)<\/loc>/g)) listed.add(bare(decode(loc.trim())));
  }
  for (const page of pages) {
    const url = bare(urlOf(page.path));
    if (page.noindex && listed.has(url)) fail(page.path, 'is noindex but listed in the sitemap');
    if (!page.noindex && !listed.has(url)) fail(page.path, 'is indexable but missing from the sitemap');
  }
  for (const url of listed) {
    if (!pageByPath.has(url === SITE ? '/' : url.slice(SITE.length))) fail('sitemap', `lists ${url}, which is not a page in dist`);
  }
}

// ---------- report ----------

if (errors.length > 0) {
  console.error(`check-dist: ${errors.length} problem${errors.length === 1 ? '' : 's'} in dist/\n`);
  for (const e of errors) console.error(`  ${e}`);
  process.exit(1);
}

console.log(
  `check-dist: ${pages.length} pages, ${linkCount} internal links, ${questionCount} FAQ questions, ` +
    `${sitemapFiles.length} sitemap file${sitemapFiles.length === 1 ? '' : 's'} — all consistent.`,
);
