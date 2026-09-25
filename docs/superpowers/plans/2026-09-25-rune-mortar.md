# Rune Mortar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A buildable Rune Mortar: long-range arcing splash shells that auto-target the biggest clump, click-to-target when operated, and a Rune Shell ability that leaves a slowing circle.

**Architecture:** Tower types get their own scripts. `TowerDefinition.scene` picks the scene `BuildSlot` builds. `MortarTower extends Tower` overrides targeting, firing, ability and drawing, and `MortarDefinition extends TowerDefinition` holds the mortar settings. New `Shell` and `RuneCircle` nodes, plus `Enemy.slow()`.

**Tech Stack:** Godot 4.7 GDScript; verification via Godot MCP in the running game.

**Spec:** `docs/superpowers/specs/2026-09-25-rune-mortar-design.md`

## Global Constraints

- Mortar Lv1: cost 15 Scrap; lv2 20 Scrap; lv3 30 Scrap + 3 Aether (listed Scrap first); damage 14; splash 70; 0.5 shots/s; range 420; min range 110; flight 0.9 s; health 150; sprite_scale 0.55; muzzle (±8, −88) from the base point.
- Operated: damage ×1.35, splash ×1.25, range ×1.15, fire rate ×1.0.
- Rune Shell: cooldown 15 s; damage ×2, radius ×2; circle 4 s; slow 0.4 (goblins move at 60%).
- Gearshot behaviour must be unchanged.
- Branch `phase8-rune-mortar`; one commit per task (`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`). New `class_name` → `godot --headless --editor --path . --import` before the headless check. `git checkout project.godot` after MCP runs. Never `queue_free` living enemies during a wave in tests; kill them with `health.take_damage(99999)`.

## Review Focus

1. **Goblins all inside min range**: the mortar holds fire rather than shelling itself (Task 2 test).
2. **Operated with the mouse on the tower itself**: the aim clamps to min range along some direction and doesn't produce a NaN or zero vector (Task 3 test).
3. **A slowed goblin that dies, or a circle that expires**: no errors; speed returns to normal after expiry (Task 1 test).
4. **Shell landing after its tower was sold or destroyed**: it still resolves without errors (Task 2 test).
5. **Gearshot baseline** (auto fire, operated fire, Rapid Fire) is unchanged (Task 2 test).

---

### Task 1: Enemy slows, Shell and RuneCircle

**Files:** Modify `scripts/enemies/enemy.gd`. Create `scripts/projectiles/shell.gd`, `scripts/projectiles/rune_circle.gd`.

**Interfaces (produced):**
- `Enemy.slow(factor: float, seconds: float) -> void`
- `Enemy.speed_multiplier() -> float`
- `class_name Shell extends Node2D`, with `signal hit(damage: float, killed: bool)`, vars `from: Vector2`, `target: Vector2`, `flight_time`, `arc_height`, `damage`, `radius`, `rune_duration := 0.0` (0 = no circle), `rune_slow := 0.0`, `color`
- `class_name RuneCircle extends Node2D`, vars `radius`, `duration`, `slow`

