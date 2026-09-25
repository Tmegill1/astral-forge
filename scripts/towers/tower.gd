class_name Tower
extends StaticBody2D
## Every tower uses this script; art, cost and stats come from the
## TowerDefinition passed to setup().
##
## Automatic: shoots the nearest enemy in range.
## Operated (hero pressed Interact on it): aims at the mouse with boosted
## damage, fire rate and range, can use its ability, and earns Mastery XP.
## The operating hero can't be hurt; enemies go for the tower instead. If
## the tower is destroyed the hero is thrown out and rubble is left behind.

signal destroyed(tower: Tower)

const BOLT_SCENE := preload("res://scenes/projectiles/hero_bolt.tscn")
## How long the firing frame shows after each shot, in seconds.
const FIRE_FRAME_TIME := 0.12
## The operating hero stands this far to the tower's Core-facing side (and a
## touch behind it), so neither hides the other and they stay inside the walls.
const OPERATOR_SIDE := 38.0
## Leaving puts the hero this far toward the Core, clear of the tower's body.
const EXIT_DISTANCE := 48.0

## How far from its base enemies can hit it from, in pixels.
@export var hit_radius := 24.0
## A rotating head only fires once it points within this of its aim (radians).
const HEAD_FIRE_TOLERANCE := 0.2
## How far the head kicks back when it fires, in pixels.
const RECOIL := 3.0

var definition: TowerDefinition
var level := 1
## Where fired bolts are added; set by whoever places the tower.
var projectile_parent: Node
## The hero currently operating this tower, or null when automatic.
var operator: Hero
## Earned from damage dealt while operated; unlocks evolutions later.
var mastery_xp := 0.0

var _cooldown := 0.0
var _aim_frame := 0
var _fire_frame_left := 0.0
var _ability_left := 0.0
var _ability_cooldown_left := 0.0
## Rotating head: where it points now and where it wants to point (radians).
var _head_angle := 0.0
var _wanted_angle := 0.0
var _head_rest := Vector2.ZERO
## Unit direction from the tower toward the Core, snapped to an axis.
var _inward := Vector2.RIGHT
## This level's rotating head, or null for frame-based art.
var _head: TurretHead

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var base_sprite: Sprite2D = $Base
@onready var head: Sprite2D = $Head
@onready var muzzle_flash: Node2D = $Head/Flash
@onready var health: Health = $Health
@onready var health_bar: HealthBar = $HealthBar


## Call before adding the tower to the scene tree.
func setup(tower_definition: TowerDefinition) -> void:
	definition = tower_definition


func _ready() -> void:
	assert(definition != null, "Call Tower.setup() before adding the tower to the tree")
	sprite.sprite_frames = definition.sprite_frames
	sprite.scale = Vector2.ONE * definition.sprite_scale
	sprite.offset = -definition.sprite_frames.get_meta("foot_offset", Vector2.ZERO)
	_show(&"idle")
	health_bar.place_above(sprite)
	_head = definition.head_for(level)
	_setup_head()
	health.reset(definition.max_health_at(level))
	health.died.connect(_on_died)
	var core := get_tree().get_first_node_in_group(&"core") as Node2D
	if core:
		var to_core := core.global_position - global_position
		_inward = Vector2(signf(to_core.x), 0) if absf(to_core.x) >= absf(to_core.y) else Vector2(0, signf(to_core.y))
	if projectile_parent == null:
		projectile_parent = get_parent()


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	_ability_left = maxf(_ability_left - delta, 0.0)
	_ability_cooldown_left = maxf(_ability_cooldown_left - delta, 0.0)
	if _fire_frame_left > 0.0:
		_fire_frame_left -= delta
		if _fire_frame_left <= 0.0:
			_show(&"idle")

	var aim_point: Vector2
	var wants_to_fire: bool
	if operator:
		aim_point = operator.get_global_mouse_position()
		wants_to_fire = operator.auto_fire or Input.is_action_pressed(&"fire")
	else:
		var target := _find_target()
		if target == null:
			return
		aim_point = _aim_point(target)
		wants_to_fire = true
	_aim_at(aim_point)
	_turn_head(delta)
	if wants_to_fire and _cooldown <= 0.0 and _head_on_target():
		_cooldown = 1.0 / fire_rate()
		_fire_at(aim_point)


# --- Current stats (operating and the ability change them) ---

func damage() -> float:
	var value := definition.damage_at(level)
	if operator:
		value *= definition.operated_damage_multiplier
	return value


func fire_rate() -> float:
	var value := definition.fire_rate_at(level)
	if operator:
		value *= definition.operated_fire_rate_multiplier
	if _ability_left > 0.0:
		value *= definition.ability_fire_rate_multiplier
	return value


func attack_range() -> float:
	var value := definition.range_at(level)
	if operator:
		value *= definition.operated_range_multiplier
	return value


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


# --- Operating ---

func interact(hero: Hero) -> void:
	if is_destroyed():
		return
	if operator == hero:
		hero.stop_operating()
	elif operator == null:
		hero.start_operating(self)


func get_interact_prompt(hero: Hero) -> String:
	if is_destroyed():
		return ""
	if operator == hero:
		return "[E] Leave %s" % definition.display_name
	if operator == null:
		return "[E] Operate %s" % definition.display_name
	return ""


func operator_position() -> Vector2:
	return global_position + _inward * OPERATOR_SIDE + Vector2(0, -4)


func exit_position() -> Vector2:
	return global_position + _inward * EXIT_DISTANCE + Vector2(0, 12)


## Solid area for enemy pathfinding: its body circle.
func nav_footprint() -> Rect2:
	var shape := $Body as CollisionShape2D
	var r: float = (shape.shape as CircleShape2D).radius
	return Rect2(global_position + shape.position - Vector2(r, r), Vector2(r, r) * 2.0)


