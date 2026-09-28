# Armored Goblin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Damage types (physical / fire / magic) with per-enemy resistance, an Armored Goblin that shrugs off bullets, a node-tree way to edit waves in Godot, and Mastery XP removed.

**Architecture:** `Health.take_damage(amount, type)` applies a per-type multiplier (`damage_taken`) that enemies fill in from their data; every attack passes its type. A tiny `ArmorSpark` shows blocked physical hits. Waves move from a nested `.tres` into a `WaveRun → Wave → SpawnGroup` node scene that converts itself to the existing `RunDefinition` data, so the `WaveDirector` logic is unchanged.

**Tech Stack:** Godot 4.7 GDScript; verification via Godot MCP in the running game.

**Spec:** `docs/superpowers/specs/2026-09-27-armored-goblin-design.md`

## Global Constraints

- Damage types: `Health.DamageType { PHYSICAL, FIRE, MAGIC }`. Physical: Gearshot bullets, hero bolts (both `Projectile`). Fire: Embercaster flame ticks, burn. Magic: Rune Mortar shells, Aether Spire strikes. Enemy attacks stay physical (default argument).
- `Health.take_damage(amount, type := PHYSICAL) -> float` returns the damage dealt (0 when dead / invulnerable / amount ≤ 0; never more than the health left) and emits `damaged(dealt, type, blocked)`.
- Armored Goblin: sprites `goblin_brute.tres`, scale 0.32; 60 health; speed 55; attack 8 at 0.8/s; attack range 20; aggro 140; hit frame 3 (calibrate); physical 0.3, fire 0.6, magic 1.0; drops 3–4 Scrap, 10% Aether.
- Waves: the existing five waves unchanged, plus armored goblin ×2 east (wave 3, delay 0), ×3 north (wave 4, delay 0), ×4 south (wave 5, delay 4), each every 2.5 s. Run settings unchanged (heaps 4 / max 8; Aether 1–2 per break, max 3, 2–4 each).
- Mastery XP removed everywhere (code, operate panel, F menu); no `mastery` left in `scripts/` or `scenes/`.
- Descriptions: Rune Mortar "Long-range lobbed rune shells that hit an area. Magic: great against armour and clusters." Aether Spire "Lightning that jumps between enemies. Magic: great against armour and spread-out groups."
- Gearshot, Mortar, Embercaster and Spire deal exactly what they did before to normal goblins; enemy attacks deal the same as before.
- Branch `phase9-armored-goblin`; one commit per task (`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`); stage only the task's files. New `class_name` → `godot --headless --editor --path . --import` before checks. `git checkout project.godot` after MCP runs.
- MCP gotchas: first `game_eval` after `run_project` says "Not connected" (retry); a script error in an eval freezes the game in a Debugger Break (check `get_debug_output`, restart); `ResourceBag.add_all` needs `var d: Dictionary[StringName, int] = {...}`; never `queue_free` living enemies or disable the WaveDirector (kill with `health.take_damage(999999)`); frozen goblins (`set_physics_process(false)`) also freeze burn/stun; move the hero away (it shoots goblins within 500 px); timing checks inside one `game_eval`.

## Review Focus

