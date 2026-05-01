#!/usr/bin/env python3
"""
Legacy: composes a **1024×1024** slab from **IntroXOMonogram** (Swift design mirror).

For **distribution** (Springboard / Spotlight / iPad / App Store): save the final master as **`AppIcon.appiconset/AppIcon-1024.png`**, then run **`build_full_app_icon_set.py`** (not this file).
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
LOGO_SRC = ROOT / "XOArena/Assets.xcassets/IntroXOMonogram.imageset/IntroXOMonogram.png"
OUT_PNG = ROOT / "XOArena/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

SIDE = 1024
LOGO_FRAC = 0.58
OPTICAL = (5, -11)

# Swift: cappuccinoHead (#F7F1EA) → cappuccinoBase (#F3EDE6)
HEAD_RGB = (247, 241, 234)
BASE_RGB = (243, 237, 230)


def main() -> None:
    if not LOGO_SRC.exists():
        raise SystemExit(f"Missing logo asset: {LOGO_SRC}")

    canvas = Image.new("RGBA", (SIDE, SIDE), (*BASE_RGB, 255))
    px = canvas.load()
    denom = max(SIDE - 1, 1)
    for y in range(SIDE):
        t = y / denom
        r = int(HEAD_RGB[0] + (BASE_RGB[0] - HEAD_RGB[0]) * t)
        g = int(HEAD_RGB[1] + (BASE_RGB[1] - HEAD_RGB[1]) * t)
        b = int(HEAD_RGB[2] + (BASE_RGB[2] - HEAD_RGB[2]) * t)
        for x in range(SIDE):
            px[x, y] = (r, g, b, 255)

    logo = Image.open(LOGO_SRC).convert("RGBA")
    max_side = round(SIDE * LOGO_FRAC)
    lw, lh = logo.size
    scale = max_side / max(lw, lh)
    nw, nh = int(lw * scale), int(lh * scale)
    logo = logo.resize((nw, nh), Image.Resampling.LANCZOS)

    ox = SIDE // 2 + OPTICAL[0] - nw // 2
    oy = SIDE // 2 + OPTICAL[1] - nh // 2
    canvas.alpha_composite(logo, dest=(ox, oy))

    OUT_PNG.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGBA").save(OUT_PNG, format="PNG", optimize=True)
    print(f"Wrote {OUT_PNG}")


if __name__ == "__main__":
    main()
