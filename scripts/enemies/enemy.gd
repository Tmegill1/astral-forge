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
## A pulse cast ended: `landed` is false when a stun or death cut it short.
signal pulse_finished(landed: bool)

## Seconds a body stays on the ground before fading out.
const CORPSE_TIME := 1.5
const SPARK_SCENE := preload("res://scenes/effects/armor_spark.tscn")
const FRENZY_PULSE_SCENE := preload("res://scenes/enemies/frenzy_pulse.tscn")
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
## Movement is multiplied by this while slowed (1 = normal).
var _slow_factor := 1.0
var _slow_left := 0.0
## Burn: each stack deals _burn_dps per second until _burn_left runs out.
var _burn_stacks := 0
var _burn_dps := 0.0
var _burn_left := 0.0
## While above 0 it can't move or attack.
var _stun_left := 0.0
## The wall or tower an ignores_walls enemy walked into.
var _smash: Node2D
## True once it has fled (the run was won): no loot, no "killed".
var fled := false
## Frenzy (from a Shaman's pulse): extra speed and damage until
## _frenzy_left runs out.
var _frenzy_speed := 0.0
var _frenzy_damage := 0.0
var _frenzy_left := 0.0
## True while standing still casting a pulse.
var _pulsing := false

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health: Health = $Health
@onready var health_bar: HealthBar = $HealthBar
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/Shape
@onready var on_screen: VisibleOnScreenNotifier2D = $OnScreen


## Call before adding the enemy to the scene tree.
func setup(enemy_definition: EnemyDefinition) -> void:
	definition = enemy_definition


func _ready() -> void:
	assert(definition != null, "Call Enemy.setup() before adding the enemy to the tree")
	sprite.sprite_frames = definition.sprite_frames
	sprite.scale = Vector2.ONE * definition.sprite_scale
	sprite.modulate = definition.tint
	sprite.offset = -definition.sprite_frames.get_meta("foot_offset", Vector2.ZERO)
	sprite.play(&"walk")
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_animation_finished)
	health_bar.place_above(sprite)
	_fit_hurtbox()
	on_screen.screen_entered.connect(_on_screen_entered, CONNECT_ONE_SHOT)
	health.reset(definition.max_health)
	health.damage_taken = PackedFloat32Array([
			definition.physical_taken, definition.fire_taken, definition.magic_taken])
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	if definition.is_boss:
		add_to_group(&"bosses")
	queue_redraw()
	if definition.pulse_interval > 0.0:
		add_child(FRENZY_PULSE_SCENE.instantiate())


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
	if _frenzy_left > 0.0:
		_frenzy_left -= delta
		if _frenzy_left <= 0.0:
			_frenzy_speed = 0.0
			_frenzy_damage = 0.0
	if _stun_left > 0.0:
		_stun_left -= delta
		velocity = Vector2.ZERO
		sprite.play(&"idle")
		return
	if _pulsing:
		velocity = Vector2.ZERO
		return
	var goal := _pick_target()
	if goal == null:
		velocity = Vector2.ZERO
		sprite.play(&"idle")
		return
	if definition.ignores_walls:
		# Straight at the goal; smash whatever wall or tower it walked into.
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

	if _in_reach(_target):
		# Standing still to attack (towers read velocity to lead their shots).
		velocity = Vector2.ZERO
		sprite.flip_h = _target.global_position.x < global_position.x
		if _cooldown <= 0.0:
			_cooldown = 1.0 / definition.attacks_per_second
			sprite.play(definition.attack_animation)
			sprite.frame = 0
		elif not _is_attacking():
			sprite.play(&"idle")
		return

	var step_to := _next_waypoint()
	var direction := (step_to - global_position).normalized()
	velocity = direction * definition.move_speed * speed_multiplier()
	move_and_slide()
	if definition.ignores_walls and _smash == null:
		for i in get_slide_collision_count():
			var collider := get_slide_collision(i).get_collider() as Node2D
			if collider and collider.is_in_group(&"breakables"):
				_smash = collider
				break
	if absf(direction.x) > 0.1:
		sprite.flip_h = direction.x < 0.0
	if not _is_attacking():
		sprite.play(&"walk")


## Slows movement to `factor` (0.6 = 60% speed) for `seconds`. The strongest
## slow wins; a new one refreshes the time.
func slow(factor: float, seconds: float) -> void:
	_slow_factor = minf(_slow_factor, factor) if _slow_left > 0.0 else factor
	_slow_left = maxf(_slow_left, seconds)


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


## Stops it moving and attacking for `seconds`. The longer stun wins.
func stun(seconds: float) -> void:
	if health.is_dead:
		return
	_stun_left = maxf(_stun_left, seconds)
	_cancel_pulse()


func is_stunned() -> bool:
	return _stun_left > 0.0


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


