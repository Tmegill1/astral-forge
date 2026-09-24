extends Node2D
## Runs one game: spawns the selected hero, keeps it and the camera inside
## the painted map, feeds the test spawner, drops loot, handles the hero
## falling and respawning, and ends the run when the Command Core falls.

const HERO_SCENE := preload("res://scenes/heroes/hero.tscn")
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
@onready var spawner: EnemySpawner = $EnemySpawner
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
	spawner.area = map.grow(-8.0)
	spawner.container = units
	spawner.enemy_spawned.connect(func(e: Enemy) -> void: e.killed.connect(_on_enemy_killed))


func _process(delta: float) -> void:
	_elapsed += delta
	if _respawn_left > 0.0:
		_respawn_left -= delta
		hud.show_respawn(_respawn_left)
		if _respawn_left <= 0.0:
			hero.revive(hero_spawn.position)


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
	game_over.show_defeat(_elapsed, kills)


func _map_rect() -> Rect2:
	var used := terrain.get_used_rect()
	var tile := Vector2(terrain.tile_set.tile_size)
	return Rect2(terrain.position + Vector2(used.position) * tile, Vector2(used.size) * tile)
