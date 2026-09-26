# Embercaster Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A buildable Embercaster: a short flame cone fed by a fuel tank that sets goblins burning (stacking), aimed at the thickest group automatically or at the mouse when operated, with an Overpressure ability.

**Architecture:** Same pattern as the Rune Mortar. `EmberDefinition extends TowerDefinition` holds the flame, fuel, burn and Overpressure settings. `EmberTower extends Tower` reuses the base firing loop, where one "shot" is one flame tick, and overrides targeting, aiming, firing, range and drawing. Base `Tower` gains a `_can_fire()` hook (for the fuel lockout) and a fallback for sheets whose wreck animation is a single `destroyed`. `Enemy.add_burn()` adds the stacking damage-over-time.

**Tech Stack:** Godot 4.7 GDScript; verification via Godot MCP in the running game.

**Spec:** `docs/superpowers/specs/2026-09-26-embercaster-design.md`

## Global Constraints

- Embercaster Lv1: cost 12 Scrap; lv2 18 Scrap; lv3 28 Scrap + 3 Aether; flame tick 3 damage; 5 ticks/s; range 150 (measured from the muzzle); cone 50° total; health 180; sprite_scale 0.55.
- Burn: 2 damage/s per stack, max 5 stacks, all stacks gone 3 s after the last one was added. Burn per stack scales exactly like the flame tick (`damage() / attack_damage`).
- Fuel: 4 s of spraying when full; 3 s to refill from empty while not spraying; after running dry, no spraying until fuel ≥ 40%.
- Operated: damage ×1.35, range ×1.15, fire rate ×1.0. Mastery XP = direct flame damage dealt while operated (not burn).
- Overpressure: duration 3 s, cooldown 15 s; no fuel used; cone angle ×1.5; range ×1.3; each tick sets goblins in the cone to 5 stacks; **`ability_fire_rate_multiplier = 1.0`** (the default is 3.0, which would triple the tick rate).
- The Gearshot and Rune Mortar must behave exactly as before.
- Branch `phase8-embercaster`; one commit per task (`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`). Stage only the task's files (`main` has unrelated uncommitted editor re-saves; leave them alone). New `class_name` → `godot --headless --editor --path . --import` before the headless check. `git checkout project.godot` after MCP runs. Never `queue_free` living enemies during a wave in tests; kill them with `health.take_damage(99999)`. Do timing checks inside one `game_eval`.

## Review Focus

1. **A burning goblin dies from burn (or from something else) mid-burn**: no errors, its tint goes back to white, and a later `add_burn` on the corpse does nothing (Task 1 test).
2. **Embercaster destroyed while spraying**: the sheet has only a single `destroyed` animation (no `lvN_destroyed`). It must show the wreck with no errors and stop the embers and the drawn flame (Task 2 test).
3. **Aim point on or behind the muzzle** (mouse on the tower, goblin hugging the base): there's no NaN or zero-vector cone, and the tower doesn't hit everything in range (Task 3 test).
4. **Fuel lockout edges**: running dry mid-Overpressure isn't possible (no drain), and when Overpressure ends with a low tank, the lockout rules apply from that moment on (Task 3 test).
5. **Two Embercasters on one goblin**: stacks cap at 5, and the stronger per-stack damage wins (Task 1 test, by calling `add_burn` twice with different values).

---

### Task 1: Enemy burn

**Files:** Modify `scripts/enemies/enemy.gd`.

**Interfaces (produced):**
- `Enemy.add_burn(dps_per_stack: float, max_stacks: int, seconds: float, stacks := 1) -> void`
- `Enemy.burn_stacks() -> int`

