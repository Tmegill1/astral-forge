class_name Enemy
extends CharacterBody2D
## Every enemy uses this script; what differs (art, stats) comes from the
## EnemyDefinition passed to setup() before it spawns.
##
## Paths around walls to the Command Core and attacks it, but turns on the
## hero when the hero comes within aggro range (or on the tower the hero is
## operating, since an operating hero can't be hurt). If walls cut it off
## completely, it breaks through the nearest wall or tower.

signal killed(enemy: Enemy)

## Seconds a body stays on the ground before fading out.
const CORPSE_TIME := 1.5
## Paths are recomputed at least this often, in seconds.
const REPATH_TIME := 0.75
## A waypoint counts as reached within this distance, in pixels.
const WAYPOINT_REACHED := 8.0
## Only walls/towers this close are considered for breaking through.
const BREAK_SEARCH_RADIUS := 220.0

var definition: EnemyDefinition

## What it's attacking or walking to right now.
var _target: Node2D
var _cooldown := 0.0
var _path := PackedVector2Array()
var _path_index := 0
var _path_goal: Node2D
var _path_version := -1
var _repath_left := 0.0
## True when the last path couldn't get within reach of the goal.
var _blocked := false

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health: Health = $Health
@onready var health_bar: HealthBar = $HealthBar
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/Shape


## Call before adding the enemy to the scene tree.
func setup(enemy_definition: EnemyDefinition) -> void:
	definition = enemy_definition


func _ready() -> void:
	assert(definition != null, "Call Enemy.setup() before adding the enemy to the tree")
	sprite.sprite_frames = definition.sprite_frames
	sprite.scale = Vector2.ONE * definition.sprite_scale
	sprite.offset = -definition.sprite_frames.get_meta("foot_offset", Vector2.ZERO)
	sprite.play(&"walk")
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_animation_finished)
	health_bar.place_above(sprite)
	_fit_hurtbox()
	health.reset(definition.max_health)
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if health.is_dead:
		return
	_cooldown -= delta
	_repath_left -= delta
	var goal := _pick_target()
	if goal == null:
		sprite.play(&"idle")
		return
	if _needs_repath(goal):
		_repath(goal)
	_target = goal
	if _blocked and not _in_reach(goal):
		var breakable := _nearest_breakable()
		if breakable:
			_target = breakable

	if _in_reach(_target):
		sprite.flip_h = _target.global_position.x < global_position.x
		if _cooldown <= 0.0:
			_cooldown = 1.0 / definition.attacks_per_second
			sprite.play(&"attack")
			sprite.frame = 0
		elif not _is_attacking():
			sprite.play(&"idle")
		return

	var step_to := _next_waypoint()
	var direction := (step_to - global_position).normalized()
	velocity = direction * definition.move_speed
	move_and_slide()
	if absf(direction.x) > 0.1:
		sprite.flip_h = direction.x < 0.0
	if not _is_attacking():
		sprite.play(&"walk")


func _needs_repath(goal: Node2D) -> bool:
	var nav := get_tree().get_first_node_in_group(&"nav_grid") as NavGrid
	return goal != _path_goal or _repath_left <= 0.0 or (nav and nav.version != _path_version)


func _repath(goal: Node2D) -> void:
	_path_goal = goal
	_path_index = 0
	_repath_left = REPATH_TIME
	var nav := get_tree().get_first_node_in_group(&"nav_grid") as NavGrid
	if nav == null:
		_path = PackedVector2Array()
		_blocked = false
		return
	# Aim for the goal's near edge, not its centre: a solid goal (the Core,
	# a tower) has open ground on several sides, and the centre can be
	# "closest" from the far side of a wall.
	var hit_radius: float = goal.get(&"hit_radius")
	var toward_me := (global_position - goal.global_position).limit_length(hit_radius)
	var aim := goal.global_position + toward_me
	_path = nav.find_path(global_position, aim)
	_path_version = nav.version
	var end := _path[-1] if not _path.is_empty() else global_position
	_blocked = end.distance_to(aim) > definition.attack_range + nav.agent_radius + nav.cell_size


## The next path point to walk to; straight at the target once the path runs out.
func _next_waypoint() -> Vector2:
	while _path_index < _path.size() and global_position.distance_to(_path[_path_index]) <= WAYPOINT_REACHED:
		_path_index += 1
	if _target == _path_goal and _path_index < _path.size():
		return _path[_path_index]
	if _target != _path_goal and _path_index < _path.size() - 1:
		# Breaking through: follow the path up to the barrier first.
		return _path[_path_index]
	return _target.global_position


## Closest wall or tower still standing, to smash when walled off.
func _nearest_breakable() -> Node2D:
	var best: Node2D = null
	var best_distance := BREAK_SEARCH_RADIUS
	for node in get_tree().get_nodes_in_group(&"breakables"):
		var structure := node as Node2D
		if structure.get_node(^"Health").is_dead:
			continue
		var distance := global_position.distance_to(structure.global_position)
		if distance < best_distance:
			best = structure
			best_distance = distance
	return best


## Sizes the hurtbox to the visible pixels of the first idle frame, padded.
func _fit_hurtbox() -> void:
	var frame := sprite.sprite_frames.get_frame_texture(&"idle", 0)
	var used := Rect2(frame.get_image().get_used_rect())
	var cell_top_left := -frame.get_size() / 2.0 + sprite.offset
	var visible := Rect2((cell_top_left + used.position) * sprite.scale, used.size * sprite.scale)
	var shape := RectangleShape2D.new()
	shape.size = visible.size * definition.hurtbox_padding
	hurtbox_shape.shape = shape
	hurtbox_shape.position = visible.get_center()


func _pick_target() -> Node2D:
	var hero := get_tree().get_first_node_in_group(&"hero") as Hero
	if hero and not hero.health.is_dead \
			and global_position.distance_to(hero.global_position) <= definition.aggro_range:
		# An operating hero is untouchable; the tower takes the hits instead.
		if hero.operating:
			return hero.operating
		return hero
	var core := get_tree().get_first_node_in_group(&"core") as CommandCore
	if core and not core.health.is_dead:
		return core
	return null


func _in_reach(target: Node2D) -> bool:
	var reach: float = definition.attack_range + target.get(&"hit_radius")
	return global_position.distance_to(target.global_position) <= reach


func _is_attacking() -> bool:
	return sprite.animation == &"attack" and sprite.is_playing()


func _on_frame_changed() -> void:
	if sprite.animation != &"attack" or sprite.frame != definition.attack_hit_frame:
		return
	# The target may have moved away or died during the wind-up.
	if not is_instance_valid(_target) or not _in_reach(_target):
		return
	var target_health := _target.get_node(^"Health") as Health
	if not target_health.is_dead:
		target_health.take_damage(definition.attack_damage)


func _on_animation_finished() -> void:
	if sprite.animation == &"death":
		var fade := create_tween()
		fade.tween_interval(CORPSE_TIME)
		fade.tween_property(self, "modulate:a", 0.0, 0.6)
		fade.tween_callback(queue_free)


func _on_died() -> void:
	velocity = Vector2.ZERO
	# Stop catching bolts; deferred because this can fire mid-physics.
	hurtbox.set_deferred(&"collision_layer", 0)
	z_index = -1
	sprite.play(&"death")
	killed.emit(self)
