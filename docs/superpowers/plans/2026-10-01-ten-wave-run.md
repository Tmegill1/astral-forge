# 10-Wave Run Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A 10-wave run with a placeholder Goblin Warchief mini-boss (wave 6) and Goblin Shaman-King final boss (wave 10), boss health bar, wave banners, and the boss's death winning the run.

**Architecture:** Bosses are `EnemyDefinition` data with new boss fields; `Enemy` gains generic hooks (tint/aura, bosses group, projectile fans, wall-smashing, structure damage, fleeing) and a generalized "channel" (stand still, play an animation) shared by `FrenzyPulse`, a new `Summoner` and a new `BossPhase` (phase 2 + shield). `WaveDirector` wins the run when an `ends_run` enemy dies. `Wave` nodes carry banner text; the HUD shows a `WaveBanner` and a `BossBar`.

**Tech Stack:** Godot 4.7 GDScript; headless test scripts plus the Godot MCP tools.

**Spec:** `docs/superpowers/specs/2026-09-30-ten-wave-run-design.md` (art: `docs/art/2026-09-30-boss-and-evolution-art-brief.md`)

## Global Constraints

- Waves 1–5 unchanged. Waves 6–10 exactly as the spec table (enemy, count, side, interval, delay, prep). Banners: 6 "Wave 6 — The Warchief approaches", 9 "Wave 9 — They're everywhere", 10 "Final wave — The Shaman-King"; others empty → "Wave N".
- Warchief: goblin_brute sprites, scale 0.58, tint Color(1, 0.62, 0.55), aura Color(1, 0.3, 0.2, 0.35); 600 hp; speed 45; phys 0.3 / fire 0.6 / magic 1.0; 20 dmg at 0.6/s; structure ×3; ignores walls; frenzy pulse every 8 s, 250 px, +30%/+30% for 5 s, animation `hurt`; XP 25; Scrap 20–25, guaranteed 5 Aether, guaranteed Lodestone; boss, not ends_run.
- Shaman-King: goblin_shaman sprites, scale 0.66, tint Color(0.8, 0.6, 1.0), aura Color(0.6, 0.3, 1.0, 0.4); 2,500 hp; speed 40; magic 0.6; orbs 8 magic ×5 in a 40° fan, 0.333/s, range 300 (aggro 300); frenzy pulse 6 s, 300 px, +30%/+30% 4 s, anim `buff`; summon 4 Goblins every 12 s in a 60 px ring, anim `buff`; phase 2 at ≤ 50% once: 1.5 s phase-shift channel (anim `buff`), purple screen flash, speed ×1.3, summon interval ÷2, shield: 10% damage taken unless the hero operates a tower whose attack range reaches the boss; XP 60; boss, ends_run.
- `ends_run` death: other living enemies flee (fade 0.6 s, freed, no loot / no `killed`), spawn queue cleared, run won.
- Boss bar: 520×16, top centre under the HUD panels, name above; visible while any `bosses` member is alive (first one).
- Banner: 40 px, upper third centre; fade in 0.3 s, hold 2 s, fade out 0.5 s; boss waves gold text with red (6) / purple (10) outline, others white; ignores the mouse.
- Placeholders now; real-art hand-off is data only.
- Branch `feature/ten-wave-run`; one commit per task (`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`); stage only the task's files; import before checks.
- MCP: first eval says "Not connected" (retry); clean `project.godot` after stopping; evals: `=` not `:=` for untyped, ≤ 25 s, disconnect lambdas; start scene is the main menu (`play_button.pressed.emit()`, 4 frames); `world.waves.break_left = 99999.0`; set `world.run_cards.ended = true` when XP isn't under test (level-ups pause the game); menus under `UI/`; filter spawned nodes by `scene_file_path`.

## Review Focus

1. **The final boss dies while escorts/summons are alive and more are queued**: all flee without loot, nothing else spawns, the Win screen shows "Waves 10 / 10" (Task 2 test).
2. **The Warchief's smash target is destroyed mid-swing, or it's fully walled in**: it re-targets and keeps going toward the Core; never stands idle against a wall (Task 2 test).
3. **The Shaman-King is stunned during a summon or the phase shift** (Spire Resonance): that channel is cancelled; phase 2 still happens once it can channel again; summoning resumes (Task 3 test).
4. **The hero stops operating or dies while the shield is open**: the shield closes again (10% damage) (Task 3 test).
5. **The boss dies off-screen / the run is restarted mid-boss**: the bar hides; the banner and bar don't linger into the next run (Task 4 test).

---

### Task 1: Boss data, waves 6–10 and banner text

**Files:** Modify `scripts/enemies/enemy_definition.gd`, `scripts/waves/wave.gd`, `scripts/waves/wave_definition.gd`, `scenes/waves/first_run.tscn`. Create `data/enemies/goblin_warchief.tres`, `data/enemies/goblin_shaman_king.tres`, `tests/test_waves.gd`.

