# Goblin Shaman Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Goblin Shaman that hangs back throwing slow magic orbs and, every few seconds, casts a pulse that frenzies nearby goblins (+30% speed and damage for 4 s).

**Architecture:** Frenzy is a status effect on `Enemy` like slow, burn and stun. A ranged attack becomes a data option on `EnemyDefinition` (`attack_animation`, `projectile_scene`, `projectile_speed`), fired through the existing `Projectile` class. The pulse is a small `FrenzyPulse` node an enemy adds to itself when its data has `pulse_interval > 0`. The Shaman is then just `data/enemies/goblin_shaman.tres` plus wave groups.

**Tech Stack:** Godot 4.7 GDScript; verification via the Godot MCP tools in the running game.

**Spec:** `docs/superpowers/specs/2026-09-29-goblin-shaman-design.md`

## Global Constraints

- Frenzy: `Enemy.frenzy(speed_bonus, damage_bonus, seconds)`; refreshes the timer, keeps the stronger bonuses, never stacks; ignored when dead; ends on death. Speed ×(1 + speed_bonus) combined with slow; damage ×(1 + damage_bonus) for melee and orbs. Tint `Color(1.0, 0.4, 0.35)`; priority stun > frenzy > burn.
- Ranged: `attack_animation` (default `&"attack"`), `projectile_scene` (null = melee), `projectile_speed` (default 260). Orb damage = `attack_damage` ×frenzy, **magic**; aimed at the target's current position; flies target distance + 60 px.
- Orb collision mask = 10 (hero layer 2 + structures layer 8). An invulnerable target (operating hero) is passed through, not hit.
- Pulse: first 2 s after spawning, then every `pulse_interval`; waits until alive, not stunned, not mid-attack; stands still and plays `pulse_animation`; on finish frenzies every **other** living enemy within `pulse_radius`; a stun or death mid-cast cancels it; a 0.3 s expanding ring shows the reach.
- Goblin Shaman: sprites `goblin_shaman.tres`, scale 0.3; `attack_animation = cast`, hit frame 3; 40 health; speed 60; 6 damage at 0.5/s; attack range 220; aggro 220; physical 1.0, fire 1.0, magic 0.7; pulse every 6 s, 160 px, +0.3 / +0.3 for 4 s; drops 2–3 Scrap, 15% Aether.
- Waves: W2 ShamanWest ×1 (delay 5); W3 ShamanEast ×1 (delay 4); W4 ShamanNorth ×1 (delay 4) + ShamanWest ×1 (delay 6); W5 ShamanEast ×1 (delay 5) + ShamanWest ×1 (delay 9). Interval 2.0 for all.
- Basic and Armored Goblins behave exactly as before.
- Branch `feature/goblin-shaman`; one commit per task (`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`); stage only the task's files.
- New `class_name` or changed PNG/scene imports → `godot --headless --editor --path . --import` before checks.
- MCP: `run_project` injects its bridge into `project.godot`; after `stop_project`, run `git diff project.godot` and remove only the bridge lines (physics interpolation must stay on). The first `game_eval` after `run_project` says "Not connected" (retry). A script error in an eval freezes the game (check `get_debug_output`, restart). Never `queue_free` living enemies or disable the WaveDirector; kill with `health.take_damage(999999, Health.DamageType.MAGIC)`. Frozen enemies (`set_physics_process(false)`) also stop their effect timers. Move the hero far away (it auto-fires at goblins within 500 px). Do timing checks inside one `game_eval`. The Core regenerates 10 hp every 5 s: measure hits via `health.damaged`, not totals.
- In evals: `var world = get_tree().current_scene`, `world.waves.spawn_at(def, pos) -> Enemy`, `world.units`, `world.hero`, `world.core` (check `world.gd` names if one differs).

## Review Focus

1. **Operating a tower near a Shaman:** orbs aimed at the operated tower must not be swallowed by the invulnerable hero standing next to it. The tower takes the damage (Task 2 test).
2. **Frenzy plus slow** (a frenzied goblin inside a Rune circle): the speed is slow × frenzy, and neither effect cancels the other (Task 1 test).
3. **A dead Shaman:** its corpse lies there 1.5 s and must never pulse, shoot or draw a ring (Task 3 test).
4. **A lone Shaman:** a pulse with no goblins nearby still plays, restarts its timer and throws no errors (Task 3 test).
5. **A Shaman whose target dies or leaves reach mid-cast:** no orb is thrown at a corpse or out of reach, and it retargets as usual (Task 2 test).

