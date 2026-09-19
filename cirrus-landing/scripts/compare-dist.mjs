// Is a refactor invisible? Compares two builds page by page.
//
//   cp -r dist ../dist-before        # the build you trust
//   …make the change…  npm run build
//   npm run compare -- ../dist-before dist
//
// For a change that must not alter what the site serves — moving copy into a
// dictionary, splitting a page into components, reshaping the content layer.
// scripts/check-dist.mjs asks "is this build self-consistent?"; this asks "is it
// the SAME as the last one?", which no amount of self-consistency can answer.
//
// Byte equality is the wrong test. Moving a sentence from template text into an
// expression turns `'` into `&#39;` and drops the source's line wrapping, and
// neither changes anything a browser, a reader or a crawler sees. So each page is
// reduced to what they DO see: the sequence of tags with their attributes, the
// text between them (entities decoded, whitespace collapsed), and the JSON-LD
// parsed and re-serialised. Hashed asset names are normalised, because the CSS
// and JS bundles legitimately get new hashes. A JSON data island that is new is
// reported as a note, not a failure.
//
// It exits 1 on any difference and names the first few per page. It has been
// run against a deliberately altered copy and caught a changed word, a changed
// aria-label and a changed JSON-LD field — a comparison that cannot fail proves
// nothing, so re-check that if this file is ever rewritten.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative, sep } from 'node:path';

const [oldRoot, newRoot] = process.argv.slice(2);
if (!oldRoot || !newRoot) {
  console.error('usage: npm run compare -- <baseline dist> <new dist>');
  process.exit(2);
}

const walk = (dir) => readdirSync(dir).flatMap((n) => {
  const f = join(dir, n);
  return statSync(f).isDirectory() ? walk(f) : [f];
});
const pagesOf = (root) => new Map(walk(root).filter((f) => f.endsWith('.html')).map((f) => [relative(root, f).split(sep).join('/'), f]));

const ENT = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: '\u00a0', middot: '·' };
const decode = (s) => s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (w, b) =>
  b[0] !== '#' ? (ENT[b.toLowerCase()] ?? w) : String.fromCodePoint(b[1].toLowerCase() === 'x' ? parseInt(b.slice(2), 16) : parseInt(b.slice(1), 10)));
const squash = (s) => decode(s).replace(/\s+/g, ' ').trim();
const unhash = (s) => s.replace(/(\/_astro\/[^"'\s]*?)\.[A-Za-z0-9_-]{6,12}(\.(?:css|js|mjs))/g, '$1$2');

function tokens(html) {
  const out = [];
  const jsonld = [];
  const islands = [];
  // Pull scripts and styles out first: their bodies are not markup.
  html = html.replace(/<(script|style)\b([^>]*)>([\s\S]*?)<\/\1>/gi, (_, tag, attrs, body) => {
    if (/application\/ld\+json/i.test(attrs)) jsonld.push(JSON.stringify(JSON.parse(body)));
    else if (/application\/json/i.test(attrs)) islands.push(attrs.trim());
    else out.push(`<${tag.toLowerCase()} ${/src=/.test(attrs) ? unhash(squash(attrs)) : 'inline'}>`);
    return '';
  });
  for (const m of html.matchAll(/<!--[\s\S]*?-->|<\/?[a-zA-Z][^>]*>|[^<]+/g)) {
    const t = m[0];
    if (t.startsWith('<!--')) continue;
    if (t[0] === '<') {
      const name = t.match(/^<\/?([a-zA-Z0-9-]+)/)[1].toLowerCase();
      if (t[1] === '/') { out.push(`</${name}>`); continue; }
      const attrs = [...t.replace(/^<[a-zA-Z0-9-]+/, '').matchAll(/([\w:@.-]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g)]
        .map((a) => `${a[1].toLowerCase()}=${unhash(squash(a[2] ?? a[3] ?? a[4] ?? ''))}`)
        // Astro's scoped-style markers are build hashes, not content.
        .filter((a) => !/^data-astro-(cid|source)/.test(a))
        .sort();
      out.push(`<${name} ${attrs.join(' ')}>`);
    } else {
      const text = squash(t);
      if (text) out.push(`"${text}"`);
    }
  }
  // Adjacent text nodes are one run of text to a reader: `a <b>x</b>` keeps its
  // tags, but `foo` + `bar` split by an expression boundary is just "foobar".
  const merged = [];
  for (const tok of out) {
    const last = merged[merged.length - 1];
    if (tok[0] === '"' && last?.[0] === '"') merged[merged.length - 1] = `"${squash(last.slice(1, -1) + ' ' + tok.slice(1, -1))}"`;
    else merged.push(tok);
  }
  return { tokens: merged, jsonld, islands };
}

const oldPages = pagesOf(oldRoot);
const newPages = pagesOf(newRoot);
let identical = 0;
const problems = [];
const notes = new Set();

for (const name of new Set([...oldPages.keys(), ...newPages.keys()])) {
  if (!oldPages.has(name)) { problems.push(`${name}: NEW page (not in baseline)`); continue; }
  if (!newPages.has(name)) { problems.push(`${name}: MISSING from the new build`); continue; }
  const a = tokens(readFileSync(oldPages.get(name), 'utf8'));
  const b = tokens(readFileSync(newPages.get(name), 'utf8'));
  const diffs = [];
  const n = Math.max(a.tokens.length, b.tokens.length);
  for (let i = 0; i < n && diffs.length < 4; i++) {
    if (a.tokens[i] !== b.tokens[i]) diffs.push(`  @${i}\n    old: ${String(a.tokens[i]).slice(0, 220)}\n    new: ${String(b.tokens[i]).slice(0, 220)}`);
  }
  if (a.jsonld.join('|') !== b.jsonld.join('|')) diffs.push('  JSON-LD differs');
  for (const isl of b.islands) if (!a.islands.includes(isl)) notes.add(`data island added: <script ${isl}> on ${name}`);
  if (diffs.length) problems.push(`${name}:\n${diffs.join('\n')}`);
  else identical += 1;
}

console.log(`${identical} of ${newPages.size} pages structurally identical to the baseline.`);
for (const n of notes) console.log(`note — ${n}`);
if (problems.length) { console.log(`\n${problems.length} page(s) differ:\n`); for (const p of problems) console.log(p + '\n'); process.exit(1); }
