# Paints a grass field onto TerrainLayer in the world scene and saves it.
# Mostly plain grass with scattered clover/flower accents; the fixed seed
# makes the layout repeatable. Overwrites any cells in the painted area.
#
# Run from the project root:
#     godot --headless --path . -s res://tools/paint_grass.gd
extends SceneTree

const SCENE_PATH := "res://scenes/world.tscn"
const WIDTH := 20
const HEIGHT := 12
const SEED := 42
const ACCENT_CHANCE := 0.12
const SOURCE_ID := 0
# Atlas coords of plain grass tiles.
const BASE := [Vector2i(1, 0), Vector2i(2, 0), Vector2i(14, 0)]
# Atlas coords of grass tiles with clover, flowers or leaves.
const ACCENTS := [Vector2i(0, 0), Vector2i(3, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(9, 0), Vector2i(10, 0)]


func _init() -> void:
	var root: Node2D = load(SCENE_PATH).instantiate()
	var layer: TileMapLayer = root.get_node("TerrainLayer")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for y in HEIGHT:
		for x in WIDTH:
			var tile: Vector2i
			if rng.randf() < ACCENT_CHANCE:
				tile = ACCENTS[rng.randi() % ACCENTS.size()]
			else:
				tile = BASE[rng.randi() % BASE.size()]
			layer.set_cell(Vector2i(x, y), SOURCE_ID, tile)
	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, SCENE_PATH)
	print("painted %dx%d grass on TerrainLayer, save result: %s" % [WIDTH, HEIGHT, error_string(err)])
	root.free()
	quit()
