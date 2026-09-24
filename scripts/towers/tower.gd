class_name Tower
extends StaticBody2D
## Every tower uses this script; art, cost and stats come from the
## TowerDefinition passed to setup(). On its own it shoots the nearest enemy
## in range. (Phase 5 adds the hero operating it.)

const BOLT_SCENE := preload("res://scenes/projectiles/hero_bolt.tscn")
## How long the firing frame shows after each shot, in seconds.
const FIRE_FRAME_TIME := 0.12

var definition: TowerDefinition
var level := 1
## Where fired bolts are added; set by whoever places the tower.
var projectile_parent: Node

var _cooldown := 0.0
var _aim_frame := 0
var _fire_frame_left := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
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
	health.reset(definition.max_health)
	if projectile_parent == null:
		projectile_parent = get_parent()


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if _fire_frame_left > 0.0:
		_fire_frame_left -= delta
		if _fire_frame_left <= 0.0:
			_show(&"idle")

	var target := _find_target()
	if target == null:
		return
	var aim_point := _aim_point(target)
	_aim_at(aim_point)
	if _cooldown <= 0.0:
		_cooldown = 1.0 / definition.attacks_per_second
		_fire_at(aim_point)


## Nearest living enemy within range.
func _find_target() -> Enemy:
	var best: Enemy = null
	var best_distance := definition.attack_range
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


func _muzzle_base() -> Vector2:
	return global_position + Vector2(0.0, -definition.muzzle_height)


## Picks the frame (or mirrored frame) whose barrel points closest to `point`.
func _aim_at(point: Vector2) -> void:
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
	var bolt: Projectile = BOLT_SCENE.instantiate()
	bolt.global_position = base + direction * definition.barrel_length
	bolt.direction = direction
	bolt.speed = definition.projectile_speed
	bolt.damage = definition.attack_damage
	bolt.max_distance = definition.attack_range + 60.0
	projectile_parent.add_child(bolt)
	_show(&"fire")
	_fire_frame_left = FIRE_FRAME_TIME


## Shows this level's idle or fire art at the current aim frame. Towers that
## don't turn just play the animation.
func _show(state: StringName) -> void:
	var animation := StringName("lv%d_%s" % [level, state])
	if definition.aim_angles.is_empty():
		sprite.play(animation)
	else:
		sprite.animation = animation
		sprite.stop()
		sprite.frame = _aim_frame