## Stun (pale blue) shows over frenzy (red) over burn (orange); all flicker.
func _update_tint() -> void:
	var flicker := sin(Time.get_ticks_msec() * 0.02)
	if _stun_left > 0.0:
		sprite.modulate = Color.WHITE.lerp(Color(0.6, 0.85, 1.0), 0.45 + 0.15 * flicker) * definition.tint
	elif _frenzy_left > 0.0:
		sprite.modulate = Color.WHITE.lerp(Color(1.0, 0.4, 0.35), 0.35 + 0.15 * flicker) * definition.tint
	elif _burn_stacks > 0:
		sprite.modulate = Color.WHITE.lerp(Color(1.0, 0.55, 0.25), 0.25 + 0.1 * flicker) * definition.tint
	else:
		sprite.modulate = definition.tint


## A physical hit that armour partly blocked throws sparks.
func _on_damaged(_dealt: float, type: int, blocked: float) -> void:
	if type != Health.DamageType.PHYSICAL or blocked <= 0.0:
		return
	var spark: ArmorSpark = SPARK_SCENE.instantiate()
	get_parent().add_child(spark)
	spark.global_position = hurtbox_shape.global_position


func _tick_burn(delta: float) -> void:
	health.take_damage(_burn_stacks * _burn_dps * minf(delta, _burn_left), Health.DamageType.FIRE)
	_burn_left -= delta
	if _burn_left <= 0.0:
		_burn_stacks = 0


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
	_blocked = not _path_reaches(goal, end, aim, nav)


## True if a path ending at `end` gets the enemy up to `goal`. A solid goal
## (the Core, a tower) can only be approached to the edge of its grown nav
## footprint, a square that on a diagonal sits farther out than `aim`.
func _path_reaches(goal: Node2D, end: Vector2, aim: Vector2, nav: NavGrid) -> bool:
	var slack := definition.attack_range + nav.agent_radius + nav.cell_size
	if goal.has_method(&"nav_footprint"):
		var footprint: Rect2 = goal.nav_footprint()
		return footprint.grow(slack).has_point(end)
	return end.distance_to(aim) <= slack


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
	on_screen.rect = visible


## The first time any enemy of this type is on screen, it joins the Codex.
func _on_screen_entered() -> void:
	Codex.mark_seen(definition)


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
	return sprite.animation == definition.attack_animation and sprite.is_playing()


func _on_frame_changed() -> void:
	if sprite.animation != definition.attack_animation or sprite.frame != definition.attack_hit_frame:
		return
	# The target may have moved away or died during the wind-up.
	if not is_instance_valid(_target) or not _in_reach(_target):
		return
	var target_health := _target.get_node(^"Health") as Health
	if target_health.is_dead:
		return
	if definition.projectile_scene:
		_shoot(_target)
	else:
		var hit := attack_damage()
		if _target.is_in_group(&"breakables"):
			hit *= definition.structure_damage_multiplier
		target_health.take_damage(hit)


## Throws the definition's projectile from the body at `target`'s current
## position; it flies a little past it, then fades out.
func _shoot(target: Node2D) -> void:
	var from := hurtbox_shape.global_position
	var to_target := target.global_position - from
	var count := maxi(definition.projectile_count, 1)
	for i in count:
		# Fanned evenly over projectile_spread_deg, centred on the target.
		var spread := 0.0 if count == 1 \
				else lerpf(-0.5, 0.5, float(i) / (count - 1)) * definition.projectile_spread_deg
		var shot: Projectile = definition.projectile_scene.instantiate()
		shot.global_position = from
		shot.direction = to_target.normalized().rotated(deg_to_rad(spread))
		shot.speed = definition.projectile_speed
		shot.damage = attack_damage()
		shot.damage_type = Health.DamageType.MAGIC
		shot.max_distance = to_target.length() + 60.0
		get_parent().add_child(shot)


func _on_animation_finished() -> void:
	if sprite.animation == definition.pulse_animation and _pulsing:
		_pulsing = false
		pulse_finished.emit(true)
		return
	if sprite.animation == &"death":
		var fade := create_tween()
		fade.tween_interval(CORPSE_TIME)
		fade.tween_property(self, "modulate:a", 0.0, 0.6)
		fade.tween_callback(queue_free)


func _on_died() -> void:
	_cancel_pulse()
	_burn_stacks = 0
	_stun_left = 0.0
	_frenzy_left = 0.0
	_frenzy_speed = 0.0
	_frenzy_damage = 0.0
	sprite.modulate = definition.tint
	queue_redraw()
	velocity = Vector2.ZERO
	# Stop catching bolts; deferred because this can fire mid-physics.
	hurtbox.set_deferred(&"collision_layer", 0)
	z_index = -1
	sprite.play(&"death")
	killed.emit(self)


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


## The placeholder bosses' glowing ring under the feet.
func _draw() -> void:
	if definition == null or definition.aura.a <= 0.0 or health.is_dead:
		return
	var radius := 18.0 * definition.sprite_scale / 0.3
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, radius, Color(definition.aura, definition.aura.a * 0.5))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, definition.aura, 3.0)
	draw_set_transform(Vector2.ZERO)
