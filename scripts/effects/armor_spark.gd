class_name ArmorSpark
extends Node2D
## A quick burst of grey-white sparks where armour turned a hit aside.
## Frees itself.

const LIFE := 0.15
const RAYS := 6

var _left := LIFE
var _angles := PackedFloat32Array()


func _ready() -> void:
	z_index = 1
	for i in RAYS:
		_angles.append(randf() * TAU)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := 1.0 - _left / LIFE
	var colour := Color(0.92, 0.94, 1.0, _left / LIFE)
	for angle in _angles:
		var direction := Vector2.from_angle(angle)
		draw_line(direction * (3.0 + 10.0 * t), direction * (7.0 + 14.0 * t), colour, 2.0)
