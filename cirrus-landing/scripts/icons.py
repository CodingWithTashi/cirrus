#!/usr/bin/env python3
"""Regenerate every site icon from the app's own launcher art.

    python3 scripts/icons.py

The mark has ONE source: ../assets/images/icon-square.png, the same file
`flutter_launcher_icons` builds the Android and iOS app icons from. Before this
script existed the site drew its own stand-in — an orange dot — which was the
wrong shape and the wrong brand colour, and it shipped in the favicon, the
Apple touch icon and every Open Graph card.

Outputs:

    public/favicon.svg              vector, traced from the art (see below)
    public/favicon-{16,32}.png      pre-rounded: nothing masks a favicon
    public/apple-touch-icon.png     SQUARE: iOS applies its own squircle, and a
                                    pre-rounded source gets rounded twice
    public/icon-{192,512}.png       square, for a manifest when one exists
    public/logo.png                 square tile; the Organization.logo a crawler
                                    fetches, so it stays opaque — a lime mark on
                                    transparent lands on white in some readers
    src/assets/mark.png             the mark ALONE, transparent, cropped to its
                                    own bounds — what the site itself renders
    scripts/mark-path.js            the traced path, so og.mjs draws this mark
                                    rather than a second, divergent one

Needs ImageMagick (`brew install imagemagick`) for the raster sizes. The trace
is pure Python: no potrace here, so it walks the mask boundary with
Moore-neighbour tracing and simplifies with Ramer-Douglas-Peucker. A polygon
rather than beziers — at 16px that is indistinguishable, and it has no
dependency that can rot.
"""
import math
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ART = os.path.join(ROOT, '..', 'assets', 'images', 'icon-square.png')

# Measured off the art, not guessed: the lime is #c4e538 and the ground is
# #161a21 (the same value pubspec.yaml pins as adaptive_icon_background).
MARK = '#c4e538'
GROUND = '#161a21'
GROUND_LIT = '#222a23'   # the art's radial centre

# 7/32 of the side — the radius the old hand-written favicon.svg used, kept so
# the tab icon's silhouette does not change shape.
CORNER = 7 / 32

TRACE_N = 512      # trace resolution; 512 is under a tenth of a pixel at 32
RDP_EPS = 1.15     # in trace pixels


def run(*args):
    subprocess.run(args, check=True)


def need_magick():
    if not shutil.which('magick'):
        sys.exit('ImageMagick not found. brew install imagemagick')


# ---------------------------------------------------------------------------
# Trace


def mask_from_art(tmp):
    """The art's lime pixels as a boolean grid."""
    raw = os.path.join(tmp, 'art.raw')
    run('magick', ART, '-resize', f'{TRACE_N}x{TRACE_N}!', '-depth', '8', f'RGB:{raw}')
    d = open(raw, 'rb').read()

    def lime(x, y):
        i = (y * TRACE_N + x) * 3
        # Green-dominant and clearly not the blue-grey ground. A plain
        # brightness threshold would also catch the radial glow at the centre.
        return d[i + 1] > 120 and d[i + 1] > d[i + 2] + 50

    return [[lime(x, y) for x in range(TRACE_N)] for y in range(TRACE_N)]


NEIGHBOURS = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]


def contours(mask):
    def on(x, y):
        return 0 <= x < TRACE_N and 0 <= y < TRACE_N and mask[y][x]

    def follow(sx, sy):
        out = [(sx, sy)]
        back = 4
        x, y = sx, sy
        for _ in range(TRACE_N * TRACE_N * 4):
            for k in range(8):
                i = (back + 1 + k) % 8
                nx, ny = x + NEIGHBOURS[i][0], y + NEIGHBOURS[i][1]
                if on(nx, ny):
                    back = (i + 4) % 8
                    x, y = nx, ny
                    break
            else:
                break
            if (x, y) == (sx, sy):
                break
            out.append((x, y))
        return out

    seen = [[False] * TRACE_N for _ in range(TRACE_N)]
    found = []
    for y in range(TRACE_N):
        for x in range(TRACE_N):
            if not mask[y][x] or seen[y][x]:
                continue
            stack, size = [(x, y)], 0
            seen[y][x] = True
            while stack:
                cx, cy = stack.pop()
                size += 1
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if on(nx, ny) and not seen[ny][nx]:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
            if size < 40:          # antialiasing crumbs
                continue
            found.append(follow(x, y))
    # The mark is a C and a wisp — both simply connected, so no hole handling
    # is needed here. If the art ever grows a closed counter, this is where it
    # would have to come from, with fill-rule="evenodd" on the path.
    return found