---

### Task 1: Frenzy status on enemies

**Files:** Modify `scripts/enemies/enemy.gd`.

**Interfaces:**
- Consumes: nothing new.
- Produces: `Enemy.frenzy(speed_bonus: float, damage_bonus: float, seconds: float) -> void`, `Enemy.is_frenzied() -> bool`, `Enemy.attack_damage() -> float`; `Enemy.speed_multiplier()` now includes frenzy.

- [ ] **Step 1: Failing check.** Run the game and eval `return get_tree().current_scene.waves.spawn_at(load("res://data/enemies/goblin.tres"), Vector2(200, 200)).has_method(&"frenzy")`. Expected: `false`. Kill that goblin.
- [ ] **Step 2: State.** In `enemy.gd`, after the `_stun_left` var:
```gdscript
## Frenzy (from a Shaman's pulse): extra speed and damage until
## _frenzy_left runs out.
var _frenzy_speed := 0.0
var _frenzy_damage := 0.0
var _frenzy_left := 0.0
```
- [ ] **Step 3: Tick it.** In `_physics_process`, right after the `_slow_left` block:
```gdscript
	if _frenzy_left > 0.0:
		_frenzy_left -= delta
		if _frenzy_left <= 0.0:
			_frenzy_speed = 0.0
			_frenzy_damage = 0.0
```
Change the movement line to `velocity = direction * definition.move_speed * speed_multiplier()`.
- [ ] **Step 4: Methods.** Replace `speed_multiplier()` and add after it:
```gdscript
func speed_multiplier() -> float:
	return _slow_factor * (1.0 + _frenzy_speed)


## Frenzy: moves `speed_bonus` faster and hits `damage_bonus` harder
## (0.3 = +30%) for `seconds`. A new frenzy restarts the time and keeps the
## stronger bonuses; it never stacks.
func frenzy(speed_bonus: float, damage_bonus: float, seconds: float) -> void:
	if health.is_dead:
		return
	var active := _frenzy_left > 0.0
	_frenzy_speed = maxf(_frenzy_speed, speed_bonus) if active else speed_bonus
	_frenzy_damage = maxf(_frenzy_damage, damage_bonus) if active else damage_bonus
	_frenzy_left = maxf(_frenzy_left, seconds)


func is_frenzied() -> bool:
	return _frenzy_left > 0.0


## Damage of one hit, including any frenzy.
func attack_damage() -> float:
	return definition.attack_damage * (1.0 + _frenzy_damage)
```
In `_on_frame_changed`, `target_health.take_damage(definition.attack_damage)` → `target_health.take_damage(attack_damage())`.
- [ ] **Step 5: Tint and death.** `_update_tint()` becomes:
```gdscript
## Stun (pale blue) shows over frenzy (red) over burn (orange); all flicker.
func _update_tint() -> void:
	var flicker := sin(Time.get_ticks_msec() * 0.02)
	if _stun_left > 0.0:
		sprite.modulate = Color.WHITE.lerp(Color(0.6, 0.85, 1.0), 0.45 + 0.15 * flicker)
	elif _frenzy_left > 0.0:
		sprite.modulate = Color.WHITE.lerp(Color(1.0, 0.4, 0.35), 0.35 + 0.15 * flicker)
	elif _burn_stacks > 0:
		sprite.modulate = Color.WHITE.lerp(Color(1.0, 0.55, 0.25), 0.25 + 0.1 * flicker)
	else:
		sprite.modulate = Color.WHITE
```
In `_on_died()`, after `_stun_left = 0.0`:
```gdscript
	_frenzy_left = 0.0
	_frenzy_speed = 0.0
	_frenzy_damage = 0.0
```
- [ ] **Step 6: Verify.** `validate_scripts`, run the game, move the hero to a far corner, and eval (one eval per bullet, timing inside the eval):
  - **Speed:** spawn a goblin 600 px from the Core. Measure its distance moved over 60 physics frames. Call `frenzy(0.3, 0.3, 4.0)` and measure again. Expected ratio 1.25–1.35. `is_frenzied()` is `true`, then `false` after 4.2 s.
  - **Damage:** spawn a goblin beside the Core and connect to `world.core.health.damaged`. The unfrenzied hit is 5; after `frenzy(0.3, 0.3, 10.0)` it's 6.5.
  - **No stacking:** `frenzy(0.3, 0.3, 4)` then `frenzy(0.2, 0.1, 2)` leaves `_frenzy_speed == 0.3`, `_frenzy_damage == 0.3` and `_frenzy_left` ≈ 4.
  - **Review Focus 2:** `slow(0.6, 5)` + `frenzy(0.3, 0.3, 5)` gives `speed_multiplier()` ≈ 0.78, and the measured speed matches.
  - **Tint:** a stunned + frenzied goblin is pale blue. Frenzied + burning is red. Burning only is orange. Take a screenshot of a frenzied goblin next to a normal one.
  - **Dead:** `frenzy()` on a killed goblin leaves `is_frenzied()` `false`.
  - Stop the game and clean `project.godot`.
