class_name EmberTower
extends Tower
## The Embercaster: sprays a short cone of flame that sets enemies burning.
## Each flame tick (attacks_per_second) damages every enemy in the cone, adds
## a burn stack and uses up fuel. The tank refills whenever it isn't spraying;
## run it dry and it can't spray until it's back to restart_fraction. On its
## own it points the cone where it hits the most enemies; operated, at the
## mouse. Q = Overpressure: no fuel used, a bigger cone, and every tick sets
## burn to the maximum.

## A tick keeps it "spraying" this much longer than the gap to the next one.
const SPRAY_GRACE := 0.05
const FLAME_SEGMENTS := 12

var ember: EmberDefinition
## Seconds of spraying left in the tank.
var fuel := 0.0
## True after running dry, until the tank is back to restart_fraction.
var dry := false
## Which way the barrel faces (the art faces right).
var _facing_left := false
## Unit direction the cone points.
var _aim_dir := Vector2.RIGHT
var _spray_left := 0.0

@onready var embers: CPUParticles2D = $Embers


func _ready() -> void:
	ember = definition as EmberDefinition
	assert(ember != null, "An EmberTower needs an EmberDefinition")
	super()
	fuel = ember.fuel_seconds


func _physics_process(delta: float) -> void:
	super(delta)
	_spray_left = maxf(_spray_left - delta, 0.0)
	if not is_spraying():
		fuel = minf(fuel + delta * ember.fuel_seconds / ember.refill_seconds, ember.fuel_seconds)
		if dry and fuel >= ember.fuel_seconds * ember.restart_fraction:
			dry = false
	_show_spray()
	queue_redraw()


func is_spraying() -> bool:
	return _spray_left > 0.0


func overpressure_active() -> bool:
	return _ability_left > 0.0


func attack_range() -> float:
	return super() * (ember.overpressure_range_multiplier if overpressure_active() else 1.0)


## Full width of the cone, in degrees.
func cone_angle() -> float:
	return ember.cone_angle * (ember.overpressure_angle_multiplier if overpressure_active() else 1.0)


## Burn per stack, scaled like the flame (levels and operating).
func burn_dps() -> float:
	return ember.burn_dps_per_stack * damage() / ember.attack_damage


func _can_fire() -> bool:
	return overpressure_active() or not dry


## Every living enemy whose body is inside the cone pointed at `point`.
func _enemies_in_cone(point: Vector2) -> Array[Enemy]:
	var enemies := _living_enemies()
	var hits: Array[Enemy] = []
	for i in _cone_hits(point, _body_points(enemies), attack_range(), deg_to_rad(cone_angle()) / 2.0):
		hits.append(enemies[i])
	return hits


## The enemy in range whose cone would catch the most enemies (nearest wins
## ties). Reach, cone and enemy positions are worked out once per search.
func _find_target() -> Enemy:
	var enemies := _living_enemies()
	var points := _body_points(enemies)
	var reach := attack_range()
	var half := deg_to_rad(cone_angle()) / 2.0
	var best: Enemy = null
	var best_count := 0
	var best_distance := INF
	for i in enemies.size():
		var distance := _muzzle_facing(points[i].x < global_position.x).distance_to(points[i])
		if distance > reach:
			continue
		var count := _cone_hits(points[i], points, reach, half).size()
		if count > best_count or (count == best_count and distance < best_distance):
			best = enemies[i]
			best_count = count
			best_distance = distance
	return best


func _living_enemies() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if not enemy.health.is_dead:
			result.append(enemy)
	return result


## Where the flame aims on each enemy (its body).
func _body_points(enemies: Array[Enemy]) -> PackedVector2Array:
	var points := PackedVector2Array()
	for enemy in enemies:
		points.append(_aim_point(enemy))
	return points


## Indices of the `points` inside a cone aimed at `point`, reaching `reach`
## from the muzzle and `half` radians either side of its centre line.
func _cone_hits(point: Vector2, points: PackedVector2Array, reach: float, half: float) -> PackedInt32Array:
	var left := point.x < global_position.x
	var muzzle := _muzzle_facing(left)
	var direction := point - muzzle
	if direction.length() < 0.001:
		direction = Vector2.LEFT if left else Vector2.RIGHT
	var reach_squared := reach * reach
	var hits := PackedInt32Array()
	for i in points.size():
		var to_point := points[i] - muzzle
		if to_point.length_squared() <= reach_squared and absf(direction.angle_to(to_point)) <= half:
			hits.append(i)
	return hits


