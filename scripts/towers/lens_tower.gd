class_name LensTower
extends SpireTower
## The Focus Lens (an evolved Aether Spire): no chaining; a continuous beam
## on one target, ticking 10 times a second, whose damage ramps from 1× to
## 5× over 3 s and resets when it changes target. On its own it picks the
## enemy with the most health in range and stays on it; operated, the enemy
## in range nearest the mouse. Q = Overload: full ramp at once and 1.5× on
## top for 4 s.

## The beam stays drawn, and the ramp kept, this long after its last tick.
const BEAM_HOLD := 0.15

var lens: LensDefinition
var beam_target: Enemy
## 0..1 toward full ramp on beam_target.
var ramp := 0.0
var _beam_left := 0.0


func _ready() -> void:
	lens = definition as LensDefinition
	assert(lens != null, "A LensTower needs a LensDefinition")
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	_beam_left -= delta
	if _beam_left <= 0.0 or not _target_ok(beam_target):
		beam_target = null
		ramp = 0.0
	elif _ability_left > 0.0:
		ramp = 1.0
	else:
		ramp = minf(ramp + delta / lens.ramp_time, 1.0)
	queue_redraw()


## Beam ticks per second (not the Spire's bolt rate).
func fire_rate() -> float:
	return lens.tick_rate


## One beam tick: the Spire's single-target damage per second spread over
## the ticks, times the ramp (and Overload).
func tick_damage() -> float:
	var value := damage() * super.fire_rate() / lens.tick_rate * lens.ramp_multiplier(ramp)
	if _ability_left > 0.0:
		value *= lens.overload_multiplier
	return value


## Keeps its current target while it's alive and in range; otherwise the
## enemy in range with the most health.
func _find_target() -> Enemy:
	if _target_ok(beam_target):
		return beam_target
	var best: Enemy = null
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy.health.is_dead or global_position.distance_to(enemy.global_position) > attack_range():
			continue
		if best == null or enemy.health.current > best.health.current:
			best = enemy
	return best


func _target_ok(enemy: Enemy) -> bool:
	return enemy != null and is_instance_valid(enemy) and not enemy.health.is_dead \
			and global_position.distance_to(enemy.global_position) <= attack_range()


func _fire_at(point: Vector2) -> void:
	var target := beam_target if operator == null and _target_ok(beam_target) else _first_target(point)
	if target == null:
		return
	if target != beam_target:
		beam_target = target
		ramp = 0.0
	target.health.take_damage(tick_damage(), Health.DamageType.MAGIC)
	_beam_left = BEAM_HOLD
	sprite.animation = StringName("lv%d_fire" % level)
	sprite.stop()
	sprite.frame = 0
	_fire_frame_left = CHARGE_FRAME_TIME


## Starts Overload if it's recharged.
func use_ability() -> void:
	if operator == null or _ability_cooldown_left > 0.0:
		return
	_ability_left = definition.ability_duration
	_ability_cooldown_left = definition.ability_cooldown


## The range ring and aim marker while operated (SpireTower), then the beam:
## wider and brighter as it ramps.
func _draw() -> void:
	super()
	if beam_target == null or not is_instance_valid(beam_target):
		return
	var from := to_local(_muzzle_base())
	var to := to_local(_aim_point(beam_target))
	var width := 2.0 + 6.0 * ramp
	draw_line(from, to, Color(lens.beam_color, 0.35), width * 2.5)
	draw_line(from, to, Color(Color.WHITE.lerp(lens.beam_color, 0.4), 0.9), width)
	draw_circle(to, width * 1.5, Color(lens.beam_color, 0.6))