def rdp(pts, eps):
    if len(pts) < 3:
        return pts
    ax, ay = pts[0]
    bx, by = pts[-1]
    dx, dy = bx - ax, by - ay
    n = math.hypot(dx, dy)
    worst, idx = -1.0, 0
    for i in range(1, len(pts) - 1):
        px, py = pts[i]
        dist = abs(dy * px - dx * py + bx * ay - by * ax) / n if n else math.hypot(px - ax, py - ay)
        if dist > worst:
            worst, idx = dist, i
    if worst <= eps:
        return [pts[0], pts[-1]]
    return rdp(pts[:idx + 1], eps)[:-1] + rdp(pts[idx:], eps)


def rdp_closed(ring, eps):
    """A closed ring has no endpoints, and RDP against a zero-length baseline
    scores every point at distance 0 and collapses the whole contour to two.
    Cut at the point farthest from the start and simplify the two arcs."""
    a = ring[0]
    j = max(range(len(ring)), key=lambda i: (ring[i][0] - a[0]) ** 2 + (ring[i][1] - a[1]) ** 2)
    return rdp(ring[:j + 1], eps)[:-1] + rdp(ring[j:] + [ring[0]], eps)[:-1]


def mark_path(mask, scale):
    """SVG path data for the mark in a `scale`-unit square, and its tight box.

    The mark is not centred in the art and does not fill it, so anything drawing
    the glyph on its own (rather than inside the tile) needs the real bounds.
    """
    k = scale / TRACE_N
    parts, xs, ys = [], [], []
    for ring in contours(mask):
        pts = []
        for X, Y in rdp_closed(ring, RDP_EPS):
            p = (round(X * k, 2), round(Y * k, 2))
            if not pts or p != pts[-1]:
                pts.append(p)
        xs += [q[0] for q in pts]
        ys += [q[1] for q in pts]
        parts.append('M' + ' '.join(f'{x} {y}' for x, y in pts) + 'Z')
    box = (round(min(xs), 2), round(min(ys), 2),
           round(max(xs) - min(xs), 2), round(max(ys) - min(ys), 2))
    return ''.join(parts), box


# ---------------------------------------------------------------------------
# Emit


def write(path, data, label):
    mode = 'wb' if isinstance(data, bytes) else 'w'
    with open(path, mode) as f:
        f.write(data)
    print(f'  {os.path.relpath(path, ROOT):32s} {os.path.getsize(path) / 1024:6.1f} KB  {label}')


def square(tmp, size, dest):
    run('magick', ART, '-resize', f'{size}x{size}', '-strip', dest)
    print(f'  {os.path.relpath(dest, ROOT):32s} {os.path.getsize(dest) / 1024:6.1f} KB  {size}px square')


def rounded(tmp, size, dest):
    """Round the corners by the same 7/32 the SVG uses, via an SVG mask —
    ImageMagick's own rounded-rectangle draw has no antialiasing on the alpha
    channel and leaves a stair-stepped edge at 16px."""
    r = round(size * CORNER, 2)
    mask_svg = os.path.join(tmp, f'mask{size}.svg')
    mask_png = os.path.join(tmp, f'mask{size}.png')
    base = os.path.join(tmp, f'base{size}.png')
    open(mask_svg, 'w').write(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}">'
        f'<rect width="{size}" height="{size}" rx="{r}" fill="#fff"/></svg>')
    run('magick', '-background', 'none', '-density', str(72 * 8), mask_svg,
        '-resize', f'{size}x{size}', mask_png)
    run('magick', ART, '-resize', f'{size}x{size}', base)
    run('magick', base, mask_png, '-alpha', 'off', '-compose', 'CopyOpacity',
        '-composite', '-strip', dest)
    print(f'  {os.path.relpath(dest, ROOT):32s} {os.path.getsize(dest) / 1024:6.1f} KB  {size}px rounded')