func _aim_at(point: Vector2) -> void:
	_facing_left = point.x < global_position.x
	sprite.flip_h = _facing_left
	var direction := point - _muzzle_base()
	if direction.length() > 0.001:
		_aim_dir = direction.normalized()


func _muzzle_facing(left: bool) -> Vector2:
	var offset := ember.muzzle_offset
	return global_position + Vector2(-offset.x if left else offset.x, offset.y)


func _muzzle_base() -> Vector2:
	return _muzzle_facing(_facing_left)


## One flame tick: damage and burn everything in the cone, and use up fuel.
func _fire_at(point: Vector2) -> void:
	var stacks := ember.burn_max_stacks if overpressure_active() else 1
	for enemy in _enemies_in_cone(point):
		var before := enemy.health.current
		enemy.health.take_damage(damage())
		if operator:
			mastery_xp += before - enemy.health.current
		enemy.add_burn(burn_dps(), ember.burn_max_stacks, ember.burn_duration, stacks)
	var tick_time := 1.0 / fire_rate()
	_spray_left = tick_time + SPRAY_GRACE
	if not overpressure_active():
		fuel = maxf(fuel - tick_time, 0.0)
		if fuel <= 0.0:
			dry = true


func _on_died() -> void:
	_spray_left = 0.0
	embers.emitting = false
	super()


## Spraying holds the first fire frame (the glowing barrel; the drawn cone is
## the flame, as the later frames' flames are clipped at the frame edge).
func _show_spray() -> void:
	var animation := StringName("lv%d_%s" % [level, "fire" if is_spraying() else "idle"])
	if sprite.animation != animation:
		if is_spraying():
			sprite.animation = animation
			sprite.stop()
			sprite.frame = 0
		else:
			sprite.play(animation)
	embers.emitting = is_spraying()
	if is_spraying():
		embers.global_position = _muzzle_base()
		embers.direction = _aim_dir
		embers.spread = cone_angle() / 2.0
		var speed := attack_range() / embers.lifetime
		embers.initial_velocity_min = speed * 0.6
		embers.initial_velocity_max = speed


## The flame while spraying, the cone outline while operated, and the fuel
## bar whenever the tank isn't full.
func _draw() -> void:
	if is_destroyed():
		return
	var muzzle := to_local(_muzzle_base())
	var facing := _aim_dir.angle()
	var half := deg_to_rad(cone_angle()) / 2.0
	if is_spraying():
		_draw_fan(muzzle, facing, half, attack_range() * randf_range(0.92, 1.0),
				Color(1.0, 0.95, 0.6, 0.9), Color(1.0, 0.35, 0.05, 0.12))
		_draw_fan(muzzle, facing, half * 0.45, attack_range() * randf_range(0.6, 0.75),
				Color(1.0, 0.9, 0.5, 0.8), Color(1.0, 0.55, 0.1, 0.25))
	if operator:
		var reach := Color(0.45, 0.85, 1.0)
		draw_arc(muzzle, attack_range(), facing - half, facing + half, 24, Color(reach, 0.5), 2.0)
		draw_line(muzzle, muzzle + Vector2.from_angle(facing - half) * attack_range(), Color(reach, 0.35), 1.5)
		draw_line(muzzle, muzzle + Vector2.from_angle(facing + half) * attack_range(), Color(reach, 0.35), 1.5)
	if fuel < ember.fuel_seconds:
		const WIDTH := 36.0
		var top_left := Vector2(-WIDTH / 2.0, 10.0)
		draw_rect(Rect2(top_left, Vector2(WIDTH, 4.0)), Color(0.0, 0.0, 0.0, 0.6))
		var fill := Color(1.0, 0.3, 0.2) if dry else Color(1.0, 0.65, 0.15)
		draw_rect(Rect2(top_left, Vector2(WIDTH * fuel / ember.fuel_seconds, 4.0)), fill)


## A flickering fan from `from`, `inner` colour at the tip fading to `outer`.
func _draw_fan(from: Vector2, facing: float, half: float, reach: float, inner: Color, outer: Color) -> void:
	var points := PackedVector2Array([from])
	var colors := PackedColorArray([inner])
	for i in FLAME_SEGMENTS + 1:
		var angle := facing - half + 2.0 * half * i / FLAME_SEGMENTS
		points.append(from + Vector2.from_angle(angle) * reach * randf_range(0.9, 1.0))
		colors.append(outer)
	draw_polygon(points, colors)
