class_name WaveDirector
extends Node
## Runs the waves in a RunDefinition: a countdown (scavenge and build),
## then the wave's enemies arrive from their sectors; once they're all dead
## the next countdown starts. Clearing the last wave wins the run.
## Enemies spawn along the middle half of their sector's map edge.

signal wave_started(number: int)
signal wave_cleared(number: int)
signal break_started(number: int)
signal run_won
signal enemy_spawned(enemy: Enemy)

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")

enum State { BREAK, WAVE, WON }

@export var run: RunDefinition

## Set by the world: the playable map and where enemies go.
var area: Rect2
var container: Node

var state := State.BREAK
## Index of the current (or upcoming, during a break) wave.
var wave_index := 0
## Seconds left in the current break.
var break_left := 0.0

var _spawn_queue: Array[Dictionary] = []
var _wave_time := 0.0
var _alive: Array[Enemy] = []


func start() -> void:
	_begin_break()


func current_wave() -> WaveDefinition:
	return run.waves[wave_index] if wave_index < run.waves.size() else null


func wave_count() -> int:
	return run.waves.size()


## Enemies still to come or still alive in the current wave.
func enemies_left() -> int:
	return _spawn_queue.size() + _alive.size()


## Sectors to warn about: the upcoming wave's during a break, otherwise
## sectors that still have enemies coming or alive.
func threatened_sectors() -> Array[StringName]:
	if state == State.BREAK and current_wave():
		return current_wave().sectors()
	var result: Array[StringName] = []
	for spawn in _spawn_queue:
		if not spawn.sector in result:
			result.append(spawn.sector)
	for enemy in _alive:
		var sector: StringName = enemy.get_meta(&"sector")
		if not sector in result:
			result.append(sector)
	return result


## Skips the rest of the break.
func start_wave_now() -> void:
	if state == State.BREAK:
		break_left = 0.0


func _process(delta: float) -> void:
	match state:
		State.BREAK:
			break_left -= delta
			if break_left <= 0.0:
				_begin_wave()
		State.WAVE:
			_wave_time += delta
			while not _spawn_queue.is_empty() and _spawn_queue[0].time <= _wave_time:
				var spawn: Dictionary = _spawn_queue.pop_front()
				_spawn(spawn.enemy, spawn.sector)
			_alive = _alive.filter(func(e: Enemy) -> bool: return is_instance_valid(e) and not e.health.is_dead)
			if _spawn_queue.is_empty() and _alive.is_empty():
				_end_wave()


func _begin_break() -> void:
	state = State.BREAK
	break_left = current_wave().prep_time
	break_started.emit(wave_index + 1)


func _begin_wave() -> void:
	state = State.WAVE
	_wave_time = 0.0
	_spawn_queue.clear()
	for group in current_wave().groups:
		for i in group.count:
			_spawn_queue.append({time = group.delay + i * group.interval,
					enemy = group.enemy, sector = StringName(group.sector)})
	_spawn_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	wave_started.emit(wave_index + 1)


func _end_wave() -> void:
	wave_cleared.emit(wave_index + 1)
	wave_index += 1
	if wave_index >= run.waves.size():
		state = State.WON
		run_won.emit()
	else:
		_begin_break()


func _spawn(enemy: EnemyDefinition, sector: StringName) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.setup(enemy)
	e.position = spawn_point(sector)
	e.set_meta(&"sector", sector)
	container.add_child(e)
	_alive.append(e)
	enemy_spawned.emit(e)
	return e


## A random point along the middle half of a sector's map edge.
func spawn_point(sector: StringName) -> Vector2:
	var inset := area.grow(-12.0)
	var t := randf_range(0.25, 0.75)
	match sector:
		&"north":
			return Vector2(lerpf(inset.position.x, inset.end.x, t), inset.position.y)
		&"south":
			return Vector2(lerpf(inset.position.x, inset.end.x, t), inset.end.y)
		&"east":
			return Vector2(inset.end.x, lerpf(inset.position.y, inset.end.y, t))
		_:
			return Vector2(inset.position.x, lerpf(inset.position.y, inset.end.y, t))


## Test/debug helper: spawn one enemy at an exact point, outside any wave.
func spawn_at(enemy: EnemyDefinition, at: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.setup(enemy)
	e.position = at
	e.set_meta(&"sector", &"west")
	container.add_child(e)
	enemy_spawned.emit(e)
	return e
