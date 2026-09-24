extends Node2D
## Runs one game: spawns the selected hero, keeps it and the camera inside
## the painted map, feeds the test spawner, and ends the run when the
## Command Core falls.

const HERO_SCENE := preload("res://scenes/heroes/hero.tscn")
## How far inside the map edge the hero's feet must stay, in pixels.
const EDGE_MARGIN := 24.0
## Seconds before a fallen hero gets back up at HeroSpawn.
const HERO_RESPAWN_TIME := 5.0

var hero: Hero
var kills := 0

var _elapsed := 0.0

@onready var terrain: TileMapLayer = $TerrainLayer
@onready var units: Node2D = $Units
@onready var core: CommandCore = $Units/CommandCore
@onready var hero_spawn: Marker2D = $HeroSpawn
@onready var spawner: EnemySpawner = $EnemySpawner
@onready var hud: HUD = $HUD
@onready var game_over: GameOverScreen = $GameOver


func _ready() -> void:
	var map := _map_rect()
	hero = HERO_SCENE.instantiate()
	hero.setup(Game.selected_hero)
	hero.position = hero_spawn.position
	hero.bounds = map.grow(-EDGE_MARGIN)
	units.add_child(hero)
	hero.camera.limit_left = int(map.position.x)
	hero.camera.limit_top = int(map.position.y)
	hero.camera.limit_right = int(map.end.x)
	hero.camera.limit_bottom = int(map.end.y)
	hero.died.connect(_on_hero_died)
	hud.bind_hero(hero)
	hud.bind_core(core)
	core.destroyed.connect(_on_core_destroyed)

	spawner.area = map.grow(-8.0)
	spawner.container = units
	spawner.enemy_spawned.connect(func(e: Enemy) -> void: e.killed.connect(_on_enemy_killed))


func _process(delta: float) -> void:
	_elapsed += delta


func _on_enemy_killed(_enemy: Enemy) -> void:
	kills += 1


func _on_hero_died() -> void:
	await get_tree().create_timer(HERO_RESPAWN_TIME, false).timeout
	hero.revive(hero_spawn.position)


func _on_core_destroyed() -> void:
	game_over.show_defeat(_elapsed, kills)


func _map_rect() -> Rect2:
	var used := terrain.get_used_rect()
	var tile := Vector2(terrain.tile_set.tile_size)
	return Rect2(terrain.position + Vector2(used.position) * tile, Vector2(used.size) * tile)
