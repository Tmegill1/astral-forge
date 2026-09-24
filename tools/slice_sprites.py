"""Slice the AI-generated sprite sheets into clean, even-grid sheets for Godot.

The source sheets in assets/source/ have no reliable grid: frame sizes vary,
rows hold different frame counts, and effects (bolts, smoke, projectiles)
sometimes bridge neighbouring frames. For each sheet this:

1. Finds rows and frames from the alpha channel, forcing the counts listed in
   SHEETS (tiny sparkle fragments are merged, bridged frames are split at the
   emptiest column).
2. Aligns each frame by its feet/base (bottom of the opaque pixels, horizontal
   centre of the lowest quarter) so animations don't jitter. Animations in
   BODY_ALIGNED line up by the head and torso instead: in a run the feet swing,
   so pinning them makes the body lurch back and forth.
3. Writes assets/sprites/<name>.png (one animation per row, equal cells) and
   assets/sprites/<name>.tres (a SpriteFrames resource with named animations).

Static objects (Core, slots, walls, pickups) are trimmed and written as
individual PNGs under assets/sprites/<name>/.

Run from the project root:
    python3 tools/slice_sprites.py [PREVIEW_PNG]

Requires Pillow and NumPy.
"""
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw

SRC_DIR = "assets/source"
OUT_DIR = "assets/sprites"

SOLID = 128      # alpha at or above this counts when finding frame boundaries
NOISE = 8        # alpha below this is generator noise and is cleared
EDGE_PAD = 48    # outer frames reach at most this far past the row's solid pixels
CELL_STEP = 32   # cell sizes are rounded up to a multiple of this
MARGIN = 4       # empty pixels kept around the largest frame


def tower_levels(idle, active, destroyed_per_level):
    """Rows for a tower sheet: one row per level (idle, active[, destroyed])."""
    rows = []
    for lv in (1, 2, 3):
        row = [(f"lv{lv}_idle", 4), (f"lv{lv}_{active}", 4)]
        if destroyed_per_level:
            row.append((f"lv{lv}_destroyed", 2))
        rows.append(row)
    if not destroyed_per_level:
        rows.append([("destroyed", 2)])
    return rows


# Each row is a list of (animation_name, frame_count) read left to right.
# Names ending in "?" in the roadmap table are placeholders until confirmed.
SHEETS = {
    "artificer": ("image-gen-2.png", [
        [("idle", 6)], [("walk", 8)], [("attack", 6)], [("build", 6)], [("death", 7)]]),
    "engineer": ("image-gen-1(1).png", [
        [("idle", 8)], [("walk", 8)], [("attack", 8)], [("death", 8)]]),
    "goblin": ("image-gen-2(1).png", [
        [("idle", 8)], [("walk", 8)], [("attack", 8)], [("death", 8)]]),
    "goblin_shaman": ("image-gen-10.png", [
        [("idle", 4)], [("walk", 8)], [("cast", 4), ("projectile", 1), ("recover", 1)], [("buff", 3)], [("death", 6)]]),
    "goblin_brute": ("image-gen-9.png", [
        [("idle", 4)], [("walk", 8)], [("attack", 6)], [("hurt", 4)], [("death", 6)]]),
    "blaster_turret": ("image-gen-3(1).png", [
        [("idle", 8)], [("fire", 8)], [("damaged", 8)], [("destroy", 8)]]),
    "gearshot": ("image-gen-4.png", tower_levels("idle", "fire", True)),
    "rune_mortar": ("image-gen-5.png", tower_levels("idle", "fire", True)),
    "embercaster": ("image-gen-6.png", tower_levels("idle", "fire", False)),
    "aether_spire": ("image-gen-7.png", tower_levels("idle", "fire", False)),
    "aether_harvester": ("image-gen-8.png", tower_levels("idle", "pulse", False)),
}

