class_name EnemySpawner
extends Node
## Test spawner for Phase 2: drops enemies at random points on the map edge,
## a little faster each time. Phase 7 replaces it with real waves.

signal enemy_spawned(enemy: Enemy)

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")

@export var enemy: EnemyDefinition
@export var first_delay := 3.0
@export var start_interval := 3.0
@export var min_interval := 0.8
## Seconds taken off the interval after each spawn.
@export var interval_step := 0.1

## Set by the world: where to spawn (edge of this rect) and where to put enemies.
var area: Rect2
var container: Node

var _interval: float
var _timer: float


func _ready() -> void:
	_interval = start_interval
	_timer = first_delay


func _process(delta: float) -> void:
	if container == null or not area.has_area():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	spawn(_random_edge_point())
	_interval = maxf(min_interval, _interval - interval_step)
	_timer = _interval


func spawn(at: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.setup(enemy)
	e.position = at
	container.add_child(e)
	enemy_spawned.emit(e)
	return e


func _random_edge_point() -> Vector2:
	# Walk a random distance around the rectangle's perimeter.
	var w := area.size.x
	var h := area.size.y
	var d := randf() * 2.0 * (w + h)
	var p := area.position
	if d < w:
		return p + Vector2(d, 0)
	d -= w
	if d < h:
		return p + Vector2(w, d)
	d -= h
	if d < w:
		return p + Vector2(w - d, h)
	return p + Vector2(0, h - (d - w))