**Interfaces:**
- Produces: `EnemyDefinition` fields `is_boss: bool`, `ends_run: bool`, `tint: Color`, `aura: Color`, `projectile_count: int`, `projectile_spread_deg: float`, `ignores_walls: bool`, `structure_damage_multiplier: float`, `guaranteed_drops: Dictionary[StringName, int]`, `drops_lodestone: bool`, `summon_interval: float`, `summon_count: int`, `summon_enemy: EnemyDefinition`, `summon_animation: StringName`, `phase2_at: float`, `phase_shift_animation: StringName`; `Wave.banner: String`, `Wave.banner_outline: Color`; `WaveDefinition.banner`, `.banner_outline`. Test command: `godot --headless --path . --script tests/test_waves.gd`.

- [ ] **Step 1: Failing test** `tests/test_waves.gd`:
```gdscript
extends SceneTree
## Headless checks for the run's wave data (scenes/waves/first_run.tscn).
## Run: godot --headless --path . --script tests/test_waves.gd
## Prints each failure and "waves: N passed, M failed"; exits 1 on failure.

var passed := 0
var failed := 0


func _init() -> void:
	var tree = load("res://scenes/waves/first_run.tscn").instantiate()
	var run = tree.to_definition()
	tree.free()
	check("10 waves", run.waves.size(), 10)
	# Waves 1-5 as they were: [enemy id, count, sector, interval, delay] per group.
	var before := {
		0: [["goblin", 6, "west", 2.0, 0.0]],
		1: [["goblin", 5, "west", 1.8, 0.0], ["goblin", 5, "north", 1.8, 4.0], ["goblin_shaman", 1, "west", 2.0, 5.0]],
		2: [["goblin", 7, "east", 1.5, 0.0], ["goblin", 7, "south", 1.5, 3.0], ["armored_goblin", 2, "east", 2.5, 0.0], ["goblin_shaman", 1, "east", 2.0, 4.0]],
	}
	for w in before:
		var groups := []
		for g in run.waves[w].groups:
			groups.append([String(g.enemy.id), g.count, g.sector, g.interval, g.delay])
		check("wave %d unchanged" % (w + 1), groups, before[w])
	var totals := {}
	var bosses := {}
	for w in run.waves.size():
		for g in run.waves[w].groups:
			totals[g.enemy.id] = totals.get(g.enemy.id, 0) + g.count
			if g.enemy.is_boss:
				bosses[g.enemy.id] = w + 1
	check("goblins", totals.get(&"goblin", 0), 236)
	check("armored", totals.get(&"armored_goblin", 0), 39)
	check("shamans", totals.get(&"goblin_shaman", 0), 24)
	check("warchief wave 6", bosses.get(&"goblin_warchief", 0), 6)
	check("king wave 10", bosses.get(&"goblin_shaman_king", 0), 10)
	check("one warchief", totals.get(&"goblin_warchief", 0), 1)
	check("one king", totals.get(&"goblin_shaman_king", 0), 1)
	check("banner 6", run.waves[5].banner, "Wave 6 — The Warchief approaches")
	check("banner 9", run.waves[8].banner, "Wave 9 — They're everywhere")
	check("banner 10", run.waves[9].banner, "Final wave — The Shaman-King")
	check("banner 7 default", run.waves[6].banner, "")
	check("prep times 6-10", [run.waves[5].prep_time, run.waves[6].prep_time, run.waves[7].prep_time, run.waves[8].prep_time, run.waves[9].prep_time], [35.0, 30.0, 30.0, 25.0, 45.0])
	var king: Resource = load("res://data/enemies/goblin_shaman_king.tres")
	check("king ends run", [king.is_boss, king.ends_run, king.projectile_count, king.phase2_at], [true, true, 5, 0.5])
	var chief: Resource = load("res://data/enemies/goblin_warchief.tres")
	check("warchief", [chief.is_boss, chief.ends_run, chief.ignores_walls, chief.structure_damage_multiplier, chief.drops_lodestone], [true, false, true, 3.0, true])
	print("waves: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(label: String, got: Variant, want: Variant) -> void:
	if got == want:
		passed += 1
	else:
		failed += 1
		print("FAIL %s: got %s, want %s" % [label, got, want])
```
  (Wave 1–3 values above come from today's `first_run.tscn`; if Step 2's run shows a different existing value, the existing scene wins — fix the expectation, not the scene, and ledger it.)