- [ ] **Step 1: Failing check.** Run the game and eval `return [world.hero.has_method(&"slow"), ResourceLoader.exists("res://scripts/projectiles/shell.gd")]` plus a spawned goblin's `has_method(&"slow")`. Expected: all false.
- [ ] **Step 2: Enemy slow.** Add to `enemy.gd`:
```gdscript
## Movement is multiplied by this while slowed (1 = normal).
var _slow_factor := 1.0
var _slow_left := 0.0
```
In `_physics_process`, after `_repath_left -= delta`:
```gdscript
	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0:
			_slow_factor = 1.0
```
Change `velocity = direction * definition.move_speed` to `velocity = direction * definition.move_speed * _slow_factor`. Add:
```gdscript
## Slows movement to `factor` (0.6 = 60% speed) for `seconds`. The strongest
## slow wins; a new one refreshes the time.
func slow(factor: float, seconds: float) -> void:
	_slow_factor = minf(_slow_factor, factor) if _slow_left > 0.0 else factor
	_slow_left = maxf(_slow_left, seconds)


func speed_multiplier() -> float:
	return _slow_factor
```
- [ ] **Step 3: Shell** `scripts/projectiles/shell.gd`:
```gdscript
class_name Shell
extends Node2D
## A mortar shell: flies from `from` to `target` over flight_time on an arc,
## with a shadow on the ground and a faint circle marking where it lands. On
## landing it damages every living enemy within `radius`, flashes, and can
## leave a RuneCircle that slows enemies.

## Emitted once per enemy damaged; `killed` if that finished it.
signal hit(damage: float, killed: bool)

const BLAST_TIME := 0.25

var from := Vector2.ZERO
var target := Vector2.ZERO
var flight_time := 0.9
var arc_height := 90.0
var damage := 14.0
var radius := 70.0
## Seconds the landing leaves a slowing rune circle for; 0 = none.
var rune_duration := 0.0
## Share of speed taken away inside the circle (0.4 = 40% slower).
var rune_slow := 0.0
var color := Color(0.45, 0.85, 1.0)

var _time := 0.0
var _blast_left := 0.0


func _ready() -> void:
	global_position = from
	z_index = 5


func _physics_process(delta: float) -> void:
	if _blast_left > 0.0:
		_blast_left -= delta
		queue_redraw()
		if _blast_left <= 0.0:
			queue_free()
		return
	_time += delta
	var t := minf(_time / flight_time, 1.0)
	global_position = from.lerp(target, t)
	queue_redraw()
	if t >= 1.0:
		_land()


func _land() -> void:
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy.health.is_dead or enemy.global_position.distance_to(target) > radius:
			continue
		enemy.health.take_damage(damage)
		hit.emit(damage, enemy.health.is_dead)
	if rune_duration > 0.0:
		var circle := RuneCircle.new()
		circle.radius = radius
		circle.duration = rune_duration
		circle.slow = rune_slow
		circle.color = color
		circle.global_position = target
		get_parent().add_child(circle)
	_blast_left = BLAST_TIME


## Height above the ground at flight progress t (0..1): a parabola.
func _height(t: float) -> float:
	return arc_height * 4.0 * t * (1.0 - t)


func _draw() -> void:
	var landing := to_local(target)
	if _blast_left > 0.0:
		var k := 1.0 - _blast_left / BLAST_TIME
		draw_circle(Vector2.ZERO, radius * (0.4 + 0.6 * k), Color(color, 0.45 * (1.0 - k)))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(Color.WHITE, 0.8 * (1.0 - k)), 3.0)
		return
	var t := minf(_time / flight_time, 1.0)
	# Where it will land.
	draw_arc(landing, radius, 0.0, TAU, 48, Color(color, 0.25 + 0.35 * t), 1.5)
	# Shadow on the ground, then the shell above it.
	draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.35))
	var up := Vector2(0, -_height(t))
	draw_circle(up, 9.0, Color(color, 0.3))
	draw_circle(up, 5.0, Color.WHITE.lerp(color, 0.5))
```
- [ ] **Step 4: RuneCircle** `scripts/projectiles/rune_circle.gd`:
```gdscript
class_name RuneCircle
extends Node2D
## A glowing rune ring left by a Rune Shell: enemies inside are slowed while
## it lasts. Fades out over its last second.

var radius := 140.0
var duration := 4.0
## Share of speed taken away inside (0.4 = move at 60%).
var slow := 0.4
var color := Color(0.45, 0.85, 1.0)

var _left := 0.0


func _ready() -> void:
	_left = duration
	z_index = -1


func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if not enemy.health.is_dead and enemy.global_position.distance_to(global_position) <= radius:
			# Short refresh: the slow ends soon after leaving the circle.
			enemy.slow(1.0 - slow, 0.2)
	queue_redraw()


func _draw() -> void:
	var alpha := clampf(_left, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(color, 0.12 * alpha))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color, 0.7 * alpha), 3.0)
	draw_arc(Vector2.ZERO, radius * 0.7, 0.0, TAU, 48, Color(color, 0.35 * alpha), 1.5)
```
- [ ] **Step 5: Verify.** Import, headless check, then eval: spawn 3 goblins (`waves.spawn_at`) at `core + (-700, 0)`, `(-700, 50)`, `(-700, 200)` with `health.reset(100)`. Add a Shell to `world.units` with `from = core + (-400, 0)`, `target = core + (-700, 20)`, `radius 70`, `damage 14`, `rune_duration 4`, `rune_slow 0.4`. Wait 60 frames (1 s). Expected:
  - goblins 1 and 2 at 86 health, goblin 3 at 100
  - a RuneCircle exists
  - goblin 1 `speed_multiplier()` is 0.6
  Then wait 300 frames: the circle is gone, and goblin 1's `speed_multiplier()` is 1.0. Kill one slowed goblin mid-circle (`take_damage(99999)`): no errors. Screenshot mid-flight and during the circle.
