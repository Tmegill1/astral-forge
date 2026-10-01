"""Write SpriteFrames that reuse another sheet's frames under new animation
names, so a spare sheet can stand in for an evolved tower (which only needs
lv3_idle, lv3_fire and destroyed).

Run from the project root after tools/slice_sprites.py:
    python3 tools/alias_frames.py
"""
import os
import re

OUT_DIR = "assets/sprites"

# New SpriteFrames -> (source sheet, [(new animation, source animation,
# frame indices or None for all, frames per second, loops)]).
ALIASES = {
    # The blaster faces right; its idle row turns the barrel, so idle is the
    # first frame only. Fire frames 1-5 glow; the last destroy frame is the wreck.
    "gatling_engine": ("blaster_turret", [
        ("lv3_idle", "idle", [0], 1, True),
        ("lv3_fire", "fire", [1, 2, 3, 4, 5], 30, False),
        ("destroyed", "destroy", [7], 1, False)]),
    "storm_array": ("aether_harvester", [
        ("lv3_idle", "lv3_idle", None, 6, True),
        ("lv3_fire", "lv3_pulse", None, 8, True),
        ("destroyed", "destroyed", None, 1, False)]),
}


def parse(name):
    """Animation name -> list of Rect2 regions, and the foot offset."""
    with open(os.path.join(OUT_DIR, name + ".tres")) as fh:
        text = fh.read()
    regions = dict(re.findall(
        r'id="(AtlasTexture_\d+)"\]\natlas = ExtResource\("1"\)\nregion = (Rect2\([^)]*\))', text))
    anims = {}
    for frames, anim in re.findall(r'"frames": \[(.*?)\],\n"loop": \w+,\n"name": &"([^"]+)"', text, re.S):
        anims[anim] = [regions[i] for i in re.findall(r'SubResource\("(AtlasTexture_\d+)"\)', frames)]
    foot = re.search(r'metadata/foot_offset = (Vector2\([^)]*\))', text).group(1)
    return anims, foot


def write(name, source, aliases):
    anims, foot = parse(source)
    subs, defs, sid = [], [], 0
    for new, src, picks, speed, loop in aliases:
        regions = anims[src] if picks is None else [anims[src][i] for i in picks]
        refs = []
        for region in regions:
            sid += 1
            subs.append(f'[sub_resource type="AtlasTexture" id="AtlasTexture_{sid}"]\n'
                        f'atlas = ExtResource("1")\nregion = {region}\n')
            refs.append(f'{{\n"duration": 1.0,\n"texture": SubResource("AtlasTexture_{sid}")\n}}')
        defs.append(f'{{\n"frames": [{", ".join(refs)}],\n"loop": {str(loop).lower()},\n'
                    f'"name": &"{new}",\n"speed": {speed}.0\n}}')
    path = os.path.join(OUT_DIR, name + ".tres")
    # Keep the uid Godot gave the file, so resources that point at it stay valid.
    uid = ""
    if os.path.exists(path):
        with open(path) as fh:
            found = re.search(r' uid="([^"]+)"', fh.readline())
        uid = f' uid="{found.group(1)}"' if found else ""
    text = (f'[gd_resource type="SpriteFrames" load_steps={sid + 2} format=3{uid}]\n\n'
            f'[ext_resource type="Texture2D" path="res://{OUT_DIR}/{source}.png" id="1"]\n\n'
            + "\n".join(subs)
            + f'\n[resource]\nanimations = [{", ".join(defs)}]\n'
            + f'metadata/foot_offset = {foot}\n')
    with open(path, "w") as fh:
        fh.write(text)
    print(f"{name}: " + ", ".join(f"{a[0]}:{len(anims[a[1]]) if a[2] is None else len(a[2])}" for a in aliases))


if __name__ == "__main__":
    for out, (src, aliases) in ALIASES.items():
        write(out, src, aliases)
