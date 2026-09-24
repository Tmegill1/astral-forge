class_name NavGrid
extends Node
## Grid pathfinding for enemies. Anything in the "nav_blockers" group with a
## nav_footprint() -> Rect2 method (walls, towers, the Core) is solid.
## Call mark_dirty() when blockers are added or removed; the grid rebuilds
## on the next physics step and bumps `version` so paths get recomputed.

## Grid cell size in pixels.
@export var cell_size := 16
## Blockers are grown by this much so enemies' bodies fit through gaps.
@export var agent_radius := 12.0

## Increases every rebuild; enemies repath when it changes.
var version := 0

var _grid := AStarGrid2D.new()
var _dirty := false


func _ready() -> void:
	add_to_group(&"nav_grid")


## Covers `area` (world space) with the grid.
func setup(area: Rect2) -> void:
	_grid.region = Rect2i(Vector2i((area.position / cell_size).floor()),
			Vector2i((area.size / cell_size).ceil()))
	_grid.cell_size = Vector2.ONE * cell_size
	_grid.offset = Vector2.ONE * cell_size / 2.0
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	rebuild()


func mark_dirty() -> void:
	_dirty = true


func _physics_process(_delta: float) -> void:
	if _dirty:
		rebuild()


func rebuild() -> void:
	_dirty = false
	_grid.fill_solid_region(_grid.region, false)
	for blocker in get_tree().get_nodes_in_group(&"nav_blockers"):
		if blocker.is_queued_for_deletion():
			continue
		var r: Rect2 = blocker.nav_footprint().grow(agent_radius)
		var from := Vector2i((r.position / cell_size).floor())
		var to := Vector2i((r.end / cell_size).ceil())
		_grid.fill_solid_region(Rect2i(from, to - from).intersection(_grid.region), true)
	version += 1


## World-space waypoints from `from` toward `to`. If `to` can't be reached
## (inside a blocker, or walled off), the path ends at the closest reachable
## point instead; compare its end with `to` to tell.
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := _free_cell_near(_cell(from))
	var end := _cell(to)
	if start == Vector2i(-1, -1):
		return PackedVector2Array()
	return _grid.get_point_path(start, end, true)


func is_solid_at(point: Vector2) -> bool:
	return _grid.is_point_solid(_cell(point))


func _cell(point: Vector2) -> Vector2i:
	var c := Vector2i((point / cell_size).floor())
	var r := _grid.region
	return c.clamp(r.position, r.end - Vector2i.ONE)


## An enemy pressed against a wall can stand in a "grown" solid cell; start
## from the nearest open cell instead.
func _free_cell_near(cell: Vector2i) -> Vector2i:
	if not _grid.is_point_solid(cell):
		return cell
	for radius in range(1, 6):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var c := cell + Vector2i(dx, dy)
				if _grid.region.has_point(c) and not _grid.is_point_solid(c):
					return c
	return Vector2i(-1, -1)