# Individual static images: sheet -> rows of image names.
# Extra sheets merged into a SHEETS entry, e.g. more directions drawn later.
# A missing file is skipped with a note, so art can be added whenever it's ready.
EXTRA_SHEETS = {
    # Artificer runs in 5 directions; left-hand ones are mirrored in-game.
    # Prompt for making this sheet: ~/Desktop/artificer_run_prompt.txt
    "artificer": [("artificer_run.png", [
        [("walk_down", 8)], [("walk_down_right", 8)], [("walk_right", 8)],
        [("walk_up_right", 8)], [("walk_up", 8)]])],
}

STATICS = {
    "fortress": ("image-gen-3.png", [
        ["core_intact", "core_damaged", "core_ruined"],
        ["slot_empty", "slot_active", "slot_locked"],
        ["wall_lv1", "wall_lv2", "wall_lv3",
         "wall_lv1_damaged", "wall_lv2_damaged", "wall_lv3_damaged"],
        ["scrap_1", "scrap_2", "scrap_3", "scrap_4",
         "aether_1", "aether_2", "aether_3", "aether_4"],
    ]),
}

FPS = {"idle": 6, "walk": 10, "death": 8, "destroyed": 1, "destroy": 10}
# Per sheet: animations whose frames line up by the upper body (see body_x), not the feet.
BODY_ALIGNED = {"artificer": {"walk", "walk_down", "walk_down_right", "walk_right",
                              "walk_up_right", "walk_up"},
                "goblin": {"walk"}, "goblin_shaman": {"walk"}, "goblin_brute": {"walk"}}
NO_LOOP = ("death", "destroy", "destroyed", "hurt", "attack", "cast", "fire", "build")


def runs(profile):
    """(start, end) spans where profile > 0."""
    out, start = [], None
    for i, v in enumerate(profile):
        if v and start is None:
            start = i
        elif not v and start is not None:
            out.append([start, i])
            start = None
    if start is not None:
        out.append([start, len(profile)])
    return out


