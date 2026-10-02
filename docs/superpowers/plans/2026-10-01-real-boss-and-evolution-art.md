# Real Boss and Evolution Art Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the placeholder looks of the two bosses and seven tower evolutions with the new art sheets, and show boss portraits on the boss bar.

**Architecture:** The new sheets are copied into `assets/source/` and sliced by `tools/slice_sprites.py` (new `--only` filter, `_`-discarded animations, same-name joining) into SpriteFrames; data files switch to them. The Gearshot pair gets rotating heads from `tools/split_turret.py`. Small data flags let the Embercaster and Spire evolutions keep idle art while their (direction-fixed) effects are drawn by the game. Portraits are a new `EnemyDefinition.portrait` shown by `BossBar`.

**Tech Stack:** Godot 4.7.1 GDScript; Python 3 + Pillow + NumPy for the art tools; headless Godot tests; Godot MCP for in-game checks.

**Spec:** `docs/superpowers/specs/2026-10-01-real-boss-and-evolution-art-design.md`

## Global Constraints

- Work on branch `real-boss-and-evolution-art` (already created; the spec is committed). One commit per task, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Stage only the task's files.
- Never edit files in `assets/source/` or the Desktop folder. Never run the slicer without `--only`: a full run rewrites the other sprite `.tres` files. After every slicer run, `git status --short assets/sprites/` must list only the outputs being built.
- Evolution SpriteFrames animations: `lv3_idle`, `lv3_fire`, `destroyed`. Boss animations: Warchief idle 4 · walk 9 · attack 6 · war_cry 6 · hurt 4 · death 8; Shaman-King idle 4 · walk 8 · cast 6 · projectile 2 · summon 6 · buff 4 · phase_shift 7 · death 9. `war_cry`, `summon`, `phase_shift` don't loop.
- Tints white and glow transparent for the seven evolutions with new art (Gatling Engine, Rune Cannon, Siege Battery, Frost Rune Mortar, Inferno, Oil Sprayer, Storm Array). The Focus Lens is untouched.
- Boss looks: tints white; Shaman-King aura transparent; Warchief keeps `aura = Color(1, 0.3, 0.2, 0.35)`. Warchief ≈ 1.8× a goblin's height, Shaman-King ≈ 2.2× (tune `sprite_scale` from screenshots).
- Portrait on the boss bar: 56×56, left of the name and bar, hidden when the boss has none.
- Gearshot pair: rotating head cut from the `lv3_idle` frame; Inferno / Oil Sprayer keep `lv3_idle` while spraying; Storm Array keeps `lv3_idle` when it fires; Mortar pair use their fire frames.
- Headless tests run with a timeout: `timeout 60 godot --headless --path . --script tests/<file>.gd` (a runtime error stops the script before `quit()` and it hangs otherwise). "Identifier not found" lines about autoloads are noise.
- New `class_name` or new/changed PNGs need `timeout 200 godot --headless --editor --path . --import` before tests or the game see them.
- MCP checks: `run_project`; the first `game_eval` usually says "Not connected" (retry). The game starts at the main menu: `get_tree().change_scene_to_file("res://scenes/world.tscn")`, await 5 process frames, `var world = get_tree().current_scene`, set `world.run_cards.ended = true`. Resources: `var d: Dictionary[StringName, int] = {&"scrap": 800, &"aether": 60}; core.stored.add_all(d)`. Spawn: `world.get_node("WaveDirector").spawn_at(load("res://data/enemies/<id>.tres"), pos)`. A script error in an eval freezes the game: check `get_debug_output`, then `stop_project` + `run_project`. Never use a ternary on a void method in an eval. After `stop_project`, `git checkout project.godot`. The camera follows the hero: move the hero next to what you screenshot (`hero.global_position = ...; hero.reset_physics_interpolation()`); the HUD covers the top ~180 px.

## Review Focus

1. **Boss channels that never end** — a looping `war_cry` / `summon` / `phase_shift` would freeze the boss forever mid-ability; each must finish and the boss walk on (Task 2 test: loop flags; in-game: the boss moves again after each ability).
2. **Rotating heads cut badly** — the Gatling / Rune Cannon base keeps a ghost barrel, or the head rotates around the wrong point and floats off the base when aiming left or up (Task 4: screenshots aiming right, left, up and down).
3. **Mirrored towers firing from the wrong spot** — shells / flames / bolts leave from empty air instead of the barrel when the tower faces left (Tasks 5–7: screenshots facing both ways).
4. **A wreck that doesn't show** — an evolved tower destroyed shows nothing or the idle art (wrong animation name) (Tasks 4–7: kill each tower and check `sprite.animation`).
5. **Re-slicing breaks existing art** — the slicer changes touch an existing sheet (e.g. same-name joining or `_` discarding changes how old sheets slice) (Task 1: `git status` after slicing shows only the new outputs, and a `--only goblin_shaman` re-run leaves it unchanged).

---

### Task 1: Slicer support and the new sheets

