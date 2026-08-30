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
import { readFileSync, writeFileSync } from 'node:fs';
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
console.log(`wrote public/og.png (1200x630) — headline on ${lines.length} line(s)`);
