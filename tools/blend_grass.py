"""Blend the grass tiles in the terrain atlas so they tile without seams.

Builds a self-tiling grass texture from one base tile, replaces each grass
tile's low-frequency shading with that texture's, and fades each tile's outer
BAND pixels into it. Every grass tile then shares identical edges, so any two
join cleanly. Only the tiles in GRASS are changed.

Edits the atlas in place and is not idempotent: run it once, on fresh output
from build_atlas.py.
    python3 tools/blend_grass.py [ATLAS_PNG]

Requires Pillow and NumPy.
"""
import sys

import numpy as np
from PIL import Image, ImageFilter

DEFAULT_ATLAS = "assets/tilesets/terrain_atlas.png"

TILE = 64
BAND = 10  # edge fade width in pixels
# Atlas coords (column, row) of grass tiles to blend.
GRASS = [(0, 0), (1, 0), (2, 0), (3, 0), (5, 0), (6, 0), (7, 0), (9, 0), (10, 0), (14, 0)]
# Plain grass tiles considered as the source of the shared edge texture.
REFERENCE_CANDIDATES = [(1, 0), (2, 0), (14, 0)]


def smoothstep(x):
    return x * x * (3 - 2 * x)


def lowpass(t, radius=12):
    """Gaussian blur with wrap-around padding, so edges don't bias the result."""
    tiled = np.tile(np.clip(t, 0, 255).astype(np.uint8), (3, 3, 1))
    blurred = np.array(Image.fromarray(tiled).filter(ImageFilter.GaussianBlur(radius)))
    return blurred.astype(float)[TILE:2 * TILE, TILE:2 * TILE]


def seam_score(t, dx, dy):
    """How far the rows/columns around a wrap offset stray from average brightness."""
    lum = t.mean(axis=2)
    cols, rows, mean = lum.mean(axis=0), lum.mean(axis=1), lum.mean()
    near = range(-3, 3)
    return (np.abs(cols[[(dx + i) % TILE for i in near]] - mean).sum()
            + np.abs(rows[[(dy + i) % TILE for i in near]] - mean).sum())


def blend(path):
    atlas = np.array(Image.open(path).convert("RGBA")).astype(float)

    def tile(c, r):
        return atlas[r * TILE:(r + 1) * TILE, c * TILE:(c + 1) * TILE, :3].copy()

    # Pick the base tile and wrap offset whose new seam lines are closest to
    # average brightness; a dark or light band there would repeat at every edge.
    _, rc, rr, dx, dy = min((seam_score(tile(c, r), dx, dy), c, r, dx, dy)
                            for c, r in REFERENCE_CANDIDATES
                            for dx in range(20, 45) for dy in range(20, 45))
    print(f"reference tile ({rc}, {rr}), wrap offset ({dx}, {dy})")

    # Self-tiling reference: original center, edges from an offset copy whose
    # wrapped borders were neighbouring pixels in the original.
    d = np.minimum(np.arange(TILE), TILE - 1 - np.arange(TILE)).astype(float)
    edge_dist = np.minimum.outer(d, d)
    center = smoothstep(np.clip((edge_dist - 4) / 20, 0, 1))[..., None]
    base = tile(rc, rr)
    ref = center * base + (1 - center) * np.roll(base, (TILE - dy, TILE - dx), axis=(0, 1))
    ref_low = lowpass(ref)

    keep = smoothstep(np.clip(edge_dist / BAND, 0, 1))[..., None]
    for c, r in GRASS:
        t = tile(c, r)
        t = t - lowpass(t) + ref_low
        t = keep * t + (1 - keep) * ref
        atlas[r * TILE:(r + 1) * TILE, c * TILE:(c + 1) * TILE, :3] = t

    Image.fromarray(np.clip(atlas, 0, 255).round().astype(np.uint8)).save(path)
    print(f"blended {len(GRASS)} grass tiles in {path}")


if __name__ == "__main__":
    blend(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_ATLAS)