- [ ] **Step 1: Failing check.** Run the game (`run_project`, then retry the first `game_eval` once if it says "Not connected"). Spawn a goblin: `var g = waves.spawn_at(load("res://data/enemies/goblin.tres"), core.global_position + Vector2(-700, 0))`. Eval `g.has_method(&"add_burn")`. Expected: `false`.
- [ ] **Step 2: Burn state.** In `enemy.gd`, under the slow vars:
```gdscript
## Burn: each stack deals _burn_dps per second until _burn_left runs out.
var _burn_stacks := 0
var _burn_dps := 0.0
var _burn_left := 0.0
```
In `_physics_process`, right after `if health.is_dead: return`:
```gdscript
	if _burn_stacks > 0:
		_tick_burn(delta)
		if health.is_dead:
			return
```
After `speed_multiplier()`:
```gdscript
## Sets it burning: adds `stacks` (capped at max_stacks), each dealing
## dps_per_stack per second, and restarts the timer. When sources differ, the
## strongest damage per stack wins.
func add_burn(dps_per_stack: float, max_stacks: int, seconds: float, stacks := 1) -> void:
	if health.is_dead:
		return
	_burn_dps = maxf(_burn_dps, dps_per_stack) if _burn_stacks > 0 else dps_per_stack
	_burn_stacks = mini(_burn_stacks + stacks, max_stacks)
	_burn_left = seconds


func burn_stacks() -> int:
	return _burn_stacks


func _tick_burn(delta: float) -> void:
	health.take_damage(_burn_stacks * _burn_dps * minf(delta, _burn_left))
	_burn_left -= delta
	if _burn_left <= 0.0:
		_burn_stacks = 0
	# Flickers orange while burning.
	var glow := (0.25 + 0.1 * sin(Time.get_ticks_msec() * 0.02)) if _burn_stacks > 0 else 0.0
	sprite.modulate = Color.WHITE.lerp(Color(1.0, 0.55, 0.25), glow)
```
In `_on_died()`, first lines:
```gdscript
	_burn_stacks = 0
	sprite.modulate = Color.WHITE
```
- [ ] **Step 3: Verify.** Headless check (`godot --headless --path . --check-only` on the script or `validate_scripts`), then run the game and, in one `game_eval` each:
  - **Stacking + damage:** spawn goblin `g` as in Step 1 and `g.health.reset(9999)`. Call `g.add_burn(2.0, 5, 3.0)` 6 times, so `g.burn_stacks() == 5`. Wait 60 physics frames: health lost ≈ 10 (5 × 2 × 1 s, ±0.5). The sprite modulate isn't white.
  - **Expiry:** wait until 3.1 s after the last `add_burn`. Stacks are 0, the total loss ≈ 30, and `g.sprite.modulate == Color.WHITE`.
  - **Strongest wins (Review Focus 5):** `add_burn(2,5,3)` then `add_burn(1,5,3)` gives `_burn_dps == 2.0` and 2 stacks. A new burn after expiry, `add_burn(1,5,3)`, gives `_burn_dps == 1.0`.
  - **Death (Review Focus 1):** a goblin with `health.reset(5)` and `add_burn(2,5,3,5)` dies within ~0.5 s from burn. Its modulate is white, then `add_burn` on it leaves `burn_stacks() == 0`. There are no errors in `game_get_errors`.
  - `git checkout project.godot`.
- [ ] **Step 4: Commit** `Add stacking burn to enemies` (stage `scripts/enemies/enemy.gd` only).

---

### Task 2: EmberTower (automatic) and building it

**Files:** Modify `scripts/towers/tower.gd` (`_can_fire` hook, destroyed fallback). Create `scripts/towers/ember_definition.gd`, `scripts/towers/ember_tower.gd`, `scenes/towers/ember_tower.tscn`. Rewrite `data/towers/embercaster.tres`.

**Interfaces:**
- Consumes: `Enemy.add_burn`, `Enemy.burn_stacks` (Task 1); `Tower._ability_left`, `damage()`, `fire_rate()`, `attack_range()`, `_aim_point()`, `_muzzle_base()`, `_on_died()`, `use_ability()`.
- Produces: `Tower._can_fire() -> bool`; `class_name EmberDefinition` (fields: `cone_angle`, `muzzle_offset`, `fuel_seconds`, `refill_seconds`, `restart_fraction`, `burn_dps_per_stack`, `burn_max_stacks`, `burn_duration`, `overpressure_angle_multiplier`, `overpressure_range_multiplier`); `class_name EmberTower` with vars `fuel: float`, `dry: bool`, and `is_spraying() -> bool`, `overpressure_active() -> bool`, `cone_angle() -> float` (full angle in degrees), `burn_dps() -> float`, `_enemies_in_cone(point: Vector2) -> Array[Enemy]`.

- [ ] **Step 1: Baselines + failing check.** Run the game.
  - **Gearshot:** build on `BuildSlotWest` (`s.build(load("res://data/towers/gearshot.tres"))`). Spawn a goblin 200 px left of it with 9999 health and wait 120 frames. Record health lost, `t.damage()`, `t.fire_rate()`, `t.attack_range()`. Operate it, press Q, and record `t.fire_rate()`.
  - **Mortar:** build on `BuildSlotEast` and record `t.damage()`, `t.fire_rate()`, `t.attack_range()`, `t.splash_radius()`.
  - Eval `load("res://data/towers/embercaster.tres").available` → `false`.
