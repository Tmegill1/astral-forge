class_name BuildSlot
extends Node2D
## A pad the hero can build on.
##
## Empty: Interact opens the build menu (game paused) listing `buildable`
## towers. Building also raises walls on both sides of the tower: they run
## out at right angles to the Core direction, then turn back toward the
## middle, funnelling enemies around them.
## Built: Interact operates the tower; Manage (F) opens repair / upgrade /
## evolve / sell. Upgrading a tower levels up its walls too (art and health).
## Destroyed: the wreckage clears after a few seconds; walls stay up.
## Locked: Interact pays unlock_cost (Scrap) to open the pad.

const TOWER_SCENE := preload("res://scenes/towers/tower.tscn")
const WALL_SCENE := preload("res://scenes/structures/wall.tscn")
## Share of the tower's cost refunded when sold.
const SELL_REFUND := 0.5
## Repairs cost 1 Scrap per this much missing health (rounded up).
const REPAIR_HP_PER_SCRAP := 25.0
## Seconds a destroyed tower's wreckage stays before the pad is free again.
const WRECKAGE_TIME := 4.0
## Posts in walls that run up/down the screen are this far apart, in pixels.
const POST_SPACING := 18.0
## Walls that run across the screen use pieces about this wide, in pixels.
const PANEL_WIDTH := 80.0
## Wall piece health at wall level 1, 2, 3.
const WALL_HEALTH: Array[float] = [120.0, 180.0, 260.0]

@export var buildable: Array[TowerDefinition] = []
@export var locked := false
## Stored resources spent to unlock a locked pad.
@export var unlock_cost: Dictionary[StringName, int] = {&"scrap": 6}
@export var empty_texture: Texture2D
@export var active_texture: Texture2D
@export var locked_texture: Texture2D
## The hero's feet must be this close for the pad to glow.
@export var highlight_radius := 70.0
## Where the tower's base sits relative to the pad's centre.
@export var tower_offset := Vector2(0, 18)

@export_group("Walls")
## Gap between the tower's centre and the first wall post, in pixels.
@export var wall_start := 26.0
## How far each wall runs out from the tower, in pixels.
@export var wall_length := 170.0
## Length of the end piece turning back toward the middle, in pixels.
@export var wall_return := 100.0
## Wall art per wall level (index 0 = Lv1).
@export var wall_textures: Array[Texture2D] = []
@export var wall_damaged_textures: Array[Texture2D] = []
## Width of each level's left pillar, cut out as a post for up/down walls.
@export var wall_post_widths: PackedInt32Array = [52, 52, 48]
@export var wall_scale := 0.4

var built: Tower
## One entry per planned wall piece; null where a piece was destroyed.
var walls: Array[Wall] = []
## Level of this slot's walls; raised by tower upgrades, reset by selling.
var wall_level := 1
## Everything paid for the current tower (build + upgrades), for refunds.
var invested: Dictionary[StringName, int] = {}

var _wall_plan: Array[Dictionary] = []
var _wreckage_left := 0.0

@onready var pad: Sprite2D = $Pad


func _process(delta: float) -> void:
	if _wreckage_left > 0.0:
		_wreckage_left -= delta
		if _wreckage_left <= 0.0:
			_clear_tower()
	if locked:
		pad.texture = locked_texture
		return
	var hero := get_tree().get_first_node_in_group(&"hero") as Hero
	var near := hero != null and not hero.health.is_dead \
			and hero.global_position.distance_to(global_position) <= highlight_radius
	pad.texture = active_texture if near and built == null else empty_texture


# --- Interaction ---

func interact(hero: Hero) -> void:
	if locked:
		unlock()
	elif built:
		built.interact(hero)
	else:
		get_tree().call_group(&"build_menu", &"open", self)


func manage(_hero: Hero) -> void:
	if built and not built.is_destroyed():
		get_tree().call_group(&"tower_menu", &"open", self)


## True when Manage would open something (the touch Manage button shows then).
func can_manage(hero: Hero) -> bool:
	return built != null and not built.is_destroyed() and hero.operating != built