def segment(profile, count):
    """Split a 1-D density profile into exactly `count` spans.

    Returns the count-1 cut positions between spans.
    """
    spans = runs(profile)
    if not spans:
        raise ValueError("nothing to segment")
    # Fold sparkle-sized fragments into the nearer neighbour.
    median = float(np.median([e - s for s, e in spans]))
    i = 0
    while len(spans) > 1 and i < len(spans):
        s, e = spans[i]
        if e - s < 0.3 * median:
            left_gap = s - spans[i - 1][1] if i > 0 else None
            right_gap = spans[i + 1][0] - e if i + 1 < len(spans) else None
            j = i - 1 if right_gap is None or (left_gap is not None and left_gap <= right_gap) else i + 1
            lo, hi = min(i, j), max(i, j)
            spans[lo] = [spans[lo][0], spans[hi][1]]
            del spans[hi]
            i = 0
            continue
        i += 1
    # Too many: join across the narrowest gap.
    while len(spans) > count:
        gaps = [spans[k + 1][0] - spans[k][1] for k in range(len(spans) - 1)]
        k = int(np.argmin(gaps))
        spans[k] = [spans[k][0], spans[k + 1][1]]
        del spans[k + 1]
    # Too few: split the widest span at its emptiest point in the middle 30-70%.
    while len(spans) < count:
        k = max(range(len(spans)), key=lambda n: spans[n][1] - spans[n][0])
        s, e = spans[k]
        lo, hi = s + int(0.3 * (e - s)), s + int(0.7 * (e - s))
        cut = lo + int(np.argmin(profile[lo:hi]))
        spans[k:k + 1] = [[s, cut], [cut, e]]
    return [(spans[k][1] + spans[k + 1][0]) // 2 for k in range(len(spans) - 1)]


def slice_sheet(path, rows):
    """Return a list of rows, each a list of RGBA frame images (untrimmed)."""
    img = Image.open(path).convert("RGBA")
    pixels = np.array(img)
    pixels[pixels[..., 3] < NOISE] = 0
    img = Image.fromarray(pixels)
    solid = pixels[..., 3] >= SOLID
    ys = np.nonzero(solid.any(1))[0]
    row_cuts = ([max(0, ys[0] - EDGE_PAD)] + segment(solid.sum(1), len(rows))
                + [min(img.height, ys[-1] + 1 + EDGE_PAD)])
    out = []
    for r, row in enumerate(rows):
        y0, y1 = row_cuts[r], row_cuts[r + 1]
        count = sum(n for _, n in row)
        xs = np.nonzero(solid[y0:y1].any(0))[0]
        col_cuts = ([max(0, xs[0] - EDGE_PAD)] + segment(solid[y0:y1].sum(0), count)
                    + [min(img.width, xs[-1] + 1 + EDGE_PAD)])
        out.append([drop_intruders(img.crop((col_cuts[c], y0, col_cuts[c + 1], y1)))
                    for c in range(count)])
    return out


def components(mask):
    """Label 4-connected regions of a boolean array (0 = background)."""
    h, w = mask.shape
    big = h * w + 1
    labels = np.where(mask, np.arange(1, big).reshape(h, w), big)
    while True:
        prev = labels
        shifted = labels.copy()
        shifted[1:] = np.minimum(shifted[1:], labels[:-1])
        shifted[:-1] = np.minimum(shifted[:-1], labels[1:])
        shifted[:, 1:] = np.minimum(shifted[:, 1:], labels[:, :-1])
        shifted[:, :-1] = np.minimum(shifted[:, :-1], labels[:, 1:])
        labels = np.where(mask, shifted, big)
        if np.array_equal(labels, prev):
            return np.where(mask, labels, 0)


def drop_intruders(frame, block=4):
    """Clear pieces of neighbouring frames (bolts, flames, shells) that poke in
    across a cut edge: any blob touching the edge that isn't the main body."""
    pixels = np.array(frame)
    h, w = pixels.shape[:2]
    hb, wb = -(-h // block), -(-w // block)
    padded = np.zeros((hb * block, wb * block), bool)
    padded[:h, :w] = pixels[..., 3] > 0
    coarse = padded.reshape(hb, block, wb, block).any(axis=(1, 3))
    labels = components(coarse)
    ids, sizes = np.unique(labels[labels > 0], return_counts=True)
    if len(ids) < 2:
        return frame
    main = ids[np.argmax(sizes)]
    edge = set(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])) - {0, main}
    if not edge:
        return frame
    drop = np.isin(labels, list(edge)).repeat(block, 0).repeat(block, 1)[:h, :w]
    pixels[drop] = 0
    return Image.fromarray(pixels)


def trim(frame):
    box = frame.getchannel("A").getbbox()
    return frame.crop(box) if box else frame