def cut_mark(tmp, dest, height=640, pad=0.02):
    """The mark on transparency, cropped to its own bounding box.

    The site's ground is Void (#0a0c10) and the art's is #161a21, so pasting the
    launcher tile into the header drew a visibly lighter grey box around the
    mark. On the site the mark has to be a mark, not an app icon.

    Not a threshold cut, which leaves a stair-stepped edge, and not a fuzz-based
    -transparent, which leaves a dark halo: the art is one flat lime over one
    near-flat ground, so alpha is recoverable by unmixing the green channel.
    Colour is then forced to the flat mark colour, which is what the art holds
    everywhere except the antialiased rim.
    """
    W = 1024
    raw = os.path.join(tmp, 'full.raw')
    run('magick', ART, '-resize', f'{W}x{W}!', '-depth', '8', f'RGB:{raw}')
    src = open(raw, 'rb').read()

    G_GROUND = 40      # the art's radial centre, its brightest ground green
    G_MARK = 229       # measured off the flat interior of the stroke
    FLOOR = 0.06       # below this it is the art's glow, not the mark

    out = bytearray(W * W * 4)
    minx, miny, maxx, maxy = W, W, -1, -1
    r, g, b = (int(MARK[i:i + 2], 16) for i in (1, 3, 5))
    for y in range(W):
        for x in range(W):
            i = (y * W + x) * 3
            gg, bb = src[i + 1], src[i + 2]
            a = 0.0
            if gg > bb + 20:                      # green-dominant: not the ground
                a = (gg - G_GROUND) / (G_MARK - G_GROUND)
                a = 0.0 if a < FLOOR else min(a, 1.0)
            if a:
                j = (y * W + x) * 4
                out[j], out[j + 1], out[j + 2], out[j + 3] = r, g, b, round(a * 255)
                minx, miny = min(minx, x), min(miny, y)
                maxx, maxy = max(maxx, x), max(maxy, y)

    rgba = os.path.join(tmp, 'mark.rgba')
    open(rgba, 'wb').write(bytes(out))
    m = round(max(maxx - minx, maxy - miny) * pad)
    x0, y0 = max(0, minx - m), max(0, miny - m)
    w, h = min(W, maxx + m + 1) - x0, min(W, maxy + m + 1) - y0
    run('magick', '-size', f'{W}x{W}', '-depth', '8', f'RGBA:{rgba}',
        '-crop', f'{w}x{h}+{x0}+{y0}', '+repage',
        '-resize', f'x{height}', '-strip', dest)
    ratio = w / h
    print(f'  {os.path.relpath(dest, ROOT):32s} {os.path.getsize(dest) / 1024:6.1f} KB  '
          f'transparent, {round(height * ratio)}x{height} (w/h {ratio:.3f})')
    return ratio


def main():
    need_magick()
    if not os.path.isfile(ART):
        sys.exit(f'app art not found: {ART}')

    with tempfile.TemporaryDirectory() as tmp:
        print(f'tracing {os.path.relpath(ART, ROOT)} …')
        mask = mask_from_art(tmp)
        d32, box = mark_path(mask, 32)

        svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <!-- GENERATED by scripts/icons.py — do not hand-edit.
       Traced from the app's launcher art so the browser tab and the phone
       home screen carry the same mark. Flat ground, no gradient: a favicon is
       16px and several renderers drop SVG gradients silently. -->
  <rect width="32" height="32" rx="7" fill="{GROUND}"/>
  <path fill="{MARK}" d="{d32}"/>
</svg>
'''
        write(os.path.join(ROOT, 'public', 'favicon.svg'), svg, 'traced vector')

        # og.mjs draws the mark on every social card. Handing it the same
        # traced path is what stops the site growing a second, divergent one.
        js = f'''// GENERATED by scripts/icons.py — do not hand-edit.
// The Cirrus mark as SVG path data in a 32x32 box, traced from the app's own
// launcher art. og.mjs scales it into place; see MARK_BOX.
export const MARK_BOX = 32;
export const MARK_FILL = '{MARK}';
export const MARK_GROUND = '{GROUND}';
export const MARK_PATH = '{d32}';
// The glyph's own bounds inside that box: [x, y, width, height]. It is neither
// centred nor full-bleed, so drawing it without the tile needs these.
export const MARK_RECT = [{box[0]}, {box[1]}, {box[2]}, {box[3]}];
'''
        write(os.path.join(HERE, 'mark-path.js'), js, 'path for og.mjs')

        print('cutting the mark out …')
        cut_mark(tmp, os.path.join(ROOT, 'src', 'assets', 'mark.png'))

        print('rasterising …')
        # iOS masks the touch icon itself; a pre-rounded source is rounded twice.
        square(tmp, 180, os.path.join(ROOT, 'public', 'apple-touch-icon.png'))
        square(tmp, 192, os.path.join(ROOT, 'public', 'icon-192.png'))
        square(tmp, 512, os.path.join(ROOT, 'public', 'icon-512.png'))
        square(tmp, 512, os.path.join(ROOT, 'public', 'logo.png'))
        # Nothing masks a favicon, so these carry the corner themselves.
        rounded(tmp, 32, os.path.join(ROOT, 'public', 'favicon-32.png'))
        rounded(tmp, 16, os.path.join(ROOT, 'public', 'favicon-16.png'))

    print('\ndone — now run `npm run og` to redraw the social cards with the mark.')


if __name__ == '__main__':
    main()
