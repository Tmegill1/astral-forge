class_name Hero
extends CharacterBody2D
## The player's hero. Every hero uses this script; what differs (art, stats)
## comes from the HeroDefinition passed to setup() before the hero spawns.
##
## Controls: WASD to move (the hero faces the way it walks), or right-click
## to walk to a spot (hold it to keep following the cursor); mouse to aim;
## E to interact. On touch (Settings.touch_mode) the on-screen controls press the
## same actions, shots auto-aim at the nearest enemy in range, and operated
## towers aim at touch_aim. Shooting is automatic toward the mouse unless auto_fire is
## off, then hold left mouse to shoot. Picked-up resources go into `carried`
## until deposited at the Core.
##
## Pressing E at a tower operates it: the hero is anchored beside it, the
## tower aims at the mouse with boosted stats, Q / right-click uses its
## ability, and the camera zooms out. E again leaves instantly.

signal died
## Text for the nearest interactable ("[E] Deposit ...", or "Deposit ..." on touch), or "" for none.
signal interact_prompt_changed(text: String)
## The tower now being operated, or null after leaving one.
signal operating_changed(tower: Tower)
## Stats changed (an upgrade was bought).
signal stats_changed

const BOLT_SCENE := preload("res://scenes/projectiles/hero_bolt.tscn")
const ARC_SCENE := preload("res://scenes/projectiles/lightning_arc.tscn")
## Arc Bolts: how far lightning can jump from one enemy to the next, in pixels.
const ARC_RANGE := 120.0
## Split Shot: degrees between neighbouring bolts.
const SPLIT_ANGLE := 12.0
## Walk animations from straight up to straight down, 45 degrees apart.
## Moving left plays these mirrored. Any the art doesn't have fall back to "walk".
const WALK_BY_DIRECTION: Array[StringName] = [
	&"walk_up", &"walk_up_right", &"walk_right", &"walk_down_right", &"walk_down"]

## When false, the hero only shoots while the "fire" action is held. Set from
## Settings (Options › Auto-fire).
@export var auto_fire := true
## How far from the hero's feet enemies can hit it from, in pixels.
@export var hit_radius := 12.0
## Camera zoom while operating a tower; 0.8 = zoomed out 20%.
@export var operating_zoom := 0.8
## Right-click movement stops this close to the target, in pixels.
@export var arrive_distance := 6.0

@export_group("Body motion")
## Seconds to turn around (the sprite squeezes to nothing and opens up
## facing the other way). 0 = instant flip.
@export var turn_time := 0.1
## How far the hero tilts into the run, in degrees.
@export var lean_degrees := 6.0
## How quickly the lean and bob settle; higher = snappier.
@export var lean_sharpness := 12.0
## Extra up-and-down per step while walking, in pixels. 0 = off.
@export var bob_height := 1.5

var definition: HeroDefinition
## Final stats for this run: baseline x this hero's multipliers.
var stats: HeroStats
## Stats at the start of the run, before upgrades.
var base_stats: HeroStats
## Ranks bought at the Core, by upgrade id. They last the whole run.
var upgrade_ranks: Dictionary[StringName, int] = {}
## World-space area the hero can't leave. Empty means no limit.
var bounds := Rect2()
## Resources picked up but not yet deposited; at risk if the hero falls.
var carried := ResourceBag.new()
## The tower being operated, or null.
var operating: Tower
## The area the camera may show (the map). When the zoomed-out view is
## bigger than this, the map is centred instead.
var camera_bounds := Rect2()
## Touch mode: where operated towers aim, set by touching the map
## (TouchControls). Unused with a mouse.
var touch_aim := Vector2.ZERO

var _cooldown := 0.0
var _prompt := ""
## Where right-click movement is heading; null when not click-moving.
var _move_target: Variant = null
var _facing_left := false
## Horizontal sprite scale sign: 1 = facing right, -1 = left, between while turning.
var _facing := 1.0
## Camera zoom with no tower operated: 1, or smaller in touch mode to undo
## the bigger UI scale so the map view matches desktop.
var _base_zoom := 1.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle
@onready var health: Health = $Health
@onready var interact_area: Area2D = $InteractArea
@onready var health_bar: HealthBar = $HealthBar
@onready var camera: Camera2D = $Camera


## Call before adding the hero to the scene tree.
func setup(hero_definition: HeroDefinition) -> void:
	definition = hero_definition
	base_stats = definition.build_stats()
	stats = base_stats.duplicate()