**Files:**
- Modify: `tools/slice_sprites.py`
- Delete: `tools/alias_frames.py`
- Create (copies): `assets/source/goblin_warchief.png`, `goblin_shaman_king.png`, `boss_portraits.png`, `gearshot_evolutions.png`, `rune_mortar_evolutions.png`, `embercaster_evolutions.png`, `aether_spire_evolutions.png`
- Create (generated): `assets/sprites/goblin_warchief.png/.tres`, `goblin_shaman_king.png/.tres`, `gatling_engine.png/.tres` (overwrites the alias), `rune_cannon.png/.tres`, `siege_battery.png/.tres`, `frost_mortar.png/.tres`, `inferno.png/.tres`, `oil_sprayer.png/.tres`, `storm_array.png/.tres` (overwrites the alias), `assets/sprites/portraits/goblin_warchief.png`, `goblin_shaman_king.png`

**Interfaces:**
- Produces: SpriteFrames at `res://assets/sprites/<id>.tres` with the animations listed in Global Constraints; portrait PNGs at `res://assets/sprites/portraits/<boss id>.png`; `python3 tools/slice_sprites.py --only a,b [PREVIEW_PNG]`.

- [ ] **Step 1: Baseline.** `git status --short` is clean. Run `python3 tools/slice_sprites.py --only goblin_shaman`. Expected: it fails (no `--only` yet: it treats `--only` as the preview path or rebuilds everything). Restore with `git checkout assets/sprites/` and delete any stray file named `--only`.

- [ ] **Step 2: Copy the sources.**

```bash
for f in goblin_warchief goblin_shaman_king boss_portraits gearshot_evolutions rune_mortar_evolutions embercaster_evolutions aether_spire_evolutions; do cp ~/Desktop/"Astral forge assests"/$f.png assets/source/; done
```

- [ ] **Step 3: `--only`, discarding and joining.** In `tools/slice_sprites.py`:
  - Docstring "Run from the project root" section becomes:

```
Run from the project root (always name the outputs to build; a full run
rewrites every sprite .tres in a different but equivalent format):
    python3 tools/slice_sprites.py --only goblin,gearshot [PREVIEW_PNG]

In a row list, animation names starting with "_" are sliced (so the frame
count still splits the row right) and then thrown away, and a name used twice
is joined into one animation.
```

  and remove the "Evolved towers that borrow a spare sheet: run tools/alias_frames.py afterwards." line.
  - In `build_animated`, replace the inner loop body that appends animations with:

```python
            for anim, n in row:
                fs = [trim(f) for f in frames[i:i + n]]
                i += n
                if anim.startswith("_"):
                    continue
                if scale != 1.0:
                    fs = [f.resize((round(f.width * scale), round(f.height * scale)),
                                   Image.LANCZOS) for f in fs]
                frames_with_anchors = [(f, anchor(f)) for f in fs]
                for k, (existing, existing_fs) in enumerate(anims):
                    if existing == anim:
                        anims[k] = (anim, existing_fs + frames_with_anchors)
                        break
                else:
                    anims.append((anim, frames_with_anchors))
```

  - `NO_LOOP` gains `"war_cry", "summon", "phase_shift"` (the full names: `write_sprite_frames` falls back to the whole name when no word matches).
  - `main()` becomes:

```python
def main():
    args = sys.argv[1:]
    only = None
    if args and args[0] == "--only":
        only = set(args[1].split(","))
        args = args[2:]
    if only is None:
        sys.exit("Name the outputs to build: --only name,name (see the docstring).")
    os.makedirs(OUT_DIR, exist_ok=True)
    unknown = only - set(SHEETS) - set(STATICS)
    if unknown:
        sys.exit("Unknown outputs: " + ", ".join(sorted(unknown)))
    results = {name: build_animated(name, src, rows)
               for name, (src, rows) in SHEETS.items() if name in only}
    statics = {name: build_static(name, src, rows)
               for name, (src, rows) in STATICS.items() if name in only}
    for name, (_s, cell, anims, _f) in results.items():
        print(f"{name:18s} cell {cell[0]}x{cell[1]}  " + ", ".join(f"{a}:{n}" for a, n in anims))
    for name, images in statics.items():
        print(f"{name}/ " + ", ".join(n for n, _ in images))
    if args:
        preview(results, statics, args[0])
        print("preview:", args[0])
```

- [ ] **Step 4: Prove old sheets are untouched.** Run `python3 tools/slice_sprites.py --only goblin_shaman,goblin_brute,gearshot`. Expected: `git status --short assets/sprites/` shows **no PNG changes**. (The three `.tres` may show the known format-only rewrite; check with `git diff --stat assets/sprites/*.png` = empty, then `git checkout assets/sprites/`.) (Review Focus 5.)

- [ ] **Step 5: The new entries.** Add a helper and the entries to `SHEETS`:

```python
def evolution_pair(first):
    """Rows for a two-evolution sheet; `first` picks which half to keep."""
    keep = [[("lv3_idle", 4)], [("lv3_fire", 4)], [("destroyed", 2)]]
    drop = [[("_idle", 4)], [("_fire", 4)], [("_destroyed", 2)]]
    return keep + drop if first else drop + keep
```

