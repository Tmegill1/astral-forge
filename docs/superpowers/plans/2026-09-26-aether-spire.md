# Aether Spire Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A buildable Aether Spire: instant chain lightning (up to 4 jumps, 20% falloff each) at the nearest goblin, or the goblin nearest the mouse when operated, with a Resonance Burst ability that stuns.

**Architecture:** Same pattern as the Mortar and Embercaster. `SpireDefinition extends TowerDefinition` holds the chain and Resonance Burst settings. `SpireTower extends Tower` keeps the base targeting and mouse aim and overrides firing, the ability and drawing. A self-contained `LightningArc` node draws each bolt. `Enemy` gains `stun()` and one shared tint function.

**Tech Stack:** Godot 4.7 GDScript; verification via Godot MCP in the running game.

**Spec:** `docs/superpowers/specs/2026-09-26-aether-spire-design.md`

## Global Constraints

- Spire Lv1: cost 14 Scrap; lv2 20 Scrap; lv3 30 Scrap + 3 Aether; damage 10; 0.8 bolts/s; range 280 (from the tower's base point); health 150; sprite_scale 0.55.
- Chain: up to 4 jumps; each jump to the nearest living goblin not yet in the chain within 120 px (body to body, inclusive) of the last one; each jump deals 20% less than the one before (10, 8, 6.4, 5.12, 4.096).
- Operated: damage ×1.35, range ×1.15, fire rate ×1.0. Mastery XP = damage dealt by bolts fired while operated.
- Resonance Burst: cooldown 15 s; 2× damage; up to 8 jumps; no falloff; 1 s stun on every goblin hit. Only fires (and only starts the cooldown) if a goblin is in range.
- Stun: no moving (velocity 0), no attacking, idle animation; burn and slows keep ticking; longer stun wins; death clears it. Tint: stun = pale blue flicker, burn = orange flicker, stun wins.
- Description: "Lightning that jumps between enemies. Best against spread-out groups."
- Gearshot, Mortar and Embercaster must behave exactly as before.
- Work happens on branch `phase8-aether-spire`; one commit per task (`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`). Stage only the task's files (`main` has unrelated uncommitted editor re-saves; leave them alone). New `class_name` → `godot --headless --editor --path . --import` before the headless check. `git checkout project.godot` after MCP runs.
- MCP testing gotchas: the first `game_eval` after `run_project` says "Not connected" (retry once); a script error inside an eval triggers a Debugger Break that freezes the game (check `get_debug_output`, then restart); `ResourceBag.add_all` needs `var d: Dictionary[StringName, int] = {...}`; never `queue_free` living enemies or disable the WaveDirector (kill with `health.take_damage(999999)`); a frozen goblin (`set_physics_process(false)`) also freezes its burn and stun; move the hero away (it shoots nearby goblins for 10) and use it to frame screenshots; do timing checks inside one `game_eval`.

## Review Focus

1. **The first target (or a middle goblin) dies from its hit**: the chain still continues from where it stood, with no errors and no double hits (Task 2 test).
2. **Stunned mid-attack swing**: the swing's hit doesn't land while stunned, and the goblin attacks again once the stun ends (Task 1 test).
3. **Operated with no goblin in range**: fire does nothing, and Q does nothing and doesn't start the cooldown (Task 3 test).
4. **The Spire sold or destroyed while an arc is still fading**: the arc finishes and frees itself with no errors (Task 2 test).
5. **Goblins exactly 120 px apart, or stacked on the same spot**: 120 counts as in range, and a stacked goblin is hit once, not twice (Task 2 test).

---

### Task 1: Enemy stun and shared tint

**Files:** Modify `scripts/enemies/enemy.gd`.

**Interfaces (produced):**
- `Enemy.stun(seconds: float) -> void`
- `Enemy.is_stunned() -> bool`
- `Enemy._update_tint() -> void` (internal; replaces the tint lines in `_tick_burn`)

- [ ] **Step 1: Failing check.** Create the branch (`git checkout -b phase8-aether-spire`). Run the game and spawn a goblin (`world.get_node("WaveDirector").spawn_at(load("res://data/enemies/goblin.tres"), core.global_position + Vector2(-700, 0))`). Eval `g.has_method(&"stun")`. Expected: `false`.
- [ ] **Step 2: Stun state.** In `enemy.gd`, under the burn vars:
```gdscript
## While above 0 it can't move or attack.
var _stun_left := 0.0
```
Replace the start of `_physics_process`, down to and including the slow countdown, with:
```gdscript
func _physics_process(delta: float) -> void:
	if health.is_dead:
		return
	if _burn_stacks > 0:
		_tick_burn(delta)
		if health.is_dead:
			return
	_update_tint()
	_cooldown -= delta
	_repath_left -= delta
	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0:
			_slow_factor = 1.0
	if _stun_left > 0.0:
		_stun_left -= delta
		velocity = Vector2.ZERO
		sprite.play(&"idle")
		return
```
(the rest of `_physics_process`, from `var goal := _pick_target()`, is unchanged). In `_tick_burn`, delete the last three lines (the `# Flickers orange while burning.` comment, `var glow ...` and `sprite.modulate = ...`). After `burn_stacks()`, add:
```gdscript
## Stops it moving and attacking for `seconds`. The longer stun wins.
func stun(seconds: float) -> void:
	if health.is_dead:
		return
	_stun_left = maxf(_stun_left, seconds)


func is_stunned() -> bool:
	return _stun_left > 0.0


## Stun (pale blue) shows over burn (orange); both flicker.
func _update_tint() -> void:
	var flicker := sin(Time.get_ticks_msec() * 0.02)
	if _stun_left > 0.0:
		sprite.modulate = Color.WHITE.lerp(Color(0.6, 0.85, 1.0), 0.45 + 0.15 * flicker)
	elif _burn_stacks > 0:
		sprite.modulate = Color.WHITE.lerp(Color(1.0, 0.55, 0.25), 0.25 + 0.1 * flicker)
	else:
		sprite.modulate = Color.WHITE
```
In `_on_died()`, add `_stun_left = 0.0` next to `_burn_stacks = 0`.
- [ ] **Step 3: Verify.** `validate_scripts` on `enemy.gd`, then run the game and eval, each in one `game_eval`:
  - **Stun stops movement:** a walking goblin 700 px left of the Core with 9999 health. Record its position, call `g.stun(1.0)`, and wait 30 frames. It hasn't moved (±0.5 px), `g.velocity == Vector2.ZERO`, `g.is_stunned()`, and the modulate is bluish (`b > r`). Wait 40 more frames: `is_stunned()` is false and it has moved more than 20 px.
  - **Longer wins:** `stun(1.0)` then `stun(0.2)` leaves `_stun_left ≈ 1.0`.
  - **Stun over burn:** `add_burn(2, 5, 3)` + `stun(0.5)` gives bluish modulate. After 40 frames it's orange (`r > b`) and burn has been dealing damage the whole time (≈ 2/s × 0.67 s). When the burn expires it's `Color.WHITE`.
  - **Stunned mid-swing (Review Focus 2):** a goblin placed next to the Core (`core.global_position + Vector2(-60, 0)`) with 9999 health. Wait until `g.sprite.animation == &"attack"`, then `g.stun(1.0)` and record `core.health.current`. After 55 frames the Core has lost nothing. Within 90 more frames the Core loses health again.
  - **Death clears it:** a stunned goblin killed with `take_damage(999999)` has `is_stunned() == false` and white modulate, and `stun()` on it afterwards does nothing.
  - **Burn still works as before:** `add_burn(2,5,3)` ×6 → 5 stacks, ≈10 damage in 60 frames, orange tint, white after expiry.
  - No new errors in `game_get_errors`. `git checkout project.godot`.
- [ ] **Step 4: Commit** `Add enemy stun and a shared tint` (stage `scripts/enemies/enemy.gd` only).

---

### Task 2: SpireTower (automatic), LightningArc and building it

**Files:** Create `scripts/projectiles/lightning_arc.gd`, `scripts/towers/spire_definition.gd`, `scripts/towers/spire_tower.gd`, `scenes/towers/spire_tower.tscn`. Rewrite `data/towers/aether_spire.tres`.

**Interfaces:**
- Consumes: `Enemy.stun(seconds)` (Task 1); base `Tower`: `damage()`, `attack_range()`, `_aim_point(enemy)`, `_operated_aim_point()`, `_fire_frame_left`, `_ability_cooldown_left`, `projectile_parent`, `mastery_xp`, `operator`, `level`.
- Produces: `class_name LightningArc` (vars `points: PackedVector2Array`, `burst: bool`); `class_name SpireDefinition` (fields `jump_count`, `jump_range`, `jump_falloff`, `bolt_heights`, `burst_damage_multiplier`, `burst_jump_count`, `burst_stun`); `class_name SpireTower` with `_first_target(point: Vector2) -> Enemy`, `chain_from(first: Enemy, jumps: int) -> Array[Enemy]`, `_strike(chain: Array[Enemy], bolt_damage: float, falloff: float, stun: float) -> void`.

- [ ] **Step 1: Baselines + failing check.** Run the game. Build a Gearshot on `BuildSlotWest`, a Mortar on `BuildSlotEast` and an Embercaster on `BuildSlotNorth` (unlock each with `locked = false`; add Scrap/Aether first). Put one frozen 999999-health goblin in front of each (Gearshot −180 px x, Mortar +250 px x, Embercaster +110, −20). Over 900 frames, record each tower's frames between shots (detect a shot as `_cooldown` rising). Expected: 40 / 120 / 12. Also eval `load("res://data/towers/aether_spire.tres").available` → `false`.
- [ ] **Step 2: LightningArc** `scripts/projectiles/lightning_arc.gd`:
```gdscript
class_name LightningArc
extends Node2D
## A lightning bolt through `points` (world positions): a jagged line between
## each pair, re-jittered every frame, that fades out and frees itself. It
## keeps its own copy of the points, so it doesn't need the tower or the
## enemies to still exist.

## Roughly how long each straight piece of the jagged line is, in pixels.
const SEGMENT := 14.0
## How far each corner can stray from the straight line, in pixels.
const JITTER := 7.0

## World positions: where the bolt starts, then each enemy it hit.
var points := PackedVector2Array()
## A Resonance Burst: thicker, brighter and longer-lasting.
var burst := false

var _life := 0.15
var _left := 0.15


func _ready() -> void:
	z_index = 1
	_life = 0.25 if burst else 0.15
	_left = _life


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var alpha := clampf(_left / _life, 0.0, 1.0)
	var width := 4.0 if burst else 2.5
	for i in points.size() - 1:
		var path := _jagged(to_local(points[i]), to_local(points[i + 1]))
		draw_polyline(path, Color(0.55, 0.85, 1.0, 0.45 * alpha), width * 2.5)
		draw_polyline(path, Color(0.92, 0.98, 1.0, alpha), width)


func _jagged(from: Vector2, to: Vector2) -> PackedVector2Array:
	var path := PackedVector2Array([from])
	var steps := maxi(2, ceili(from.distance_to(to) / SEGMENT))
	var normal := (to - from).orthogonal().normalized()
	for s in range(1, steps):
		path.append(from.lerp(to, float(s) / steps) + normal * randf_range(-JITTER, JITTER))
	path.append(to)
	return path
```
- [ ] **Step 3: SpireDefinition** `scripts/towers/spire_definition.gd`:
```gdscript
class_name SpireDefinition
extends TowerDefinition
## An Aether Spire's extra settings: lightning that jumps between enemies,
## and the Resonance Burst ability.

@export_group("Chain")
## Jumps after the first target.
@export var jump_count := 4
## A jump reaches the nearest enemy not yet hit within this of the last one,
## in pixels.
@export var jump_range := 120.0
## Each jump deals this share less than the one before (0.2 = 20% less).
@export var jump_falloff := 0.2
## How high above the base point bolts leave from (the crystal tip), per
## level (index 0 = Lv1), in on-screen pixels.
@export var bolt_heights: PackedFloat32Array = [90.0, 100.0, 125.0]

@export_group("Resonance Burst")
@export var burst_damage_multiplier := 2.0
@export var burst_jump_count := 8
## Seconds each enemy hit is stunned.
@export var burst_stun := 1.0
```
- [ ] **Step 4: SpireTower** `scripts/towers/spire_tower.gd`:
```gdscript
class_name SpireTower
extends Tower
## The Aether Spire: lightning that jumps between enemies. Each bolt hits a
## first target, then jumps to the nearest enemy it hasn't hit within
## jump_range, each jump dealing less. On its own the first target is the
## nearest enemy; operated, the enemy in range nearest the mouse. Q =
## Resonance Burst: a double-damage bolt with more jumps and no falloff that
## stuns everything it hits.

## How long the charge frame shows after a bolt, in seconds.
const CHARGE_FRAME_TIME := 0.2

var spire: SpireDefinition


func _ready() -> void:
	spire = definition as SpireDefinition
	assert(spire != null, "A SpireTower needs a SpireDefinition")
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	if operator:
		queue_redraw()


## Where bolts leave from: this level's crystal tip.
func _muzzle_base() -> Vector2:
	return global_position + Vector2(0.0, -spire.bolt_heights[level - 1])


## The living enemy in range nearest `point`, or null.
func _first_target(point: Vector2) -> Enemy:
	var best: Enemy = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy.health.is_dead or global_position.distance_to(enemy.global_position) > attack_range():
			continue
		var distance := point.distance_to(_aim_point(enemy))
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best


## `first` and up to `jumps` more living enemies: each the nearest one not
## yet in the chain within jump_range of the last.
func chain_from(first: Enemy, jumps: int) -> Array[Enemy]:
	var chain: Array[Enemy] = [first]
	var others: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy != first and not enemy.health.is_dead:
			others.append(enemy)
	while chain.size() <= jumps and not others.is_empty():
		var from := _aim_point(chain[-1])
		var best := -1
		var best_distance := spire.jump_range
		for i in others.size():
			var distance := from.distance_to(_aim_point(others[i]))
			if distance <= best_distance:
				best = i
				best_distance = distance
		if best < 0:
			break
		chain.append(others[best])
		others.remove_at(best)
	return chain


func _fire_at(point: Vector2) -> void:
	var first := _first_target(point)
	if first:
		_strike(chain_from(first, spire.jump_count), damage(), spire.jump_falloff, 0.0)


## Fires a Resonance Burst at the enemy nearest the mouse, if it's recharged
## and an enemy is in range.
func use_ability() -> void:
	if operator == null or _ability_cooldown_left > 0.0:
		return
	var first := _first_target(_operated_aim_point())
	if first == null:
		return
	_ability_cooldown_left = definition.ability_cooldown
	_strike(chain_from(first, spire.burst_jump_count),
			damage() * spire.burst_damage_multiplier, 0.0, spire.burst_stun)


## Deals `bolt_damage` down the chain (each jump `falloff` less than the one
## before), stuns each enemy hit for `stun` seconds if above 0, and draws the
## bolt.
func _strike(chain: Array[Enemy], bolt_damage: float, falloff: float, stun: float) -> void:
	var points := PackedVector2Array([_muzzle_base()])
	var hit_damage := bolt_damage
	for enemy in chain:
		points.append(_aim_point(enemy))
		var before := enemy.health.current
		enemy.health.take_damage(hit_damage)
		if operator:
			mastery_xp += before - enemy.health.current
		if stun > 0.0:
			enemy.stun(stun)
		hit_damage *= 1.0 - falloff
	var arc := LightningArc.new()
	arc.points = points
	arc.burst = stun > 0.0
	projectile_parent.add_child(arc)
	# The first fire frame is the swirling charge; the later ones' beams are
	# clipped at the frame edge.
	sprite.animation = StringName("lv%d_fire" % level)
	sprite.stop()
	sprite.frame = 0
	_fire_frame_left = CHARGE_FRAME_TIME


## While operated: the range ring, and a ring on the enemy the next bolt
## would hit first.
func _draw() -> void:
	if operator == null:
		return
	var reach := Color(0.45, 0.85, 1.0)
	draw_circle(Vector2.ZERO, attack_range(), Color(reach, 0.04))
	draw_arc(Vector2.ZERO, attack_range(), 0.0, TAU, 96, Color(reach, 0.35), 2.0)
	var first := _first_target(_operated_aim_point())
	if first:
		draw_arc(to_local(_aim_point(first)), 16.0, 0.0, TAU, 24, Color(reach, 0.9), 2.0)
```
- [ ] **Step 5: Scene** `scenes/towers/spire_tower.tscn`:
```
[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://scenes/towers/tower.tscn" id="1_tower"]
[ext_resource type="Script" path="res://scripts/towers/spire_tower.gd" id="2_spire"]

[node name="SpireTower" instance=ExtResource("1_tower")]
script = ExtResource("2_spire")
```
- [ ] **Step 6: Data** Rewrite `data/towers/aether_spire.tres`:
```
[gd_resource type="Resource" script_class="SpireDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/towers/spire_definition.gd" id="1_def"]
[ext_resource type="SpriteFrames" path="res://assets/sprites/aether_spire.tres" id="2_frames"]
[ext_resource type="PackedScene" path="res://scenes/towers/spire_tower.tscn" id="3_scene"]

[resource]
script = ExtResource("1_def")
id = &"aether_spire"
display_name = "Aether Spire"
description = "Lightning that jumps between enemies. Best against spread-out groups."
sprite_frames = ExtResource("2_frames")
sprite_scale = 0.55
scene = ExtResource("3_scene")
cost = Dictionary[StringName, int]({
&"scrap": 14
})
lv2_cost = Dictionary[StringName, int]({
&"scrap": 20
})
lv3_cost = Dictionary[StringName, int]({
&"scrap": 30,
&"aether": 3
})
max_health = 150.0
attack_damage = 10.0
attacks_per_second = 0.8
attack_range = 280.0
operated_damage_multiplier = 1.35
operated_fire_rate_multiplier = 1.0
operated_range_multiplier = 1.15
ability_name = "Resonance Burst"
ability_cooldown = 15.0
ability_fire_rate_multiplier = 1.0
```
(The `available` line is gone, so it defaults to true.)
- [ ] **Step 7: Verify.** Import (`godot --headless --editor --path . --import`), `validate_scripts`, then run the game and eval:
  - **Baselines** (Step 1 again): 40 / 120 / 12 frames.
  - **Build:** Spire on `BuildSlotWest`. 14 Scrap are spent, `s.built is SpireTower`, and `health.max_health == 150`.
  - **Chain falloff:** freeze the Spire (`set_physics_process(false)`) and move the hero 400 px away. Place 6 frozen 1000-health goblins in a line going away from the tower, bodies 100 px apart, with the first 150 px from the tower (position them by body point: `g.global_position += wanted - g.hurtbox_shape.global_position`). Add one more 150 px sideways from the 3rd. `t._fire_at(_aim_point(first))`: losses are 10 / 8 / 6.4 / 5.12 / 4.096, the 6th loses 0 (jump limit), and the sideways one loses 0.
  - **Early stop:** a lone goblin → the chain is length 1, and only it loses 10.
  - **Exact 120 and stacked goblins (Review Focus 5):** two goblins with bodies exactly 120 px apart → both hit. Two goblins at the same spot plus one 50 px away → the chain has 3 distinct goblins, and each loses health once.
  - **Kill mid-chain (Review Focus 1):** the first goblin has 5 health, and three more are 100 px apart. All four are hit (the first dies), with no errors.
  - **Automatic rate:** unfreeze the Spire with one frozen goblin in range and count bolts over 600 frames, detecting a bolt as `_cooldown` rising. The average gap is 75 frames (0.8/s), and it hits the nearest goblin.
  - **Bolt origin calibration:** screenshot a bolt at each level (upgrade with `s.upgrade()`). The bolt should start at the crystal tip. If it doesn't, adjust `bolt_heights` in `spire_definition.gd` and `aether_spire.tres`, then re-check.
  - **Arc outlives the tower (Review Focus 4):** fire, then `s.sell()` in the same eval. The arc is still in the tree for the next few frames and gone after 20 frames, with no errors.
  - **Destroyed:** `t.health.take_damage(999999)` shows the `destroyed` wreck, with no errors.
  - Screenshots: a normal chain, the charge frame.
  - `git checkout project.godot`.
- [ ] **Step 8: Commit** `Add the Aether Spire tower (automatic fire)` (stage `scripts/projectiles/lightning_arc.gd*`, `scripts/towers/spire_definition.gd*`, `scripts/towers/spire_tower.gd*`, `scenes/towers/spire_tower.tscn`, `data/towers/aether_spire.tres`).

---

### Task 3: Operating the Spire and Resonance Burst

Operating and Resonance Burst are already in the Task 2 code (`_first_target` with the mouse, `use_ability`, `_draw`). This task verifies them and fixes anything found.

- [ ] **Step 1: Verify.**
  - Build a Spire and operate it (`hero.start_operating(t)`, `auto_fire = false`). Move the mouse with `get_viewport().warp_mouse(get_viewport().get_canvas_transform() * world_pos)`.
  - **Mouse targeting:** two frozen goblins in range, one on each side. With the mouse next to the left one, `_first_target(_operated_aim_point())` is the left one; next to the right one, it's the right one. With the mouse far outside range beyond the right one, it's still the right one.
  - **Fire only when held:** with fire released for 60 frames, nothing is hit. Holding fire (`Input.action_press(&"fire")`) for 90 frames hits (≈1–2 bolts), then release.
  - **Operated numbers:** `t.damage() == 13.5`; `t.attack_range() == 322`; `t.fire_rate() == 0.8`. Mastery XP rises by exactly the damage dealt. It doesn't change while automatic.
  - **No goblin in range (Review Focus 3):** with all goblins killed, holding fire does nothing, and `t.use_ability()` leaves `ability_cooldown_left() == 0` with no arc spawned.
  - **Resonance Burst:** 10 unfrozen goblins (walking, 9999 health) in a loose line 90 px apart inside range; press Q.
    - The first 9 goblins of the chain lose `27` each (`10 × 1.35 × 2`, no falloff), and the 10th loses 0.
    - All 9 are stunned: none moves for 55 frames, and all move again after 70 more.
    - The arc is `burst`.
    - `ability_cooldown_left() == 15`, and Q again does nothing.
    - The HUD reads `[Q] Resonance Burst recharging: 15s`.
  - **Upgrade:** Lv2 costs 20 Scrap and Lv3 costs 30 Scrap + 3 Aether. The art switches to lv3, `t.damage() == 16.9` (automatic), and the first-jump damage in a chain scales the same.
  - Screenshots: the operated range ring with the first-target ring, a Resonance Burst, a stunned (blue) goblin.
  - `git checkout project.godot`.
- [ ] **Step 2: Commit** any fixes as `Fix operated Aether Spire <what>`. If nothing needed fixing, record that in the ledger (no commit).

---

### Task 4: Roadmap

- [ ] In `ROADMAP.md`:
  - Tick `- [x] **[AI]** Aether Spire (chain lightning)` and add a one-line summary: 14 Scrap (Lv2 20, Lv3 30 + 3 Aether); 10 damage, 0.8/s, 280 range; up to 4 jumps within 120 px, 20% less each jump; nearest goblin first; operated = goblin nearest the mouse; Q = Resonance Burst (2×, 8 jumps, no falloff, 1 s stun).
  - Mark `5) Spire ✅` in the order line.
  - Commit `Tick the Aether Spire on the roadmap`.