1. **A hit that kills**: `take_damage` returns at most the health that was left (overkill isn't counted), and sparks/`damaged` still fire once, with no errors after death (Task 2 test).
2. **Invulnerable or dead targets** (the hero while operating, corpses): `take_damage` returns 0, emits nothing, and resistance doesn't matter (Task 2 test).
3. **A SpawnGroup left with no enemy, or a group parked under a plain Node**: skipped with a warning, the rest of the wave still spawns, no crash (Task 4 test).
4. **Many physical hits on armour at once** (Gearshot + hero on one Armored Goblin): each hit makes its own short spark, all sparks free themselves, no pile-up (Task 3 test).
5. **Wave count and warnings after the switch**: the HUD shows "Wave 1 / 5", and the sector warnings for the upcoming wave still point the right way (Task 4 test).

---

### Task 1: Remove Mastery XP

**Files:** Modify `scripts/towers/tower.gd`, `scripts/towers/mortar_tower.gd`, `scripts/towers/ember_tower.gd`, `scripts/towers/spire_tower.gd`, `scripts/ui/hud.gd`, `scenes/ui/hud.tscn`, `scripts/ui/tower_menu.gd`.

**Interfaces:** Produces nothing new. Removes `Tower.mastery_xp`.

- [ ] **Step 1: Failing check.** Create the branch (`git checkout -b phase9-armored-goblin`). Run `grep -rn -i mastery scripts scenes`. Expected: 12 matches (the list in Step 2).
- [ ] **Step 2: Remove it.**
  - `tower.gd`:
    - Class comment: "damage, fire rate and range, can use its ability, and earns Mastery XP." → "damage, fire rate and range, and can use its ability."
    - Delete the `## Earned from damage dealt…` line and `var mastery_xp := 0.0`.
    - In `_fire_at`, delete the two lines `if operator:` / `bolt.hit.connect(… mastery_xp += dealt)`.
  - `mortar_tower.gd`: delete `if operator:` / `shell.hit.connect(… mastery_xp += dealt)`.
  - `ember_tower.gd` `_fire_at`: the loop body becomes:
```gdscript
	for enemy in _enemies_in_cone(point):
		enemy.health.take_damage(damage())
		enemy.add_burn(burn_dps(), ember.burn_max_stacks, ember.burn_duration, stacks)
```
  - `spire_tower.gd` `_strike`: the loop body becomes:
```gdscript
	for enemy in chain:
		points.append(_aim_point(enemy))
		enemy.health.take_damage(hit_damage)
		if stun > 0.0:
			enemy.stun(stun)
		hit_damage *= 1.0 - falloff
```
  - `hud.gd`: delete `@onready var mastery_text: Label = %MasteryText` and the `mastery_text.text = …` line.
  - `hud.tscn`: delete the whole `[node name="MasteryText" …]` block (7 lines, through `horizontal_alignment = 1`).
  - `tower_menu.gd`: the info line becomes:
```gdscript
	info.text = "Tower %d / %d health\nWalls: %d standing (%d damaged), %d destroyed" % [
		ceili(tower.health.current), ceili(tower.health.max_health),
		standing, damaged, lost]
```
- [ ] **Step 3: Verify.**
  - `grep -rn -i mastery scripts scenes` → no matches.
  - `validate_scripts` (scope changed) → all valid.
  - Run the game:
    - Build a Gearshot, Mortar, Embercaster and Spire (unlock the slots and add Scrap/Aether first).
    - Operate each in turn with a frozen goblin in range, and fire for 60 frames.
    - The operate panel has no Mastery line: `%MasteryText` is gone, and `HUD.find_child("MasteryText")` is null.
    - The F menu info text starts with "Tower ".
    - No new errors.
  - Screenshot the operate panel.
  - `git checkout project.godot`.
- [ ] **Step 4: Commit** `Remove Mastery XP`.

---

### Task 2: Damage types

**Files:** Modify `scripts/components/health.gd`, `scripts/projectiles/projectile.gd`, `scripts/projectiles/shell.gd`, `scripts/towers/ember_tower.gd`, `scripts/towers/spire_tower.gd`, `scripts/enemies/enemy.gd`, `scripts/enemies/enemy_definition.gd`.

**Interfaces:**
- Produces: `Health.DamageType` (enum `PHYSICAL`, `FIRE`, `MAGIC`); `Health.damage_taken: PackedFloat32Array` (index = type); `Health.take_damage(amount: float, type := DamageType.PHYSICAL) -> float`; `signal Health.damaged(dealt: float, type: int, blocked: float)`; `Projectile.damage_type`; `EnemyDefinition.physical_taken / fire_taken / magic_taken: float`.

- [ ] **Step 1: Baseline + failing check.** Run the game.
  - Record against normal frozen 1000-health goblins:
    - A Gearshot bullet: 8.
    - A hero bolt: 10. Fire `world.hero` at a goblin 150 px away; `hero.auto_fire = true` for 60 frames, then count the damage per hit.
    - A Mortar shell (`t._fire_at(point)`, wait 60 frames): 14.
    - An Embercaster tick (`t._fire_at`): 3.
    - Burn for 1 s at 1 stack: ≈2.
    - A Spire chain: 10 / 8.
  - Record a goblin's hit on the Core: 5.
  - Eval `Health.new().has_signal(&"damaged")` → `false`.
- [ ] **Step 2: Health** `scripts/components/health.gd`. Add after `signal died`:
```gdscript
## Emitted whenever damage is applied: what got through, its type, and the
## part the target's resistance blocked.
signal damaged(dealt: float, type: int, blocked: float)

## What kind of harm a hit does. Enemies can resist some kinds.
enum DamageType { PHYSICAL, FIRE, MAGIC }
```
After `var invulnerable := false`:
```gdscript
## Share of each DamageType's damage that gets through (1 = all of it),
## indexed by DamageType.
var damage_taken := PackedFloat32Array([1.0, 1.0, 1.0])
```
Replace `take_damage` with:
```gdscript
## Applies damage of `type`, reduced by damage_taken, and returns how much
## health it actually took (0 if it was ignored).
func take_damage(amount: float, type := DamageType.PHYSICAL) -> float:
	if is_dead or invulnerable or amount <= 0.0:
		return 0.0
	var scaled := amount * damage_taken[type]
	var dealt := minf(scaled, current)
	current = maxf(current - scaled, 0.0)
	changed.emit(current, max_health)
	damaged.emit(dealt, type, amount - scaled)
	if is_dead:
		died.emit()
	return dealt
```
- [ ] **Step 3: Enemy data.** `enemy_definition.gd`, add a group after `attack_hit_frame`:
```gdscript
@export_group("Armour")
## Share of each kind of damage that gets through (1 = all, 0.3 = 30%).
@export var physical_taken := 1.0
@export var fire_taken := 1.0
@export var magic_taken := 1.0
```
`enemy.gd` `_ready()`, after `health.reset(definition.max_health)`:
```gdscript
	health.damage_taken = PackedFloat32Array([
			definition.physical_taken, definition.fire_taken, definition.magic_taken])
```
- [ ] **Step 4: Attack types.**
  - `projectile.gd`:
    - After `var max_distance := 500.0`, add:
```gdscript
## Gearshot bullets and hero bolts are physical.
var damage_type := Health.DamageType.PHYSICAL
```
    - Replace `health.take_damage(damage)` / `hit.emit(damage, health.is_dead)` with:
```gdscript
	var dealt := health.take_damage(damage, damage_type)
	hit.emit(dealt, health.is_dead)
```
  - `shell.gd` `_land()`: replace the two lines with:
```gdscript
		var dealt := enemy.health.take_damage(damage, Health.DamageType.MAGIC)
		hit.emit(dealt, enemy.health.is_dead)
```
  - `ember_tower.gd` `_fire_at`: `enemy.health.take_damage(damage(), Health.DamageType.FIRE)`.
  - `enemy.gd` `_tick_burn`: `health.take_damage(_burn_stacks * _burn_dps * minf(delta, _burn_left), Health.DamageType.FIRE)`.
  - `spire_tower.gd` `_strike`: `enemy.health.take_damage(hit_damage, Health.DamageType.MAGIC)`.
- [ ] **Step 5: Verify.** `validate_scripts` (changed), then run the game and eval:
  - **Baseline** (Step 1 again): identical numbers against normal goblins, and the Core takes 5 per goblin hit.
  - **Resistance by type:** set a frozen goblin's `health.damage_taken = PackedFloat32Array([0.3, 0.6, 1.0])`:
    - Gearshot bullet → 2.4
    - Hero bolt → 3
    - Mortar shell → 14
    - Embercaster tick → 1.8
    - Burn for 1 s at 1 stack → ≈1.2
    - Spire → 10 then 8 (a second goblin with the same resistances)
  - **Return value and signal:** on a 5-health goblin, `take_damage(8)` returns 5, and `damaged` fires once with `dealt 5, blocked 0`. Physical `take_damage(10)` on a 0.3 goblin returns 3 with `blocked 7`.
  - **Review Focus 1 and 2:**
    - `take_damage` on a dead goblin returns 0 and emits nothing (count `damaged` emissions with a connected lambda).
    - With the hero operating a tower (`hero.health.invulnerable == true`), `hero.health.take_damage(10)` returns 0.
  - No new errors. `git checkout project.godot`.
- [ ] **Step 6: Commit** `Add damage types: physical, fire and magic`.

---

### Task 3: Armour spark and the Armored Goblin

**Files:** Create `scripts/effects/armor_spark.gd`, `data/enemies/armored_goblin.tres`. Modify `scripts/enemies/enemy.gd`.

**Interfaces:**
- Consumes: `Health.damaged`, `Health.DamageType` (Task 2); `EnemyDefinition.*_taken` (Task 2).
- Produces: `class_name ArmorSpark`; `res://data/enemies/armored_goblin.tres`.

- [ ] **Step 1: Failing check.** Run the game and eval `ResourceLoader.exists("res://data/enemies/armored_goblin.tres")`. Expected: `false`.
- [ ] **Step 2: ArmorSpark** `scripts/effects/armor_spark.gd`:
```gdscript
class_name ArmorSpark
extends Node2D
## A quick burst of grey-white sparks where armour turned a hit aside.
## Frees itself.

const LIFE := 0.15
const RAYS := 6

var _left := LIFE
var _angles := PackedFloat32Array()


func _ready() -> void:
	z_index = 1
	for i in RAYS:
		_angles.append(randf() * TAU)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := 1.0 - _left / LIFE
	var colour := Color(0.92, 0.94, 1.0, _left / LIFE)
	for angle in _angles:
		var direction := Vector2.from_angle(angle)
		draw_line(direction * (3.0 + 10.0 * t), direction * (7.0 + 14.0 * t), colour, 2.0)
```
`enemy.gd` `_ready()`, after the `health.damage_taken = …` line:
```gdscript
	health.damaged.connect(_on_damaged)
```
Add after `_update_tint()`:
```gdscript
## A physical hit that armour partly blocked throws sparks.
func _on_damaged(_dealt: float, type: int, blocked: float) -> void:
	if type != Health.DamageType.PHYSICAL or blocked <= 0.0:
		return
	var spark := ArmorSpark.new()
	get_parent().add_child(spark)
	spark.global_position = hurtbox_shape.global_position
```
- [ ] **Step 3: Armored Goblin** `data/enemies/armored_goblin.tres`:
```
[gd_resource type="Resource" script_class="EnemyDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/enemies/enemy_definition.gd" id="1_def"]
[ext_resource type="SpriteFrames" path="res://assets/sprites/goblin_brute.tres" id="2_frames"]

[resource]
script = ExtResource("1_def")
id = &"armored_goblin"
display_name = "Armored Goblin"
sprite_frames = ExtResource("2_frames")
sprite_scale = 0.32
max_health = 60.0
move_speed = 55.0
attack_damage = 8.0
attacks_per_second = 0.8
attack_range = 20.0
aggro_range = 140.0
attack_hit_frame = 3
physical_taken = 0.3
fire_taken = 0.6
magic_taken = 1.0
drops = Dictionary[StringName, Vector2i]({
&"scrap": Vector2i(3, 4)
})
rare_drops = Dictionary[StringName, float]({
&"aether": 0.1
})
```
- [ ] **Step 4: Verify.** Import, `validate_scripts`, then run the game and eval:
  - **Stats:** spawn one (`waves.spawn_at(load(".../armored_goblin.tres"), …)`): max health 60, `health.damage_taken == [0.3, 0.6, 1.0]`, and its walk speed ≈55 px/s over 60 frames (unslowed).
  - **Attack:** placed next to the Core, it takes 8 off the Core per swing, and the hit lands on the swing frame. Screenshot mid-swing. If the damage lands before or after the cleaver swing, change `attack_hit_frame` to the frame that shows the swing's arc.
  - **Loot:** killed 10 times (`health.take_damage(999999)`), each drop is 3–4 Scrap. Count Scrap pickups spawned per death via the `Loot` children added to `Units`.
  - **Sparks:**
    - A Gearshot shooting a frozen Armored Goblin creates an `ArmorSpark` in `Units` per hit, each gone within 15 frames.
    - A Gearshot on a normal goblin makes none.
    - A Spire chain or a Mortar shell on the Armored Goblin makes none.
  - **Review Focus 4:** a Gearshot and the hero (auto-fire) both shooting one Armored Goblin for 120 frames: the number of `ArmorSpark` nodes alive at once never goes above 4, and all are gone 15 frames after firing stops.
  - **Screenshots:**
    - An Armored Goblin beside a basic goblin, for size and look.
    - A spark on a Gearshot hit.
    - A Spire chain through two Armored Goblins.
  - `git checkout project.godot`.
- [ ] **Step 5: Commit** `Add the Armored Goblin and armour sparks`.

---

### Task 4: Waves as a node tree

**Files:** Create `scripts/waves/wave_run.gd`, `scripts/waves/wave.gd`, `scripts/waves/spawn_group.gd`, `scenes/waves/first_run.tscn`. Modify `scripts/waves/wave_director.gd`, `scenes/world.tscn`. Delete `data/waves/first_playtest.tres`.

**Interfaces:**
- Consumes: `data/enemies/armored_goblin.tres` (Task 3); existing `RunDefinition`, `WaveDefinition`, `WaveGroup`.
- Produces: `class_name WaveRun` (`to_definition() -> RunDefinition`), `class_name Wave` (`prep_time`, `to_definition() -> WaveDefinition`), `class_name SpawnGroup` (`enemy`, `count`, `sector`, `interval`, `delay`, `to_definition() -> WaveGroup` or null); `WaveDirector.waves_scene: PackedScene`; `WaveDirector.run` is now a plain var.

- [ ] **Step 1: Record the current waves + failing check.** Run the game and eval a signature of the current run:
```gdscript
var run = get_tree().current_scene.get_node("WaveDirector").run
var sig = []
for w in run.waves:
	sig.append([w.prep_time, w.groups.map(func(g): return [g.enemy.id, g.count, g.sector, g.interval, g.delay])])
return [sig, run.heaps_per_break, run.max_heaps, run.aether_per_break, run.max_aether, run.aether_amount]
```
Save the output to the ledger. Also eval `"waves_scene" in get_tree().current_scene.get_node("WaveDirector")` → `false`.
- [ ] **Step 2: Node scripts.**

`scripts/waves/spawn_group.gd`:
```gdscript
class_name SpawnGroup
extends Node
## One batch of enemies in a Wave (see WaveRun): what, how many, from which
## side, and how quickly they arrive.

@export var enemy: EnemyDefinition
@export var count := 5
## Which map edge they come from.
@export_enum("north", "east", "south", "west") var sector := "west"
## Seconds between spawns in this group.
@export var interval := 1.5
## Seconds after the wave starts before this group begins.
@export var delay := 0.0


## This group as wave data, or null (with a warning) if no enemy is set.
func to_definition() -> WaveGroup:
	if enemy == null:
		push_warning("Waves: %s/%s has no enemy set, so it's skipped" % [get_parent().name, name])
		return null
	var group := WaveGroup.new()
	group.enemy = enemy
	group.count = count
	group.sector = sector
	group.interval = interval
	group.delay = delay
	return group
```
`scripts/waves/wave.gd`:
```gdscript
class_name Wave
extends Node
## One wave in a WaveRun scene: a break of prep_time seconds, then its
## SpawnGroup children arrive. Groups parked under any other kind of node
## are ignored.

## Seconds of calm before this wave starts (shown as a countdown).
@export var prep_time := 30.0


func to_definition() -> WaveDefinition:
	var wave := WaveDefinition.new()
	wave.prep_time = prep_time
	for child in get_children():
		if child is SpawnGroup:
			var group := (child as SpawnGroup).to_definition()
			if group:
				wave.groups.append(group)
	return wave
```
`scripts/waves/wave_run.gd`:
```gdscript
class_name WaveRun
extends Node
## The root of a waves scene (scenes/waves/): its Wave children, top to
## bottom, are the run's waves. Edit them in the scene tree: duplicate a
## wave or group with Ctrl+D, drag to reorder, pick enemies and sides in the
## inspector. The WaveDirector reads this when the game starts.

## Scrap heaps scattered around the map at the start of each break.
@export var heaps_per_break := 4
## Never more than this many Scrap heaps on the map at once.
@export var max_heaps := 8
## Aether crystals added each break: a random count from x to y.
@export var aether_per_break := Vector2i(1, 2)
## Never more than this many Aether crystals on the map at once.
@export var max_aether := 3
## Aether in each crystal: a random amount from x to y.
@export var aether_amount := Vector2i(2, 4)


func to_definition() -> RunDefinition:
	var run := RunDefinition.new()
	run.heaps_per_break = heaps_per_break
	run.max_heaps = max_heaps
	run.aether_per_break = aether_per_break
	run.max_aether = max_aether
	run.aether_amount = aether_amount
	for child in get_children():
		if child is Wave:
			run.waves.append((child as Wave).to_definition())
	return run
```
- [ ] **Step 3: The scene** `scenes/waves/first_run.tscn`:
```
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/waves/wave_run.gd" id="1_run"]
[ext_resource type="Script" path="res://scripts/waves/wave.gd" id="2_wave"]
[ext_resource type="Script" path="res://scripts/waves/spawn_group.gd" id="3_group"]
[ext_resource type="Resource" path="res://data/enemies/goblin.tres" id="4_goblin"]
[ext_resource type="Resource" path="res://data/enemies/armored_goblin.tres" id="5_armored"]

[node name="FirstRun" type="Node"]
script = ExtResource("1_run")

[node name="Wave1" type="Node" parent="."]
script = ExtResource("2_wave")
prep_time = 45.0

[node name="GoblinsWest" type="Node" parent="Wave1"]
script = ExtResource("3_group")
enemy = ExtResource("4_goblin")
count = 6
sector = "west"
interval = 2.0

[node name="Wave2" type="Node" parent="."]
script = ExtResource("2_wave")
prep_time = 30.0

[node name="GoblinsWest" type="Node" parent="Wave2"]
script = ExtResource("3_group")
enemy = ExtResource("4_goblin")
count = 5
sector = "west"
interval = 1.8

[node name="GoblinsNorth" type="Node" parent="Wave2"]
script = ExtResource("3_group")
enemy = ExtResource("4_goblin")
count = 5
sector = "north"
interval = 1.8
delay = 4.0

[node name="Wave3" type="Node" parent="."]
script = ExtResource("2_wave")
prep_time = 30.0

[node name="GoblinsEast" type="Node" parent="Wave3"]
script = ExtResource("3_group")
enemy = ExtResource("4_goblin")
count = 7
sector = "east"
interval = 1.5

[node name="GoblinsSouth" type="Node" parent="Wave3"]
script = ExtResource("3_group")
enemy = ExtResource("4_goblin")
count = 7
sector = "south"
interval = 1.5
delay = 3.0

[node name="ArmoredEast" type="Node" parent="Wave3"]
script = ExtResource("3_group")
enemy = ExtResource("5_armored")
count = 2
sector = "east"
interval = 2.5

[node name="Wave4" type="Node" parent="."]
script = ExtResource("2_wave")
prep_time = 30.0

[node name="GoblinsNorth" type="Node" parent="Wave4"]
script = ExtResource("3_group")
enemy = ExtResource("4_goblin")
count = 6
sector = "north"
interval = 1.4

[node name="GoblinsWest" type="Node" parent="Wave4"]
script = ExtResource("3_group")
enemy = ExtResource("4_goblin")
count = 6
sector = "west"
interval = 1.4
delay = 2.0

[node name="GoblinsSouth" type="Node" parent="Wave4"]
script = ExtResource("3_group")
enemy = ExtResource("4_goblin")
count = 6
sector = "south"
interval = 1.4
delay = 4.0

[node name="ArmoredNorth" type="Node" parent="Wave4"]
script = ExtResource("3_group")
enemy = ExtResource("5_armored")
count = 3
sector = "north"
interval = 2.5

[node name="Wave5" type="Node" parent="."]
script = ExtResource("2_wave")
prep_time = 35.0

[node name="GoblinsNorth" type="Node" parent="Wave5"]
script = ExtResource("3_group")
enemy = ExtResource("4_goblin")
count = 7
sector = "north"
interval = 1.2

[node name="GoblinsEast" type="Node" parent="Wave5"]
script = ExtResource("3_group")
enemy = ExtResource("4_goblin")
count = 7
sector = "east"
interval = 1.2
delay = 2.0

[node name="GoblinsSouth" type="Node" parent="Wave5"]
script = ExtResource("3_group")
enemy = ExtResource("4_goblin")
count = 7
sector = "south"
interval = 1.2
delay = 4.0

[node name="GoblinsWest" type="Node" parent="Wave5"]
script = ExtResource("3_group")
enemy = ExtResource("4_goblin")
count = 7
sector = "west"
interval = 1.2
delay = 6.0

[node name="ArmoredSouth" type="Node" parent="Wave5"]
script = ExtResource("3_group")
enemy = ExtResource("5_armored")
count = 4
sector = "south"
interval = 2.5
delay = 4.0
```
Before writing it, compare every goblin group against the Step 1 signature. If any value differs from this listing, the signature wins; ledger a ruling.
- [ ] **Step 4: WaveDirector + world.**
  - `wave_director.gd`: replace `@export var run: RunDefinition` with:
```gdscript
## The run's waves, edited as a node tree (a WaveRun scene in scenes/waves/).
## Read once when the director is ready.
@export var waves_scene: PackedScene

## Built from waves_scene.
var run: RunDefinition
```
    and add (merging into an existing `_ready` if there is one):
```gdscript
func _ready() -> void:
	var tree := waves_scene.instantiate() as WaveRun
	assert(tree != null, "WaveDirector.waves_scene must be a WaveRun scene")
	run = tree.to_definition()
	tree.free()
```
    Update the class comment's first line: "Runs the waves in a RunDefinition" → "Runs the waves from waves_scene".
  - `world.tscn`:
    - Replace the ext_resource line for `first_playtest.tres` with `[ext_resource type="PackedScene" path="res://scenes/waves/first_run.tscn" id="6_waves"]`.
    - In the WaveDirector node, replace `run = ExtResource("6_run")` with `waves_scene = ExtResource("6_waves")`.
  - `git rm data/waves/first_playtest.tres`.
- [ ] **Step 5: Verify.** Import, `validate_scripts`, then run the game and eval:
  - **Same waves:** the Step 1 signature eval now matches the saved one exactly, with the three armored groups added (wave 3: `[armored_goblin, 2, east, 2.5, 0]`; wave 4: `[…, 3, north, 2.5, 0]`; wave 5: `[…, 4, south, 2.5, 4]`). Run settings are identical.
  - **HUD (Review Focus 5):** `HUD.wave_title.text == "Wave 1 / 5"`. During the first break, `waves.threatened_sectors() == [&"west"]`. Screenshot the sector warning.
  - **Wave 3 in play:** set `waves.wave_index = 2` and `start_wave_now()`, wait until 16 enemies have spawned, and check that 2 of them are Armored Goblins from the east. Kill all with `take_damage(999999)`, and `wave_cleared(3)` fires.
  - **Editing:**
    - Instantiate `first_run.tscn` in an eval.
    - Duplicate `Wave1/GoblinsWest` with `count = 3` into Wave1, add a `SpawnGroup` with no enemy, and add a plain `Node` holding a `SpawnGroup` with an enemy.
    - `to_definition()` gives Wave1 exactly 2 groups (6 and 3).
    - The warning "Waves: Wave1/… has no enemy set" appears in `game_get_errors`, and nothing crashes (Review Focus 3).
    - Free the tree afterwards.
  - No new errors. `git checkout project.godot`.
- [ ] **Step 6: Commit** `Edit waves as a node tree`, staging:
  - `scripts/waves/wave_run.gd*`, `wave.gd*`, `spawn_group.gd*`
  - `scenes/waves/first_run.tscn`
  - `scripts/waves/wave_director.gd`
  - `scenes/world.tscn`
  - the deletion of `data/waves/first_playtest.tres`

---

### Task 5: Descriptions and roadmap

**Files:** Modify `data/towers/rune_mortar.tres`, `data/towers/aether_spire.tres`, `ROADMAP.md`.

- [ ] **Step 1: Descriptions.** Set the two `description =` lines to the Global Constraints text. Check that both show in the build menu: eval `load(...).description`.
- [ ] **Step 2: Roadmap.**
  - Phase 9: tick `Armored Goblin (resists bullets → need magic)` with the summary "(`goblin_brute` art): takes 30% physical / 60% fire / 100% magic; 60 health, speed 55, 8 per swing; 3–4 Scrap + 10% Aether; waves 3–5. Damage types: Gearshot + hero = physical, Embercaster = fire, Mortar + Spire = magic. Waves are now edited as a node tree in `scenes/waves/first_run.tscn`."
  - Line "Tower earns Mastery XP (1 XP per damage dealt while you operate it)" becomes `- [x] ~~**[AI]** Tower earns Mastery XP (1 XP per damage dealt while you operate it)~~ (removed 2026-09-27: replaced by player XP)`.
  - Delete `- [ ] **[You]** Decide: is Mastery per-tower or per-tower-type?`.
  - Phase 10:
    - Replace the two items "Specialized roguelite hero upgrades, picked during a run: …" and "Upgrade choices after waves (pick 1 of 3) — …" with one item: `- [ ] **[AI]** Power-up cards: after waves, pick 1 of 3 cards that make you stronger for the run (chain-lightning shots, flamethrower, and similar)`.
    - Add `- [ ] **[AI]** Player XP earned during a run — **[You]** decide how it's earned (kills, damage, waves survived)`.
    - Append to "One evolution per tower (…)": ` — needs a new unlock now Mastery is gone (e.g. a card or Aether)`.
  - Art table: the `goblin_brute` row's name cell becomes `` `goblin_brute` — **Armored Goblin** (brown goblin with cleaver) ``.
- [ ] **Step 3: Commit** `Tick the Armored Goblin on the roadmap` (stage `data/towers/rune_mortar.tres`, `data/towers/aether_spire.tres`, `ROADMAP.md`).