- [ ] **Step 2: Tower hooks** in `scripts/towers/tower.gd`.
  - In `_physics_process`, change the fire condition to `if wants_to_fire and _cooldown <= 0.0 and _head_on_target() and _can_fire():`.
  - Add after `_operated_aim_point()`:
```gdscript
## False blocks firing (e.g. an Embercaster whose tank ran dry).
func _can_fire() -> bool:
	return true
```
  - In `_on_died()`, replace `sprite.animation = StringName("lv%d_destroyed" % level)` with:
```gdscript
	# Some sheets have one wreck for every level.
	var wreck := StringName("lv%d_destroyed" % level)
	sprite.animation = wreck if sprite.sprite_frames.has_animation(wreck) else &"destroyed"
```
- [ ] **Step 3: EmberDefinition** `scripts/towers/ember_definition.gd`:
```gdscript
class_name EmberDefinition
extends TowerDefinition
## An Embercaster's extra settings: a short flame cone that sets enemies
## burning, fed by a fuel tank, and the Overpressure ability.

@export_group("Flame")
## Full width of the flame cone, in degrees.
@export var cone_angle := 50.0
## Where the flame leaves from, relative to the base point, facing right.
@export var muzzle_offset := Vector2(44, -50)

@export_group("Fuel")
## Seconds of spraying a full tank holds.
@export var fuel_seconds := 4.0
## Seconds to refill from empty while not spraying.
@export var refill_seconds := 3.0
## After running dry it can't spray until the tank is back to this share.
@export var restart_fraction := 0.4

@export_group("Burn")
## Damage per second of each burn stack at Lv1 (scales like the flame).
@export var burn_dps_per_stack := 2.0
@export var burn_max_stacks := 5
## All stacks drop off this many seconds after the last one was added.
@export var burn_duration := 3.0

@export_group("Overpressure")
@export var overpressure_angle_multiplier := 1.5
@export var overpressure_range_multiplier := 1.3
```
- [ ] **Step 4: EmberTower** `scripts/towers/ember_tower.gd`:
```gdscript
class_name EmberTower
extends Tower
## The Embercaster: sprays a short cone of flame that sets enemies burning.
## Each flame tick (attacks_per_second) damages every enemy in the cone, adds
## a burn stack and uses up fuel. The tank refills whenever it isn't spraying;
## run it dry and it can't spray until it's back to restart_fraction. On its
## own it points the cone where it hits the most enemies; operated, at the
## mouse. Q = Overpressure: no fuel used, a bigger cone, and every tick sets
## burn to the maximum.

## A tick keeps it "spraying" this much longer than the gap to the next one.
const SPRAY_GRACE := 0.05
const FLAME_SEGMENTS := 12

var ember: EmberDefinition
## Seconds of spraying left in the tank.
var fuel := 0.0
## True after running dry, until the tank is back to restart_fraction.
var dry := false
## Which way the barrel faces (the art faces right).
var _facing_left := false
## Unit direction the cone points.
var _aim_dir := Vector2.RIGHT
var _spray_left := 0.0

@onready var embers: CPUParticles2D = $Embers


func _ready() -> void:
	ember = definition as EmberDefinition
	assert(ember != null, "An EmberTower needs an EmberDefinition")
	super()
	fuel = ember.fuel_seconds


func _physics_process(delta: float) -> void:
	super(delta)
	_spray_left = maxf(_spray_left - delta, 0.0)
	if not is_spraying():
		fuel = minf(fuel + delta * ember.fuel_seconds / ember.refill_seconds, ember.fuel_seconds)
		if dry and fuel >= ember.fuel_seconds * ember.restart_fraction:
			dry = false
	_show_spray()
	queue_redraw()


func is_spraying() -> bool:
	return _spray_left > 0.0


func overpressure_active() -> bool:
	return _ability_left > 0.0


func attack_range() -> float:
	return super() * (ember.overpressure_range_multiplier if overpressure_active() else 1.0)


## Full width of the cone, in degrees.
func cone_angle() -> float:
	return ember.cone_angle * (ember.overpressure_angle_multiplier if overpressure_active() else 1.0)


## Burn per stack, scaled like the flame (levels and operating).
func burn_dps() -> float:
	return ember.burn_dps_per_stack * damage() / ember.attack_damage


func _can_fire() -> bool:
	return overpressure_active() or not dry


## Every living enemy whose body is inside the cone pointed at `point`.
func _enemies_in_cone(point: Vector2) -> Array[Enemy]:
	var left := point.x < global_position.x
	var muzzle := _muzzle_facing(left)
	var direction := point - muzzle
	if direction.length() < 0.001:
		direction = Vector2.LEFT if left else Vector2.RIGHT
	var half := deg_to_rad(cone_angle()) / 2.0
	var result: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy.health.is_dead:
			continue
		var to_enemy := _aim_point(enemy) - muzzle
		if to_enemy.length() <= attack_range() and absf(direction.angle_to(to_enemy)) <= half:
			result.append(enemy)
	return result


## The enemy in range whose cone would catch the most enemies (nearest wins
## ties).
func _find_target() -> Enemy:
	var best: Enemy = null
	var best_count := 0
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy.health.is_dead:
			continue
		var point := _aim_point(enemy)
		var distance := _muzzle_facing(point.x < global_position.x).distance_to(point)
		if distance > attack_range():
			continue
		var count := _enemies_in_cone(point).size()
		if count > best_count or (count == best_count and distance < best_distance):
			best = enemy
			best_count = count
			best_distance = distance
	return best


func _aim_at(point: Vector2) -> void:
	_facing_left = point.x < global_position.x
	sprite.flip_h = _facing_left
	var direction := point - _muzzle_base()
	if direction.length() > 0.001:
		_aim_dir = direction.normalized()


func _muzzle_facing(left: bool) -> Vector2:
	var offset := ember.muzzle_offset
	return global_position + Vector2(-offset.x if left else offset.x, offset.y)


func _muzzle_base() -> Vector2:
	return _muzzle_facing(_facing_left)


## One flame tick: damage and burn everything in the cone, and use up fuel.
func _fire_at(point: Vector2) -> void:
	var stacks := ember.burn_max_stacks if overpressure_active() else 1
	for enemy in _enemies_in_cone(point):
		var before := enemy.health.current
		enemy.health.take_damage(damage())
		if operator:
			mastery_xp += before - enemy.health.current
		enemy.add_burn(burn_dps(), ember.burn_max_stacks, ember.burn_duration, stacks)
	var tick_time := 1.0 / fire_rate()
	_spray_left = tick_time + SPRAY_GRACE
	if not overpressure_active():
		fuel = maxf(fuel - tick_time, 0.0)
		if fuel <= 0.0:
			dry = true


func _on_died() -> void:
	_spray_left = 0.0
	embers.emitting = false
	super()


## Spraying holds the first fire frame (the glowing barrel; the drawn cone is
## the flame, as the later frames' flames are clipped at the frame edge).
func _show_spray() -> void:
	var animation := StringName("lv%d_%s" % [level, "fire" if is_spraying() else "idle"])
	if sprite.animation != animation:
		if is_spraying():
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


## The flame while spraying, the cone outline while operated, and the fuel
## bar whenever the tank isn't full.
func _draw() -> void:
	if is_destroyed():
		return
	var muzzle := to_local(_muzzle_base())
	var facing := _aim_dir.angle()
	var half := deg_to_rad(cone_angle()) / 2.0
	if is_spraying():
		_draw_fan(muzzle, facing, half, attack_range() * randf_range(0.92, 1.0),
				Color(1.0, 0.95, 0.6, 0.9), Color(1.0, 0.35, 0.05, 0.12))
		_draw_fan(muzzle, facing, half * 0.45, attack_range() * randf_range(0.6, 0.75),
				Color(1.0, 0.9, 0.5, 0.8), Color(1.0, 0.55, 0.1, 0.25))
	if operator:
		var reach := Color(0.45, 0.85, 1.0)
		draw_arc(muzzle, attack_range(), facing - half, facing + half, 24, Color(reach, 0.5), 2.0)
		draw_line(muzzle, muzzle + Vector2.from_angle(facing - half) * attack_range(), Color(reach, 0.35), 1.5)
		draw_line(muzzle, muzzle + Vector2.from_angle(facing + half) * attack_range(), Color(reach, 0.35), 1.5)
	if fuel < ember.fuel_seconds:
		const WIDTH := 36.0
		var top_left := Vector2(-WIDTH / 2.0, 10.0)
		draw_rect(Rect2(top_left, Vector2(WIDTH, 4.0)), Color(0.0, 0.0, 0.0, 0.6))
		var fill := Color(1.0, 0.3, 0.2) if dry else Color(1.0, 0.65, 0.15)
		draw_rect(Rect2(top_left, Vector2(WIDTH * fuel / ember.fuel_seconds, 4.0)), fill)


## A flickering fan from `from`, `inner` colour at the tip fading to `outer`.
func _draw_fan(from: Vector2, facing: float, half: float, reach: float, inner: Color, outer: Color) -> void:
	var points := PackedVector2Array([from])
	var colors := PackedColorArray([inner])
	for i in FLAME_SEGMENTS + 1:
		var angle := facing - half + 2.0 * half * i / FLAME_SEGMENTS
		points.append(from + Vector2.from_angle(angle) * reach * randf_range(0.9, 1.0))
		colors.append(outer)
	draw_polygon(points, colors)
```
- [ ] **Step 5: Scene** `scenes/towers/ember_tower.tscn`:
```
[gd_scene load_steps=4 format=3]

[ext_resource type="PackedScene" path="res://scenes/towers/tower.tscn" id="1_tower"]
[ext_resource type="Script" path="res://scripts/towers/ember_tower.gd" id="2_ember"]

[sub_resource type="Gradient" id="Gradient_embers"]
offsets = PackedFloat32Array(0, 0.5, 1)
colors = PackedColorArray(1, 0.9, 0.5, 1, 1, 0.45, 0.1, 0.9, 0.6, 0.1, 0.05, 0)

[node name="EmberTower" instance=ExtResource("1_tower")]
script = ExtResource("2_ember")

[node name="Embers" type="CPUParticles2D" parent="."]
z_index = 1
emitting = false
amount = 40
lifetime = 0.35
direction = Vector2(1, 0)
spread = 25.0
gravity = Vector2(0, -60)
initial_velocity_min = 250.0
initial_velocity_max = 430.0
scale_amount_min = 2.0
scale_amount_max = 4.0
color_ramp = SubResource("Gradient_embers")
```
- [ ] **Step 6: Data** Rewrite `data/towers/embercaster.tres`:
```
[gd_resource type="Resource" script_class="EmberDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/towers/ember_definition.gd" id="1_def"]
[ext_resource type="SpriteFrames" path="res://assets/sprites/embercaster.tres" id="2_frames"]
[ext_resource type="PackedScene" path="res://scenes/towers/ember_tower.tscn" id="3_scene"]

[resource]
script = ExtResource("1_def")
id = &"embercaster"
display_name = "Embercaster"
description = "Short-range flame cone that sets enemies burning."
sprite_frames = ExtResource("2_frames")
sprite_scale = 0.55
scene = ExtResource("3_scene")
cost = Dictionary[StringName, int]({
&"scrap": 12
})
lv2_cost = Dictionary[StringName, int]({
&"scrap": 18
})
lv3_cost = Dictionary[StringName, int]({
&"scrap": 28,
&"aether": 3
})
max_health = 180.0
attack_damage = 3.0
attacks_per_second = 5.0
attack_range = 150.0
operated_damage_multiplier = 1.35
operated_fire_rate_multiplier = 1.0
operated_range_multiplier = 1.15
ability_name = "Overpressure"
ability_duration = 3.0
ability_cooldown = 15.0
ability_fire_rate_multiplier = 1.0
```
(The `available` line is gone, so it defaults to true.)
- [ ] **Step 7: Verify.** Import (`godot --headless --editor --path . --import`), headless check, then run the game and eval:
  - **Baselines** (Step 1 again): identical Gearshot and Mortar numbers.
  - **Build:** Embercaster on `BuildSlotWest`. 12 Scrap are spent, `s.built is EmberTower`, `t.health.max_health == 180`, and `t.fuel == 4.0`. The build menu card is no longer "Coming soon".
  - **Muzzle calibration:** screenshot the tower facing right, then facing left (a goblin on each side). The drawn flame should start at the barrel mouth. If it's off, adjust `muzzle_offset` in `ember_definition.gd` and `embercaster.tres`, then re-check.
  - **Cone:** freeze goblins (`set_physics_process(false)`) at 100 px straight out from the muzzle, 100 px at 40° off-axis (outside 25°), and 200 px out (beyond 150). Aim at the first one and call `t._fire_at(...)` once. Only the first loses 3 and has 1 burn stack.
  - **Most-goblins targeting:** one goblin alone 80 px above-left, and 3 goblins together 120 px right. `t._find_target()` is one of the 3.
  - **Fuel:** keep a frozen 99999-health goblin in the cone and let it spray. After ~3.8–4.0 s, `t.dry == true` and `t.fuel == 0`, and no ticks happen while dry. Fuel reaches 40% ~1.2 s after it stops spraying, then `dry == false` and spraying restarts. Removing the goblin (kill it) refills a full tank in ~3 s.
  - **Burn in play:** a goblin that stays in the flame for 1 s has 5 stacks.
  - **Destroyed while spraying (Review Focus 2):** `t.health.take_damage(99999)` while spraying shows the `destroyed` wreck, `embers.emitting == false`, and there are no errors.
  - Screenshots: spraying cone with embers, a burning goblin, the fuel bar (orange, then red while dry).
  - `git checkout project.godot`.
