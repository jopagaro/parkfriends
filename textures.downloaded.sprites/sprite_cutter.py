#!/usr/bin/env python3
"""
Auto sprite-sheet cutter.

Strategy:
  1. If the sheet has fully-transparent gutter rows/columns, split there.
     Each contiguous opaque band becomes a row; within each row, contiguous
     opaque bands become frames. Frames are padded to a uniform size per row
     (or per sheet) so they can be played back as an animation.
  2. Otherwise fall back to a guessed uniform grid based on common cell sizes
     (16, 24, 32, 48, 64) that divide both width and height evenly. We pick
     the largest cell size that yields a sensible frame count (>= 2 frames).
  3. Per-sheet overrides (manifest) can force a fixed (cols, rows) split.

Output: <out_dir>/<sheet_name>/frame_000.png ...
If gutter mode finds multiple rows, output is grouped:
       <out_dir>/<sheet_name>/row_<r>/frame_<f>.png
"""

import argparse
import os
import sys
from pathlib import Path
from PIL import Image

# Manual overrides: relative path -> (cols, rows) OR (cell_w, cell_h) using "grid" / "cell".
MANIFEST = {
    # Detected based on filename / dimensions. Add more as needed.
    "BIRDSPRITESHEET_Blue.png":   ("grid", 4, 13),
    "BIRDSPRITESHEET_White.png":  ("grid", 4, 13),
    "CATSPRITESHEET_Gray.png":    ("grid", 4, 13),
    "CATSPRITESHEET_Orange.png":  ("grid", 4, 13),
    "FOXSPRITESHEET.png":         ("grid", 4, 13),
    "RACCOONSPRITESHEET.png":     ("grid", 4, 13),
    "48DogSpriteSheet.png":       ("cell", 32, 48),
    "56Dogs.png":                 ("cell", 16, 16),
    "Turtle.png":                 ("cell", 64, 96),
    "torch.png":                  ("cell", 48, 48),
    "platformConnector1.png":     ("cell", 16, 16),
    "Iron_03-Sheet.png":          ("cell", 32, 32),
    # Animation-folder sheets:
    "Basic Charakter Spritesheet.png": ("cell", 48, 48),
    "Frame indexes.png":          ("cell", 32, 32),
    "cat 1.png":                  ("cell", 32, 32),
    "cat 1.6.png":                ("cell", 32, 32),
    "cat 1.9.png":                ("cell", 32, 32),
}

# Pattern-based defaults: (regex, (kind, a, b)) — first match wins.
import re as _re
PATTERN_MANIFEST = [
    # Mana Seed Character Base v1 — char_a_p1_*.png (512x512, 64x64 cells)
    (_re.compile(r"^char_a_p1_.*\.png$"),  ("cell", 64, 64)),
]


def manifest_for(name, size):
    if name in MANIFEST:
        return MANIFEST[name]
    for rx, rule in PATTERN_MANIFEST:
        if rx.match(name):
            return rule
    # Mana Seed Cat Generator: 1024x544 sheets are 32x32 cells.
    if size == (1024, 544):
        return ("cell", 32, 32)
    return None


def is_transparent_row(img, y):
    a = img.crop((0, y, img.width, y + 1)).getchannel("A")
    return a.getextrema()[1] == 0


def is_transparent_col(img, x):
    a = img.crop((x, 0, x + 1, img.height)).getchannel("A")
    return a.getextrema()[1] == 0


def find_bands(length, is_blank):
    bands = []
    in_band = False
    start = 0
    for i in range(length):
        blank = is_blank(i)
        if not blank and not in_band:
            in_band = True
            start = i
        elif blank and in_band:
            in_band = False
            bands.append((start, i))
    if in_band:
        bands.append((start, length))
    return bands


def cut_with_gutters(img):
    """Return list of (row_idx, frame_idx, PIL.Image) using gutter detection."""
    rows = find_bands(img.height, lambda y: is_transparent_row(img, y))
    if not rows:
        return None
    out = []
    for r_idx, (y0, y1) in enumerate(rows):
        strip = img.crop((0, y0, img.width, y1))
        cols = find_bands(strip.width, lambda x: is_transparent_col(strip, x))
        if not cols:
            continue
        # Uniform frame size for this row: max width/height of detected frames.
        max_w = max(x1 - x0 for x0, x1 in cols)
        max_h = strip.height
        for f_idx, (x0, x1) in enumerate(cols):
            frame = strip.crop((x0, 0, x1, strip.height))
            canvas = Image.new("RGBA", (max_w, max_h), (0, 0, 0, 0))
            # Center horizontally so frame anchors look consistent.
            ox = (max_w - frame.width) // 2
            canvas.paste(frame, (ox, 0))
            out.append((r_idx, f_idx, canvas))
    return out if out else None