```python
    "goblin_warchief": ("goblin_warchief.png", [
        [("idle", 4)], [("walk", 9)], [("attack", 6)], [("war_cry", 6)], [("hurt", 4)], [("death", 8)]]),
    # Row 3: cast frames 1-4, the loose orb fan (dropped), cast 5-6, then the orb.
    "goblin_shaman_king": ("goblin_shaman_king.png", [
        [("idle", 4)], [("walk", 8)],
        [("cast", 4), ("_fan", 1), ("cast", 2), ("projectile", 2)],
        [("summon", 6)], [("buff", 4)], [("phase_shift", 7)], [("death", 9)]]),
    "gatling_engine": ("gearshot_evolutions.png", evolution_pair(True)),
    "rune_cannon": ("gearshot_evolutions.png", evolution_pair(False)),
    "siege_battery": ("rune_mortar_evolutions.png", evolution_pair(True)),
    "frost_mortar": ("rune_mortar_evolutions.png", evolution_pair(False)),
    "inferno": ("embercaster_evolutions.png", evolution_pair(True)),
    "oil_sprayer": ("embercaster_evolutions.png", evolution_pair(False)),
    # The Focus Lens rows came out jumbled (row 3: 6 lens frames; row 4: the
    # Storm Array's 2 wreck frames, then 3 lens beam frames). Lens art: see
    # ~/Desktop/astral_forge_focus_lens_prompt.txt.
    "storm_array": ("aether_spire_evolutions.png", [
        [("lv3_idle", 4)], [("lv3_fire", 4)], [("_lens", 6)], [("destroyed", 2), ("_lens_fire", 3)]]),
```

  `BODY_ALIGNED` gains `"goblin_warchief": {"walk"}, "goblin_shaman_king": {"walk"}`. Add to `STATICS`:

```python
    "portraits": ("boss_portraits.png", [["goblin_warchief", "goblin_shaman_king"]]),
```

- [ ] **Step 6: Slice and look.** Run:

```bash
python3 tools/slice_sprites.py --only goblin_warchief,goblin_shaman_king,gatling_engine,rune_cannon,siege_battery,frost_mortar,inferno,oil_sprayer,storm_array,portraits /tmp/claude-1000/-home-tylermegill-astral-forge/328258b9-3171-4dce-be05-60316129fd28/scratchpad/art_preview.png
```

  Expected printout: the animation counts from Global Constraints. Open the preview image (Read tool) and check every frame: one whole character/tower per cell, nothing cut in half, no stray piece of a neighbour, feet/base on the red line. In particular: the King's `cast` row has 6 figures and no orb fan, `projectile` is 2 orbs; the Storm Array wreck is the 2 rubble piles. If a row splits wrongly, adjust that row's counts (e.g. split `("_fan", 1)` differently) and re-run until right. `git status --short assets/sprites/` lists only the new outputs (plus `portraits/`).

- [ ] **Step 7: Delete the alias tool.** `git rm tools/alias_frames.py`. `grep -rn alias_frames .` (excluding `.git` and `docs/superpowers`) → nothing.

- [ ] **Step 8: Import and quick check.** `timeout 200 godot --headless --editor --path . --import`. Then run all five existing headless tests (`test_evolutions`, `test_help_text`, `test_cards`, `test_waves`, `test_run_summary`). Expected: all pass (the Gatling/Storm data now point at real art through the overwritten `.tres`; their look is tuned in Tasks 4 and 7).

- [ ] **Step 9: Commit**

```bash
git add tools/slice_sprites.py assets/source/goblin_warchief.png assets/source/goblin_shaman_king.png assets/source/boss_portraits.png assets/source/gearshot_evolutions.png assets/source/rune_mortar_evolutions.png assets/source/embercaster_evolutions.png assets/source/aether_spire_evolutions.png assets/sprites/goblin_warchief.* assets/sprites/goblin_shaman_king.* assets/sprites/gatling_engine.* assets/sprites/rune_cannon.* assets/sprites/siege_battery.* assets/sprites/frost_mortar.* assets/sprites/inferno.* assets/sprites/oil_sprayer.* assets/sprites/storm_array.* assets/sprites/portraits/
git commit -m "Slice the real boss, portrait and evolution art

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(`git rm` already staged the alias tool's removal.)

---

### Task 2: Bosses use their real art

**Files:**
- Create: `tests/test_art.gd`, `scenes/projectiles/king_orb.tscn`
- Modify: `data/enemies/goblin_warchief.tres`, `data/enemies/goblin_shaman_king.tres`

**Interfaces:**
- Consumes: `res://assets/sprites/goblin_warchief.tres`, `goblin_shaman_king.tres` (Task 1).
- Produces: `tests/test_art.gd` with a `check(label, got, want)` helper and sections later tasks extend (`check_portraits()`, `check_evolution(...)`).

- [ ] **Step 1: Failing test** `tests/test_art.gd`:

