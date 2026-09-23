"""Trim the Fantasy RPG terrain source atlas into a uniform 64x64 tile grid.

The source image has uneven tiles (roughly 56-90 px) separated by
semi-transparent gutters, and its bottom row is stretched vertically. This
crops each cell to its opaque content, drops a 1 px soft edge, and resizes
every tile to 64x64 in a 16x15 atlas with no gaps.

Run from the project root, then run blend_grass.py on the output:
    python3 tools/build_atlas.py [SOURCE_PNG] [OUTPUT_PNG]

Requires Pillow and NumPy.
"""
import os
import sys

import numpy as np
from PIL import Image

DEFAULT_SRC = os.path.expanduser("~/Desktop/Fantasy RPG Terrain Tileset Atlas.png")
DEFAULT_OUT = "assets/tilesets/terrain_atlas.png"

TILE = 64
COLS, ROWS = 16, 15
INSET = 1  # pixels to drop past the soft edge

# Gutter pixel ranges (start, end) measured from the source image's alpha channel.
COL_GUTTERS = [(0, 5), (77, 85), (159, 166), (239, 246), (319, 326), (399, 406),
               (478, 486), (558, 566), (638, 645), (719, 725), (797, 805),
               (878, 885), (958, 965), (1036, 1044), (1112, 1121), (1186, 1193),
               (1249, 1253)]
ROW_GUTTERS = [(0, 5), (78, 86), (158, 165), (234, 240), (314, 318), (392, 399),
               (482, 487), (566, 570), (649, 653), (732, 737), (817, 822),
               (895, 901), (975, 981), (1054, 1061), (1136, 1142), (1248, 1253)]


def longest_run(mask):
    """Return (start, end) of the longest run of True values."""
    best, start = (0, -1), None
    for i, on in enumerate(list(mask) + [False]):
        if on and start is None:
            start = i
        if not on and start is not None:
            if i - 1 - start > best[1] - best[0]:
                best = (start, i - 1)
            start = None
    return best


def build(src_path, out_path):
    src = Image.open(src_path).convert("RGBA")
    alpha = np.array(src)[:, :, 3]
    out = Image.new("RGBA", (COLS * TILE, ROWS * TILE))
    for r in range(ROWS):
        for c in range(COLS):
            # Pad the cell a little to tolerate gutters that aren't perfectly straight.
            y0 = max(0, ROW_GUTTERS[r][0] - 3)
            y1 = min(alpha.shape[0], ROW_GUTTERS[r + 1][1] + 4)
            x0 = max(0, COL_GUTTERS[c][0] - 3)
            x1 = min(alpha.shape[1], COL_GUTTERS[c + 1][1] + 4)
            solid = alpha[y0:y1, x0:x1] >= 200
            ys = longest_run(solid.mean(axis=1) > 0.6)
            xs = longest_run(solid[ys[0]:ys[1] + 1].mean(axis=0) > 0.9)
            ys = longest_run(solid[:, xs[0]:xs[1] + 1].mean(axis=1) > 0.9)
            box = (x0 + xs[0] + INSET, y0 + ys[0] + INSET,
                   x0 + xs[1] + 1 - INSET, y0 + ys[1] + 1 - INSET)
            tile = src.crop(box).convert("RGB").resize((TILE, TILE), Image.LANCZOS)
            out.paste(tile.convert("RGBA"), (c * TILE, r * TILE))
    out.save(out_path)
    print(f"wrote {out_path} ({out.size[0]}x{out.size[1]}, {COLS}x{ROWS} tiles)")


if __name__ == "__main__":
    build(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC,
          sys.argv[2] if len(sys.argv) > 2 else DEFAULT_OUT)
