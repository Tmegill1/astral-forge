# Tower Levels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the player upgrade a built tower from Lv1 to Lv3 from the tower menu (Lv2 for Scrap, Lv3 for Scrap + Aether), boosting its stats and switching its art, with its walls levelling up alongside.

**Architecture:** Level data lives on `TowerDefinition` (multipliers, `lv2_cost`/`lv3_cost`, one `TurretHead` resource per level). `Tower` computes stats from its `level` and applies a level with `set_level`. `BuildSlot` owns the purchase (`upgrade()`), tracks what was spent for sell refunds, and tracks `wall_level` for wall art and health. `TowerMenu` gains an Upgrade button and preview.

**Tech Stack:** Godot 4.7, GDScript, `.tscn`/`.tres`, Python 3 + Pillow/NumPy for `tools/split_turret.py`. Verification by driving the running game with the Godot MCP tools.

**Spec:** `docs/superpowers/specs/2026-09-24-tower-levels-design.md`

## Global Constraints

- `MAX_LEVEL = 3`. Multipliers compound per level above 1: damage 1.3, fire rate 1.15, range 1.1, health 1.4.
- Gearshot: `lv2_cost = {&"scrap": 15}`, `lv3_cost = {&"scrap": 25, &"aether": 3}`.
- Wall health by level: 120 / 180 / 260. Post widths by level: 52 / 52 / 48 px.
- Sell refunds `floor(0.5 × invested)` per resource, where invested = build cost + upgrades paid.
- Button text: `Upgrade to Lv2 — 15 Scrap`; short: `Upgrade to Lv2 — need 4 Scrap more`; maxed: `Max level`.
- Menu title `Gearshot Turret — Lv2`; operating title `Operating Gearshot Turret Lv2`.
- Style: tabs, `##` doc comments, typed GDScript, StringName literals.
- Work on branch `phase8-tower-levels`; one commit per task ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- After each MCP run: `git checkout project.godot` if it shows modified. New `class_name`: run `godot --headless --editor --path . --import` before the headless check.
- Headless check (the per-task recorded test): `.superpowers/sdd/<plan>/check.sh`, copied from step 1: load the project headless and fail on `SCRIPT ERROR|Parse Error|ERROR: Failed`.
- Don't free living enemies directly in tests during a wave; the wave director's `_alive` filter breaks on freed objects.

## Review Focus

1. **Upgrading a destroyed tower** (wreckage phase) must be refused and spend nothing (Task 4 test).
2. **Short on Aether but rich in Scrap at Lv2→Lv3**: nothing is spent (Task 4 test).
3. **A wall damaged below half at upgrade** keeps showing damaged art at its new level (Task 4 test).
4. **Operating a tower while it upgrades**: the head swaps without the hero being thrown out, and the aim keeps working (Task 3 test).
5. **Sell after a destroyed-and-rebuilt tower**: the refund only counts the current tower's spend, not the old one's (Task 4 test).

## How to test

Same as step 1: `mcp__godot__run_project`; the first `game_eval` may say "Not connected", so repeat it once. Prelude: `var world = get_tree().current_scene`. Check `get_debug_output` for new errors, then `stop_project`.

---

### Task 1: TurretHead resource (refactor, no behaviour change)

**Files:**
- Create: `scripts/towers/turret_head.gd`
- Modify: `scripts/towers/tower_definition.gd` (rotating-head group)
- Modify: `scripts/towers/tower.gd` (`_has_head`, `_setup_head`, `_turn_head`, `_barrel_length`)
- Modify: `data/towers/gearshot.tres`

**Interfaces:**
- Produces: `class_name TurretHead` (`base_texture`, `head_texture`, `pivot: Vector2`, `drawn_angle: float`, `barrel_length: float`); `TowerDefinition.heads: Array[TurretHead]`; `TowerDefinition.head_for(level: int) -> TurretHead` (null if none); `Tower._head: TurretHead`

- [ ] **Step 1: Record the current Gearshot head numbers (baseline)**

Run the game, build a Gearshot on `BuildSlotWest`, and eval:
```gdscript
var world = get_tree().current_scene
world.core.stored.add(&"scrap", 20)
var s = world.get_node("Units/BuildSlotWest")
s.build(load("res://data/towers/gearshot.tres"))
await get_tree().physics_frame
var t = s.built
return [t.head.visible, t.head.texture.resource_path, t._head_rest, t._barrel_length(), t.muzzle_flash.position]
```
Expected: `[true, "res://assets/sprites/towers/gearshot_lv1_head.png", (-1.65, -42.35), 34.65, <vector>]`. Write the output into the ledger; Step 4 must match it exactly. Stop.