- [ ] **Step 2: Run it.** Expected: fails ("10 waves: got 5").
- [ ] **Step 3: Definition fields.** Append to `enemy_definition.gd`:
```gdscript
@export_group("Boss")
## Shows the boss health bar and joins the "bosses" group.
@export var is_boss := false
## Killing it wins the run (every other enemy flees).
@export var ends_run := false
## Multiplies the sprite's colour (white = none). Placeholder bosses use it.
@export var tint := Color.WHITE
## A glowing ring drawn under the feet; transparent = none.
@export var aura := Color(0, 0, 0, 0)
## Ranged attacks fire this many projectiles, fanned over projectile_spread_deg.
@export var projectile_count := 1
@export var projectile_spread_deg := 0.0
## Walks straight at its goal and smashes the first wall or tower it bumps into.
@export var ignores_walls := false
## Damage × this against walls and towers.
@export var structure_damage_multiplier := 1.0
## Always dropped on death, on top of `drops`.
@export var guaranteed_drops: Dictionary[StringName, int] = {}
@export var drops_lodestone := false

@export_group("Summon")
## Seconds between summons; 0 = never summons.
@export var summon_interval := 0.0
@export var summon_count := 4
@export var summon_enemy: EnemyDefinition
## Played while summoning (must not loop).
@export var summon_animation: StringName = &"summon"

@export_group("Phase 2")
## Health share (0-1) at which phase 2 starts; 0 = no phase 2.
@export var phase2_at := 0.0
## Played during the phase change (must not loop).
@export var phase_shift_animation: StringName = &"phase_shift"
```
  `wave.gd`: add
```gdscript
## Big text at the wave's start; empty shows "Wave N".
@export var banner := ""
## Outline colour for the banner's gold text (boss waves); transparent = plain white text.
@export var banner_outline := Color(0, 0, 0, 0)
```
  and in `to_definition()` copy them (`wave.banner = banner`, `wave.banner_outline = banner_outline`). `wave_definition.gd`: add `@export var banner := ""` and `@export var banner_outline := Color(0, 0, 0, 0)`.
- [ ] **Step 4: Boss data.** `data/enemies/goblin_warchief.tres` (ext resources: `enemy_definition.gd`, `goblin_brute.tres` frames):
```
id = &"goblin_warchief"
display_name = "Goblin Warchief"
sprite_frames = <goblin_brute frames>
sprite_scale = 0.58
max_health = 600.0
move_speed = 45.0
attack_damage = 20.0
attacks_per_second = 0.6
attack_range = 24.0
aggro_range = 140.0
attack_hit_frame = 3
physical_taken = 0.3
fire_taken = 0.6
magic_taken = 1.0
drops = { scrap: Vector2i(20, 25) }
xp_value = 25
pulse_interval = 8.0
pulse_radius = 250.0
pulse_duration = 5.0
pulse_animation = &"hurt"
is_boss = true
tint = Color(1, 0.62, 0.55, 1)
aura = Color(1, 0.3, 0.2, 0.35)
ignores_walls = true
structure_damage_multiplier = 3.0
guaranteed_drops = { aether: 5 }
drops_lodestone = true
codex_summary = "The armoured goblins' warlord: a hulking brute with a steam-cleaver."
codex_strengths = PackedStringArray("Smashes straight through walls and towers", "War cry frenzies nearby goblins")
codex_weaknesses = PackedStringArray("Slow", "Alone once his escort falls")
codex_tip = "Pile magic on him before he reaches your walls."
```
  `data/enemies/goblin_shaman_king.tres` (ext: definition script, `goblin_shaman.tres` frames, `enemy_orb.tscn`, `goblin.tres`):
```
id = &"goblin_shaman_king"
display_name = "Goblin Shaman-King"
sprite_frames = <goblin_shaman frames>
sprite_scale = 0.66
max_health = 2500.0
move_speed = 40.0
attack_damage = 8.0
attacks_per_second = 0.333
attack_range = 300.0
aggro_range = 300.0
attack_hit_frame = 3
attack_animation = &"cast"
projectile_scene = <enemy_orb>
magic_taken = 0.6
drops = { scrap: Vector2i(40, 50) }
xp_value = 60
pulse_interval = 6.0
pulse_radius = 300.0
pulse_duration = 4.0
pulse_animation = &"buff"
is_boss = true
ends_run = true
tint = Color(0.8, 0.6, 1, 1)
aura = Color(0.6, 0.3, 1, 0.4)
projectile_count = 5
projectile_spread_deg = 40.0
summon_interval = 12.0
summon_count = 4
summon_enemy = <goblin.tres>
summon_animation = &"buff"
phase2_at = 0.5
phase_shift_animation = &"buff"
codex_summary = "Master of the shamans, floating on a ring of runes."
codex_strengths = PackedStringArray("Fans of magic orbs", "Summons goblins and frenzies them", "Shields itself when wounded")
codex_weaknesses = PackedStringArray("Slow", "Its shield drops while you operate a tower in range")
codex_tip = "Below half health, man a tower that can reach it."
```
  (Write both in the usual `.tres` syntax like `goblin_shaman.tres`.)
- [ ] **Step 5: Waves.** `first_run.tscn`: add ext resources for the two boss files (`id="7_warchief"`, `id="8_king"`); add `Wave6`…`Wave10` nodes (`type="Node" parent="."`, `script = ExtResource("2_wave")`, `prep_time`, `banner`, `banner_outline`) and their `SpawnGroup` children (`script = ExtResource("3_group")`, `enemy`, `count`, `sector`, `interval`, `delay`) exactly per the spec table. Banner outlines: wave 6 `Color(0.85, 0.2, 0.15, 1)`, wave 10 `Color(0.55, 0.25, 0.9, 1)`; wave 9 has a banner but transparent outline. Name groups like `GoblinsWest`, `ShamanEast`, `Warchief`, `Burst2GoblinsNorth`, `King`.
- [ ] **Step 6: Run it.** Import; `test_waves.gd` → 0 failed; the other three test scripts still 0 failed.
- [ ] **Step 7: Commit** `Add waves 6-10 and the placeholder Warchief and Shaman-King data`.

