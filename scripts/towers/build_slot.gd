class_name BuildSlot
extends Node2D
## A pad the hero can build on. Stand on it and press Interact to spend the
## Core's stored resources on `tower`. Glows when the hero is close and it
## can be built on.

@export var tower: TowerDefinition
@export var locked := false
@export var empty_texture: Texture2D
@export var active_texture: Texture2D
@export var locked_texture: Texture2D
## The hero's feet must be this close for the pad to glow.
@export var highlight_radius := 70.0
## Where the tower's base sits relative to the pad's centre.
@export var tower_offset := Vector2(0, 18)

const TOWER_SCENE := preload("res://scenes/towers/tower.tscn")

var built: Tower

@onready var pad: Sprite2D = $Pad


func _process(_delta: float) -> void:
	if locked:
		pad.texture = locked_texture
		return
	var hero := get_tree().get_first_node_in_group(&"hero") as Hero
	var near := hero != null and not hero.health.is_dead \
			and hero.global_position.distance_to(global_position) <= highlight_radius
	pad.texture = active_texture if near and built == null else empty_texture


func interact(hero: Hero) -> void:
	if built:
		built.interact(hero)
		return
	if locked or tower == null:
		return
	var core := get_tree().get_first_node_in_group(&"core") as CommandCore
	if core == null or not core.stored.spend_all(tower.cost):
		return
	built = TOWER_SCENE.instantiate()
	built.setup(tower)
	built.position = tower_offset
	built.projectile_parent = get_parent()
	add_child(built)


func get_interact_prompt(hero: Hero) -> String:
	if built:
		return built.get_interact_prompt(hero)
	if locked or tower == null:
		return ""
	var core := get_tree().get_first_node_in_group(&"core") as CommandCore
	var missing := core.stored.shortfall(tower.cost)
	if missing.is_empty():
		return "[E] Build %s (%s)" % [tower.display_name, Loot.describe(tower.cost)]
	return "%s costs %s stored — need %s more" % [
		tower.display_name, Loot.describe(tower.cost), Loot.describe(missing)]