func get_interact_prompt(hero: Hero) -> String:
	if locked:
		var missing := core().stored.shortfall(unlock_cost)
		if missing.is_empty():
			return "%sUnlock slot (%s)" % [_key_hint(&"interact"), Loot.describe(unlock_cost)]
		return "Unlock slot: need %s more" % Loot.describe(missing)
	if built == null:
		return _key_hint(&"interact") + "Build"
	if built.is_destroyed():
		return "%s destroyed — clearing in %ds" % [built.definition.display_name, ceili(_wreckage_left)]
	var text := built.get_interact_prompt(hero)
	if hero.operating == built:
		return text
	return text + "    %sRepair / Upgrade / Sell" % _key_hint(&"manage")


# --- Building, selling, repairing ---

func core() -> CommandCore:
	return get_tree().get_first_node_in_group(&"core") as CommandCore


## Pays unlock_cost and opens the pad for building. False if it isn't
## locked or the Core can't afford it (nothing is spent then).
func unlock() -> bool:
	if not locked or not core().stored.spend_all(unlock_cost):
		return false
	locked = false
	return true


## Pays for and builds `tower`, plus any missing walls. False if it can't.
func build(tower: TowerDefinition) -> bool:
	if built or locked or not tower.available or not core().stored.spend_all(tower.cost):
		return false
	invested = tower.cost.duplicate()
	built = _spawn_tower(tower, 1)
	_raise_walls()
	get_tree().call_group(&"nav_grid", &"mark_dirty")
	return true


func sell_value() -> Dictionary[StringName, int]:
	var value: Dictionary[StringName, int] = {}
	for type in invested:
		value[type] = floori(invested[type] * SELL_REFUND)
	return value


## Removes the tower and its walls and refunds part of what was spent on it.
func sell() -> void:
	if built == null or built.is_destroyed():
		return
	core().stored.add_all(sell_value())
	if built.operator:
		built.operator.stop_operating()
	for wall in walls:
		if is_instance_valid(wall):
			wall.queue_free()
	walls.clear()
	_wall_plan.clear()
	wall_level = 1
	_clear_tower()
	invested = {}


## Scrap needed to bring the tower and every wall piece back to full.
func repair_cost() -> int:
	var missing := built.health.max_health - built.health.current
	for wall in walls:
		if is_instance_valid(wall):
			missing += wall.health.max_health - wall.health.current
		else:
			missing += WALL_HEALTH[wall_level - 1]
	return ceili(missing / REPAIR_HP_PER_SCRAP)


func repair() -> bool:
	var cost: Dictionary[StringName, int] = {Loot.SCRAP: repair_cost()}
	if cost[Loot.SCRAP] <= 0 or not core().stored.spend_all(cost):
		return false
	built.health.heal(built.health.max_health)
	for wall in walls:
		if is_instance_valid(wall):
			wall.health.heal(wall.health.max_health)
	_raise_walls()
	return true


## Pays for the tower's next level and applies it, levelling up the walls
## with it. False if there's no tower, it's wrecked or maxed, or the Core
## can't afford it (nothing is spent then).
func upgrade() -> bool:
	if built == null or built.is_destroyed() or built.level >= TowerDefinition.MAX_LEVEL:
		return false
	var cost := built.definition.upgrade_cost(built.level + 1)
	if not core().stored.spend_all(cost):
		return false
	for type in cost:
		invested[type] = invested.get(type, 0) + cost[type]
	built.set_level(built.level + 1)
	if built.level > wall_level:
		wall_level = built.level
		for i in walls.size():
			if is_instance_valid(walls[i]):
				var textures := _wall_art(_wall_plan[i].post)
				walls[i].restyle(textures[0], textures[1], WALL_HEALTH[wall_level - 1])
	return true


## True when the tower can evolve now (cost aside): standing, Lv3, not yet
## evolved, and it has branches.
func can_evolve() -> bool:
	return built != null and not built.is_destroyed() \
			and built.level >= TowerDefinition.MAX_LEVEL \
			and not built.definition.evolved and not built.definition.evolutions.is_empty()


## Pays for `branch` and swaps the tower for it, in place: same spot, Lv3,
## the same damage taken, walls untouched, and an operating hero stays on.
## False if it can't evolve, `branch` isn't one of its branches, or the Core
## can't afford it (nothing is spent then).
func evolve(branch: TowerDefinition) -> bool:
	if not can_evolve() or branch not in built.definition.evolutions:
		return false
	if not core().stored.spend_all(branch.evolve_cost):
		return false
	for type in branch.evolve_cost:
		invested[type] = invested.get(type, 0) + branch.evolve_cost[type]
	var old := built
	var missing := old.health.max_health - old.health.current
	var hero := old.operator
	if hero:
		hero.stop_operating()
	remove_child(old)
	old.queue_free()
	built = _spawn_tower(branch, TowerDefinition.MAX_LEVEL)
	if missing > 0.0:
		built.health.take_damage(minf(missing, built.health.max_health - 1.0))
	if hero:
		hero.start_operating(built)
	get_tree().call_group(&"nav_grid", &"mark_dirty")
	return true