func _ready() -> void:
	assert(definition != null, "Call Hero.setup() before adding the hero to the tree")
	sprite.sprite_frames = definition.sprite_frames
	sprite.scale = Vector2.ONE * definition.sprite_scale
	sprite.offset = -definition.sprite_frames.get_meta("foot_offset", Vector2.ZERO)
	sprite.play(&"idle")
	muzzle.position = definition.muzzle_offset * definition.sprite_scale
	health_bar.place_above(sprite)
	health.reset(stats.max_health)
	health.died.connect(_on_died)
	auto_fire = Settings.auto_fire
	Settings.changed.connect(_on_settings_changed)
	if Settings.touch_mode:
		_base_zoom = 1.0 / Settings.TOUCH_UI_SCALE
	camera.zoom = Vector2.ONE * _base_zoom
	var cards := get_tree().get_first_node_in_group(&"run_cards") as RunCards
	if cards:
		cards.changed.connect(rebuild_stats)


## Auto-fire follows the Options setting, even mid-run.
func _on_settings_changed() -> void:
	auto_fire = Settings.auto_fire


func _process(_delta: float) -> void:
	_update_camera_limits()


func _physics_process(delta: float) -> void:
	if health.is_dead:
		return
	if operating:
		_facing_left = aim_position().x < global_position.x
		sprite.play(&"idle")
		_animate_body(Vector2.ZERO, delta)
		_update_prompt()
		return
	var input := _movement_input()
	velocity = input * stats.move_speed
	move_and_slide()
	if bounds.has_area():
		global_position = global_position.clamp(bounds.position, bounds.end)
	# Walked into something (the Core, a tower) on the way: give up.
	if _move_target != null and input != Vector2.ZERO \
			and get_real_velocity().length() < stats.move_speed * 0.1:
		_move_target = null
	queue_redraw()

	# Face where you're walking; when standing still, face where you'd shoot.
	# Walking straight up/down keeps the current facing.
	if input.x != 0.0:
		_facing_left = input.x < 0.0
	elif input == Vector2.ZERO:
		var look: Variant = _shot_target()
		if look != null:
			_facing_left = look.x < global_position.x
	muzzle.position.x = -absf(muzzle.position.x) if _facing_left else absf(muzzle.position.x)
	if input:
		_play_walk(_walk_animation(input))
	else:
		sprite.play(&"idle")
	# Step in time with the actual speed so the feet don't skate.
	sprite.speed_scale = clampf(get_real_velocity().length() / stats.move_speed, 0.4, 1.5) \
			if input else 1.0
	_animate_body(input, delta)
	_update_prompt()

	_cooldown -= delta
	if _cooldown <= 0.0 and (auto_fire or Input.is_action_pressed(&"fire")):
		var target: Variant = _shot_target()
		if target != null:
			_fire(target)
			_cooldown = 1.0 / stats.attacks_per_second


## The walk animation for moving along `move`, or plain "walk" if the art
## doesn't have that direction.
func _walk_animation(move: Vector2) -> StringName:
	# Fold left onto right, then round to the nearest 45 degrees (-2 = up, 2 = down).
	var step := roundi(Vector2(absf(move.x), move.y).angle() / (PI / 4.0))
	var anim := WALK_BY_DIRECTION[step + 2]
	return anim if sprite.sprite_frames.has_animation(anim) else &"walk"


## Plays a walk animation; changing direction mid-stride keeps the step
## cycle going instead of restarting it.
func _play_walk(anim: StringName) -> void:
	if sprite.animation == anim:
		sprite.play(anim)
		return
	var mid_stride := String(sprite.animation).begins_with("walk")
	var frame := sprite.frame
	var progress := sprite.frame_progress
	sprite.play(anim)
	if mid_stride:
		sprite.set_frame_and_progress(frame % sprite.sprite_frames.get_frame_count(anim), progress)


## Turning, leaning and bobbing on top of the sprite's own frames.
## `move` is this frame's movement input (zero when standing still).
func _animate_body(move: Vector2, delta: float) -> void:
	var facing_sign := -1.0 if _facing_left else 1.0
	_facing = move_toward(_facing, facing_sign, 2.0 * delta / turn_time) \
			if turn_time > 0.0 else facing_sign
	sprite.scale = Vector2(_facing, 1.0) * definition.sprite_scale
	var walking := move != Vector2.ZERO and String(sprite.animation).begins_with("walk")
	# Lean into the sideways part of the run. With only the side-on "walk" art,
	# also lean forward running up the screen and back running down, to hint
	# at the direction the art can't show.
	var forward := absf(move.x)
	if sprite.animation == &"walk":
		forward = clampf(forward - move.y * 0.5, -1.0, 1.0)
	var blend := 1.0 - exp(-lean_sharpness * delta)
	sprite.rotation = lerpf(sprite.rotation, deg_to_rad(lean_degrees) * forward * facing_sign, blend)
	# Two bobs per walk cycle, one per step.
	var bob := 0.0
	if walking:
		var cycle := (sprite.frame + sprite.frame_progress) \
				/ sprite.sprite_frames.get_frame_count(sprite.animation)
		bob = -absf(sin(cycle * TAU)) * bob_height
	sprite.position.y = lerpf(sprite.position.y, bob, blend)