- [ ] **Step 6: Commit** `Add mortar shells, rune circles and enemy slows`.

---

### Task 2: MortarTower (automatic) and building it

**Files:** Modify `scripts/towers/tower_definition.gd` (`scene`), `scripts/towers/build_slot.gd` (use it), `scripts/towers/tower.gd` (`_operated_aim_point` hook). Create `scripts/towers/mortar_definition.gd`, `scripts/towers/mortar_tower.gd`, `scenes/towers/mortar_tower.tscn`. Rewrite `data/towers/rune_mortar.tres`.

**Interfaces:**
- Consumes: `Shell` (Task 1)
- Produces: `TowerDefinition.scene: PackedScene`; `Tower._operated_aim_point() -> Vector2`; `class_name MortarDefinition` (fields in Global Constraints: `splash_radius`, `min_range`, `shell_flight_time`, `shell_arc_height`, `operated_splash_multiplier`, `rune_damage_multiplier`, `rune_radius_multiplier`, `rune_slow`, `rune_duration`); `class_name MortarTower` with `splash_radius() -> float`, `min_range() -> float`

- [ ] **Step 1: Gearshot baseline + failing check.** Run the game. Build a Gearshot on `BuildSlotWest`, spawn a goblin 200 px left of it with 9999 health, and wait 120 frames. Record the goblin's health lost, `t.damage()`, `t.fire_rate()`, `t.attack_range()`, and the class of the fired projectiles (`find_children("*", "Projectile")`). Then operate it, press Q, and record `t.fire_rate()` (×3 → 6.75). Also eval `load("res://data/towers/rune_mortar.tres").available` → `false`, and `"scene" in load(...)` → `false`.
- [ ] **Step 2: Hooks.** `TowerDefinition`: add after `sprite_scale`:
```gdscript
## Scene to build for this tower type; empty uses the standard tower scene.
## Towers with their own behaviour (e.g. the Rune Mortar) set their own.
@export var scene: PackedScene
```
`BuildSlot.build()`: `built = (tower.scene if tower.scene else TOWER_SCENE).instantiate()`.
`Tower._physics_process`: replace `aim_point = operator.get_global_mouse_position()` with `aim_point = _operated_aim_point()`, and add in the Targeting section:
```gdscript
## Where an operated tower aims: the mouse. Tower types can clamp it.
func _operated_aim_point() -> Vector2:
	return operator.get_global_mouse_position()
```
- [ ] **Step 3: MortarDefinition** `scripts/towers/mortar_definition.gd`:
```gdscript
class_name MortarDefinition
extends TowerDefinition
## A Rune Mortar's extra settings: lobbed splash shells that can't hit up
## close, and the Rune Shell ability.

@export_group("Mortar")
## Damage reaches every enemy within this of the impact point, in pixels.
@export var splash_radius := 70.0
## Targets closer than this can't be shelled, in pixels.
@export var min_range := 110.0
## Seconds a shell is in the air.
@export var shell_flight_time := 0.9
## How high the shell's arc peaks, in pixels.
@export var shell_arc_height := 90.0
## Splash radius multiplier while operated.
@export var operated_splash_multiplier := 1.25
## Where shells leave from, relative to the base point, facing right.
@export var muzzle_offset := Vector2(8, -88)

@export_group("Rune Shell")
@export var rune_damage_multiplier := 2.0
@export var rune_radius_multiplier := 2.0
## Share of speed taken away inside the rune circle (0.4 = 40% slower).
@export var rune_slow := 0.4
## Seconds the rune circle lasts.
@export var rune_duration := 4.0
```
- [ ] **Step 4: MortarTower** `scripts/towers/mortar_tower.gd`:
```gdscript
class_name MortarTower
extends Tower
## The Rune Mortar: lobs splash shells. On its own it shells the biggest
## clump of enemies (leading them); operated, shells land on the mouse
## (clamped to its minimum and maximum range) and Q fires a Rune Shell.
## It can't hit anything closer than min_range.

var mortar: MortarDefinition
## Which way the barrel faces (the art faces right).
var _facing_left := false


func _ready() -> void:
	mortar = definition as MortarDefinition
	assert(mortar != null, "A MortarTower needs a MortarDefinition")
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	_show_charge()
	if operator:
		queue_redraw()


func splash_radius() -> float:
	return mortar.splash_radius * (mortar.operated_splash_multiplier if operator else 1.0)


func min_range() -> float:
	return mortar.min_range


## Biggest clump in range: the enemy with the most others within splash
## radius of it (nearest breaks ties), outside the minimum range.
func _find_target() -> Enemy:
	var candidates: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		var distance := global_position.distance_to(enemy.global_position)
		if not enemy.health.is_dead and distance >= min_range() and distance <= attack_range():
			candidates.append(enemy)
	var best: Enemy = null
	var best_count := -1
	var best_distance := INF
	for enemy in candidates:
		var count := 0
		for other in candidates:
			if other.global_position.distance_to(enemy.global_position) <= splash_radius():
				count += 1
		var distance := global_position.distance_to(enemy.global_position)
		if count > best_count or (count == best_count and distance < best_distance):
			best = enemy
			best_count = count
			best_distance = distance
	return best


## Lead the target: where it will be when the shell lands (its feet).
func _aim_point(enemy: Enemy) -> Vector2:
	return enemy.global_position + enemy.velocity * mortar.shell_flight_time


## The mouse, pulled in or out to lie between min range and range.
func _operated_aim_point() -> Vector2:
	var offset := operator.get_global_mouse_position() - global_position
	if offset.length() < 0.001:
		offset = Vector2.RIGHT if not _facing_left else Vector2.LEFT
	return global_position + offset.normalized() * clampf(offset.length(), min_range(), attack_range())


func _aim_at(point: Vector2) -> void:
	_facing_left = point.x < global_position.x
	sprite.flip_h = _facing_left


func _muzzle_base() -> Vector2:
	var offset := mortar.muzzle_offset
	return global_position + Vector2(-offset.x if _facing_left else offset.x, offset.y)


func _fire_at(point: Vector2) -> void:
	_launch(point, damage(), splash_radius(), 0.0)
	_show(&"fire")
	_fire_frame_left = 0.35


## Fires a Rune Shell at the aim point if it's recharged.
func use_ability() -> void:
	if operator == null or _ability_cooldown_left > 0.0:
		return
	_ability_cooldown_left = definition.ability_cooldown
	var point := _operated_aim_point()
	_aim_at(point)
	_launch(point, damage() * mortar.rune_damage_multiplier,
			splash_radius() * mortar.rune_radius_multiplier, mortar.rune_duration)
	_show(&"fire")
	_fire_frame_left = 0.35


func _launch(point: Vector2, shell_damage: float, radius: float, rune_duration: float) -> void:
	var shell := Shell.new()
	shell.from = _muzzle_base()
	shell.target = point
	shell.flight_time = mortar.shell_flight_time
	shell.arc_height = mortar.shell_arc_height
	shell.damage = shell_damage
	shell.radius = radius
	shell.rune_duration = rune_duration
	shell.rune_slow = mortar.rune_slow
	if operator:
		shell.hit.connect(func(dealt: float, _killed: bool) -> void: mastery_xp += dealt)
	projectile_parent.add_child(shell)


## Idle frames show the reload: frame 0 just fired, the last frame ready.
func _show_charge() -> void:
	if _fire_frame_left > 0.0 or is_destroyed():
		return
	var idle := StringName("lv%d_idle" % level)
	if sprite.animation != idle:
		sprite.animation = idle
	sprite.stop()
	var frames := sprite.sprite_frames.get_frame_count(idle)
	var charged := 1.0 - clampf(_cooldown * fire_rate(), 0.0, 1.0)
	sprite.frame = mini(floori(charged * frames), frames - 1)


## While operated: outer reach, the inner no-fire ring, and the aim reticle.
func _draw() -> void:
	if operator == null:
		return
	var reach := Color(0.45, 0.85, 1.0)
	draw_circle(Vector2.ZERO, attack_range(), Color(reach, 0.04))
	draw_arc(Vector2.ZERO, attack_range(), 0.0, TAU, 96, Color(reach, 0.35), 2.0)
	draw_arc(Vector2.ZERO, min_range(), 0.0, TAU, 48, Color(1.0, 0.45, 0.35, 0.4), 1.5)
	var aim := to_local(_operated_aim_point())
	draw_arc(aim, splash_radius(), 0.0, TAU, 48, Color(reach, 0.6), 2.0)
	draw_line(aim + Vector2(-8, 0), aim + Vector2(8, 0), Color(reach, 0.9), 2.0)
	draw_line(aim + Vector2(0, -8), aim + Vector2(0, 8), Color(reach, 0.9), 2.0)
```
Notes for the implementer:
- `Tower._ready` must not fail for the mortar: it has no heads, so `_setup_head()` returns early.
- `_show(&"idle")` plays the idle animation because `aim_angles` is empty. `_show_charge` then stops it on the reload frame each physics step.
- Death: `Tower._on_died` sets the destroyed art and turns off physics processing, so the charge display stops.
- `_turn_head` / `_head_on_target` return early or true without a head.