```gdscript
extends SceneTree
## Headless checks that the bosses and evolved towers use their real art.
## Run: timeout 60 godot --headless --path . --script tests/test_art.gd
## Prints each failure and "art: N passed, M failed"; exits 1 on failure.

var passed := 0
var failed := 0


func _init() -> void:
	var warchief = load("res://data/enemies/goblin_warchief.tres")
	var king = load("res://data/enemies/goblin_shaman_king.tres")
	check_boss(warchief, [&"idle", &"walk", &"death", &"attack", &"war_cry", &"hurt"], [&"war_cry"])
	check_boss(king, [&"idle", &"walk", &"death", &"cast", &"projectile", &"summon", &"buff", &"phase_shift"],
			[&"summon", &"buff", &"phase_shift"])
	check("warchief pulse", warchief.pulse_animation, &"war_cry")
	check("warchief keeps aura", warchief.aura.a > 0.0, true)
	check("king summon anim", king.summon_animation, &"summon")
	check("king phase anim", king.phase_shift_animation, &"phase_shift")
	check("king pulse anim", king.pulse_animation, &"buff")
	check("king attack anim", king.attack_animation, &"cast")
	check("king no aura", king.aura.a, 0.0)
	check("king orb", king.projectile_scene.resource_path, "res://scenes/projectiles/king_orb.tscn")
	print("art: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


## `channels` must exist and play once (a looping one never ends a channel).
func check_boss(def, anims: Array, channels: Array) -> void:
	var frames: SpriteFrames = def.sprite_frames
	check("%s frames" % def.id, frames.resource_path, "res://assets/sprites/%s.tres" % def.id)
	check("%s untinted" % def.id, def.tint, Color.WHITE)
	for anim in anims:
		check("%s has %s" % [def.id, anim], frames.has_animation(anim), true)
	for anim in channels:
		check("%s %s plays once" % [def.id, anim], frames.has_animation(anim) and not frames.get_animation_loop(anim), true)
	check("%s attack frame in range" % def.id,
			frames.has_animation(def.attack_animation)
			and def.attack_hit_frame < frames.get_frame_count(def.attack_animation), true)


func check(label: String, got: Variant, want: Variant) -> void:
	if got == want:
		passed += 1
	else:
		failed += 1
		print("FAIL %s: got %s, want %s" % [label, got, want])
```

Run `timeout 60 godot --headless --path . --script tests/test_art.gd`. Expected: FAILs (frames path, tint, war_cry, summon, aura, king orb…).

- [ ] **Step 2: The King's orb.** Find the region of the King's first `projectile` frame:

```bash
python3 - <<'EOF'
import re
t = open("assets/sprites/goblin_shaman_king.tres").read()
regions = dict(re.findall(r'id="(AtlasTexture_\d+)"\]\natlas = ExtResource\("1"\)\nregion = (Rect2\([^)]*\))', t))
block = re.search(r'"frames": \[(.*?)\],\n"loop": \w+,\n"name": &"projectile"', t, re.S).group(1)
first = re.search(r'SubResource\("(AtlasTexture_\d+)"\)', block).group(1)
print(regions[first])
EOF
```

  Then crop that region of `assets/sprites/goblin_shaman_king.png` to the orb's opaque pixels (PIL `getbbox()` on alpha) and note the tight `Rect2` and where the orb's bright head sits (it flies right; the trail is on the left). Create `scenes/projectiles/king_orb.tscn` (like `enemy_orb.tscn`) with that tight region, the sprite `offset` putting the orb's head at the node origin, and a `scale` so the orb is about 20 px across on screen:

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/projectiles/projectile.gd" id="1_projectile"]
[ext_resource type="Texture2D" path="res://assets/sprites/goblin_shaman_king.png" id="2_sheet"]

[sub_resource type="AtlasTexture" id="AtlasTexture_orb"]
atlas = ExtResource("2_sheet")
region = Rect2(<x>, <y>, <w>, <h>)

[sub_resource type="CircleShape2D" id="CircleShape2D_orb"]
radius = 7.0

[node name="KingOrb" type="Area2D"]
collision_layer = 0
collision_mask = 10
script = ExtResource("1_projectile")
draw_streak = false

[node name="Sprite" type="Sprite2D" parent="."]
scale = Vector2(<s>, <s>)
texture = SubResource("AtlasTexture_orb")
offset = Vector2(<-dx>, 0)

