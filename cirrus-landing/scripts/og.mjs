// Renders public/og.png (1200x630) in the Midnight Ember palette.
// Regenerate with `npm run og` after editing SITE_TAGLINE in consts.ts.
//
// Rendered with resvg rather than sharp. sharp rasterises SVG through librsvg,
// which resolves fonts via fontconfig and so cannot see a project-local TTF —
// it silently fell back to Helvetica. Outlining the glyphs with opentype.js
// avoided that but hit a second librsvg bug: it drops glyphs partway through a
// run, with no warning (the card rendered "you t ink." instead of "you think.").
// resvg takes font files directly and shapes the text itself, so <text> stays
// <text> and the brand faces are the ones that actually get drawn.
//
// opentype.js is still here, but only to measure advance widths for wrapping —
// SVG has no notion of a text box, so the line breaks have to be computed.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Resvg } from '@resvg/resvg-js';
import opentype from 'opentype.js';

const here = (p) => fileURLToPath(new URL(p, import.meta.url));

const DISPLAY_TTF = here('./fonts/SpaceGrotesk-Bold.ttf');
const BODY_TTF = here('./fonts/Inter-Regular.ttf');

// parse() wants an ArrayBuffer, and Node pools Buffers — .buffer alone hands it
// the whole pool at the wrong offset.
const loadFont = (file) => {
  const buf = readFileSync(file);
  return opentype.parse(buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength));
};

const display = loadFont(DISPLAY_TTF);

// Sum per-glyph advances instead of font.getAdvanceWidth(): that call routes
// through opentype's text shaper, which throws on Inter's ccmp table.
const width = (font, text, size) => {
  const scale = size / font.unitsPerEm;
  let x = 0;
  let prev = null;
  for (const ch of text) {
    const glyph = font.charToGlyph(ch);
    if (prev) x += font.getKerningValue(prev, glyph) * scale;
    x += glyph.advanceWidth * scale;
    prev = glyph;
  }
  return x;
};

const consts = readFileSync(here('../src/consts.ts'), 'utf8');
const pick = (name) => consts.match(new RegExp(`${name}\\s*=\\s*'([^']*)'`))?.[1] ?? '';

const title = pick('SITE_TITLE');
const tagline = `${pick('SITE_TAGLINE')}.`;
const SUB = 'A taper built on your real numbers. No invented stats.';
const DOMAIN = 'cirrusquit.com';

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

const MARGIN = 88;
const MAX_W = 1200 - MARGIN * 2;
const SIZE = 76;

// Greedy wrap on measured advance widths.
const lines = [];
let line = '';
for (const word of tagline.split(' ')) {
  const candidate = line ? `${line} ${word}` : word;
  if (width(display, candidate, SIZE) > MAX_W && line) {
    lines.push(line);
    line = word;
  } else {
    line = candidate;
  }
}
if (line) lines.push(line);

const LINE_H = SIZE * 1.14;
// Bottom-anchor the block so 1, 2 or 3 lines all clear the subhead.
const firstBaseline = 396 - (lines.length - 1) * LINE_H;
const btnW = Math.round(width(display, DOMAIN, 23) + 60);

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <defs>
    <radialGradient id="glow" cx="10%" cy="86%" r="58%">
      <stop offset="0%" stop-color="#ff8a00" stop-opacity="0.28"/>
      <stop offset="100%" stop-color="#ff8a00" stop-opacity="0"/>
    </radialGradient>
  </defs>

  <rect width="1200" height="630" fill="#0a0c10"/>
  <rect width="1200" height="630" fill="url(#glow)"/>
  <rect x="0" y="0" width="1200" height="6" fill="#c8f542"/>

  <circle cx="${MARGIN}" cy="84" r="13" fill="#ff8a00"/>
  <text x="${MARGIN + 30}" y="96" font-family="Space Grotesk" font-size="34"
        font-weight="700" fill="#ffffff">${esc(title)}</text>

  <text font-family="Space Grotesk" font-size="${SIZE}" font-weight="700" fill="#ffffff">
    ${lines
      .map((l, i) => `<tspan x="${MARGIN}" y="${(firstBaseline + i * LINE_H).toFixed(1)}">${esc(l)}</tspan>`)
      .join('\n    ')}
  </text>

  <text x="${MARGIN}" y="470" font-family="Inter" font-size="29" fill="#9aa3b2">${esc(SUB)}</text>

  <rect x="${MARGIN}" y="520" width="${btnW}" height="58" rx="12" fill="#c8f542"/>
  <text x="${MARGIN + btnW / 2}" y="557" font-family="Space Grotesk" font-size="23"
        font-weight="700" fill="#0a0c10" text-anchor="middle">${esc(DOMAIN)}</text>