- [ ] **Step 2: Add the resource**

`scripts/towers/turret_head.gd`:
```gdscript
class_name TurretHead
extends Resource
## One level's rotating-head art, made by tools/split_turret.py: a static
## base plus a head that turns to face any direction.

@export var base_texture: Texture2D
@export var head_texture: Texture2D
## Where the head turns, relative to the tower's base point, in texture pixels.
@export var pivot := Vector2.ZERO
## Direction the barrel points in head_texture (degrees, 0 = right, -90 = up).
@export var drawn_angle := 0.0
## Pivot to barrel tip, in texture pixels.
@export var barrel_length := 0.0
```

- [ ] **Step 3: Switch the definition and tower to it**

In `scripts/towers/tower_definition.gd`, replace the whole `@export_group("Rotating head")` block (from its comment down to and including `head_turn_speed`) with:
```gdscript
@export_group("Rotating head")
## Optional, per level (index 0 = Lv1): a static base plus a head that turns
## to face any direction. A level with an entry uses it instead of its
## idle/fire frames and aim_angles below.
@export var heads: Array[TurretHead] = []
## Degrees per second the head can turn.
@export var head_turn_speed := 720.0
```
and add after `icon()`:
```gdscript
## This level's rotating head, or null to use the frame-based art.
func head_for(tower_level: int) -> TurretHead:
	return heads[tower_level - 1] if tower_level <= heads.size() else null
```
In `scripts/towers/tower.gd`:
- add `var _head: TurretHead` under `var _inward`
- `_has_head()` → `return _head != null`
- in `_ready`, before `_setup_head()`: `_head = definition.head_for(level)`
- in `_setup_head()`, use `_head.base_texture`, `_head.head_texture`, `_head.pivot`, `_head.drawn_angle`, `_head.barrel_length` in place of the old `definition.*` fields
- in `_turn_head()`: `head.rotation = _head_angle - deg_to_rad(_head.drawn_angle)`
- in `_barrel_length()`: `return _head.barrel_length * definition.sprite_scale`

