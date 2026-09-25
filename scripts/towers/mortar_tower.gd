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