`scenes/towers/mortar_tower.tscn`:
```
[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://scenes/towers/tower.tscn" id="1_tower"]
[ext_resource type="Script" path="res://scripts/towers/mortar_tower.gd" id="2_mortar"]

[node name="MortarTower" instance=ExtResource("1_tower")]
script = ExtResource("2_mortar")
```
`data/towers/rune_mortar.tres`: `script_class="MortarDefinition"`, script = `mortar_definition.gd`, `scene` = the mortar scene, `available` removed (true), and:
- sprite_scale 0.55; cost `{scrap: 15}`; lv2_cost `{scrap: 20}`; lv3_cost `{scrap: 30, aether: 3}`
- max_health 150; attack_damage 14; attacks_per_second 0.5; attack_range 420
- operated_damage_multiplier 1.35; operated_fire_rate_multiplier 1.0; operated_range_multiplier 1.15
- ability_name "Rune Shell"; ability_cooldown 15
- keep id, display_name, description, sprite_frames
- [ ] **Step 5: Verify.** Import, headless check. Eval:
  - **Gearshot baseline** (Step 1 again): identical numbers, projectiles are still `Projectile`s.
  - **Build** a Mortar on `BuildSlotEast` (`s.build(load(".../rune_mortar.tres"))`): 15 Scrap spent, `s.built is MortarTower`.
  - **Clump over nearest:** spawn 1 goblin 200 px right of the tower (nearer) and 3 goblins together 350 px right. Freeze them with `set_physics_process(false)` so they stand still. `t._find_target()` is one of the 3.
  - **Min range:** a goblin 80 px away and nothing else in range gives `_find_target() == null`, and no shell fires in 120 frames (Review Focus 1).
  - **Leading:** unfreeze one goblin walking at speed 70 and fire. The shell's `target` is within ~20 px of where the goblin actually is at landing (compare after 0.9 s).
  - **Auto splash:** the clump of 3 all lose 14 after the first shell lands.
  - **Shell outlives its tower:** fire, then `s.sell()` at once. The shell still lands, with no errors (Review Focus 4).
  - Screenshot the mortar firing (fire frame) and a shell mid-flight.