In `data/towers/gearshot.tres`:
- set the header to `load_steps=7`
- add `[ext_resource type="Script" path="res://scripts/towers/turret_head.gd" id="5_head"]`
- add before `[resource]`:
```
[sub_resource type="Resource" id="TurretHead_lv1"]
script = ExtResource("5_head")
base_texture = ExtResource("3_base")
head_texture = ExtResource("4_head")
pivot = Vector2(-3, -77)
drawn_angle = -111.0
barrel_length = 63.0
```
- in `[resource]`, remove `base_texture`, `head_texture`, `head_pivot`, `head_drawn_angle` and `head_barrel_length`, and add:
```
heads = Array[ExtResource("5_head")]([SubResource("TurretHead_lv1")])
```
(For the typed array of a script class, the element type is the script's ExtResource, the same pattern as `buildable` in `build_slot.tscn`.)

Run `godot --headless --editor --path . --import`, then the headless check. Expected: no errors.

- [ ] **Step 4: Verify identical behaviour**

Re-run Step 1's eval. Expected: identical output. Screenshot the tower with the hero operating it and the mouse moved to 3 directions (`game_mouse_move` or eval `Input.warp_mouse`); the head turns as before. Stop.

- [ ] **Step 5: Commit**

```bash
git add scripts/towers/turret_head.gd scripts/towers/turret_head.gd.uid scripts/towers/tower_definition.gd scripts/towers/tower.gd data/towers/gearshot.tres
git commit -m "Move rotating-head settings into a per-level TurretHead resource

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
(`turret_head.gd.uid` exists after the import; add it if present.)

---

### Task 2: Levels on the definition and tower

**Files:**
- Modify: `scripts/components/health.gd` (`grow_max`)
- Modify: `scripts/towers/tower_definition.gd` (Levels group, helpers)
- Modify: `scripts/towers/tower.gd` (stats, `_ready` health, `set_level`)
- Modify: `data/towers/gearshot.tres` (costs)

**Interfaces:**
- Consumes: `TowerDefinition.head_for` (Task 1)
- Produces: `Health.grow_max(new_max: float)`; `TowerDefinition.MAX_LEVEL := 3`; `lv2_cost`, `lv3_cost: Dictionary[StringName, int]`; `upgrade_cost(to_level: int) -> Dictionary[StringName, int]`; `damage_at(l)`, `fire_rate_at(l)`, `range_at(l)`, `max_health_at(l) -> float`; `Tower.set_level(new_level: int) -> void`

- [ ] **Step 1: Failing check**

Run the game and eval:
```gdscript
var world = get_tree().current_scene
world.core.stored.add(&"scrap", 20)
var s = world.get_node("Units/BuildSlotWest")
s.build(load("res://data/towers/gearshot.tres"))
await get_tree().physics_frame
return [s.built.has_method(&"set_level"), s.built.definition.get(&"lv2_cost")]
```
Expected: `[false, null]`. Stop.

- [ ] **Step 2: Health.grow_max**

Add to `scripts/components/health.gd` after `reset`:
```gdscript
## Changes the maximum but keeps the same amount of missing health
## (an upgrade adds the new health on top). Does nothing when dead.
func grow_max(new_max: float) -> void:
	if is_dead:
		return
	current = maxf(current + new_max - max_health, 1.0)
	max_health = new_max
	changed.emit(current, max_health)
```

- [ ] **Step 3: Definition levels**

In `scripts/towers/tower_definition.gd`, add `const MAX_LEVEL := 3` under `extends Resource`, and add after the `@export_group("Stats")` block (before `Operated`):
```gdscript
@export_group("Levels")
## Stored resources spent to upgrade to Lv2 and to Lv3.
@export var lv2_cost: Dictionary[StringName, int] = {}
@export var lv3_cost: Dictionary[StringName, int] = {}
## Each level above 1 multiplies these stats again (compounding).
@export var level_damage_multiplier := 1.3
@export var level_fire_rate_multiplier := 1.15
@export var level_range_multiplier := 1.1
@export var level_health_multiplier := 1.4
```
Add helpers after `head_for`:
```gdscript
func upgrade_cost(to_level: int) -> Dictionary[StringName, int]:
	return lv2_cost if to_level == 2 else lv3_cost


func damage_at(tower_level: int) -> float:
	return attack_damage * pow(level_damage_multiplier, tower_level - 1)


func fire_rate_at(tower_level: int) -> float:
	return attacks_per_second * pow(level_fire_rate_multiplier, tower_level - 1)


func range_at(tower_level: int) -> float:
	return attack_range * pow(level_range_multiplier, tower_level - 1)


func max_health_at(tower_level: int) -> float:
	return max_health * pow(level_health_multiplier, tower_level - 1)
```
Update the class doc's second sentence to: `Sprites need lv1_idle and lv1_fire animations (and lv2_/lv3_ for levels) and must face right.`

- [ ] **Step 4: Tower uses the level**

In `scripts/towers/tower.gd`:
- `damage()`: `var value := definition.damage_at(level)`
- `fire_rate()`: `var value := definition.fire_rate_at(level)`
- `attack_range()`: `var value := definition.range_at(level)`
- `_ready`: `health.reset(definition.max_health_at(level))`
- add after `set_operator` (in the `# --- Operating ---` section, or a new `# --- Levels ---` section before it):
```gdscript
# --- Levels ---

## Switches to another level: stats, health (keeping the damage taken) and
## art. BuildSlot.upgrade() pays for it.
func set_level(new_level: int) -> void:
	level = clampi(new_level, 1, TowerDefinition.MAX_LEVEL)
	health.grow_max(definition.max_health_at(level))
	_head = definition.head_for(level)
	sprite.visible = true
	_setup_head()
	_show(&"idle")
	health_bar.place_above(sprite)
	queue_redraw()
```
`_setup_head()` already hides the frame sprite when a head exists and shows base/head only then. Confirm it sets `base_sprite.visible`/`head.visible` from `_has_head()` first (it does); `sprite.visible = true` above re-shows frames for a level without a head.

In `data/towers/gearshot.tres` `[resource]`, add after `cost`:
```
lv2_cost = Dictionary[StringName, int]({
&"scrap": 15
})
lv3_cost = Dictionary[StringName, int]({
&"aether": 3,
&"scrap": 25
})
```

- [ ] **Step 5: Verify**

Run the game and eval:
```gdscript
var world = get_tree().current_scene
world.core.stored.add(&"scrap", 20)
var s = world.get_node("Units/BuildSlotWest")
s.build(load("res://data/towers/gearshot.tres"))
await get_tree().physics_frame
var t = s.built
t.health.take_damage(50)
var out = [[t.level, t.damage(), snappedf(t.fire_rate(), 0.001), snappedf(t.attack_range(), 0.1), t.health.current, t.health.max_health]]
for l in [2, 3]:
	t.set_level(l)
	await get_tree().physics_frame
	out.append([t.level, snappedf(t.damage(), 0.01), snappedf(t.fire_rate(), 0.001), snappedf(t.attack_range(), 0.1), snappedf(t.health.current, 0.1), snappedf(t.health.max_health, 0.1), t.sprite.visible, t.head.visible, String(t.sprite.animation)])
return out
```
Expected:
- `[1, 8, 1.5, 260, 100, 150]`
- `[2, 10.4, 1.725, 286, 160, 210, true, false, "lv2_idle"]` (no Lv2 head yet, so frames show)
- `[3, 13.52, 1.984, 314.6, 244, 294, true, false, "lv3_idle"]`

Screenshot to confirm the Lv3 frame art shows at the tower. Stop.

- [ ] **Step 6: Commit**

```bash
git add scripts/components/health.gd scripts/towers/tower_definition.gd scripts/towers/tower.gd data/towers/gearshot.tres
git commit -m "Add tower levels: compounding stats, costs and set_level

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Gearshot Lv2/Lv3 rotating heads

**Files:**
- Modify: `tools/split_turret.py` (`TURRETS`)
- Create: `assets/sprites/towers/gearshot_lv2_base.png`, `gearshot_lv2_head.png`, `gearshot_lv3_base.png`, `gearshot_lv3_head.png`
- Modify: `data/towers/gearshot.tres` (two more `TurretHead`s)

**Interfaces:**
- Consumes: `TurretHead`, `TowerDefinition.heads` (Task 1); `Tower.set_level` (Task 2)

- [ ] **Step 1: Pick and measure the frames**

In the sliced sheet (`assets/sprites/gearshot.png`, 192×288 cells), rows are `lv1_idle, lv1_fire, lv1_destroyed, lv2_idle, lv2_fire, lv2_destroyed, lv3_idle, lv3_fire, lv3_destroyed`. So Lv2 idle is row 3 and Lv3 idle is row 6. Lv1 used column 2 (barrel pointing up at −111°). For each of rows 3 and 6, render the 4 idle frames at 3× with a 10 px grid to the scratchpad and pick the column whose barrels point most cleanly along one direction with the least overlap on the housing:
```bash
python3 - <<'EOF'
from PIL import Image, ImageDraw
im = Image.open('assets/sprites/gearshot.png')
for row in (3, 6):
    for col in range(4):
        f = im.crop((col*192, row*288, (col+1)*192, (row+1)*288)).resize((576, 864), Image.NEAREST)
        bg = Image.new('RGBA', f.size, (90, 160, 60, 255)); bg.alpha_composite(f)
        d = ImageDraw.Draw(bg)
        for x in range(0, 576, 30): d.line([(x, 0), (x, 864)], fill=(0, 0, 0, 60))
        for y in range(0, 864, 30): d.line([(0, y), (576, y)], fill=(0, 0, 0, 60))
        bg.save(f'<scratchpad>/gearshot_r{row}_c{col}.png')
EOF
```
Read the images. For the chosen frame, note in cell pixels (grid lines every 10 cell px):
- `pivot`: centre of the round housing the barrels turn on
- `radius`: housing radius
- `tip`: midpoint of the barrel ends
- `barrel_half_width`: half the width of all barrels together
- `base_extent`: half-width and half-height of the stone base around the pivot

Lv1 reference values: pivot (93, 205), radius 33, tip (70, 146), barrel_half_width 21, base_extent (60, 44).

- [ ] **Step 2: Add the entries and run**

Add to `TURRETS` in `tools/split_turret.py` (with the measured numbers):
```python
    "gearshot_lv2": dict(sheet="assets/sprites/gearshot.png", cell=(192, 288), frame=(3, <col>),
                         pivot=(<x>, <y>), radius=<r>, tip=(<x>, <y>), barrel_half_width=<w>,
                         base_extent=(<ex>, <ey>)),
    "gearshot_lv3": dict(sheet="assets/sprites/gearshot.png", cell=(192, 288), frame=(6, <col>),
                         pivot=(<x>, <y>), radius=<r>, tip=(<x>, <y>), barrel_half_width=<w>,
                         base_extent=(<ex>, <ey>)),
```
Run `python3 tools/split_turret.py`. It prints each head's drawn angle and length. Check that `gearshot_lv1_base.png`/`_head.png` are byte-identical to before (`git diff --stat assets/sprites/towers/` shows only the new files). View the 4 new PNGs on a green background: the head holds the whole housing and every barrel; the base has no leftover barrel pixels and no visible hole. Adjust the numbers and re-run until both look clean.

- [ ] **Step 3: Add the heads to the data**

In `data/towers/gearshot.tres`, add ext_resources for the 4 new textures (`6_base2`, `7_head2`, `8_base3`, `9_head3`), bump `load_steps` by 4, and add:
```
[sub_resource type="Resource" id="TurretHead_lv2"]
script = ExtResource("5_head")
base_texture = ExtResource("6_base2")
head_texture = ExtResource("7_head2")
pivot = Vector2(<pivot.x - 96>, <pivot.y - 282>)
drawn_angle = <printed angle>
barrel_length = <printed length>
```
and the same for `TurretHead_lv3`. Then set `heads = Array[ExtResource("5_head")]([SubResource("TurretHead_lv1"), SubResource("TurretHead_lv2"), SubResource("TurretHead_lv3")])`.
Run the import, then the headless check.

- [ ] **Step 4: Verify in game**

Run the game. Build a Gearshot on `BuildSlotWest`, put the hero in it (`world.hero.start_operating(t)`), and for each level 1, 2, 3 (`t.set_level(l)`): warp the mouse to 4 points around the tower (up-left, up-right, down-right, down-left of it), wait 20 frames each, and screenshot. Expected:
- the head turns to face each point
- no seam or hole at the base
- the muzzle flash (fire with auto_fire) sits on the barrel tips
- bolts leave from the tips

This also covers Review Focus #4: call `t.set_level(3)` while the hero is operating. The hero stays in (`world.hero.operating == t`), and aiming keeps working. Stop.

- [ ] **Step 5: Commit**

```bash
git add tools/split_turret.py assets/sprites/towers/ data/towers/gearshot.tres
git commit -m "Cut Gearshot Lv2 and Lv3 art into rotating heads

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Buying upgrades, refunds and wall levels

**Files:**
- Modify: `scripts/structures/wall.gd` (`restyle`)
- Modify: `scripts/towers/build_slot.gd` (upgrade, invested, wall levels)
- Modify: `scenes/towers/build_slot.tscn` (texture arrays)

**Interfaces:**
- Consumes: `Tower.set_level`, `TowerDefinition.upgrade_cost`, `MAX_LEVEL` (Task 2); `Health.grow_max`
- Produces: `BuildSlot.upgrade() -> bool`; `BuildSlot.wall_level: int`; `BuildSlot.invested: Dictionary[StringName, int]`; `BuildSlot.WALL_HEALTH: Array[float]`; `Wall.restyle(intact: Texture2D, damaged: Texture2D, new_max: float) -> void`

- [ ] **Step 1: Failing check**

Run the game and eval: `return world.get_node("Units/BuildSlotWest").has_method(&"upgrade")` (with the prelude). Expected: `false`. Stop.

- [ ] **Step 2: Wall.restyle**

Add to `scripts/structures/wall.gd` after `_ready`:
```gdscript
## Switches to another level's art and maximum health, keeping the damage
## taken (for a tower upgrade).
func restyle(intact: Texture2D, damaged: Texture2D, new_max: float) -> void:
	intact_texture = intact
	damaged_texture = damaged
	max_health = new_max
	sprite.offset = Vector2(0, -intact_texture.get_height() / 2.0)
	health.grow_max(new_max)
	_on_health_changed(health.current, health.max_health)
```

- [ ] **Step 3: BuildSlot**

In `scripts/towers/build_slot.gd`:

Class doc: change the "Built:" line to `## Built: Interact operates the tower; Manage (F) opens repair / upgrade / sell.` and add `## Upgrading a tower levels up its walls too (art and health).`

Add constants after `PANEL_WIDTH`:
```gdscript
## Wall piece health at wall level 1, 2, 3.
const WALL_HEALTH: Array[float] = [120.0, 180.0, 260.0]
```
Replace the `wall_texture` / `wall_damaged_texture` exports with:
```gdscript
## Wall art per wall level (index 0 = Lv1).
@export var wall_textures: Array[Texture2D] = []
@export var wall_damaged_textures: Array[Texture2D] = []
## Width of each level's left pillar, cut out as a post for up/down walls.
@export var wall_post_widths: PackedInt32Array = [52, 52, 48]
```
Add vars after `walls`:
```gdscript
## Level of this slot's walls; raised by tower upgrades, reset by selling.
var wall_level := 1
## Everything paid for the current tower (build + upgrades), for refunds.
var invested: Dictionary[StringName, int] = {}
```
In `build()`, after the spend succeeds (after `built = TOWER_SCENE.instantiate()` line block, before `_raise_walls()`), set `invested = tower.cost.duplicate()`.

Replace `sell_value()`:
```gdscript
func sell_value() -> Dictionary[StringName, int]:
	var value: Dictionary[StringName, int] = {}
	for type in invested:
		value[type] = floori(invested[type] * SELL_REFUND)
	return value
```
In `sell()`, after `_wall_plan.clear()` add `wall_level = 1`, and at the end `invested = {}`.

In `repair_cost()` replace `missing += Wall.DEFAULT_MAX_HEALTH` with `missing += WALL_HEALTH[wall_level - 1]`.

Add after `repair()`:
```gdscript
## Pays for the tower's next level and applies it, levelling up the walls
## with it. False if there's no tower, it's wrecked or maxed, or the Core
## can't afford it (nothing is spent then).
func upgrade() -> bool:
	if built == null or built.is_destroyed() or built.level >= TowerDefinition.MAX_LEVEL:
		return false
	var cost := built.definition.upgrade_cost(built.level + 1)
	if not core().stored.spend_all(cost):
		return false
	for type in cost:
		invested[type] = invested.get(type, 0) + cost[type]
	built.set_level(built.level + 1)
	if built.level > wall_level:
		wall_level = built.level
		for i in walls.size():
			if is_instance_valid(walls[i]):
				var textures := _wall_art(_wall_plan[i].post)
				walls[i].restyle(textures[0], textures[1], WALL_HEALTH[wall_level - 1])
	return true
```
In `_raise_walls()`, replace the texture lines and the `setup` calls so art and health come from `wall_level`:
```gdscript
	for i in _wall_plan.size():
		if is_instance_valid(walls[i]):
			continue
		var piece: Dictionary = _wall_plan[i]
		var wall: Wall = WALL_SCENE.instantiate()
		var textures := _wall_art(piece.post)
		var size := Vector2(20, 14) if piece.post else Vector2(piece.width, 14)
		wall.setup(textures[0], textures[1], size, wall_scale)
		wall.max_health = WALL_HEALTH[wall_level - 1]
		wall.position = piece.position
		get_parent().add_child(wall)
		walls[i] = wall
```
(remove the old `post_intact` / `post_damaged` locals). Add:
```gdscript
## [intact, damaged] art for a wall piece at the current wall level.
func _wall_art(post: bool) -> Array[Texture2D]:
	var intact := wall_textures[wall_level - 1]
	var damaged := wall_damaged_textures[wall_level - 1]
	if post:
		var width := wall_post_widths[wall_level - 1]
		return [_post_texture(intact, width), _post_texture(damaged, width)]
	return [intact, damaged]
```
and change `_post_texture` to take the width:
```gdscript
## The left pillar of a wall picture, used as a post.
func _post_texture(texture: Texture2D, width: int) -> Texture2D:
	var post := AtlasTexture.new()
	post.atlas = texture
	post.region = Rect2(0, 0, width, texture.get_height())
	return post
```
If `Wall.DEFAULT_MAX_HEALTH` is now unused anywhere (`grep -rn DEFAULT_MAX_HEALTH scripts`), leave it; `wall.gd` still uses it as its export default.

In `scenes/towers/build_slot.tscn`: add ext_resources for `wall_lv2.png`, `wall_lv3.png`, `wall_lv2_damaged.png`, `wall_lv3_damaged.png` (ids `12_wall2`, `13_wall3`, `14_wall2_damaged`, `15_wall3_damaged`), bump `load_steps` by 4, and replace the two wall lines with:
```
wall_textures = Array[Texture2D]([ExtResource("9_wall"), ExtResource("12_wall2"), ExtResource("13_wall3")])
wall_damaged_textures = Array[Texture2D]([ExtResource("10_wall_damaged"), ExtResource("14_wall2_damaged"), ExtResource("15_wall3_damaged")])
```
Check `scenes/world.tscn` doesn't override `wall_texture` on any slot (`grep -n wall_texture scenes/`). Expected: none.

- [ ] **Step 4: Verify**

Run the game and eval (all in one; keep waits short):
```gdscript
var world = get_tree().current_scene
var st = world.core.stored
st.take_all()
st.add(&"scrap", 100)
var s = world.get_node("Units/BuildSlotWest")
var g = load("res://data/towers/gearshot.tres")
s.build(g)
await get_tree().physics_frame
var t = s.built
var out = {}
# Review Focus 3: damage one wall below half before upgrading.
s.walls[0].health.take_damage(70)
st.take_all(); st.add(&"scrap", 14)
out.short_lv2 = [s.upgrade(), t.level, st.get_amount(&"scrap")]
st.add(&"scrap", 1)
out.lv2 = [s.upgrade(), t.level, st.get_amount(&"scrap"), s.wall_level, s.walls[1].health.max_health, s.walls[0].health.current, s.walls[0].sprite.texture == s.walls[0].damaged_texture]
st.add(&"scrap", 30)
out.no_aether = [s.upgrade(), t.level, st.get_amount(&"scrap")]
st.add(&"aether", 3)
out.lv3 = [s.upgrade(), t.level, st.get_amount(&"scrap"), st.get_amount(&"aether"), s.walls[1].health.max_health]
out.maxed = [s.upgrade(), t.level]
out.sell_value = s.sell_value()
# Repair rebuilds a destroyed piece at wall level 3.
s.walls[2].health.take_damage(9999)
await get_tree().physics_frame
out.repair_cost = s.repair_cost()
st.add(&"scrap", 50)
s.repair()
await get_tree().physics_frame
out.rebuilt = [s.walls[2].health.max_health, s.walls[2].intact_texture.resource_path if s.walls[2].intact_texture.resource_path != "" else s.walls[2].intact_texture.atlas.resource_path]
return out
```
Expected:
- `short_lv2`: `[false, 1, 14]`
- `lv2`: `[true, 2, 0, 2, 180, 110, false]`. Piece 0 had 50/120 left; `grow_max` makes it 110/180, above half, so it shows intact art.
- `no_aether`: `[false, 2, 30]`
- `lv3`: `[true, 3, 5, 0, 260]`
- `maxed`: `[false, 3]`
- `sell_value`: `{scrap: 25, aether: 1}` (invested 10 + 15 + 25 = 50 Scrap, 3 Aether)
- `repair_cost`: `ceil((260 + 70) / 25)` = 14 (the destroyed piece at Lv3 health plus piece 0's 70 missing)
- `rebuilt`: `[260, "res://assets/sprites/fortress/wall_lv3.png"]`

Review Focus 3 (same session, after the eval above): eval `var w = world.get_node("Units/BuildSlotWest").walls[3]; w.health.take_damage(150); return [w.sprite.texture == w.damaged_texture, w.damaged_texture.atlas.resource_path if w.damaged_texture is AtlasTexture else w.damaged_texture.resource_path]`. Expected: `[true, "res://assets/sprites/fortress/wall_lv3_damaged.png"]`.

Review Focus 1 and 5 (separate eval):
```gdscript
var world = get_tree().current_scene
var st = world.core.stored
var s = world.get_node("Units/BuildSlotEast")
var g = load("res://data/towers/gearshot.tres")
st.take_all(); st.add(&"scrap", 100); st.add(&"aether", 5)
s.build(g); s.upgrade(); s.upgrade()
await get_tree().physics_frame
s.built.health.take_damage(99999)
await get_tree().physics_frame
var before = st.get_amount(&"scrap")
var wreck_upgrade = s.upgrade()
s._clear_tower()
await get_tree().physics_frame
s.build(g)
await get_tree().physics_frame
return {wreck_upgrade = wreck_upgrade, scrap_unchanged = st.get_amount(&"scrap") == before - 10, wall_level = s.wall_level, sell_value = s.sell_value(), new_level = s.built.level}
```
Expected: `wreck_upgrade` false, `scrap_unchanged` true (only the new build's 10 was spent), `wall_level` 3, `sell_value` `{scrap: 5}`, `new_level` 1.

Screenshot a Lv3 slot with its walls to check the Lv3 wall art and that the posts show a clean pillar. Stop.

- [ ] **Step 5: Commit**

```bash
git add scripts/structures/wall.gd scripts/towers/build_slot.gd scenes/towers/build_slot.tscn
git commit -m "Buy tower upgrades from the slot; walls level up and refunds count upgrades

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Upgrade button, level title and preview

**Files:**
- Modify: `scenes/ui/tower_menu.tscn` (UpgradeButton)
- Modify: `scripts/ui/tower_menu.gd`
- Modify: `scripts/ui/hud.gd` (operating title)

**Interfaces:**
- Consumes: `BuildSlot.upgrade()`, `TowerDefinition.upgrade_cost`/`*_at`, `MAX_LEVEL`

- [ ] **Step 1: Failing check**

Run the game, build a Gearshot on `BuildSlotWest`, `s.manage(world.hero)`, and eval `return world.get_node("TowerMenu").find_child("UpgradeButton", true, false)`. Expected: `null`. Close the menu (`world.get_node("TowerMenu").close()`). Stop.

- [ ] **Step 2: Scene**

In `scenes/ui/tower_menu.tscn`, add between the RepairButton and SellButton blocks:
```
[node name="UpgradeButton" type="Button" parent="Center/Panel/Margin/Rows"]
unique_name_in_owner = true
custom_minimum_size = Vector2(0, 36)
layout_mode = 2
text = "Upgrade"
```

- [ ] **Step 3: Script**

In `scripts/ui/tower_menu.gd`:
- class doc: `## Pop-up for a built tower: repair it and its walls, upgrade it (walls too), or sell it (and its walls) for part of what was spent. Pauses the game while open. Esc or F closes.`
- `@onready var upgrade_button: Button = %UpgradeButton`
- `_ready`: `upgrade_button.pressed.connect(_on_upgrade)`
- in `_refresh()`:
  - title: `title.text = "%s — Lv%d" % [tower.definition.display_name, tower.level]`
  - after building `info.text`, append the preview when not maxed:
```gdscript
	var def := tower.definition
	var next := tower.level + 1
	if tower.level < TowerDefinition.MAX_LEVEL:
		info.text += "\nNext: damage %.0f → %.0f · %.1f → %.1f shots/s · range %.0f → %.0f · health %.0f → %.0f" % [
			def.damage_at(tower.level), def.damage_at(next),
			def.fire_rate_at(tower.level), def.fire_rate_at(next),
			def.range_at(tower.level), def.range_at(next),
			def.max_health_at(tower.level), def.max_health_at(next)]
		var cost := def.upgrade_cost(next)
		var missing := _slot.core().stored.shortfall(cost)
		upgrade_button.disabled = not missing.is_empty()
		upgrade_button.text = "Upgrade to Lv%d — %s" % [next, Loot.describe(cost)] if missing.is_empty() \
				else "Upgrade to Lv%d — need %s more" % [next, Loot.describe(missing)]
	else:
		upgrade_button.disabled = true
		upgrade_button.text = "Max level"
```
- add:
```gdscript
func _on_upgrade() -> void:
	_slot.upgrade()
	_refresh()
```
In `scripts/ui/hud.gd`: `operate_title.text = "Operating %s Lv%d" % [def.display_name, tower.level]`.

- [ ] **Step 4: Verify**

Run the game and eval:
```gdscript
var world = get_tree().current_scene
var st = world.core.stored
st.take_all(); st.add(&"scrap", 20)
var s = world.get_node("Units/BuildSlotWest")
s.build(load("res://data/towers/gearshot.tres"))
await get_tree().physics_frame
var m = world.get_node("TowerMenu")
s.manage(world.hero)
var b = m.find_child("UpgradeButton", true, false)
var out = {short = [m.title.text, b.text, b.disabled]}
st.add(&"scrap", 5)
m._refresh()
out.ok = [b.text, b.disabled, m.info.text.split("\n")[-1]]
b.pressed.emit()
out.after = [m.title.text, b.text, b.disabled]
return out
```
Expected:
- `short`: `["Gearshot Turret — Lv1", "Upgrade to Lv2 — need 5 Scrap more", true]` (20 − 10 build = 10 stored)
- `ok`: `["Upgrade to Lv2 — 15 Scrap", false, "Next: damage 8 → 10 · 1.5 → 1.7 shots/s · range 260 → 286 · health 150 → 210"]`
- `after`: `["Gearshot Turret — Lv2", "Upgrade to Lv3 — need 25 Scrap, 3 Aether more", true]`

Screenshot the open menu to check the layout fits. Close it, operate the tower (`world.hero.start_operating(s.built)`), and screenshot: the panel title reads `Operating Gearshot Turret Lv2`. Stop.

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/tower_menu.tscn scripts/ui/tower_menu.gd scripts/ui/hud.gd
git commit -m "Add the Upgrade button, level title and next-level preview

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Roadmap and wrap-up

**Files:**
- Modify: `ROADMAP.md`

- [ ] **Step 1: Update**

In Phase 8: tick `- [x] **[AI]** Tower levels 1 → 3 ...` and add after it: `Upgrade in the F menu: Lv2 15 Scrap, Lv3 25 Scrap + 3 Aether (Gearshot); ×1.3 damage, ×1.15 fire rate, ×1.1 range, ×1.4 health per level; walls level up too (120/180/260).` Change the order line's `2) levels` to `2) levels ✅`.

- [ ] **Step 2: Final check and commit**

Headless check: no errors. Then:
```bash
git add ROADMAP.md
git commit -m "Tick tower levels on the roadmap

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
