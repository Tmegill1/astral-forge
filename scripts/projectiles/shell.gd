class_name Shell
extends Node2D
## A mortar shell: flies from `from` to `target` over flight_time on an arc,
## with a shadow on the ground and a faint circle marking where it lands. On
## landing it damages every living enemy within `radius`, flashes, and can
## leave a RuneCircle that slows enemies.

## Emitted once per enemy damaged; `killed` if that finished it.
signal hit(damage: float, killed: bool)

const BLAST_TIME := 0.25

var from := Vector2.ZERO
var target := Vector2.ZERO
var flight_time := 0.9
var arc_height := 90.0
var damage := 14.0
var radius := 70.0
## Seconds the landing leaves a slowing rune circle for; 0 = none.
var rune_duration := 0.0
## Share of speed taken away inside the circle (0.4 = 40% slower).
var rune_slow := 0.0
var color := Color(0.45, 0.85, 1.0)

var _time := 0.0
var _blast_left := 0.0


func _ready() -> void:
	global_position = from
	z_index = 5


func _physics_process(delta: float) -> void:
	if _blast_left > 0.0:
		_blast_left -= delta
		queue_redraw()
		if _blast_left <= 0.0:
			queue_free()
		return
	_time += delta
	var t := minf(_time / flight_time, 1.0)
	global_position = from.lerp(target, t)
	queue_redraw()
	if t >= 1.0:
		_land()


func _land() -> void:
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy.health.is_dead or enemy.global_position.distance_to(target) > radius:
			continue
		enemy.health.take_damage(damage)
		hit.emit(damage, enemy.health.is_dead)
	if rune_duration > 0.0:
		var circle := RuneCircle.new()
		circle.radius = radius
		circle.duration = rune_duration
		circle.slow = rune_slow
		circle.color = color
		circle.position = target
		# Under the units, over the ground (falls back to the shell's parent).
		var layer := get_tree().get_first_node_in_group(&"ground_effects")
		(layer if layer else get_parent()).add_child(circle)
	_blast_left = BLAST_TIME


## Height above the ground at flight progress t (0..1): a parabola.
func _height(t: float) -> float:
	return arc_height * 4.0 * t * (1.0 - t)


func _draw() -> void:
	var landing := to_local(target)
	if _blast_left > 0.0:
		var k := 1.0 - _blast_left / BLAST_TIME
		draw_circle(Vector2.ZERO, radius * (0.4 + 0.6 * k), Color(color, 0.45 * (1.0 - k)))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(Color.WHITE, 0.8 * (1.0 - k)), 3.0)
		return
	var t := minf(_time / flight_time, 1.0)
	# Where it will land.
	draw_arc(landing, radius, 0.0, TAU, 48, Color(color, 0.25 + 0.35 * t), 1.5)
	# Shadow on the ground, then the shell above it.
	draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.35))
	var up := Vector2(0, -_height(t))
	draw_circle(up, 9.0, Color(color, 0.3))
	draw_circle(up, 5.0, Color.WHITE.lerp(color, 0.5))
