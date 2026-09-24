extends Node2D
## Spawns the selected hero at HeroSpawn and keeps the hero and camera
## inside the painted part of TerrainLayer.

const HERO_SCENE := preload("res://scenes/heroes/hero.tscn")
## How far inside the map edge the hero's feet must stay, in pixels.
const EDGE_MARGIN := 24.0

var hero: Hero

@onready var terrain: TileMapLayer = $TerrainLayer
@onready var hero_spawn: Marker2D = $HeroSpawn
@onready var hud: HUD = $HUD


func _ready() -> void:
	var map := _map_rect()
	hero = HERO_SCENE.instantiate()
	hero.setup(Game.selected_hero)
	hero.position = hero_spawn.position
	hero.bounds = map.grow(-EDGE_MARGIN)
	add_child(hero)
	hud.bind_hero(hero)
	hero.camera.limit_left = int(map.position.x)
	hero.camera.limit_top = int(map.position.y)
	hero.camera.limit_right = int(map.end.x)
	hero.camera.limit_bottom = int(map.end.y)


func _map_rect() -> Rect2:
	var used := terrain.get_used_rect()
	var tile := Vector2(terrain.tile_set.tile_size)
	return Rect2(terrain.position + Vector2(used.position) * tile, Vector2(used.size) * tile)