---

### Task 2: Boss behaviour on Enemy and the run-ending kill

**Files:** Modify `scripts/enemies/enemy.gd`, `scripts/waves/wave_director.gd`, `scripts/world.gd`.

**Interfaces:**
- Consumes: Task 1 fields.
- Produces: `Enemy.flee()`, `Enemy.fled: bool`; `Enemy` in group `bosses` when `is_boss`; `WaveDirector.win_now()`.

- [ ] **Step 1: Failing check.** Run the game, Play, spawn the Shaman-King (`waves.spawn_at`) at Core + (−400, 0) and eval `return [king.is_in_group("bosses"), king.sprite.modulate]`. Expected: `[false, white]`. Stop.
- [ ] **Step 2: Enemy.** In `enemy.gd`:
  - `_ready()`: after `health.died.connect(_on_died)`: `if definition.is_boss: add_to_group(&"bosses")`; and `queue_redraw()` (aura).
  - `_update_tint()`: multiply every assigned colour by `definition.tint` (e.g. `sprite.modulate = Color.WHITE * definition.tint` in the plain branch; `Color.WHITE.lerp(...) * definition.tint` in the others).
  - `_on_died()`: `sprite.modulate = definition.tint` instead of white.
  - Add:
```gdscript
## The placeholder bosses' glowing ring under the feet.
func _draw() -> void:
	if definition.aura.a <= 0.0 or health.is_dead:
		return
	var radius := 18.0 * definition.sprite_scale / 0.3
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, radius, Color(definition.aura, definition.aura.a * 0.5))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, definition.aura, 3.0)
	draw_set_transform(Vector2.ZERO)
```
    and `queue_redraw()` at the start of `_on_died()`.
  - **Projectile fan** — `_shoot()` becomes:
```gdscript
func _shoot(target: Node2D) -> void:
	var from := hurtbox_shape.global_position
	var to_target := target.global_position - from
	var count := maxi(definition.projectile_count, 1)
	for i in count:
		var spread := 0.0 if count == 1 else lerpf(-0.5, 0.5, float(i) / (count - 1)) * definition.projectile_spread_deg
		var shot: Projectile = definition.projectile_scene.instantiate()
		shot.global_position = from
		shot.direction = to_target.normalized().rotated(deg_to_rad(spread))
		shot.speed = definition.projectile_speed
		shot.damage = attack_damage()
		shot.damage_type = Health.DamageType.MAGIC
		shot.max_distance = to_target.length() + 60.0
		get_parent().add_child(shot)
```
  - **Structure damage** — in `_on_frame_changed()`, the melee line becomes:
```gdscript
		var hit := attack_damage()
		if _target.is_in_group(&"breakables"):
			hit *= definition.structure_damage_multiplier
		target_health.take_damage(hit)
```
  - **Wall smashing** — add `var _smash: Node2D` ("## The wall or tower an ignores_walls enemy walked into."). In `_physics_process`, replace the block from `if _needs_repath(goal):` through the `_blocked` re-target with:
```gdscript
	if definition.ignores_walls:
		_path = PackedVector2Array()
		_path_goal = goal
		_target = goal
		if is_instance_valid(_smash) and not _smash.get_node(^"Health").is_dead:
			_target = _smash
		else:
			_smash = null
	else:
		if _needs_repath(goal):
			_repath(goal)
		_target = goal
		if _blocked and not _in_reach(goal):
			var breakable := _nearest_breakable()
			if breakable:
				_target = breakable
```
    and after `move_and_slide()`:
```gdscript
	if definition.ignores_walls and _smash == null:
		for i in get_slide_collision_count():
			var collider := get_slide_collision(i).get_collider() as Node2D
			if collider and collider.is_in_group(&"breakables"):
				_smash = collider
				break
```
    (`_next_waypoint()` already walks straight at `_target` when the path is empty.)
  - **Fleeing**:
```gdscript
## True once it has fled (the run was won): no loot, no "killed".
var fled := false


## Leaves the field: fades out and is freed, without dying or dropping loot.
func flee() -> void:
	if health.is_dead or fled:
		return
	fled = true
	set_physics_process(false)
	velocity = Vector2.ZERO
	hurtbox.set_deferred(&"collision_layer", 0)
	health.invulnerable = true
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.6)
	fade.tween_callback(queue_free)
```
- [ ] **Step 3: World drops.** In `world.gd` `_on_enemy_killed`, after the rare drops:
```gdscript
	var guaranteed := enemy.definition.guaranteed_drops
	for type in guaranteed:
		Loot.drop(units, at, type, guaranteed[type])
	if enemy.definition.drops_lodestone:
		Lodestone.drop(units, at)
```
  (Before the random Lodestone roll; the random roll then sees `is_dropping()` and skips.)