- [ ] **Step 7: Commit** `Let enemies be frenzied`.

---

### Task 2: Ranged attacks, the enemy orb and the Goblin Shaman

**Files:** Modify `scripts/enemies/enemy_definition.gd`, `scripts/enemies/enemy.gd`, `scripts/projectiles/projectile.gd`. Create `scenes/projectiles/enemy_orb.tscn`, `data/enemies/goblin_shaman.tres`.

**Interfaces:**
- Consumes: `Enemy.attack_damage()` (Task 1).
- Produces: `EnemyDefinition.attack_animation: StringName`, `.projectile_scene: PackedScene`, `.projectile_speed: float`; `Projectile.draw_streak: bool`; `res://scenes/projectiles/enemy_orb.tscn`; `res://data/enemies/goblin_shaman.tres`.

- [ ] **Step 1: Failing check.** Eval `ResourceLoader.exists("res://data/enemies/goblin_shaman.tres")`. Expected: `false`.
- [ ] **Step 2: Definition.** In `enemy_definition.gd`, change the class comment's last sentence to "Sprites must face right and have idle, walk and death animations, plus the attack animation (`attack` unless set below)." After `attack_hit_frame` add:
```gdscript
## Animation played for each attack; the hit (or shot) comes on attack_hit_frame.
@export var attack_animation: StringName = &"attack"
## When set, each attack throws this projectile (magic damage) at the target
## instead of hitting it directly. Empty = melee.
@export var projectile_scene: PackedScene
## Pixels per second.
@export var projectile_speed := 260.0
```
- [ ] **Step 3: Enemy.** In `enemy.gd`, replace each `&"attack"` with `definition.attack_animation`. There are three: the `sprite.play(&"attack")` in `_physics_process`, `_is_attacking()` and `_on_frame_changed()`. The end of `_on_frame_changed` becomes:
```gdscript
	var target_health := _target.get_node(^"Health") as Health
	if target_health.is_dead:
		return
	if definition.projectile_scene:
		_shoot(_target)
	else:
		target_health.take_damage(attack_damage())


## Throws the definition's projectile from the body at `target`'s current
## position; it flies a little past it, then fades out.
func _shoot(target: Node2D) -> void:
	var from := hurtbox_shape.global_position
	var to_target := target.global_position - from
	var shot: Projectile = definition.projectile_scene.instantiate()
	shot.global_position = from
	shot.direction = to_target.normalized()
	shot.speed = definition.projectile_speed
	shot.damage = attack_damage()
	shot.damage_type = Health.DamageType.MAGIC
	shot.max_distance = to_target.length() + 60.0
	get_parent().add_child(shot)
```
- [ ] **Step 4: Projectile.** In `projectile.gd`:
  - Add after `radius`:
```gdscript
## Draw the placeholder streak; off for scenes with their own sprite.
@export var draw_streak := true
```
  - In `_on_hit`, change the check to `if health == null or health.is_dead or health.invulnerable:`, with the comment `# Dead or untouchable (an operating hero): fly on through.` above it.
  - Start `_draw()` with `if not draw_streak: return`.
  - Update the class comment: "damages the first thing it touches that has a Health child and can be hurt".
- [ ] **Step 5: Orb scene** `scenes/projectiles/enemy_orb.tscn`:
```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/projectiles/projectile.gd" id="1_projectile"]
[ext_resource type="Texture2D" path="res://assets/sprites/goblin_shaman.png" id="2_sheet"]

[sub_resource type="AtlasTexture" id="AtlasTexture_orb"]
atlas = ExtResource("2_sheet")
region = Rect2(51, 768, 217, 124)

[sub_resource type="CircleShape2D" id="CircleShape2D_orb"]
radius = 6.0

[node name="EnemyOrb" type="Area2D"]
collision_layer = 0
collision_mask = 10
monitorable = false
script = ExtResource("1_projectile")
draw_streak = false

[node name="Sprite" type="Sprite2D" parent="."]
scale = Vector2(0.11, 0.11)
texture = SubResource("AtlasTexture_orb")
offset = Vector2(-75, 0)

[node name="Shape" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_orb")
```
  The region is the visible part of the sheet's `projectile` cell. The offset puts the glowing head at the node's origin, which is where it collides.
- [ ] **Step 6: Shaman data** `data/enemies/goblin_shaman.tres`:
```
[gd_resource type="Resource" script_class="EnemyDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/enemies/enemy_definition.gd" id="1_def"]
[ext_resource type="SpriteFrames" path="res://assets/sprites/goblin_shaman.tres" id="2_frames"]
[ext_resource type="PackedScene" path="res://scenes/projectiles/enemy_orb.tscn" id="3_orb"]

[resource]
script = ExtResource("1_def")
id = &"goblin_shaman"
display_name = "Goblin Shaman"
sprite_frames = ExtResource("2_frames")
sprite_scale = 0.3
max_health = 40.0
move_speed = 60.0
attack_damage = 6.0
attacks_per_second = 0.5
attack_range = 220.0
aggro_range = 220.0
attack_hit_frame = 3
attack_animation = &"cast"
projectile_scene = ExtResource("3_orb")
magic_taken = 0.7
drops = Dictionary[StringName, Vector2i]({
&"scrap": Vector2i(2, 3)
})
rare_drops = Dictionary[StringName, float]({
&"aether": 0.15
})
```
- [ ] **Step 7: Verify.** Import, `validate_scripts`, run the game, move the hero to a far corner, then eval:
  - **Stats:** spawn a Shaman: max health 40, `health.damage_taken == [1.0, 1.0, 0.7]`, walk speed ≈60 px/s.
  - **Orbs:** spawn one 500 px from the Core and connect to `world.core.health.damaged`. It stops about 220 px + the Core's `hit_radius` away. Over 8 s it lands 3–4 hits of 6 magic each, about 2 s apart. The orb node exists in `world.units` while flying and is freed after it hits.
  - **Walls block:** build a tower on a slot and put a Shaman on the far side of that slot's wall, aiming at the Core. A wall piece loses health and the Core doesn't.
  - **Review Focus 1:** with the hero operating a tower and a Shaman in range, the tower's Health drops by 6 per orb over 10 s. The hero's health doesn't change.
  - **Review Focus 5:** put the hero in the Shaman's range, then kill the hero (`hero.health.take_damage(999999)`) while the Shaman is on `cast` frames 0–2. No orb spawns, and the Shaman goes back to the Core.
  - **Melee unchanged:** a basic goblin still hits the Core for 5 and an Armored Goblin for 8, with no orb nodes spawned.
  - **Size and look:** screenshot a Shaman beside a basic goblin, and an orb in flight. If the Shaman looks noticeably bigger or smaller, adjust `sprite_scale` (0.27–0.33). If the orb's head isn't at the collision point (enable `get_tree().debug_collisions_hint` or draw a marker), adjust `offset`.
  - **Frame:** screenshot the Shaman on each `cast` frame. The orb should leave on the frame where the staff points forward. If that isn't frame 3, set `attack_hit_frame` to it.
  - **Loot:** kill 10 Shamans. Each drops 2–3 Scrap.
  - Stop the game and clean `project.godot`.