- [ ] **Step 6: Commit** `Add the Rune Mortar tower (automatic fire)`.

---

### Task 3: Operating the Mortar

Operating is already in the Task 2 code (`_operated_aim_point`, `use_ability`, `_draw`). This task verifies it and fixes anything found.

- [ ] **Step 1: Verify.**
  - Build a Mortar and operate it (`hero.start_operating(t)`, `auto_fire = false`).
  - **Aim:** warp the mouse 300 px from the tower → `_operated_aim_point()` is 300 px away. At 900 px → clamped to `attack_range()` (483 operated). At 20 px → clamped to 110. Mouse exactly on the tower → a valid point 110 px away, no NaN (Review Focus 2).
  - **Operated shot:** fire once with `auto_fire` true. The shell lands at the aim point, and goblins placed there lose `14 × 1.35 = 18.9`. Mastery XP rises by the damage dealt.
  - **Rune Shell:** press Q (`t.use_ability()`) at a clump. Damage is `37.8`, radius `70 × 1.25 × 2 = 175`, a RuneCircle appears, and goblins inside have `speed_multiplier() == 0.6`. Q again right away does nothing. The HUD reads `[Q] Rune Shell recharging: 15s`.
  - **Upgrade:** the Mortar at Lv3 costs 20 then 30 + 3 Aether, and switches to the level 3 art.
  - Screenshots: operated rings with the reticle, and the rune circle.
- [ ] **Step 2: Commit** any fixes as `Fix operated Rune Mortar <what>`. If nothing needed fixing, record that in the ledger (no commit).

---

### Task 4: Roadmap

- [ ] Tick `- [x] **[AI]** Rune Mortar (long-range splash): ...` with a one-line summary (costs, clump targeting, click-to-target, Rune Shell), and mark `3) Mortar ✅` in the order line. Commit `Tick the Rune Mortar on the roadmap`.