def cut_with_grid(img, cols, rows):
    cw = img.width // cols
    ch = img.height // rows
    out = []
    for r in range(rows):
        for c in range(cols):
            box = (c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)
            out.append((r, c, img.crop(box)))
    return out


def cut_with_cell(img, cw, ch):
    cols = img.width // cw
    rows = img.height // ch
    return cut_with_grid(img, cols, rows)


def guess_grid(img):
    """Guess a sensible cell size. Returns (cw, ch) or None."""
    candidates = [64, 48, 32, 24, 16, 8]
    best = None
    for s in candidates:
        if img.width % s == 0 and img.height % s == 0:
            n = (img.width // s) * (img.height // s)
            if 2 <= n <= 256:
                best = (s, s)
                break
    return best


def is_frame_blank(im):
    if im.mode != "RGBA":
        im = im.convert("RGBA")
    return im.getchannel("A").getextrema()[1] == 0


def process(src_path, out_root, rel_key=None, force=False):
    rel_key = rel_key or src_path.name
    img = Image.open(src_path).convert("RGBA")
    name = src_path.stem
    out_dir = out_root / name
    if out_dir.exists() and not force:
        print(f"  skip (exists): {out_dir}")
        return
    out_dir.mkdir(parents=True, exist_ok=True)

    frames = None
    mode = None
    rule = manifest_for(rel_key, img.size)
    if rule:
        kind, a, b = rule
        if kind == "grid":
            frames = cut_with_grid(img, a, b)
            mode = f"manifest grid {a}x{b}"
        elif kind == "cell":
            frames = cut_with_cell(img, a, b)
            mode = f"manifest cell {a}x{b}"

    if frames is None:
        gutters = cut_with_gutters(img)
        # Only accept gutter results that actually segment into >1 frame.
        if gutters and len(gutters) > 1:
            frames = gutters
            mode = "gutter detection"
        # Do NOT fall back to a uniform-grid guess — it shreds single tiles
        # into quadrants. Add to MANIFEST instead for ambiguous sheets.

    if frames is None:
        print(f"  ! could not split: {src_path}")
        return

    # Drop blank frames.
    frames = [(r, c, im) for (r, c, im) in frames if not is_frame_blank(im)]

    rows_present = sorted({r for r, _, _ in frames})
    multi_row = len(rows_present) > 1

    if multi_row:
        for r in rows_present:
            (out_dir / f"row_{r:02d}").mkdir(exist_ok=True)
        per_row_count = {}
        for (r, _c, im) in frames:
            i = per_row_count.get(r, 0)
            im.save(out_dir / f"row_{r:02d}" / f"frame_{i:03d}.png")
            per_row_count[r] = i + 1
    else:
        for i, (_r, _c, im) in enumerate(frames):
            im.save(out_dir / f"frame_{i:03d}.png")

    print(f"  ok  {src_path.name}: {len(frames)} frames via {mode} -> {out_dir.relative_to(out_root.parent)}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="*", help="PNG files or directories")
    ap.add_argument("--out", default="split_frames", help="output root")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    here = Path(__file__).parent
    out_root = (here / args.out).resolve()
    out_root.mkdir(exist_ok=True)

    targets = []
    if not args.paths:
        # Default: top-level PNGs in this directory.
        for p in sorted(here.iterdir()):
            if p.suffix.lower() == ".png" and p.is_file():
                targets.append(p)
    else:
        for raw in args.paths:
            p = Path(raw)
            if p.is_dir():
                for q in sorted(p.rglob("*.png")):
                    targets.append(q)
            elif p.is_file():
                targets.append(p)

    print(f"processing {len(targets)} sheets -> {out_root}")
    for p in targets:
        try:
            process(p, out_root, rel_key=p.name, force=args.force)
        except Exception as e:
            print(f"  !! error on {p}: {e}")


if __name__ == "__main__":
    main()