- [ ] **Step 8: Commit** `Add the Goblin Shaman's ranged orb`.

---

### Task 3: The frenzy pulse

**Files:** Create `scripts/enemies/frenzy_pulse.gd`, `scenes/enemies/frenzy_pulse.tscn`. Modify `scripts/enemies/enemy_definition.gd`, `scripts/enemies/enemy.gd`, `data/enemies/goblin_shaman.tres`, `assets/sprites/goblin_shaman.tres`, `tools/slice_sprites.py`.

**Interfaces:**
- Consumes: `Enemy.frenzy()`, `Enemy.is_frenzied()` (Task 1); `goblin_shaman.tres` (Task 2).
- Produces: `EnemyDefinition.pulse_interval`, `.pulse_radius`, `.pulse_duration`, `.pulse_speed_bonus`, `.pulse_damage_bonus`, `.pulse_animation`; `Enemy.pulse_finished(landed: bool)` signal, `Enemy.can_pulse() -> bool`, `Enemy.start_pulse() -> void`; `class_name FrenzyPulse`.

- [ ] **Step 1: Failing check.** Spawn a Shaman and eval `return shaman.has_signal(&"pulse_finished")`. Expected: `false`.
- [ ] **Step 2: Definition.** At the end of `enemy_definition.gd`:
```gdscript
@export_group("Frenzy pulse")
## Seconds between pulses that frenzy nearby enemies. 0 = never pulses.
@export var pulse_interval := 0.0
## How far a pulse reaches, in pixels.
@export var pulse_radius := 160.0
## Seconds each pulse's frenzy lasts.
@export var pulse_duration := 4.0
## Extra move speed while frenzied (0.3 = +30%).
@export var pulse_speed_bonus := 0.3
## Extra attack damage while frenzied (0.3 = +30%).
@export var pulse_damage_bonus := 0.3
## Played while casting a pulse (must not loop); the frenzy lands when it ends.
@export var pulse_animation: StringName = &"buff"
```
Add to `goblin_shaman.tres`, after `magic_taken`: `pulse_interval = 6.0`.
- [ ] **Step 3: Make `buff` play once.**
  - In `assets/sprites/goblin_shaman.tres`, the `buff` animation's `"loop": true` → `"loop": false`.
  - In `tools/slice_sprites.py`, add `"buff"` to `NO_LOOP`, so re-slicing keeps it that way.
  - Check with `grep -B2 '"name": &"buff"' assets/sprites/goblin_shaman.tres`.
- [ ] **Step 4: Enemy hooks.** In `enemy.gd`:
  - Add below the `killed` signal:
```gdscript
## A pulse cast ended: `landed` is false when a stun or death cut it short.
signal pulse_finished(landed: bool)
```
  - Add below `SPARK_SCENE`: `const FRENZY_PULSE_SCENE := preload("res://scenes/enemies/frenzy_pulse.tscn")`.
  - Add after the frenzy vars: `## True while standing still casting a pulse.` / `var _pulsing := false`.
  - At the end of `_ready()`:
```gdscript
	if definition.pulse_interval > 0.0:
		add_child(FRENZY_PULSE_SCENE.instantiate())
```
  - In `_physics_process`, right after the `if _stun_left > 0.0:` block:
```gdscript
	if _pulsing:
		velocity = Vector2.ZERO
		return
```
  - In `stun()`, after setting `_stun_left`: `_cancel_pulse()`.
  - Add after `is_stunned()`:
```gdscript
## True when it could stop and cast a pulse right now.
func can_pulse() -> bool:
	return not health.is_dead and _stun_left <= 0.0 and not _pulsing and not _is_attacking()


## Stands still playing the pulse animation; pulse_finished follows.
func start_pulse() -> void:
	_pulsing = true
	velocity = Vector2.ZERO
	sprite.play(definition.pulse_animation)
	sprite.frame = 0


func _cancel_pulse() -> void:
	if _pulsing:
		_pulsing = false
		pulse_finished.emit(false)
```
  - At the start of `_on_animation_finished()`:
```gdscript
	if sprite.animation == definition.pulse_animation and _pulsing:
		_pulsing = false
		pulse_finished.emit(true)
		return
```
  - In `_on_died()`, first line: `_cancel_pulse()`.
- [ ] **Step 5: FrenzyPulse** `scripts/enemies/frenzy_pulse.gd`:
```gdscript
class_name FrenzyPulse
extends Node2D
## Added by an Enemy whose definition has a pulse (the Goblin Shaman). Every
## pulse_interval seconds the enemy stops and casts; when the cast finishes,
## every other living enemy within pulse_radius is frenzied. A stun or death
## during the cast cancels it.

## Seconds after spawning before the first pulse.
const FIRST_PULSE := 2.0
## How long the ring showing the pulse's reach stays on screen.
const RING_TIME := 0.3

var _left := FIRST_PULSE
var _casting := false
var _ring_left := 0.0

@onready var enemy: Enemy = get_parent()


func _ready() -> void:
	enemy.pulse_finished.connect(_on_pulse_finished)


func _physics_process(delta: float) -> void:
	if _ring_left > 0.0:
		_ring_left -= delta
		queue_redraw()
	if _casting or enemy.health.is_dead:
		return
	_left -= delta
	if _left <= 0.0 and enemy.can_pulse():
		_casting = true
		enemy.start_pulse()


func _on_pulse_finished(landed: bool) -> void:
	_casting = false
	var def := enemy.definition
	_left = def.pulse_interval
	if not landed:
		return
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy
		if other == enemy or other.health.is_dead:
			continue
		if other.global_position.distance_to(enemy.global_position) <= def.pulse_radius:
			other.frenzy(def.pulse_speed_bonus, def.pulse_damage_bonus, def.pulse_duration)
	_ring_left = RING_TIME
	queue_redraw()


func _draw() -> void:
	if _ring_left <= 0.0:
		return
	var t := 1.0 - _ring_left / RING_TIME
	draw_arc(Vector2.ZERO, enemy.definition.pulse_radius * t, 0.0, TAU, 48,
			Color(1.0, 0.45, 0.35, 0.7 * (1.0 - t)), 3.0)
```
`scenes/enemies/frenzy_pulse.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/enemies/frenzy_pulse.gd" id="1_script"]

[node name="FrenzyPulse" type="Node2D"]
script = ExtResource("1_script")
```
- [ ] **Step 6: Verify.** Import, `validate_scripts`, run the game, move the hero to a far corner, and eval:
  - **Reach:** spawn a Shaman at (300, 300), plus goblin A 100 px away, goblin B 150 px away and goblin C 250 px away. Freeze all four with `set_physics_process(false)` so nobody walks. The Shaman's `FrenzyPulse` child and its sprite keep running, so it still pulses. Await `pulse_finished` (≤ 3 s). A and B are frenzied, C and the Shaman aren't, and `pulse_finished` gave `true`.
  - **Timing:** the first pulse lands 2.0–2.6 s after spawning and the next one 6.0–6.6 s after that. The Shaman's position doesn't change during a cast.
  - **Wears off:** unfreeze A. It's frenzied, then not after 4.2 s.
  - **Stun cancels:** poll until `shaman._pulsing`, then `shaman.stun(1.0)`. `pulse_finished(false)` fires, nobody nearby gets frenzied, and the next pulse comes about 6 s later.
  - **Death cancels:** poll until `_pulsing`, then kill the Shaman. Nobody is frenzied.
  - **Review Focus 3:** after the Shaman dies, wait 2 s. No `pulse_finished` fires, no orb is thrown and `FrenzyPulse._ring_left` stays 0.
  - **Review Focus 4:** a lone Shaman pulses twice in 9 s with no errors (`get_debug_output`).
  - **Two Shamans:** one goblin between two Shamans gets pulsed by both. `_frenzy_speed` stays 0.3.
  - **Others unchanged:** basic and Armored Goblins have no `FrenzyPulse` child.
  - **Screenshots:** the Shaman mid-cast (`buff` pose), the ring at about half size, and frenzied goblins tinted red.
  - Stop the game and clean `project.godot`.