func is_destroyed() -> bool:
	return health.is_dead


func _on_died() -> void:
	if operator:
		operator.stop_operating()
	set_physics_process(false)
	for group in [&"towers", &"nav_blockers", &"breakables"]:
		remove_from_group(group)
	set_deferred(&"collision_layer", 0)
	base_sprite.visible = false
	head.visible = false
	sprite.visible = true
	sprite.flip_h = false
	sprite.animation = StringName("lv%d_destroyed" % level)
	sprite.stop()
	sprite.frame = 0
	queue_redraw()
	get_tree().call_group(&"nav_grid", &"mark_dirty")
	destroyed.emit(self)


## Called by Hero.start_operating / stop_operating; pass null to release.
func set_operator(hero: Hero) -> void:
	operator = hero
	_ability_left = 0.0
	queue_redraw()


func use_ability() -> void:
	if operator and _ability_cooldown_left <= 0.0:
		_ability_left = definition.ability_duration
		_ability_cooldown_left = definition.ability_cooldown


func ability_active_left() -> float:
	return _ability_left


func ability_cooldown_left() -> float:
	return _ability_cooldown_left


# --- Targeting and firing ---

## Nearest living enemy within range.
func _find_target() -> Enemy:
	var best: Enemy = null
	var best_distance := attack_range()
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy.health.is_dead:
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


## Middle of the enemy's body rather than its feet.
func _aim_point(enemy: Enemy) -> Vector2:
	return enemy.hurtbox_shape.global_position


func _has_head() -> bool:
	return _head != null


func _setup_head() -> void:
	base_sprite.visible = _has_head()
	head.visible = _has_head()
	if not _has_head():
		return
	sprite.visible = false
	var scale_v := Vector2.ONE * definition.sprite_scale
	base_sprite.texture = _head.base_texture
	base_sprite.scale = scale_v
	base_sprite.offset = sprite.offset
	head.texture = _head.head_texture
	head.scale = scale_v
	_head_rest = _head.pivot * definition.sprite_scale
	head.position = _head_rest
	muzzle_flash.position = Vector2.from_angle(deg_to_rad(_head.drawn_angle)) * _head.barrel_length
	_head_angle = deg_to_rad(_head.drawn_angle)
	_wanted_angle = _head_angle


func _turn_head(delta: float) -> void:
	if not _has_head():
		return
	_head_angle = wrapf(rotate_toward(_head_angle, _wanted_angle,
			deg_to_rad(definition.head_turn_speed) * delta), -PI, PI)
	head.rotation = _head_angle - deg_to_rad(_head.drawn_angle)
	# Ease back from recoil.
	head.position = head.position.lerp(_head_rest, minf(1.0, delta * 20.0))


func _head_on_target() -> bool:
	return not _has_head() or absf(angle_difference(_head_angle, _wanted_angle)) <= HEAD_FIRE_TOLERANCE


## Where shots start before the barrel length is added.
func _muzzle_base() -> Vector2:
	if _has_head():
		return global_position + _head_rest
	return global_position + Vector2(0.0, -definition.muzzle_height)


func _barrel_length() -> float:
	if _has_head():
		return _head.barrel_length * definition.sprite_scale
	return definition.barrel_length


## Turns the head toward `point`, or picks the frame (or mirrored frame)
## whose barrel points closest to it.
func _aim_at(point: Vector2) -> void:
	if _has_head():
		_wanted_angle = (point - _muzzle_base()).angle()
		return
	if definition.aim_angles.is_empty():
		return
	var wanted := (point - _muzzle_base()).angle()
	var best_error := INF
	for i in definition.aim_angles.size():
		var drawn := deg_to_rad(definition.aim_angles[i])
		for mirrored in [false, true]:
			var angle := PI - drawn if mirrored else drawn
			var error := absf(angle_difference(angle, wanted))
			if error < best_error:
				best_error = error
				_aim_frame = i
				sprite.flip_h = mirrored
	sprite.frame = _aim_frame


func _fire_at(point: Vector2) -> void:
	var base := _muzzle_base()
	var direction := (point - base).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	var bolt: Projectile = BOLT_SCENE.instantiate()
	bolt.global_position = base + direction * _barrel_length()
	bolt.direction = direction
	bolt.speed = definition.projectile_speed
	bolt.damage = damage()
	# Operated shots fly exactly the (boosted) range; automatic ones a bit
	# past it so they can reach a target that walked out while in flight.
	bolt.max_distance = attack_range() if operator else attack_range() + 60.0
	if operator:
		bolt.hit.connect(func(dealt: float, _killed: bool) -> void: mastery_xp += dealt)
	projectile_parent.add_child(bolt)
	if _has_head():
		muzzle_flash.flash(FIRE_FRAME_TIME)
		head.position = _head_rest - direction * RECOIL
	else:
		_show(&"fire")
		_fire_frame_left = FIRE_FRAME_TIME


## Shows this level's idle or fire art at the current aim frame. Towers that
## don't turn just play the animation. (Unused while a rotating head is shown.)
func _show(state: StringName) -> void:
	var animation := StringName("lv%d_%s" % [level, state])
	if definition.aim_angles.is_empty():
		sprite.play(animation)
	else:
		sprite.animation = animation
		sprite.stop()
		sprite.frame = _aim_frame


## While operated: a faint ring showing how far shots reach.
func _draw() -> void:
	if operator == null:
		return
	var centre := _muzzle_base() - global_position
	draw_circle(centre, attack_range(), Color(0.45, 0.85, 1.0, 0.05))
	draw_arc(centre, attack_range(), 0.0, TAU, 96, Color(0.45, 0.85, 1.0, 0.35), 2.0)
