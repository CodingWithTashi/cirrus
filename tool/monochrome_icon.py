"""Cut the Android themed-icon silhouette out of the launcher art.

    python tool/monochrome_icon.py

Reads assets/images/icon-square.png and writes assets/images/cirrus_monochrome.png:
a white silhouette of the lime mark with alpha, which `dart run
flutter_launcher_icons` turns into drawable-*/ic_launcher_monochrome.png (the
layer Android 13+ tints with the wallpaper colour). Re-run it whenever the art
changes, before the launcher-icon generator.

The mark is a flat lime (#B4DC28) on a near-black radial gradient, so the green
channel alone separates them: background G tops out around 45, the mark sits at
~220, and the antialiased edge pixels are spread evenly between — a linear ramp
over that range reproduces the art's own edge softness. The `g > b + 12` gate
keeps the neutral background at exactly zero, gradient and all.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "images" / "icon-square.png"
OUT = ROOT / "assets" / "images" / "cirrus_monochrome.png"

BG_G = 48    # at or below this green level the pixel is background
MARK_G = 212 # at or above it the pixel is solid mark


def alpha_of(pixel: tuple[int, int, int]) -> int:
    r, g, b = pixel
    if g <= b + 12:
        return 0
    t = (g - BG_G) / (MARK_G - BG_G)
    return round(255 * min(1.0, max(0.0, t)))


def main() -> None:
    src = Image.open(SRC).convert("RGB")
    w, h = src.size
    px = src.load()
    out = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    op = out.load()
    for y in range(h):
        for x in range(w):
            op[x, y] = (255, 255, 255, alpha_of(px[x, y]))
    # Write to a temp path then replace, so a failed encode never leaves a
    # truncated file where the generator will look for one.
    tmp = OUT.with_suffix(".tmp.png")
    out.save(tmp, optimize=True)
    tmp.replace(OUT)
    solid = sum(1 for y in range(h) for x in range(w) if op[x, y][3] == 255)
    print(f"wrote {OUT.relative_to(ROOT)} ({w}x{h}, {solid} solid pixels)")


if __name__ == "__main__":
    main()
