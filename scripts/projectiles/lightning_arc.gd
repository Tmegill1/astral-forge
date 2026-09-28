class_name LightningArc
extends Node2D
## A lightning bolt through `points` (world positions): a jagged line between
## each pair, re-jittered every frame, that fades out and frees itself. It
## keeps its own copy of the points, so it doesn't need the tower or the
## enemies to still exist.

## Roughly how long each straight piece of the jagged line is, in pixels.
const SEGMENT := 14.0
## How far each corner can stray from the straight line, in pixels.
const JITTER := 7.0

## World positions: where the bolt starts, then each enemy it hit.
var points := PackedVector2Array()
## A Resonance Burst: thicker, brighter and longer-lasting.
var burst := false

var _life := 0.15
var _left := 0.15


func _ready() -> void:
	_life = 0.25 if burst else 0.15
	_left = _life


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var alpha := clampf(_left / _life, 0.0, 1.0)
	var width := 4.0 if burst else 2.5
	for i in points.size() - 1:
		var path := _jagged(to_local(points[i]), to_local(points[i + 1]))
		draw_polyline(path, Color(0.55, 0.85, 1.0, 0.45 * alpha), width * 2.5)
		draw_polyline(path, Color(0.92, 0.98, 1.0, alpha), width)


func _jagged(from: Vector2, to: Vector2) -> PackedVector2Array:
	var path := PackedVector2Array([from])
	var steps := maxi(2, ceili(from.distance_to(to) / SEGMENT))
	var normal := (to - from).orthogonal().normalized()
	for s in range(1, steps):
		path.append(from.lerp(to, float(s) / steps) + normal * randf_range(-JITTER, JITTER))
	path.append(to)
	return path
