class_name TowerGlow
extends Node2D
## Placeholder look for evolved towers: a soft, slowly pulsing coloured ring
## on the ground under the tower.

var color := Color.WHITE
var radius := 30.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.004)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, radius * 1.4, Color(color, 0.12 * pulse))
	draw_circle(Vector2.ZERO, radius, Color(color, 0.22 * pulse))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, 0.7 * pulse), 2.0)
	draw_set_transform(Vector2.ZERO)
