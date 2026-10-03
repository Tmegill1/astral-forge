extends Node2D
## Runs one game: spawns the selected hero, keeps it and the camera inside
## the painted map, runs the waves, scatters scrap heaps and Aether crystals
## each break, drops loot, handles the hero falling and respawning, and ends
## the run when the Command Core falls (defeat) or the last wave is cleared
## (victory).

## Chance per kill of a Lodestone, unless one is already on the map.
const LODESTONE_CHANCE := 0.03
const HERO_SCENE := preload("res://scenes/heroes/hero.tscn")
const HEAP_SCENE := preload("res://scenes/loot/resource_heap.tscn")
## Scrap heaps never appear closer to the Core than this, in pixels.
const HEAP_MIN_DISTANCE := 380.0
## Heaps get 1 more Scrap per this many pixels from the Core.
const HEAP_DISTANCE_PER_SCRAP := 250.0
## Aether crystals never appear closer to the Core than this, in pixels.
const AETHER_MIN_DISTANCE := 800.0
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
## Kills this run by enemy type, for the end-of-run summary.
var kills_by_type: Dictionary[EnemyDefinition, int] = {}

var _elapsed := 0.0
var _respawn_left := 0.0

@onready var terrain: TileMapLayer = $TerrainLayer
@onready var units: Node2D = $Units
@onready var core: CommandCore = $Units/CommandCore
@onready var hero_spawn: Marker2D = $HeroSpawn
@onready var waves: WaveDirector = $WaveDirector
@onready var run_cards: RunCards = $RunCards
@onready var nav: NavGrid = $NavGrid
@onready var hud: HUD = $UI/HUD
@onready var game_over: GameOverScreen = $UI/GameOver


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
	hud.bind_run_cards(run_cards)
	run_cards.changed.connect(_on_cards_changed)
	core.destroyed.connect(_on_core_destroyed)

	nav.setup(map)
	waves.area = map
	waves.container = units
	waves.enemy_spawned.connect(func(e: Enemy) -> void: e.killed.connect(_on_enemy_killed))
	waves.break_started.connect(func(_number: int) -> void: _scatter_heaps(map))
	waves.run_won.connect(_on_run_won)
	hud.bind_waves(waves)
	var touch := get_node_or_null("UI/TouchControls") as TouchControls
	if touch and not touch.is_queued_for_deletion():
		touch.bind(hero, waves)
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


## Each break: Scrap heaps at random open spots away from the Core (farther
## ones hold more, rewarding the risk of going out), plus a few Aether
## crystals only far from the Core.
func _scatter_heaps(map: Rect2) -> void:
	var run := waves.run
	var scrap_room := run.max_heaps - _heaps_of(Loot.SCRAP).size()
	_place_heaps(map, Loot.SCRAP, mini(run.heaps_per_break, scrap_room), HEAP_MIN_DISTANCE,
			func(distance: float) -> int: return 3 + floori(distance / HEAP_DISTANCE_PER_SCRAP))
	var aether_room := run.max_aether - _heaps_of(Loot.AETHER).size()
	var aether_count := randi_range(run.aether_per_break.x, run.aether_per_break.y)
	_place_heaps(map, Loot.AETHER, mini(aether_count, aether_room), AETHER_MIN_DISTANCE,
			func(_distance: float) -> int: return randi_range(run.aether_amount.x, run.aether_amount.y))


## Heaps of one resource type currently on the map.
func _heaps_of(type: StringName) -> Array:
	return get_tree().get_nodes_in_group(&"resource_heaps").filter(
			func(heap: ResourceHeap) -> bool: return heap.type == type)