func _on_tower_destroyed(_tower: Tower) -> void:
	_wreckage_left = WRECKAGE_TIME


## Creates `tower` at `tower_level` on this pad and hooks it up.
func _spawn_tower(tower: TowerDefinition, tower_level: int) -> Tower:
	var spawned: Tower = (tower.scene if tower.scene else TOWER_SCENE).instantiate()
	spawned.setup(tower)
	spawned.level = tower_level
	spawned.position = tower_offset
	spawned.projectile_parent = get_parent()
	spawned.destroyed.connect(_on_tower_destroyed)
	add_child(spawned)
	return spawned


func _clear_tower() -> void:
	_wreckage_left = 0.0
	if built:
		built.queue_free()
		built = null
	get_tree().call_group(&"nav_grid", &"mark_dirty")


# --- Walls ---

## Builds every planned wall piece that isn't standing.
func _raise_walls() -> void:
	if _wall_plan.is_empty():
		_wall_plan = _plan_walls()
		walls.resize(_wall_plan.size())
	for i in _wall_plan.size():
		if is_instance_valid(walls[i]):
			continue
		var piece: Dictionary = _wall_plan[i]
		var wall: Wall = WALL_SCENE.instantiate()
		var textures := _wall_art(piece.post)
		var size := Vector2(20, 14) if piece.post else Vector2(piece.width, 14)
		wall.setup(textures[0], textures[1], size, wall_scale)
		wall.max_health = WALL_HEALTH[wall_level - 1]
		wall.position = piece.position
		get_parent().add_child(wall)
		walls[i] = wall
	get_tree().call_group(&"nav_grid", &"mark_dirty")


## Where each wall piece goes (world positions): two runs out from the
## tower at right angles to the Core direction, each ending in a piece
## that turns back toward the middle (unless wall_return is 0).
func _plan_walls() -> Array[Dictionary]:
	var origin := global_position + tower_offset
	var to_core := core().global_position - origin
	var inward := Vector2(signf(to_core.x), 0) if absf(to_core.x) >= absf(to_core.y) \
			else Vector2(0, signf(to_core.y))
	var along := inward.orthogonal()
	var plan: Array[Dictionary] = []
	for side in [-1.0, 1.0]:
		var start: Vector2 = origin + along * side * wall_start
		var corner: Vector2 = origin + along * side * wall_length
		plan.append_array(_plan_segment(start, corner))
		# wall_return 0 (the slot ring) means a straight run, not a zero-length piece.
		if wall_return > 0.0:
			plan.append_array(_plan_segment(corner, corner + inward * wall_return))
	return plan


## Up/down runs are rows of posts; across runs are wall pieces.
func _plan_segment(from: Vector2, to: Vector2) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var length := from.distance_to(to)
	var vertical := absf(to.y - from.y) > absf(to.x - from.x)
	if vertical:
		var count := maxi(1, ceili(length / POST_SPACING))
		for i in count + 1:
			plan.append({position = from.lerp(to, float(i) / count), post = true})
	else:
		var count := maxi(1, ceili(length / PANEL_WIDTH))
		for i in count:
			plan.append({position = from.lerp(to, (i + 0.5) / count), post = false, width = length / count})
	return plan


## [intact, damaged] art for a wall piece at the current wall level.
func _wall_art(post: bool) -> Array[Texture2D]:
	var intact := wall_textures[wall_level - 1]
	var damaged := wall_damaged_textures[wall_level - 1]
	if post:
		var width := wall_post_widths[wall_level - 1]
		return [_post_texture(intact, width), _post_texture(damaged, width)]
	return [intact, damaged]


## The left pillar of a wall picture, used as a post.
func _post_texture(texture: Texture2D, width: int) -> Texture2D:
	var post := AtlasTexture.new()
	post.atlas = texture
	post.region = Rect2(0, 0, width, texture.get_height())
	return post


## Looked up by path: tests load this script standalone, where the Settings
## autoload is not a known identifier.
func _key_hint(action: StringName) -> String:
	return get_node("/root/Settings").key_hint(action)
