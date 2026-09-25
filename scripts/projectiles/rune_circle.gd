class_name RuneCircle
extends Node2D
## A glowing rune ring left by a Rune Shell: enemies inside are slowed while
## it lasts. Fades out over its last second.

var radius := 140.0
var duration := 4.0
## Share of speed taken away inside (0.4 = move at 60%).
var slow := 0.4
var color := Color(0.45, 0.85, 1.0)

var _left := 0.0


func _ready() -> void:
	_left = duration


func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if not enemy.health.is_dead and enemy.global_position.distance_to(global_position) <= radius:
			# Short refresh: the slow ends soon after leaving the circle.
			enemy.slow(1.0 - slow, 0.2)
	queue_redraw()


func _draw() -> void:
	var alpha := clampf(_left, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(color, 0.12 * alpha))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color, 0.7 * alpha), 3.0)
	draw_arc(Vector2.ZERO, radius * 0.7, 0.0, TAU, 48, Color(color, 0.35 * alpha), 1.5)