[node name="Shape" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_orb")
```

  (fill the `<…>` values from the measurement — they are numbers from this step, not left as text).

- [ ] **Step 3: Boss data.** In `goblin_warchief.tres`: `sprite_frames` ext_resource → `res://assets/sprites/goblin_warchief.tres`; delete the `tint` line (default white); `pulse_animation = &"war_cry"`; keep `aura`. In `goblin_shaman_king.tres`: `sprite_frames` → `res://assets/sprites/goblin_shaman_king.tres`; delete `tint` and `aura` lines; `summon_animation = &"summon"`; `phase_shift_animation = &"phase_shift"`; `projectile_scene` ext_resource → `res://scenes/projectiles/king_orb.tscn`. Keep `attack_hit_frame = 3` on both. Remove any `uid=` on the changed ext_resource lines.

- [ ] **Step 4: Import and test.** `timeout 200 godot --headless --editor --path . --import`; `timeout 60 godot --headless --path . --script tests/test_art.gd` → `0 failed`. Other headless tests still pass.

- [ ] **Step 5: In-game size and abilities.** Load the world; spawn a goblin, the Warchief and the King 200 px apart, frozen (`set_physics_process(false)`), and screenshot with the hero beside them. Tune `sprite_scale` on each boss so the Warchief stands ≈ 1.8× and the King ≈ 2.2× the goblin's height (measure with `sprite.sprite_frames.get_frame_texture(&"idle",0).get_image().get_used_rect().size.y * sprite.scale.y`). Restart after each data change. Then, unfrozen and with 99999 health, for each boss: let it walk (screenshot), trigger each ability and confirm the boss moves again afterwards (Review Focus 1): Warchief — call `$FrenzyPulse` (find the child whose script is `frenzy_pulse.gd`) to pulse, or wait `pulse_interval`; check `sprite.animation == &"war_cry"` during it and `walk` after. King — wait for a cast near the Core (orbs are the new purple sprite, screenshot one), a summon (`summon` playing, 4 goblins appear), push it below 50% health (`health.take_damage(health.max_health * 0.6, Health.DamageType.MAGIC)`) for `phase_shift`, then kill each and screenshot the death's last frame. No errors in `get_debug_output`.

- [ ] **Step 6: Commit**

```bash
git add tests/test_art.gd scenes/projectiles/king_orb.tscn data/enemies/goblin_warchief.tres data/enemies/goblin_shaman_king.tres
git commit -m "Give the Warchief and Shaman-King their real art

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Boss portraits on the boss bar

**Files:**
- Modify: `scripts/enemies/enemy_definition.gd`, `scenes/ui/boss_bar.tscn`, `scripts/ui/boss_bar.gd`, both boss `.tres`, `tests/test_art.gd`

**Interfaces:**
- Produces: `EnemyDefinition.portrait: Texture2D`; `BossBar.portrait: TextureRect` (`%BossPortrait`).

- [ ] **Step 1: Failing test.** In `tests/test_art.gd` `_init`, before the `print`:

```gdscript
	for def in [warchief, king]:
		check("%s portrait" % def.id, def.portrait != null and def.portrait.resource_path
				== "res://assets/sprites/portraits/%s.png" % def.id, true)
```

  Run → FAIL (`portrait` doesn't exist: an error; that counts as red).

- [ ] **Step 2: Field.** In `enemy_definition.gd`, next to `is_boss`:

```gdscript
## Head-and-shoulders picture for the boss bar; null = name only.
@export var portrait: Texture2D
```

  Set it in both boss files (`portrait = ExtResource(...)` pointing at `res://assets/sprites/portraits/<id>.png`).

- [ ] **Step 3: Boss bar.** In `scenes/ui/boss_bar.tscn`, put an `HBoxContainer` named `Line` (separation 8, `mouse_filter = 2`) under `Center`, move `Rows` under it, and add before `Rows`:

```
[node name="BossPortrait" type="TextureRect" parent="Center/Line"]
unique_name_in_owner = true
custom_minimum_size = Vector2(56, 56)
layout_mode = 2
mouse_filter = 2
expand_mode = 1
stretch_mode = 5
```

  (`Rows`' parent becomes `Center/Line`, and its children's parents `Center/Line/Rows`.) Raise `offset_bottom` so the bar block is 60 px tall. In `boss_bar.gd`: `@onready var portrait: TextureRect = %BossPortrait`, and in `_process` inside `if boss:`:

```gdscript
		portrait.texture = boss.definition.portrait
		portrait.visible = boss.definition.portrait != null
```

- [ ] **Step 4: Test and look.** Import; `test_art.gd` → 0 failed. In game, spawn the Warchief: screenshot the top of the screen (bar with portrait, nothing overlapping the HUD panels or wave banner); spawn the King too and kill the Warchief: the bar switches to the King's portrait. A temporary `boss.definition.portrait = null` hides the picture (restore after).

- [ ] **Step 5: Commit**

```bash
git add scripts/enemies/enemy_definition.gd scenes/ui/boss_bar.tscn scripts/ui/boss_bar.gd data/enemies/goblin_warchief.tres data/enemies/goblin_shaman_king.tres tests/test_art.gd
git commit -m "Show boss portraits on the boss bar

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Gatling Engine and Rune Cannon with rotating heads

**Files:**
- Modify: `tools/split_turret.py`, `data/towers/gatling_engine.tres`, `data/towers/rune_cannon.tres`, `scripts/towers/gatling_definition.gd`, `scripts/towers/gatling_tower.gd`, `tests/test_art.gd`
- Create (generated): `assets/sprites/towers/gatling_engine_base.png`, `_head.png`, `rune_cannon_base.png`, `_head.png`

**Interfaces:**
- Produces: `check_evolution(id: StringName)` in `tests/test_art.gd` (reused by Tasks 5–7).

- [ ] **Step 1: Failing test.** Add to `tests/test_art.gd`:

```gdscript
## An evolution with new art: its own frames (lv3_idle, lv3_fire, a wreck),
## no placeholder tint or glow.
func check_evolution(id: StringName):
	var def = load("res://data/towers/%s.tres" % id)
	var frames: SpriteFrames = def.sprite_frames
	check("%s frames" % id, frames.resource_path, "res://assets/sprites/%s.tres" % id)
	for anim in [&"lv3_idle", &"lv3_fire", &"destroyed"]:
		check("%s has %s" % [id, anim], frames.has_animation(anim), true)
	check("%s untinted" % id, def.tint, Color.WHITE)
	check("%s no glow" % id, def.glow.a, 0.0)
	return def
```

  and in `_init`:

```gdscript
	for id in [&"gatling_engine", &"rune_cannon"]:
		var def = check_evolution(id)
		var head = def.head_for(3)
		check("%s rotating head" % id, head != null
				and head.head_texture.resource_path == "res://assets/sprites/towers/%s_head.png" % id, true)
```

  Run → FAILs (tint, glow, heads).

- [ ] **Step 2: Measure the cut.** The slicer cell for `gatling_engine` / `rune_cannon` is printed by Task 1 (also `get_size()` of a frame). Save frame 0 of `lv3_idle` (row 0, col 0 of `assets/sprites/<id>.png`) enlarged ×3 to the scratchpad with a 10-px grid drawn on it, and Read it. Pick, in cell pixels: `pivot` = centre of the turret's turning housing (where the gun meets the body), `radius` (housing), `tip` = end of the barrel (pointing right, so `drawn` ≈ 0°), `barrel_half_width`, `base_extent` (half-width/height of the stone base around the pivot).

- [ ] **Step 3: Cut.** Add to `TURRETS` in `tools/split_turret.py` (values from Step 2 — numbers, not text):

```python
    "gatling_engine": dict(sheet="assets/sprites/gatling_engine.png", cell=(<cw>, <ch>), frame=(0, 0),
                           pivot=(<px>, <py>), radius=<r>, tip=(<tx>, <ty>), barrel_half_width=<bw>,
                           base_extent=(<ex>, <ey>)),
    "rune_cannon": dict(sheet="assets/sprites/rune_cannon.png", cell=(<cw>, <ch>), frame=(0, 0),
                        pivot=(<px>, <py>), radius=<r>, tip=(<tx>, <ty>), barrel_half_width=<bw>,
                        base_extent=(<ex>, <ey>)),
```

  and give `main()` an optional name filter so old heads aren't rewritten:

```python
def main():
    names = sys.argv[1:] or list(TURRETS)
    for name in names:
        split(name, **TURRETS[name])
```

  (add `import sys`). Run `python3 tools/split_turret.py gatling_engine rune_cannon`. Read both `_base.png` and `_head.png`: the base has no barrel ghost and the stone behind is patched; the head is the whole gun. Repeat Steps 2–3 until clean. `git status --short assets/sprites/towers/` shows only the four new files.

- [ ] **Step 4: Data.** In each `.tres`: `TurretHead` sub-resource for Lv3 with `base_texture` / `head_texture` = the new PNGs, `pivot` = (cell pivot − cell centre − `foot_offset`) — i.e. `Vector2(px - cw/2 - fx, py - ch/2 - fy)` where `foot_offset = (fx, fy)` is the `metadata/foot_offset` in `assets/sprites/<id>.tres`; `drawn_angle` and `barrel_length` as printed by the tool. `heads = [lv3, lv3, lv3]` (same sub-resource three times; evolutions only use Lv3). Delete the `tint`, `glow` lines; `sprite_scale = 0.55`. `rune_cannon.tres`: remove the copied Gearshot head sub-resources and their ext_resources. `gatling_engine.tres`: remove `muzzle_offset`, `barrel_length = 0.0`.

- [ ] **Step 5: Gatling aims like the Gearshot.** In `gatling_tower.gd` delete `_facing_left`, `_aim_at()` and `_muzzle_base()` (the base `Tower` versions handle a rotating head), and update the class comment ("Faces left or right (mirrored art)." → "Its gun turns to face any direction, like the Gearshot."). In `gatling_definition.gd` delete `muzzle_offset`.

- [ ] **Step 6: Test and look.** Import; `test_art.gd` and `test_evolutions.gd` → 0 failed. In game, evolve a Lv3 Gearshot into each on `BuildSlotWest` and `BuildSlotWestNorth`; place a frozen goblin right, left, above and below in turn and screenshot each (Review Focus 2): the gun turns about the housing, stays on the base, bullets / rune rounds leave the barrel tip. Tune `sprite_scale` so they match a Lv3 Gearshot's footprint. Kill each: `sprite.animation == &"destroyed"` and the wreck shows (Review Focus 4). Gatling spin-up and Overcharge still work (one shot each).

- [ ] **Step 7: Commit**

```bash
git add tools/split_turret.py assets/sprites/towers/gatling_engine_* assets/sprites/towers/rune_cannon_* data/towers/gatling_engine.tres data/towers/rune_cannon.tres scripts/towers/gatling_definition.gd scripts/towers/gatling_tower.gd tests/test_art.gd
git commit -m "Give the Gatling Engine and Rune Cannon their real art and rotating heads

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Siege Battery and Frost Rune Mortar

**Files:**
- Modify: `data/towers/siege_battery.tres`, `data/towers/frost_mortar.tres`, `tests/test_art.gd`

- [ ] **Step 1: Failing test.** In `_init`: `for id in [&"siege_battery", &"frost_mortar"]: check_evolution(id)`. Run → FAILs.

- [ ] **Step 2: Measure the muzzle.** For each, Read frame 0 of `lv3_fire` (enlarged ×3 with a grid) and find where the shell leaves the barrel mouth, in cell pixels; `muzzle_offset = Vector2(mx - cw/2 - fx, my - ch/2 - fy)` (feet = `metadata/foot_offset`).

- [ ] **Step 3: Data.** `sprite_frames` → the new `.tres`; delete `tint`, `glow`; `sprite_scale = 0.55`; `muzzle_offset = Vector2(...)` from Step 2.

- [ ] **Step 4: Test and look.** Import; tests → 0 failed. In game, evolve both; fire at points to the right and left (`t._fire_at(t.global_position + Vector2(±260, 0))`) and screenshot each facing (Review Focus 3): shells leave the mouth, fire frames show, frost circles still pale blue. Tune `sprite_scale` against a Lv3 Mortar. Kill each: `destroyed` shows.

- [ ] **Step 5: Commit**

```bash
git add data/towers/siege_battery.tres data/towers/frost_mortar.tres tests/test_art.gd
git commit -m "Give the Siege Battery and Frost Rune Mortar their real art

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Inferno and Oil Sprayer

**Files:**
- Modify: `scripts/towers/ember_definition.gd`, `scripts/towers/ember_tower.gd` (`_show_spray`), `data/towers/inferno.tres`, `data/towers/oil_sprayer.tres`, `tests/test_art.gd`

**Interfaces:**
- Produces: `EmberDefinition.fire_frame_while_spraying: bool` (default true).

- [ ] **Step 1: Failing test.** In `_init`:

```gdscript
	for id in [&"inferno", &"oil_sprayer"]:
		var def = check_evolution(id)
		check("%s idle art while spraying" % id, def.fire_frame_while_spraying, false)
	check("embercaster keeps fire frame", load("res://data/towers/embercaster.tres").fire_frame_while_spraying, true)
```

  Run → FAIL.

- [ ] **Step 2: Flag.** In `ember_definition.gd`'s `Flame` group:

```gdscript
## Show the first fire frame while spraying. Off for art whose painted flame
## only points one way: the drawn cone is the flame.
@export var fire_frame_while_spraying := true
```

  In `ember_tower.gd`, `_show_spray()` becomes:

```gdscript
## Spraying holds the first fire frame (the glowing barrel; the drawn cone is
## the flame, as the later frames' flames are clipped at the frame edge) —
## unless the art's flame is painted in, then it stays on its idle art.
func _show_spray() -> void:
	var fire_art := is_spraying() and ember.fire_frame_while_spraying
	var animation := StringName("lv%d_%s" % [level, "fire" if fire_art else "idle"])
	if sprite.animation != animation:
		if fire_art:
			sprite.animation = animation
			sprite.stop()
			sprite.frame = 0
		else:
			sprite.play(animation)
	embers.emitting = is_spraying()
	if is_spraying():
		embers.global_position = _muzzle_base()
		embers.direction = _aim_dir
		embers.spread = cone_angle() / 2.0
		var speed := attack_range() / embers.lifetime
		embers.initial_velocity_min = speed * 0.6
		embers.initial_velocity_max = speed
```

- [ ] **Step 3: Measure and data.** Nozzle tip on `lv3_idle` frame 0 → `muzzle_offset` (as in Task 5 Step 2). Each file: `sprite_frames` → new; delete `tint`, `glow`; `sprite_scale = 0.55`; `fire_frame_while_spraying = false`; `muzzle_offset`.

- [ ] **Step 4: Test and look.** Import; tests → 0 failed. In game, both spraying a frozen goblin to the right, then one to the left: idle art shows, the cone and embers leave the nozzle, facing both ways (Review Focus 3); screenshots. Base Embercaster still shows its fire frame while spraying. Kill each: `destroyed` shows.

- [ ] **Step 5: Commit**

```bash
git add scripts/towers/ember_definition.gd scripts/towers/ember_tower.gd data/towers/inferno.tres data/towers/oil_sprayer.tres tests/test_art.gd
git commit -m "Give the Inferno and Oil Sprayer their real art

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Storm Array

**Files:**
- Modify: `scripts/towers/spire_definition.gd`, `scripts/towers/spire_tower.gd` (`_strike`), `data/towers/storm_array.tres`, `tests/test_art.gd`

**Interfaces:**
- Produces: `SpireDefinition.show_fire_frame: bool` (default true).

- [ ] **Step 1: Failing test.** In `_init`:

```gdscript
	var storm = check_evolution(&"storm_array")
	check("storm idle art when firing", storm.show_fire_frame, false)
	check("spire keeps fire frame", load("res://data/towers/aether_spire.tres").show_fire_frame, true)
```

  Run → FAIL.

- [ ] **Step 2: Flag.** In `spire_definition.gd`'s `Chain` group:

```gdscript
## Show the charge frame when a bolt fires. Off for art whose painted
## lightning only points one way.
@export var show_fire_frame := true
```

  In `spire_tower.gd` `_strike()`, wrap the four fire-frame lines:

```gdscript
	# The first fire frame is the swirling charge; the later ones' beams are
	# clipped at the frame edge.
	if spire.show_fire_frame:
		sprite.animation = StringName("lv%d_fire" % level)
		sprite.stop()
		sprite.frame = 0
		_fire_frame_left = CHARGE_FRAME_TIME
```

- [ ] **Step 3: Measure and data.** On `lv3_idle` frame 0, the height of the top of the tallest crystal above the feet × 0.9 (in on-screen pixels after `sprite_scale`) → `bolt_heights[2]`. `storm_array.tres`: `show_fire_frame = false`; `sprite_scale = 0.55` (tune); `bolt_heights = PackedFloat32Array(90, 100, <h>)`.

- [ ] **Step 4: Test and look.** Import; tests → 0 failed. In game, bolts at goblins left and right leave the crystal tips; idle art stays; Thunderstorm works; kill → `destroyed`. Screenshot beside a Lv3 Spire and tune scale.

- [ ] **Step 5: Commit**

```bash
git add scripts/towers/spire_definition.gd scripts/towers/spire_tower.gd data/towers/storm_array.tres tests/test_art.gd
git commit -m "Give the Storm Array its real art

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Full pass, docs and roadmap

**Files:**
- Modify: `ROADMAP.md`

- [ ] **Step 1: Every test.** All six headless test files (`test_art`, `test_evolutions`, `test_help_text`, `test_cards`, `test_waves`, `test_run_summary`) → `0 failed`.

- [ ] **Step 2: Full in-game pass.** Build and evolve all eight towers (the Focus Lens stays a tinted Spire), start waves 1–3 at 3× speed (`Engine.time_scale = 3.0`, reset to 1 after) — no errors, all fire. Spawn both bosses near the towers and let them fight for ~20 s: no errors; screenshot. Help screen and Codex: the bosses' Codex pictures use the new idle art (unlock with `Codex.mark_seen(definition)` if needed and delete `user://codex.cfg` after).

- [ ] **Step 3: Web build.** Export (`timeout 300 godot --headless --path . --export-release "Web" export/web/index.html`), serve, load in Playwright (Play at y≈321), wait 8 s: no console errors.

- [ ] **Step 4: Roadmap.** In `ROADMAP.md`: Phase 10's 10-wave line — replace "Real boss art: see `docs/art/...`" with "Real boss art and portraits (2026-10-01)"; the evolutions line — replace "Placeholder look (tint + glow, or the spare blaster/harvester sheets); real art: ..." with "Real art for all but the Focus Lens (its sheet is being redone: `~/Desktop/astral_forge_focus_lens_prompt.txt`)". In "What each art file is", add rows:

```markdown
| `goblin_warchief.png` | `goblin_warchief` — **Goblin Warchief** (mini-boss) | idle, walk, attack, war_cry, hurt, death | 10 |
| `goblin_shaman_king.png` | `goblin_shaman_king` — **Goblin Shaman-King** (final boss) | idle, walk, cast, projectile, summon, buff, phase_shift, death | 10 |
| `boss_portraits.png` | `portraits/*.png` — boss bar portraits | single images | 10 |
| `gearshot_evolutions.png` | `gatling_engine`, `rune_cannon` | lv3_idle, lv3_fire, destroyed (+ rotating heads) | 10 |
| `rune_mortar_evolutions.png` | `siege_battery`, `frost_mortar` | lv3_idle, lv3_fire, destroyed | 10 |
| `embercaster_evolutions.png` | `inferno`, `oil_sprayer` | lv3_idle, lv3_fire, destroyed | 10 |
| `aether_spire_evolutions.png` | `storm_array` (Focus Lens rows unusable) | lv3_idle, lv3_fire, destroyed | 10 |
```

  and under "Art still needed": "Focus Lens (`focus_lens.png`, prompt on the Desktop)"; remove "Elite enemy, final boss".

- [ ] **Step 5: Commit**

```bash
git add ROADMAP.md
git commit -m "Note the real boss and evolution art on the roadmap

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