## Places up to `count` heaps of `type` at random open spots at least
## `min_distance` from the Core and apart from other heaps.
## `amount_for(distance)` decides how much each one holds.
func _place_heaps(map: Rect2, type: StringName, count: int, min_distance: float,
		amount_for: Callable) -> void:
	var placed := 0
	var tries := 0
	var inner := map.grow(-60.0)
	while placed < count and tries < 200:
		tries += 1
		var at := Vector2(randf_range(inner.position.x, inner.end.x), randf_range(inner.position.y, inner.end.y))
		var distance := at.distance_to(core.global_position)
		if distance < min_distance or nav.is_solid_at(at):
			continue
		if get_tree().get_nodes_in_group(&"resource_heaps").any(
				func(h: Node2D) -> bool: return h.global_position.distance_to(at) < 120.0):
			continue
		var heap: ResourceHeap = HEAP_SCENE.instantiate()
		heap.type = type
		heap.amount = amount_for.call(distance)
		heap.position = at
		units.add_child(heap)
		placed += 1


func _on_enemy_killed(enemy: Enemy) -> void:
	kills += 1
	kills_by_type[enemy.definition] = kills_by_type.get(enemy.definition, 0) + 1
	var at := enemy.global_position
	var drops := enemy.definition.drops
	for type in drops:
		var amount := randi_range(drops[type].x, drops[type].y)
		if type == Loot.SCRAP:
			amount = maxi(amount, roundi(amount * RunCards.multiplier(self, &"scrap_drops")))
		Loot.drop(units, at, type, amount)
	var rare := enemy.definition.rare_drops
	for type in rare:
		if randf() < rare[type]:
			Loot.drop(units, at, type, 1)
	var guaranteed := enemy.definition.guaranteed_drops
	for type in guaranteed:
		Loot.drop(units, at, type, guaranteed[type])
	if enemy.definition.drops_lodestone:
		Lodestone.drop(units, at)
	XpOrb.drop(units, at, enemy.definition.xp_value)
	if randf() < LODESTONE_CHANCE and not Lodestone.is_dropping() \
			and get_tree().get_nodes_in_group(&"lodestones").is_empty():
		Lodestone.drop(units, at)


## A card was taken: re-apply max-health bonuses to everything built.
func _on_cards_changed() -> void:
	core.refresh_max_health()
	get_tree().call_group(&"breakables", &"refresh_max_health")


func _on_hero_died() -> void:
	# Lose part of what was carried (rounded down); drop the rest here.
	var carried := hero.carried.take_all()
	for type in carried:
		var kept := carried[type] - floori(carried[type] * fall_loss)
		Loot.drop(units, hero.global_position, type, kept)
	_respawn_left = hero_respawn_time
	hud.show_respawn(_respawn_left)


func _on_core_destroyed() -> void:
	run_cards.end_run()
	game_over.show_summary(run_summary(false))


func _on_run_won() -> void:
	run_cards.end_run()
	game_over.show_summary(run_summary(true))


## Everything the end screen shows about this run.
func run_summary(victory: bool) -> Dictionary:
	var kill_rows := []
	for enemy in kills_by_type:
		kill_rows.append([enemy, kills_by_type[enemy]])
	kill_rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	var cards := []
	for card in run_cards.pool:
		var rank := run_cards.rank_of(card)
		if rank > 0:
			cards.append([card.title, rank])
	var towers := []
	for slot: BuildSlot in find_children("*", "BuildSlot", true, false):
		if slot.built and not slot.built.health.is_dead:
			towers.append([slot.built.definition, slot.built.level])
	return {
		"victory": victory,
		"seconds": _elapsed,
		"waves_cleared": waves.wave_index,
		"wave_count": waves.wave_count(),
		"core_health": core.health.current,
		"core_max": core.health.max_health,
		"kills": kill_rows,
		"kills_total": kills,
		"level": run_cards.level,
		"cards": cards,
		"towers": towers,
		"gathered": core.gathered.duplicate(),
	}


func _map_rect() -> Rect2:
	var used := terrain.get_used_rect()
	var tile := Vector2(terrain.tile_set.tile_size)
	return Rect2(terrain.position + Vector2(used.position) * tile, Vector2(used.size) * tile)