</svg>`;

const resvg = new Resvg(svg, {
  fitTo: { mode: 'width', value: 1200 },
  font: {
    // Only these two faces exist as far as the renderer is concerned, so a
    // typo in font-family fails loudly as a missing glyph rather than quietly
    // resolving to a system font.
    fontFiles: [DISPLAY_TTF, BODY_TTF],
    loadSystemFonts: false,
    defaultFontFamily: 'Space Grotesk',
  },
});

writeFileSync(here('../public/og.png'), resvg.render().asPng());

// Apple touch icon: the brand mark on Void, 180x180. Same renderer so the ember
// glow matches the card exactly.
const iconSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="180" height="180" viewBox="0 0 180 180">
  <defs>
    <radialGradient id="g" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#ff8a00" stop-opacity="0.55"/>
      <stop offset="100%" stop-color="#ff8a00" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="180" height="180" fill="#0a0c10"/>
  <circle cx="90" cy="90" r="72" fill="url(#g)"/>
  <circle cx="90" cy="90" r="34" fill="#ff8a00"/>
</svg>`;
writeFileSync(
  here('../public/apple-touch-icon.png'),
  new Resvg(iconSvg, { fitTo: { mode: 'width', value: 180 } }).render().asPng(),
);

console.log(`wrote public/og.png (1200x630) — headline on ${lines.length} line(s), and apple-touch-icon.png (180x180)`);

// ---------------------------------------------------------------------------
// Per-post cards.
//
// Each post gets a real 1200x630 PNG that is used twice: as the social card
// (`image` in the post's frontmatter) and as the featured image at the top of
// the article. Rendered here rather than drawn by hand so a post card can never
// go stale against its headline, and so the brand faces are the ones that
// actually get drawn — see the resvg note at the top of this file.
//
// docs/07 forbids photography, so a Cirrus hero is type, colour and numbers.
// The rank blocks below carry the article's own ranking; the colours are the
// risk levels the piece assigns, not a gradient invented to look like data.

const VOLT = '#c8f542';
const EMBER = '#ff8a00';

const POSTS = [
  {
    slug: 'most-dangerous-vapes-ranked-2026',
    eyebrow: 'VAPE SAFETY · RANKED BY SCIENCE',
    headline: 'The 5 most dangerous vapes in 2026',
    blocks: [
      { n: '1', label: 'THC carts', color: '#ff5c5c' },
      { n: '2', label: '6-MN vapes', color: '#ff5c5c' },
      { n: '3', label: 'Disposables', color: EMBER },
      { n: '4', label: 'Sub-ohm mods', color: EMBER },
      { n: '5', label: 'Closed pods', color: VOLT },
    ],
  },
  {
    slug: 'how-many-puffs-a-day-is-a-lot',
    eyebrow: 'PUFF COUNT · WHAT THE EVIDENCE SAYS',
    headline: 'How many puffs a day is a lot?',
    blocks: [
      { n: '≈14', label: 'puffs ≈ 1 cigarette', color: VOLT },
      { n: '76%', label: 'vape within 30 min', color: EMBER },
      { n: '41%', label: '20+ days a month', color: EMBER },
      { n: '27%', label: 'vape every day', color: EMBER },
    ],
  },
  {
    slug: 'how-many-puffs-in-a-disposable-vape',
    eyebrow: 'DISPOSABLES · THE REAL NUMBERS',
    headline: 'How many puffs are in a disposable vape?',
    blocks: [
      { n: '800mg', label: 'nicotine, one Pulse', color: EMBER },
      { n: '300–500', label: 'cigarette equivalent', color: EMBER },
      { n: '66%', label: 'of youth vapers', color: VOLT },
      { n: '97.6%', label: 'unauthorized sales', color: '#ff5c5c' },
    ],
  },
  {
    slug: 'how-long-does-vaping-withdrawal-last',
    eyebrow: 'WITHDRAWAL · THE TIMELINE',
    headline: 'How long does vaping withdrawal last?',
    blocks: [
      { n: '4–24h', label: 'symptoms start', color: VOLT },
      { n: 'Day 2–3', label: 'the peak', color: EMBER },
      { n: '10 days', label: 'physical eases', color: VOLT },
      { n: '3–4 wks', label: 'mostly through it', color: VOLT },
    ],
  },
  {
    slug: 'easiest-way-to-quit-vaping',
    eyebrow: 'QUITTING VAPING · A PLAN THAT STACKS',
    headline: 'The easiest way to quit vaping',
    blocks: [
      { n: '2', label: 'problems, not one', color: EMBER },
      { n: '10', label: 'small steps', color: VOLT },
      { n: '15–20', label: 'min per craving', color: VOLT },
      { n: 'Day 2–3', label: 'the hard part', color: EMBER },
    ],
  },
  {
    slug: 'what-happens-when-you-quit-vaping',
    eyebrow: 'QUITTING VAPING · DAY BY DAY',
    headline: 'What happens when you quit vaping?',
    blocks: [
      { n: '~2h', label: 'nicotine half-life', color: VOLT },
      { n: 'Day 2–3', label: 'the peak', color: EMBER },
      { n: 'Week 2', label: 'habit takes over', color: EMBER },
      { n: 'Month 3', label: 'the new normal', color: VOLT },
    ],
  },
  {
    slug: 'how-to-choose-a-puff-counter-app',
    eyebrow: 'PUFF COUNTER APPS · WHAT TO LOOK FOR',
    headline: 'How to choose a puff counter app',
    blocks: [
      { n: '1', label: 'Your real number', color: VOLT },
      { n: '2', label: 'Sources you can check', color: VOLT },
      { n: '3', label: 'Adapts when you slip', color: VOLT },
      { n: '4', label: 'A free tier that works', color: VOLT },
    ],
  },
];