- [ ] **Step 8: Commit** `Add the Embercaster tower (automatic fire)` (stage `scripts/towers/tower.gd`, `scripts/towers/ember_definition.gd*`, `scripts/towers/ember_tower.gd*`, `scenes/towers/ember_tower.tscn`, `data/towers/embercaster.tres`).

---

### Task 3: Operating the Embercaster and Overpressure

Operating and Overpressure are already in the Task 2 code (`_operated_aim_point` from the base, `use_ability` from the base, `overpressure_active`, `_draw`). This task verifies them and fixes anything found.

- [ ] **Step 1: Verify.**
  - Build an Embercaster and operate it (`hero.start_operating(t)`, `auto_fire = false`).
  - **Aim:** warp the mouse right of the tower, and the cone points at it. Warp it left and the sprite flips with the cone pointing left. Mouse exactly on the muzzle, or on the tower's base (Review Focus 3): `_aim_dir` stays a unit vector (no NaN), and `_enemies_in_cone` with goblins placed around the tower returns only the ones in a 50° wedge, never all of them.
  - **Fire only when held:** with fire released, fuel stays full and no goblin is damaged. Holding fire (`Input.action_press(&"fire")`) sprays. Releasing it refills the tank.
  - **Operated numbers:** `t.damage() == 3 × 1.35 = 4.05`; `t.attack_range() == 150 × 1.15 = 172.5`; `t.fire_rate() == 5`; `t.burn_dps() == 2 × 1.35 = 2.7`. Mastery XP rises by exactly the flame damage dealt, and is unchanged by burn ticks and while automatic.
  - **Overpressure:** press Q (`t.use_ability()`). For 3 s, `t.cone_angle() == 75`, `t.attack_range() == 172.5 × 1.3 = 224.25`, and `t.fire_rate() == 5` (not 15). The fuel doesn't drop while spraying, and goblins hit have 5 stacks after one tick. Q again does nothing. The HUD reads `Overpressure active: …` then `[Q] Overpressure recharging: …s`.
  - **Lockout edge (Review Focus 4):** run the tank dry, then press Q. It sprays through Overpressure while still `dry`. After it ends, spraying stays blocked until fuel ≥ 1.6.
  - **Upgrade:** Lv2 costs 18 Scrap and Lv3 costs 28 Scrap + 3 Aether. The art switches to lv3, `t.damage() == 3 × 1.3² = 5.07` (automatic), and burn per stack scales the same.
  - Screenshots: operated cone outline, Overpressure's wider flame.
  - `git checkout project.godot`.
- [ ] **Step 2: Commit** any fixes as `Fix operated Embercaster <what>`. If nothing needed fixing, record that in the ledger (no commit).

---

### Task 4: Roadmap

- [ ] In `ROADMAP.md`:
  - Tick `- [x] **[AI]** Embercaster (short-range flamethrower + burn)` and add a one-line summary: 12 Scrap (Lv2 18, Lv3 28 + 3 Aether); 50° cone, 150 px; fuel tank 4 s / 3 s refill, locks out until 40% when dry; burn stacks to 5 × 2/s for 3 s; aims where it hits the most goblins; operated = cone at the mouse; Q = Overpressure.
  - Mark `4) Embercaster ✅` in the order line.
  - Commit `Tick the Embercaster on the roadmap`.
