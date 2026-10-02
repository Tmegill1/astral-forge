"""Split a baked turret frame into a static base and a rotating head.

The AI-generated tower art only has a few fixed barrel directions. For a head
that can point anywhere, this cuts the round housing plus barrel out of one
frame (the head), removes them from the frame (the base), and patches the
stone behind the old barrel with the mirrored stone from the other side.

Measurements are in the sliced sheet's cell pixels (see slice_sprites.py).
Run from the project root (name turrets to cut only those):
    python3 tools/split_turret.py [gatling_engine rune_cannon ...]

Requires Pillow and NumPy.
"""
import math
import os
import sys

import numpy as np
from PIL import Image

from slice_sprites import components

OUT_DIR = "assets/sprites/towers"

# name: sheet, cell size, (row, col) of the frame to cut, housing centre and
# radius, barrel tip, barrel half-width, and the stone base's half-width and
# half-height around the pivot (the patch never reaches past it).
TURRETS = {
    "gearshot_lv1": dict(sheet="assets/sprites/gearshot.png", cell=(192, 288), frame=(0, 2),
                         pivot=(93, 205), radius=33, tip=(70, 146), barrel_half_width=21,
                         base_extent=(60, 44)),
    "gearshot_lv2": dict(sheet="assets/sprites/gearshot.png", cell=(192, 288), frame=(3, 2),
                         pivot=(96, 185), radius=43, tip=(88, 122), barrel_half_width=28,
                         base_extent=(60, 50)),
    "gearshot_lv3": dict(sheet="assets/sprites/gearshot.png", cell=(192, 288), frame=(6, 2),
                         pivot=(93, 182), radius=43, tip=(88, 97), barrel_half_width=30,
                         base_extent=(60, 50)),
    # Evolutions: the gun sticks out past the body, so only air was behind
    # it (no stone to patch: base_extent 1x1).
    "gatling_engine": dict(sheet="assets/sprites/gatling_engine.png", cell=(512, 224), frame=(0, 0),
                           pivot=(312, 122), radius=26, tip=(405, 122), barrel_half_width=34,
                           base_extent=(1, 1)),
    "rune_cannon": dict(sheet="assets/sprites/rune_cannon.png", cell=(544, 192), frame=(0, 0),
                        pivot=(298, 90), radius=36, tip=(418, 90), barrel_half_width=48,
                        base_extent=(1, 1)),
}


def split(name, sheet, cell, frame, pivot, radius, tip, barrel_half_width, base_extent):
    cw, ch = cell
    row, col = frame
    img = Image.open(sheet).convert("RGBA").crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch))
    px = np.array(img)
    h, w = px.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w]
    px_, py_ = pivot
    # Housing: a circle around the pivot.
    housing = (xs - px_) ** 2 + (ys - py_) ** 2 <= radius ** 2
    # Barrel: a strip from the pivot to just past the tip.
    ax, ay = tip[0] - px_, tip[1] - py_
    length = math.hypot(ax, ay)
    ux, uy = ax / length, ay / length
    along = (xs - px_) * ux + (ys - py_) * uy
    across = np.abs((xs - px_) * -uy + (ys - py_) * ux)
    barrel = (along >= 0) & (along <= length + 10) & (across <= barrel_half_width)
    head_mask = (housing | barrel) & (px[..., 3] > 0)

    head = np.zeros_like(px)
    head[head_mask] = px[head_mask]
    base = px.copy()
    base[head_mask] = 0
    # Behind the barrel (outside the housing) was stone ring: borrow the
    # mirror-image pixel from the other side of the pivot.
    ex, ey = base_extent
    inside_base = ((xs - px_) / ex) ** 2 + ((ys - py_) / ey) ** 2 <= 1.0
    hole = barrel & ~housing & inside_base
    mirror_x = np.clip(2 * px_ - xs, 0, w - 1)
    borrowed = px[ys, mirror_x]
    fill = hole & ~head_mask[ys, mirror_x] & (borrowed[..., 3] > 0)
    base[fill] = borrowed[fill]

    base = drop_loose(base)

    # Head image is a square centred on the pivot so it rotates in place.
    size = int(math.ceil(length + 8)) * 2
    head_img = Image.new("RGBA", (size, size))
    head_img.alpha_composite(Image.fromarray(head), (size // 2 - px_, size // 2 - py_))
    os.makedirs(OUT_DIR, exist_ok=True)
    Image.fromarray(base).save(os.path.join(OUT_DIR, name + "_base.png"), optimize=True)
    head_img.save(os.path.join(OUT_DIR, name + "_head.png"), optimize=True)
    drawn = math.degrees(math.atan2(ay, ax))
    print(f"{name}: pivot {pivot} in a {cw}x{ch} cell, barrel drawn at {drawn:.0f} deg, "
          f"length {length:.0f}px, head {size}x{size}")


def drop_loose(pixels, smallest=60):
    """Clears specks left floating on the base after the cut: any piece of
    visible pixels smaller than `smallest` that isn't the main body."""
    labels = components(pixels[..., 3] > 0)
    ids, sizes = np.unique(labels[labels > 0], return_counts=True)
    main = ids[np.argmax(sizes)]
    loose = [i for i, n in zip(ids, sizes) if i != main and n < smallest]
    out = pixels.copy()
    out[np.isin(labels, loose)] = 0
    return out


def main():
    """Cuts the turrets named on the command line, or all of them."""
    for name in sys.argv[1:] or list(TURRETS):
        split(name, **TURRETS[name])


if __name__ == "__main__":
    main()