// Greedy wrap on measured advance widths — SVG has no text box, so the line
// breaks have to be computed. Same routine the site card uses.
const wrap = (font, text, size, maxW) => {
  const out = [];
  let line = '';
  for (const word of text.split(' ')) {
    const candidate = line ? `${line} ${word}` : word;
    if (width(font, candidate, size) > maxW && line) {
      out.push(line);
      line = word;
    } else {
      line = candidate;
    }
  }
  if (line) out.push(line);
  return out;
};

mkdirSync(here('../public/og'), { recursive: true });

for (const post of POSTS) {
  const H_SIZE = 66;
  const headLines = wrap(display, post.headline, H_SIZE, MAX_W);
  const H_LINE = H_SIZE * 1.12;

  const BLOCK_Y = 396;
  const BLOCK_H = 146;
  const GAP = 16;
  const BLOCK_W = (MAX_W - GAP * (post.blocks.length - 1)) / post.blocks.length;

  const blocks = post.blocks
    .map((b, i) => {
      const x = MARGIN + i * (BLOCK_W + GAP);
      return `<g>
    <rect x="${x}" y="${BLOCK_Y}" width="${BLOCK_W.toFixed(1)}" height="${BLOCK_H}" rx="14" fill="#161a22"/>
    <rect x="${x}" y="${BLOCK_Y}" width="${BLOCK_W.toFixed(1)}" height="5" rx="2.5" fill="${b.color}"/>
    <text x="${x + 20}" y="${BLOCK_Y + 84}" font-family="Space Grotesk" font-size="54"
          font-weight="700" fill="${b.color}">${b.n}</text>
    <text x="${x + 20}" y="${BLOCK_Y + 120}" font-family="Inter" font-size="20"
          fill="#9aa3b2">${esc(b.label)}</text>
  </g>`;
    })
    .join('\n  ');

  const postSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <defs>
    <radialGradient id="glow" cx="8%" cy="70%" r="62%">
      <stop offset="0%" stop-color="#ff8a00" stop-opacity="0.26"/>
      <stop offset="100%" stop-color="#ff8a00" stop-opacity="0"/>
    </radialGradient>
  </defs>

  <rect width="1200" height="630" fill="#0a0c10"/>
  <rect width="1200" height="630" fill="url(#glow)"/>
  <rect x="0" y="0" width="1200" height="6" fill="#c8f542"/>

  <circle cx="${MARGIN}" cy="82" r="12" fill="#ff8a00"/>
  <text x="${MARGIN + 28}" y="93" font-family="Space Grotesk" font-size="30"
        font-weight="700" fill="#ffffff">${esc(title)}</text>
  <text x="1112" y="93" font-family="Inter" font-size="20" fill="#9aa3b2"
        text-anchor="end">${esc(DOMAIN)}</text>

  <text x="${MARGIN}" y="182" font-family="Inter" font-size="21" fill="#c8f542"
        letter-spacing="2.4">${esc(post.eyebrow)}</text>

  <text font-family="Space Grotesk" font-size="${H_SIZE}" font-weight="700" fill="#ffffff">
    ${headLines
      .map((l, i) => `<tspan x="${MARGIN}" y="${(248 + i * H_LINE).toFixed(1)}">${esc(l)}</tspan>`)
      .join('\n    ')}
  </text>

  ${blocks}
</svg>`;

  const out = `../public/og/${post.slug}.png`;
  writeFileSync(
    here(out),
    new Resvg(postSvg, {
      fitTo: { mode: 'width', value: 1200 },
      font: { fontFiles: [DISPLAY_TTF, BODY_TTF], loadSystemFonts: false, defaultFontFamily: 'Space Grotesk' },
    })
      .render()
      .asPng(),
  );
  console.log(`wrote public/og/${post.slug}.png (1200x630) — headline on ${headLines.length} line(s)`);
}
