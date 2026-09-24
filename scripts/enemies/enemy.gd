class_name Enemy
extends CharacterBody2D
## Every enemy uses this script; what differs (art, stats) comes from the
## EnemyDefinition passed to setup() before it spawns.
##
## Walks straight at the Command Core and attacks it, but turns on the hero
## when the hero comes within aggro range.

signal killed(enemy: Enemy)

## Seconds a body stays on the ground before fading out.
const CORPSE_TIME := 1.5

var definition: EnemyDefinition

var _target: Node2D
var _cooldown := 0.0

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
	_target = _pick_target()
	if _target == null:
		sprite.play(&"idle")
		return

	var to_target := _target.global_position - global_position
	sprite.flip_h = to_target.x < 0.0
	if _in_reach(_target):
		if _cooldown <= 0.0:
			_cooldown = 1.0 / definition.attacks_per_second
			sprite.play(&"attack")
			sprite.frame = 0
		elif not _is_attacking():
			sprite.play(&"idle")
	else:
		velocity = to_target.normalized() * definition.move_speed
		move_and_slide()
		if not _is_attacking():
			sprite.play(&"walk")


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