def anchor(frame):
    """(x, y) of the frame's feet: centre of the lowest quarter, bottom edge."""
    solid = np.array(frame.getchannel("A")) >= SOLID
    ys, xs = np.nonzero(solid)
    bottom = ys.max() + 1
    top = ys.min()
    low = xs[ys >= bottom - max(1, (bottom - top) // 4)]
    return int(np.median(low)), int(bottom)


def body_x(frame):
    """Horizontal centre of the frame's head and torso (its top 45%)."""
    solid = np.array(frame.getchannel("A")) >= SOLID
    ys, xs = np.nonzero(solid)
    top, bottom = ys.min(), ys.max() + 1
    return float(np.median(xs[ys < top + (bottom - top) * 0.45]))


def body_offset(frames):
    """Average distance from the feet anchor to the upper body, in pixels."""
    return sum(body_x(f) - ax for f, (ax, _ay) in frames) / len(frames)


def body_aligned(frames, offset):
    """Re-anchor frames so the upper body holds still, sitting `offset` pixels
    from the origin (pass the idle's body_offset so starting to walk doesn't
    make the body jump)."""
    return [(f, (round(body_x(f) - offset), ay)) for f, (_ax, ay) in frames]


def build_animated(name, src, rows):
    anims = []  # (anim_name, [trimmed frames with anchors])
    for sheet_src, sheet_rows in [(src, rows)] + EXTRA_SHEETS.get(name, []):
        path = os.path.join(SRC_DIR, sheet_src)
        if not os.path.exists(path):
            print(f"{name}: skipping {sheet_src} (not in {SRC_DIR}/ yet)")
            continue
        grid = slice_sheet(path, sheet_rows)
        for row, frames in zip(sheet_rows, grid):
            i = 0
            for anim, n in row:
                anims.append((anim, [(f, anchor(f)) for f in map(trim, frames[i:i + n])]))
                i += n
    body_anims = BODY_ALIGNED.get(name, ())
    if body_anims:
        idle = dict(anims).get("idle")
        anims = [(anim, body_aligned(fs, body_offset(idle or fs)) if anim in body_anims else fs)
                 for anim, fs in anims]
    # Cell size: fit every frame around a shared anchor point.
    left = max(ax for _, fs in anims for _, (ax, _ay) in fs)
    right = max(f.width - ax for _, fs in anims for f, (ax, _ay) in fs)
    above = max(ay for _, fs in anims for _, (_ax, ay) in fs)
    below = max(f.height - ay for _, fs in anims for f, (_ax, ay) in fs)
    half_w = max(left, right) + MARGIN
    cell_w = -(-2 * half_w // CELL_STEP) * CELL_STEP
    cell_h = -(-(above + below + 2 * MARGIN) // CELL_STEP) * CELL_STEP
    foot_x, foot_y = cell_w // 2, cell_h - MARGIN - below
    cols = max(len(fs) for _, fs in anims)
    sheet = Image.new("RGBA", (cols * cell_w, len(anims) * cell_h))
    for r, (_anim, fs) in enumerate(anims):
        for c, (f, (ax, ay)) in enumerate(fs):
            sheet.alpha_composite(f, (c * cell_w + foot_x - ax, r * cell_h + foot_y - ay))
    sheet.save(os.path.join(OUT_DIR, name + ".png"), optimize=True)
    write_sprite_frames(name, anims, cell_w, cell_h, (foot_x, foot_y))
    return sheet, (cell_w, cell_h), [(a, len(fs)) for a, fs in anims], (foot_x, foot_y)


def write_sprite_frames(name, anims, cell_w, cell_h, foot):
    subs, anim_defs, sid = [], [], 0
    for r, (anim, fs) in enumerate(anims):
        refs = []
        for c in range(len(fs)):
            sid += 1
            subs.append(f'[sub_resource type="AtlasTexture" id="AtlasTexture_{sid}"]\n'
                        f'atlas = ExtResource("1")\n'
                        f'region = Rect2({c * cell_w}, {r * cell_h}, {cell_w}, {cell_h})\n')
            refs.append(f'{{\n"duration": 1.0,\n"texture": SubResource("AtlasTexture_{sid}")\n}}')
        # "lv2_fire" -> "fire", "walk_down_right" -> "walk".
        base = next((w for w in anim.split("_") if w in FPS or w in NO_LOOP), anim)
        loop = "false" if base in NO_LOOP else "true"
        anim_defs.append(f'{{\n"frames": [{", ".join(refs)}],\n"loop": {loop},\n'
                         f'"name": &"{anim}",\n"speed": {FPS.get(base, 8)}.0\n}}')
    path = os.path.join(OUT_DIR, name + ".tres")
    # Keep the uid Godot gave the file, so resources that point at it by uid stay valid.
    uid = ""
    if os.path.exists(path):
        with open(path) as fh:
            found = re.search(r' uid="([^"]+)"', fh.readline())
        uid = f' uid="{found.group(1)}"' if found else ""
    text = (f'[gd_resource type="SpriteFrames" load_steps={sid + 2} format=3{uid}]\n\n'
            f'[ext_resource type="Texture2D" path="res://{OUT_DIR}/{name}.png" id="1"]\n\n'
            + "\n".join(subs)
            + f'\n[resource]\nanimations = [{", ".join(anim_defs)}]\n'
            # Feet position relative to the cell centre; nodes use it to stand on their origin.
            + f'metadata/foot_offset = Vector2({foot[0] - cell_w / 2}, {foot[1] - cell_h / 2})\n')
    with open(path, "w") as fh:
        fh.write(text)


def build_static(name, src, rows):
    grid = slice_sheet(os.path.join(SRC_DIR, src), [[(n, 1) for n in row] for row in rows])
    os.makedirs(os.path.join(OUT_DIR, name), exist_ok=True)
    images = []
    for names, frames in zip(rows, grid):
        for n, f in zip(names, frames):
            f = trim(f)
            f.save(os.path.join(OUT_DIR, name, n + ".png"), optimize=True)
            images.append((n, f))
    return images


def preview(results, statics, path):
    """One labelled image showing every output, for eyeballing mistakes."""
    scale = 0.5
    blocks = []
    for name, (sheet, cell, anims, foot) in results.items():
        im = sheet.resize((int(sheet.width * scale), int(sheet.height * scale)))
        bg = Image.new("RGBA", im.size, (60, 62, 72, 255))
        d = ImageDraw.Draw(bg)
        cw, ch = cell[0] * scale, cell[1] * scale
        for r, (anim, n) in enumerate(anims):
            for c in range(n):
                d.rectangle([c * cw, r * ch, (c + 1) * cw - 1, (r + 1) * ch - 1], outline=(90, 92, 105))
                fx, fy = c * cw + foot[0] * scale, r * ch + foot[1] * scale
                d.line([fx - 6, fy, fx + 6, fy], fill=(255, 80, 80))
        bg.alpha_composite(im)
        d = ImageDraw.Draw(bg)
        for r, (anim, n) in enumerate(anims):
            d.text((4, r * ch + 2), anim, fill=(255, 230, 90))
        blocks.append((f"{name}  (cell {cell[0]}x{cell[1]})", bg))
    for name, images in statics.items():
        x, h, tiles = 0, 0, []
        for n, f in images:
            t = f.resize((max(1, int(f.width * scale)), max(1, int(f.height * scale))))
            tiles.append((n, t, x))
            x += t.width + 20
            h = max(h, t.height)
        bg = Image.new("RGBA", (x, h + 14), (60, 62, 72, 255))
        d = ImageDraw.Draw(bg)
        for n, t, tx in tiles:
            bg.alpha_composite(t, (tx, 14))
            d.text((tx, 0), n, fill=(255, 230, 90))
        blocks.append((name + "/", bg))
    width = max(b.width for _, b in blocks) + 20
    height = sum(b.height + 34 for _, b in blocks) + 10
    out = Image.new("RGB", (width, height), (35, 36, 42))
    d = ImageDraw.Draw(out)
    y = 10
    for title, b in blocks:
        d.text((10, y), title, fill=(255, 255, 255))
        out.paste(b, (10, y + 18), b)
        y += b.height + 34
    out.save(path)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    results = {name: build_animated(name, src, rows) for name, (src, rows) in SHEETS.items()}
    statics = {name: build_static(name, src, rows) for name, (src, rows) in STATICS.items()}
    for name, (_s, cell, anims, _f) in results.items():
        print(f"{name:18s} cell {cell[0]}x{cell[1]}  " + ", ".join(f"{a}:{n}" for a, n in anims))
    for name, images in statics.items():
        print(f"{name}/ " + ", ".join(n for n, _ in images))
    if len(sys.argv) > 1:
        preview(results, statics, sys.argv[1])
        print("preview:", sys.argv[1])


if __name__ == "__main__":
    main()
