#!/usr/bin/env python3
"""
Regenerates **`AppIcon.appiconset`** raster slots from **`AppIcon-1024.png`** (master).

Run after replacing the master icon:
  python3 Scripts/build_full_app_icon_set.py

Covers Springboard / Settings / Spotlight on **iPhone** and **iPad**, plus **App Store** marketing 1024.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ICONSET = ROOT / "XOArena/Assets.xcassets/AppIcon.appiconset"
MASTER = ICONSET / "AppIcon-1024.png"


# (idiom, size_pt string, scale, pixel_edge)
SLOTS: list[tuple[str, str, str, int]] = [
    # iPhone Notification
    ("iphone", "20x20", "2x", 40),
    ("iphone", "20x20", "3x", 60),
    # iPhone Settings
    ("iphone", "29x29", "2x", 58),
    ("iphone", "29x29", "3x", 87),
    # iPhone Spotlight
    ("iphone", "40x40", "2x", 80),
    ("iphone", "40x40", "3x", 120),
    # iPhone App
    ("iphone", "60x60", "2x", 120),
    ("iphone", "60x60", "3x", 180),
    # iPad Notification
    ("ipad", "20x20", "1x", 20),
    ("ipad", "20x20", "2x", 40),
    # iPad Settings
    ("ipad", "29x29", "1x", 29),
    ("ipad", "29x29", "2x", 58),
    # iPad Spotlight
    ("ipad", "40x40", "1x", 40),
    ("ipad", "40x40", "2x", 80),
    # iPad App
    ("ipad", "76x76", "1x", 76),
    ("ipad", "76x76", "2x", 152),
    ("ipad", "83.5x83.5", "2x", 167),
    # App Store Connect
    ("ios-marketing", "1024x1024", "1x", 1024),
]


def resize_master(px: int, out: Path) -> None:
    cmd = ["sips", "-z", str(px), str(px), str(MASTER), "--out", str(out)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr or r.stdout, file=sys.stderr)
        raise SystemExit(r.returncode)


def main() -> None:
    if not MASTER.exists():
        raise SystemExit(f"Missing master: {MASTER}")

    ICONSET.mkdir(parents=True, exist_ok=True)
    pixel_to_name = {pixel: f"AppIcon-{pixel}.png" for _, _, _, pixel in SLOTS}

    images: list[dict[str, str]] = []
    for idiom, size, scale, pixel in SLOTS:
        name = pixel_to_name[pixel]
        out_path = ICONSET / name
        resize_master(pixel, out_path)
        images.append(
            {
                "filename": name,
                "idiom": idiom,
                "scale": scale,
                "size": size,
            },
        )

    contents = {"images": images, "info": {"author": "xcode", "version": 1}}

    destination = ICONSET / "Contents.json"
    destination.write_text(json.dumps(contents, indent=2, sort_keys=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(images)} slots under {ICONSET}")


if __name__ == "__main__":
    main()