## Drops any turn, lean or bob in progress (for death).
func _reset_body() -> void:
	_facing = -1.0 if _facing_left else 1.0
	sprite.scale = Vector2(_facing, 1.0) * definition.sprite_scale
	sprite.rotation = 0.0
	sprite.position = Vector2.ZERO
	sprite.speed_scale = 1.0


## WASD wins; otherwise head for the right-click target. Holding right-click
## keeps moving the target to the cursor.
func _movement_input() -> Vector2:
	var keys := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if keys != Vector2.ZERO:
		_move_target = null
		return keys
	if Input.is_action_pressed(&"move_to"):
		var target := get_global_mouse_position()
		_move_target = target.clamp(bounds.position, bounds.end) if bounds.has_area() else target
	if _move_target == null:
		return Vector2.ZERO
	var to_target: Vector2 = _move_target - global_position
	if to_target.length() <= arrive_distance:
		_move_target = null
		return Vector2.ZERO
	# Slow down on the last step so the hero lands on the spot, not past it.
	return to_target.normalized() * minf(1.0, to_target.length() / (stats.move_speed / 60.0))


## Small ring on the ground where a right-click is heading.
func _draw() -> void:
	if _move_target == null:
		return
	var at: Vector2 = _move_target - global_position
	draw_arc(at, 7.0, 0.0, TAU, 24, Color(1.0, 0.92, 0.6, 0.8), 1.5)
	draw_circle(at, 2.0, Color(1.0, 0.92, 0.6, 0.8))


func _unhandled_input(event: InputEvent) -> void:
	if health.is_dead:
		return
	if event.is_action_pressed(&"interact"):
		interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"manage"):
		var target := nearest_interactable()
		if target and target.has_method(&"manage"):
			target.manage(self)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"tower_ability") and operating:
		operating.use_ability()


func start_operating(tower: Tower) -> void:
	if operating:
		stop_operating()
	operating = tower
	health.invulnerable = true
	_move_target = null
	queue_redraw()
	tower.set_operator(self)
	global_position = tower.operator_position()
	# Touch: aim just in front of the tower until the player touches the map.
	touch_aim = tower.global_position + (Vector2.LEFT if _facing_left else Vector2.RIGHT) * 120.0
	reset_physics_interpolation()
	velocity = Vector2.ZERO
	_zoom_to(operating_zoom)
	operating_changed.emit(tower)


func stop_operating() -> void:
	if operating == null:
		return
	operating.set_operator(null)
	global_position = operating.exit_position()
	reset_physics_interpolation()
	operating = null
	health.invulnerable = false
	_zoom_to(1.0)
	operating_changed.emit(null)


func _zoom_to(zoom: float) -> void:
	create_tween().tween_property(camera, "zoom", Vector2.ONE * zoom * _base_zoom, 0.25) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Keeps the camera inside camera_bounds; if the view is bigger than the
## bounds on an axis, centres the bounds on that axis instead.
func _update_camera_limits() -> void:
	if not camera_bounds.has_area():
		return
	var view := get_viewport_rect().size / camera.zoom
	var area := camera_bounds
	for axis in 2:
		if area.size[axis] < view[axis]:
			area.position[axis] -= (view[axis] - area.size[axis]) / 2.0
			area.size[axis] = view[axis]
	camera.limit_left = floori(area.position.x)
	camera.limit_top = floori(area.position.y)
	camera.limit_right = ceili(area.end.x)
	camera.limit_bottom = ceili(area.end.y)


## Uses the nearest interactable in reach (towers, build slots, the Core...).
func interact() -> void:
	var target := nearest_interactable()
	if target:
		target.interact(self)
		_update_prompt()


## Anything in reach with an interact(hero) method counts. It may also have
## get_interact_prompt(hero) -> String to show a hint on screen.
func nearest_interactable() -> Node:
	var nearest: Node = null
	var nearest_distance := INF
	for area in interact_area.get_overlapping_areas():
		var target: Node = area if area.has_method(&"interact") else area.get_parent()
		if not target.has_method(&"interact"):
			continue
		var distance := global_position.distance_squared_to(area.global_position)
		if distance < nearest_distance:
			nearest = target
			nearest_distance = distance
	return nearest


func _update_prompt() -> void:
	var text := ""
	var target := nearest_interactable()
	if target and not health.is_dead and target.has_method(&"get_interact_prompt"):
		text = target.get_interact_prompt(self)
	if text != _prompt:
		_prompt = text
		interact_prompt_changed.emit(text)


# --- Upgrades ---