- [ ] **Step 4: Run-ending kill.** In `wave_director.gd`, in `_spawn()` and `spawn_at()` after creating `e`: `e.killed.connect(_on_enemy_killed)`; add:
```gdscript
func _on_enemy_killed(enemy: Enemy) -> void:
	if enemy.definition.ends_run and state != State.WON:
		win_now()


## Ends the run as a victory now: everything else flees, nothing more spawns.
func win_now() -> void:
	_spawn_queue.clear()
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy
		if other and not other.health.is_dead:
			other.flee()
	_alive.clear()
	wave_index = run.waves.size()
	state = State.WON
	run_won.emit()
```
  Also make `_process` ignore `State.WON` (it already does: no match arm).
- [ ] **Step 5: Verify.** Import, all four test scripts, run the game, Play, `break_left = 99999`, `run_cards.ended = true`, hero far away, eval:
  - **Look:** a spawned Shaman-King is in `bosses`, its modulate ≈ (0.8, 0.6, 1); a Warchief's ≈ (1, 0.62, 0.55); screenshot both beside a goblin (aura rings visible).
  - **Fan:** the King within range of the Core: one cast spawns 5 orbs whose directions span 40° (−20 … +20 from the aim).
  - **Wall smash:** build a tower on the west slot (walls up), spawn the Warchief 300 px west of the wall line, frozen hero far: within 15 s a wall piece or the tower takes 60-damage hits and is destroyed, and the Warchief then continues toward the Core. **Review Focus 2:** destroy its current `_smash` target via eval mid-swing: within 1 s it is moving again (velocity non-zero) or attacking another breakable/the Core.
  - **Structure ×3 only on structures:** the Warchief beside the Core hits it for 20.
  - **Drops:** kill the Warchief next to the hero: a Lodestone appears, Aether pickups total 5, Scrap 20–25.
  - **Review Focus 1:** spawn the King plus 6 goblins, put 10 more entries in the spawn queue (`waves._spawn_queue.append({time = 999.0, enemy = goblin, sector = &"west"})`, state WAVE), kill the King: within 1 s every goblin has `fled` and is gone (no new pickups besides the King's), `_spawn_queue` empty, Win screen visible (after the banner), "Waves 10 / 10".
  - Stop; clean `project.godot`.
- [ ] **Step 6: Commit** `Give bosses tint, auras, fans, wall smashing, drops and a run-ending death`.

---

### Task 3: Channels, the Summoner and phase 2

**Files:** Modify `scripts/enemies/enemy.gd`, `scripts/enemies/frenzy_pulse.gd`. Create `scripts/enemies/summoner.gd`, `scenes/enemies/summoner.tscn`, `scripts/enemies/boss_phase.gd`, `scenes/enemies/boss_phase.tscn`.

**Interfaces:**
- Consumes: Task 1 fields; Task 2 behaviour.
- Produces: `Enemy.signal channel_finished(by: Node, landed: bool)`, `Enemy.can_channel() -> bool`, `Enemy.start_channel(animation: StringName, by: Node, min_time := 0.0)`, `Enemy.is_channeling() -> bool`, `Enemy.phase_speed: float`; `class_name Summoner` (`interval: float`); `class_name BossPhase` (`shifted: bool`, `shield_open: bool`, `const SHIELD_TAKEN := 0.1`).

- [ ] **Step 1: Failing check.** `grep -c channel_finished scripts/enemies/enemy.gd` → 0.
- [ ] **Step 2: Generalize the pulse into channels.** In `enemy.gd`:
  - Replace `signal pulse_finished(landed: bool)` with:
```gdscript
## A channel (pulse, summon, phase shift) ended: `landed` is false when a
## stun or death cut it short. `by` is the node that started it.
signal channel_finished(by: Node, landed: bool)
```
  - Replace `var _pulsing := false` with
```gdscript
## The node whose channel is playing, or null.
var _channel_by: Node
var _channel_animation: StringName
## Seconds the channel must still last even after its animation ends.
var _channel_left := 0.0
var _channel_anim_done := false
## Movement × this (phase 2 sets it to 1.3).
var phase_speed := 1.0
```
  - Replace `can_pulse()`, `start_pulse()`, `_cancel_pulse()` with:
```gdscript
func can_channel() -> bool:
	return not health.is_dead and _stun_left <= 0.0 and _channel_by == null and not _is_attacking()


func is_channeling() -> bool:
	return _channel_by != null


## Stands still playing `animation` for at least `min_time` seconds;
## channel_finished(by, true) follows.
func start_channel(animation: StringName, by: Node, min_time := 0.0) -> void:
	_channel_by = by
	_channel_animation = animation
	_channel_left = min_time
	_channel_anim_done = false
	velocity = Vector2.ZERO
	sprite.play(animation)
	sprite.frame = 0


func _cancel_channel() -> void:
	if _channel_by:
		var by := _channel_by
		_channel_by = null
		channel_finished.emit(by, false)


func _finish_channel() -> void:
	var by := _channel_by
	_channel_by = null
	channel_finished.emit(by, true)
```
  - `_physics_process`: replace `if _pulsing:` block with:
```gdscript
	if _channel_by:
		velocity = Vector2.ZERO
		_channel_left -= delta
		if _channel_anim_done and _channel_left <= 0.0:
			_finish_channel()
		return
```
  - `_on_animation_finished()`: replace the pulse branch with:
```gdscript
	if _channel_by and sprite.animation == _channel_animation:
		_channel_anim_done = true
		if _channel_left <= 0.0:
			_finish_channel()
		return
```
  - `stun()` and `_on_died()`: `_cancel_pulse()` → `_cancel_channel()`.
  - `speed_multiplier()` → `return _slow_factor * (1.0 + _frenzy_speed) * phase_speed`.
  - `_ready()`: after the FrenzyPulse line add
```gdscript
	if definition.summon_interval > 0.0 and definition.summon_enemy:
		add_child(SUMMONER_SCENE.instantiate())
	if definition.phase2_at > 0.0:
		add_child(BOSS_PHASE_SCENE.instantiate())
```
    with consts `SUMMONER_SCENE := preload("res://scenes/enemies/summoner.tscn")` and `BOSS_PHASE_SCENE := preload("res://scenes/enemies/boss_phase.tscn")`.
- [ ] **Step 3: FrenzyPulse** — `frenzy_pulse.gd`: `enemy.pulse_finished.connect(_on_pulse_finished)` → `enemy.channel_finished.connect(_on_channel_finished)`; `enemy.can_pulse()` → `enemy.can_channel()`; `enemy.start_pulse()` → `enemy.start_channel(enemy.definition.pulse_animation, self)`; the handler becomes `func _on_channel_finished(by: Node, landed: bool) -> void:` starting with `if by != self: return`, then the old body with `landed`.
- [ ] **Step 4: Summoner** `scripts/enemies/summoner.gd`:
```gdscript
class_name Summoner
extends Node
## Added by an Enemy whose definition summons (the Shaman-King): every
## `interval` seconds it channels, then raises summon_count summon_enemy in a
## ring around itself. A stun or death cancels the cast.

const RING := 60.0
## First summon this long after spawning.
const FIRST_SUMMON := 4.0

var interval := 12.0
var _left := FIRST_SUMMON
var _casting := false

@onready var enemy: Enemy = get_parent()


func _ready() -> void:
	interval = enemy.definition.summon_interval
	enemy.channel_finished.connect(_on_channel_finished)


func _physics_process(delta: float) -> void:
	if _casting or enemy.health.is_dead or enemy.fled:
		return
	_left -= delta
	if _left <= 0.0 and enemy.can_channel():
		_casting = true
		enemy.start_channel(enemy.definition.summon_animation, self)


func _on_channel_finished(by: Node, landed: bool) -> void:
	if by != self:
		return
	_casting = false
	_left = interval
	if not landed:
		return
	var director := get_tree().get_first_node_in_group(&"wave_director") as WaveDirector
	if director == null:
		return
	var count: int = enemy.definition.summon_count
	for i in count:
		var at := enemy.global_position + Vector2.from_angle(TAU * i / count) * RING
		director.summon(enemy.definition.summon_enemy, at)
```
  `scenes/enemies/summoner.tscn`: a `Node` named `Summoner` with the script. In `wave_director.gd`: `add_to_group(&"wave_director")` in `_ready()`, and
```gdscript
## A boss raises `enemy` at `at`; it counts toward the current wave.
func summon(enemy: EnemyDefinition, at: Vector2) -> Enemy:
	var e := spawn_at(enemy, at)
	if state == State.WAVE:
		_alive.append(e)
	return e
```
- [ ] **Step 5: BossPhase** `scripts/enemies/boss_phase.gd`:
```gdscript
class_name BossPhase
extends Node2D
## Added by an Enemy with phase2_at > 0 (the Shaman-King). Once its health
## falls to phase2_at, it channels a phase shift (1.5 s), flashes the screen,
## speeds up, summons twice as often and raises a shield: the boss takes
## SHIELD_TAKEN of all damage unless the hero is operating a tower whose
## range reaches it.

const SHIFT_TIME := 1.5
const SPEED := 1.3
const SHIELD_TAKEN := 0.1
const FLASH := Color(0.6, 0.3, 1.0, 0.45)

var shifted := false
var shield_open := false
var _waiting := false
var _base_taken := PackedFloat32Array()

@onready var enemy: Enemy = get_parent()


func _ready() -> void:
	_base_taken = enemy.health.damage_taken.duplicate()
	enemy.channel_finished.connect(_on_channel_finished)


func _physics_process(_delta: float) -> void:
	if enemy.health.is_dead or enemy.fled:
		return
	if not shifted:
		var ratio := enemy.health.current / enemy.health.max_health
		if ratio <= enemy.definition.phase2_at and not _waiting and enemy.can_channel():
			_waiting = true
			enemy.start_channel(enemy.definition.phase_shift_animation, self, SHIFT_TIME)
		return
	var open := _hero_operating_in_range()
	if open != shield_open:
		shield_open = open
		_apply_shield()
		queue_redraw()


func _on_channel_finished(by: Node, landed: bool) -> void:
	if by != self:
		return
	_waiting = false
	if not landed:
		return  # try again when it can channel
	shifted = true
	enemy.phase_speed = SPEED
	for child in enemy.get_children():
		if child is Summoner:
			child.interval *= 0.5
	_apply_shield()
	_flash()
	queue_redraw()


func _hero_operating_in_range() -> bool:
	var hero := get_tree().get_first_node_in_group(&"hero") as Hero
	if hero == null or hero.health.is_dead or hero.operating == null:
		return false
	var tower := hero.operating
	return tower.global_position.distance_to(enemy.global_position) <= tower.attack_range()


func _apply_shield() -> void:
	var taken := _base_taken.duplicate()
	if not shield_open:
		for i in taken.size():
			taken[i] *= SHIELD_TAKEN
	enemy.health.damage_taken = taken


func _flash() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	var rect := ColorRect.new()
	rect.color = FLASH
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	get_tree().current_scene.add_child(layer)
	var tween := layer.create_tween()
	tween.tween_property(rect, "color:a", 0.0, 0.6)
	tween.tween_callback(layer.queue_free)


func _draw() -> void:
	if not shifted or enemy.health.is_dead:
		return
	var radius := 70.0
	var alpha := 0.12 if shield_open else 0.35
	draw_circle(Vector2(0, -50), radius, Color(0.6, 0.3, 1.0, alpha))
	draw_arc(Vector2(0, -50), radius, 0.0, TAU, 48, Color(0.75, 0.5, 1.0, alpha + 0.3), 3.0)
```
  `scenes/enemies/boss_phase.tscn`: a `Node2D` named `BossPhase` with the script. Also clear the bubble on death: in `_physics_process` the early return already stops updates; add `queue_redraw()` before that return when `enemy.health.is_dead` (once).
- [ ] **Step 6: Verify.** Import, all test scripts, run the game, Play, hold waves, `run_cards.ended = true`, hero far away, eval:
  - **Shaman pulse still works** (regression): a normal Shaman pulses and frenzies nearby goblins (the old FrenzyPulse checks: lands at ~2 s, radius respected).
  - **Summon:** a frozen-in-place King (keep its physics on, but put it where it has no target: hero far, Core > 300 px? It walks; acceptable) summons 4 goblins at 60 px around itself ~4 s after spawning and again ~12 s later; summons count in `waves._alive` during a wave.
  - **Phase 2:** set the King to 49% health (`health.take_damage` with type MAGIC so 0.6 applies — compute); within 0.5 s it channels; ~1.5 s later `shifted` is true, `phase_speed == 1.3`, the Summoner's `interval == 6`, a purple flash layer appeared and freed, and a 100-damage magic hit now takes 6 (10% × 0.6 × 100).
  - **Shield open:** build a tower, `hero.start_operating(tower)` and place the King within the tower's range: `shield_open` true, the same hit takes 60. **Review Focus 4:** `hero.stop_operating()` → shield closes (6 again); also with the hero dead while operating.
  - **Review Focus 3:** with the King about to summon (`_left` ≈ 0.1), stun it (`stun(1.0)`) as soon as it channels: no goblins appear, `_casting` false, next summon after `interval`. Drop it below 50% while stunned: no phase shift until the stun ends, then it shifts.
  - Screenshot the shielded King (bubble) and the open shield.
  - Stop; clean `project.godot`.
- [ ] **Step 7: Commit** `Add channels, the Shaman-King's summons and its phase-2 shield`.

---

### Task 4: Boss bar, wave banners, full run, web check, roadmap

**Files:** Create `scripts/ui/boss_bar.gd`, `scenes/ui/boss_bar.tscn`, `scripts/ui/wave_banner.gd`, `scenes/ui/wave_banner.tscn`. Modify `scenes/ui/hud.tscn`, `scripts/ui/hud.gd`, `ROADMAP.md`.

**Interfaces:**
- Consumes: `bosses` group (Task 2); `WaveDefinition.banner`, `.banner_outline` (Task 1); `WaveDirector.wave_started(number)`, `current_wave()`.
- Produces: `class_name BossBar` (`boss: Enemy`); `class_name WaveBanner` (`show_text(text: String, outline: Color)`).

- [ ] **Step 1: Failing check.** `test -f scenes/ui/boss_bar.tscn` → missing.
- [ ] **Step 2: Boss bar.** `scripts/ui/boss_bar.gd`:
```gdscript
class_name BossBar
extends Control
## A wide health bar across the top while a boss is alive (the first one
## found in the "bosses" group), with its name above.

var boss: Enemy

@onready var name_label: Label = %BossName
@onready var bar: ProgressBar = %BossHealth


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if boss == null or not is_instance_valid(boss) or boss.health.is_dead or boss.fled:
		boss = null
		for node in get_tree().get_nodes_in_group(&"bosses"):
			var candidate := node as Enemy
			if candidate and not candidate.health.is_dead and not candidate.fled:
				boss = candidate
				break
	visible = boss != null
	if boss:
		name_label.text = boss.definition.display_name
		bar.max_value = boss.health.max_health
		bar.value = boss.health.current
```
  `scenes/ui/boss_bar.tscn` (root `Control` named `BossBar`, anchors top-wide, `offset_top = 104`, `offset_bottom = 150`, `mouse_filter = 2`, script). Build it as: `BossBar (Control)` → `Center (CenterContainer, full rect, mouse_filter 2)` → `Rows (VBoxContainer, separation 2, mouse_filter 2)` → `BossName (Label, unique, 16 px, gold Color(1, 0.85, 0.5), black outline 4, centred)` and `BossHealth (ProgressBar, unique, custom_minimum_size Vector2(520, 16), show_percentage false, fill StyleBoxFlat bg Color(0.85, 0.2, 0.2), background StyleBoxFlat Color(0.1, 0.08, 0.1, 0.85))`.
- [ ] **Step 3: Wave banner.** `scripts/ui/wave_banner.gd`:
```gdscript
class_name WaveBanner
extends Control
## Big text when a wave starts: fades in, holds, fades out. Boss waves use
## gold text with a coloured outline.

const GOLD := Color(1, 0.85, 0.45)

var _tween: Tween

@onready var label: Label = %BannerText


func _ready() -> void:
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_text(text: String, outline: Color) -> void:
	label.text = text
	var boss := outline.a > 0.0
	label.add_theme_color_override(&"font_color", GOLD if boss else Color.WHITE)
	label.add_theme_color_override(&"font_outline_color", outline if boss else Color.BLACK)
	if _tween:
		_tween.kill()
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.3)
	_tween.tween_interval(2.0)
	_tween.tween_property(self, "modulate:a", 0.0, 0.5)
```
  `scenes/ui/wave_banner.tscn`: root `Control` `WaveBanner` (full rect, `mouse_filter = 2`, script) → `Label` `BannerText` (unique, anchors top-wide, `offset_top = 170`, `offset_bottom = 230`, 40 px, outline size 8, centred, `mouse_filter = 2`).
- [ ] **Step 4: HUD.** Instance both scenes as children of the HUD root in `hud.tscn` (after the existing panels). `hud.gd`: `@onready var boss_bar: BossBar = $BossBar`, `@onready var wave_banner: WaveBanner = $WaveBanner`; in `bind_waves(director)` add:
```gdscript
	director.wave_started.connect(func(number: int) -> void:
		var wave := director.run.waves[number - 1]
		wave_banner.show_text(wave.banner if wave.banner != "" else "Wave %d" % number, wave.banner_outline))
```
- [ ] **Step 5: Verify.** Import, all test scripts, run the game, Play, eval:
  - **Banner:** start wave 1 → "Wave 1" white within 0.3 s, gone after ~2.8 s. Force wave 6 (`waves.wave_index = 5`, `start_wave_now()`) → "Wave 6 — The Warchief approaches", gold with a red outline. Screenshot. Banner ignores the mouse.
  - **Boss bar:** spawn the Warchief: bar visible with "Goblin Warchief", value = health; damage it → bar follows; kill it → bar hides. **Review Focus 5:** spawn the King far off-screen: bar shows; kill it off-screen → bar hides; restart the run (`game_over.restart()`) with a boss alive → new run has no bar and no banner showing.
  - **Full run:** `run_cards.ended = true`, `Engine.time_scale = 8`, start waves early and kill everything that comes within 900 px of the Core each physics frame, EXCEPT bosses get damage via `take_damage(300, MAGIC)` per second so their mechanics run (summons, phase shift); loop evals until the Win screen: "Waves 10 / 10", kills include Goblin Warchief 1 and Goblin Shaman-King 1, no errors in `get_debug_output`. Reset time scale.
  - Stop; clean `project.godot`.
- [ ] **Step 6: Web check.** Export, serve, Playwright: Play, Enter to start wave 1 → screenshot shows "Wave 1" banner; no console errors. Kill server by PID; `rm -rf export`.
- [ ] **Step 7: Roadmap.** Phase 10: `- [ ] **[AI]** 10 waves, a mini-boss around wave 6, final boss` → `- [x] **[AI]** 10 waves (≈ 510 XP): placeholder Goblin Warchief mini-boss (wave 6: smashes walls, war cry) and Goblin Shaman-King final boss (wave 10: orb fans, summons, phase-2 shield that drops while you operate a tower in range; its death wins the run); boss health bar and wave banners. Real boss art: see `docs/art/2026-09-30-boss-and-evolution-art-brief.md`
- [ ] **Step 8: Commit** `Add the boss bar and wave banners; tick the 10-wave run on the roadmap`.
