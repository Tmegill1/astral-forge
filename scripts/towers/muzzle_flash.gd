extends Node2D
## A brief glow at a barrel tip when a tower fires.

@export var color := Color(0.5, 0.9, 1.0)
@export var radius := 14.0

var _left := 0.0


func _ready() -> void:
	visible = false


func flash(duration: float) -> void:
	_left = duration
	visible = true


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0:
			visible = false


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius * 1.8, Color(color, 0.3))
	draw_circle(Vector2.ZERO, radius, Color(color, 0.85))
	draw_circle(Vector2.ZERO, radius * 0.45, Color.WHITE)