- [ ] **Step 7: Commit** `Add the Goblin Shaman's frenzy pulse`.

---

### Task 4: Shamans in the waves, and the roadmap

**Files:** Modify `scenes/waves/first_run.tscn`, `ROADMAP.md`.

**Interfaces:**
- Consumes: `data/enemies/goblin_shaman.tres` (Tasks 2–3); `SpawnGroup` (`enemy`, `count`, `sector`, `interval`, `delay`).
- Produces: nothing new.

- [ ] **Step 1: Failing check.** `grep -c goblin_shaman scenes/waves/first_run.tscn`. Expected: `0`.
- [ ] **Step 2: Waves.** In `first_run.tscn`:
  - Header `load_steps=6` → `load_steps=7`.
  - Add after the `5_armored` line: `[ext_resource type="Resource" path="res://data/enemies/goblin_shaman.tres" id="6_shaman"]`.
  - Append at the end of the file:
```
[node name="ShamanWest" type="Node" parent="Wave2"]
script = ExtResource("3_group")
enemy = ExtResource("6_shaman")
count = 1
sector = "west"
interval = 2.0
delay = 5.0

[node name="ShamanEast" type="Node" parent="Wave3"]
script = ExtResource("3_group")
enemy = ExtResource("6_shaman")
count = 1
sector = "east"
interval = 2.0
delay = 4.0

[node name="ShamanNorth" type="Node" parent="Wave4"]
script = ExtResource("3_group")
enemy = ExtResource("6_shaman")
count = 1
sector = "north"
interval = 2.0
delay = 4.0

[node name="ShamanWest" type="Node" parent="Wave4"]
script = ExtResource("3_group")
enemy = ExtResource("6_shaman")
count = 1
sector = "west"
interval = 2.0
delay = 6.0

[node name="ShamanEast" type="Node" parent="Wave5"]
script = ExtResource("3_group")
enemy = ExtResource("6_shaman")
count = 1
sector = "east"
interval = 2.0
delay = 5.0

[node name="ShamanWest" type="Node" parent="Wave5"]
script = ExtResource("3_group")
enemy = ExtResource("6_shaman")
count = 1
sector = "west"
interval = 2.0
delay = 9.0
```
- [ ] **Step 3: Roadmap.**
  - Phase 9: `- [ ] **[AI]** Goblin Shaman (buffs nearby goblins)` →
    `- [x] **[AI]** Goblin Shaman (buffs nearby goblins): hangs back and throws slow magic orbs (6 dmg / 2 s, 220 range; walls block them); every 6 s pulses Frenzy on goblins within 160 px (+30% speed and damage for 4 s; stuns and kills cancel the cast); 40 health, speed 60, takes 70% magic; 2–3 Scrap + 15% Aether; 1–2 per wave in waves 2–5.`
  - Phase 1: the line starting `- [x] **[Both]** Running in 8 directions` →
    `- [x] **[Both]** Running in 8 directions: `assets/source/artificer_run.png` has run art for right, down-right and down (left ones mirrored); running up and up-diagonal uses the side-on run with a lean until that art is redone (its frames were nearly identical). The hero picks the walk art by direction, leans into turns, and lines frames up by the body so the run doesn't jitter`
- [ ] **Step 4: Verify.** Run the game and eval:
  - **Wave signature:** from `world.waves.run`, list each wave's groups as (enemy id, count, sector, delay). Waves 2–5 contain the Shaman groups above, and every other group is unchanged from before.
  - **Wave 2 run:** set `Engine.time_scale = 3.0`, start wave 1 and then wave 2 (Enter or the director's start method), and let the hero and towers fight. Wave 2 spawns 1 Shaman and ends cleared with no errors in `get_debug_output`. Reset `Engine.time_scale = 1.0`.
  - **Screenshot:** a Shaman pulsing among goblins mid-wave.
  - Stop the game, clean `project.godot`, and run `grep -n "Goblin Shaman" ROADMAP.md` (expect 2 lines: Phase 9 and the art table).
- [ ] **Step 5: Commit** `Send Goblin Shamans in waves 2 to 5; tick them on the roadmap`.