func rank_of(upgrade: HeroUpgrade) -> int:
	return upgrade_ranks.get(upgrade.id, 0)


## Adds one rank of `upgrade` (the Core has already been paid). Extra max
## health is added on top of the current health.
func add_rank(upgrade: HeroUpgrade) -> void:
	upgrade_ranks[upgrade.id] = rank_of(upgrade) + 1
	rebuild_stats()


## Stats = base × Core upgrades × power-up cards. Extra max health is added
## on top of the current health.
func rebuild_stats() -> void:
	stats = base_stats.duplicate()
	for owned in definition.upgrades:
		var rank := rank_of(owned)
		if rank > 0:
			stats.set(owned.stat, base_stats.get(owned.stat) * owned.multiplier(rank))
	stats.attack_damage *= RunCards.multiplier(self, &"hero_damage")
	stats.attacks_per_second *= RunCards.multiplier(self, &"hero_fire_rate")
	stats.move_speed *= RunCards.multiplier(self, &"hero_move_speed")
	stats.max_health *= RunCards.multiplier(self, &"hero_max_health")
	if not is_equal_approx(stats.max_health, health.max_health):
		health.grow_max(stats.max_health)
	stats_changed.emit()


## Brings a dead hero back at full health.
func revive(at: Vector2) -> void:
	global_position = at
	reset_physics_interpolation()
	velocity = Vector2.ZERO
	_cooldown = 0.0
	health.reset(stats.max_health)
	sprite.play(&"idle")


func _fire(target: Vector2) -> void:
	var aim := target - muzzle.global_position
	if aim.is_zero_approx():
		aim = Vector2.LEFT if _facing_left else Vector2.RIGHT
	var split := _mod_rank(&"split_shot")
	for i in range(-split, split + 1):
		var bolt: Projectile = BOLT_SCENE.instantiate()
		bolt.global_position = muzzle.global_position
		bolt.direction = aim.normalized().rotated(deg_to_rad(SPLIT_ANGLE * i))
		bolt.speed = stats.projectile_speed
		bolt.damage = stats.attack_damage
		bolt.max_distance = stats.attack_range
		bolt.struck.connect(_on_bolt_struck.bind(bolt.damage))
		get_parent().add_child(bolt)


## Where the hero's shots go: the mouse; in touch mode the body of the
## nearest living enemy in range, or null when there is none (no shot).
func _shot_target() -> Variant:
	if not Settings.touch_mode:
		return get_global_mouse_position()
	var best: Enemy = null
	var best_distance := stats.attack_range
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy.health.is_dead:
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	if best == null:
		return null
	return best.hurtbox_shape.global_position


## Where an operated tower aims: touch_aim in touch mode, else the mouse.
func aim_position() -> Vector2:
	return touch_aim if Settings.touch_mode else get_global_mouse_position()


func _mod_rank(mod: StringName) -> int:
	var cards := get_tree().get_first_node_in_group(&"run_cards") as RunCards
	return cards.mod_rank(mod) if cards else 0


## Ember Rounds burns the enemy hit; Arc Bolts chains lightning from it.
func _on_bolt_struck(target: Node, bolt_damage: float) -> void:
	var enemy := target as Enemy
	if enemy == null:
		return
	var embers := _mod_rank(&"ember_rounds")
	if embers > 0 and not enemy.health.is_dead:
		enemy.add_burn(2.0, 5, 3.0, embers)
	var jumps := _mod_rank(&"arc_bolts")
	if jumps > 0:
		_chain_lightning(enemy, jumps, bolt_damage * 0.5)


## Lightning from `from` to up to `jumps` more enemies, each the nearest
## living one within ARC_RANGE of the last, never the same one twice.
func _chain_lightning(from: Enemy, jumps: int, arc_damage: float) -> void:
	var hit: Array[Enemy] = [from]
	var points := PackedVector2Array([from.hurtbox_shape.global_position])
	var last := from
	for i in jumps:
		var next: Enemy = null
		var best := ARC_RANGE
		for node in get_tree().get_nodes_in_group(&"enemies"):
			var other := node as Enemy
			if other in hit or other.health.is_dead:
				continue
			var distance := last.global_position.distance_to(other.global_position)
			if distance <= best:
				next = other
				best = distance
		if next == null:
			break
		next.health.take_damage(arc_damage, Health.DamageType.MAGIC)
		hit.append(next)
		points.append(next.hurtbox_shape.global_position)
		last = next
	if points.size() < 2:
		return
	var arc: LightningArc = ARC_SCENE.instantiate()
	arc.points = points
	get_parent().add_child(arc)


func _on_died() -> void:
	stop_operating()
	_move_target = null
	queue_redraw()
	velocity = Vector2.ZERO
	_reset_body()
	sprite.play(&"death")
	_update_prompt()
	died.emit()
