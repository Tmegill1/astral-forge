extends Node2D
## Runs one game: spawns the selected hero, keeps it and the camera inside
## the painted map, runs the waves, scatters scrap heaps each break, drops
## loot, handles the hero falling and respawning, and ends the run when the
## Command Core falls (defeat) or the last wave is cleared (victory).

const HERO_SCENE := preload("res://scenes/heroes/hero.tscn")
const HEAP_SCENE := preload("res://scenes/loot/resource_heap.tscn")
## Scrap heaps never appear closer to the Core than this, in pixels.
const HEAP_MIN_DISTANCE := 380.0
## Heaps get 1 more Scrap per this many pixels from the Core.
const HEAP_DISTANCE_PER_SCRAP := 250.0
## How far inside the map edge the hero's feet must stay, in pixels.
const EDGE_MARGIN := 24.0

const OUTSIDE_MAP_COLOR := Color(0.07, 0.1, 0.07)

## Seconds before a fallen hero gets back up at HeroSpawn (by the Core).
@export var hero_respawn_time := 15.0
## Share of carried resources lost when the hero falls. The rest is dropped
## where they fell, so they can go back for it.
@export_range(0.0, 1.0) var fall_loss := 0.5

var hero: Hero
var kills := 0

var _elapsed := 0.0
var _respawn_left := 0.0

@onready var terrain: TileMapLayer = $TerrainLayer
@onready var units: Node2D = $Units
@onready var core: CommandCore = $Units/CommandCore
@onready var hero_spawn: Marker2D = $HeroSpawn
@onready var waves: WaveDirector = $WaveDirector
@onready var nav: NavGrid = $NavGrid
@onready var hud: HUD = $HUD
@onready var game_over: GameOverScreen = $GameOver


func _ready() -> void:
	var map := _map_rect()
	hero = HERO_SCENE.instantiate()
	hero.setup(Game.selected_hero)
	hero.position = hero_spawn.position
	hero.bounds = map.grow(-EDGE_MARGIN)
	units.add_child(hero)
	hero.camera_bounds = map
	# What shows past the map's edge when zoomed out.
	RenderingServer.set_default_clear_color(OUTSIDE_MAP_COLOR)
	hero.died.connect(_on_hero_died)
	hud.bind_hero(hero)
	hud.bind_core(core)
	core.destroyed.connect(_on_core_destroyed)

	nav.setup(map)
	waves.area = map
	waves.container = units
	waves.enemy_spawned.connect(func(e: Enemy) -> void: e.killed.connect(_on_enemy_killed))
	waves.break_started.connect(func(_number: int) -> void: _scatter_heaps(map))
	waves.run_won.connect(_on_run_won)
	hud.bind_waves(waves)
	waves.start()


func _process(delta: float) -> void:
	_elapsed += delta
	if _respawn_left > 0.0:
		_respawn_left -= delta
		hud.show_respawn(_respawn_left)
		if _respawn_left <= 0.0:
			hero.revive(hero_spawn.position)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"start_wave"):
		waves.start_wave_now()


## Drops scrap heaps at random open spots away from the Core; farther ones
## hold more, rewarding the risk of going out.
func _scatter_heaps(map: Rect2) -> void:
	var placed := 0
	var tries := 0
	var inner := map.grow(-60.0)
	var room := waves.run.max_heaps - get_tree().get_nodes_in_group(&"resource_heaps").size()
	while placed < mini(waves.run.heaps_per_break, room) and tries < 200:
		tries += 1
		var at := Vector2(randf_range(inner.position.x, inner.end.x), randf_range(inner.position.y, inner.end.y))
		var distance := at.distance_to(core.global_position)
		if distance < HEAP_MIN_DISTANCE or nav.is_solid_at(at):
			continue
		if get_tree().get_nodes_in_group(&"resource_heaps").any(
				func(h: Node2D) -> bool: return h.global_position.distance_to(at) < 120.0):
			continue
		var heap: ResourceHeap = HEAP_SCENE.instantiate()
		heap.amount = 3 + floori(distance / HEAP_DISTANCE_PER_SCRAP)
		heap.position = at
		units.add_child(heap)
		placed += 1


func _on_enemy_killed(enemy: Enemy) -> void:
	kills += 1
	var drops := enemy.definition.drops
	for type in drops:
		Loot.drop(units, enemy.global_position, type, randi_range(drops[type].x, drops[type].y))


func _on_hero_died() -> void:
	# Lose part of what was carried (rounded down); drop the rest here.
	var carried := hero.carried.take_all()
	for type in carried:
		var kept := carried[type] - floori(carried[type] * fall_loss)
		Loot.drop(units, hero.global_position, type, kept)
	_respawn_left = hero_respawn_time
	hud.show_respawn(_respawn_left)


func _on_core_destroyed() -> void:
	game_over.show_defeat(_elapsed, kills, waves.wave_index)


func _on_run_won() -> void:
	game_over.show_victory(_elapsed, kills)


func _map_rect() -> Rect2:
	var used := terrain.get_used_rect()
	var tile := Vector2(terrain.tile_set.tile_size)
	return Rect2(terrain.position + Vector2(used.position) * tile, Vector2(used.size) * tile)
