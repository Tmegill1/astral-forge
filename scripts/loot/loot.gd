class_name Loot
extends RefCounted
## Resource types and dropping pickups into the world.

const PICKUP_SCENE := preload("res://scenes/loot/pickup.tscn")

const SCRAP := &"scrap"
const AETHER := &"aether"

const NAMES := {SCRAP: "Scrap", AETHER: "Aether"}
const ICONS := {
	SCRAP: [
		preload("res://assets/sprites/fortress/scrap_1.png"),
		preload("res://assets/sprites/fortress/scrap_2.png"),
		preload("res://assets/sprites/fortress/scrap_3.png"),
		preload("res://assets/sprites/fortress/scrap_4.png"),
	],
	AETHER: [
		preload("res://assets/sprites/fortress/aether_1.png"),
		preload("res://assets/sprites/fortress/aether_2.png"),
		preload("res://assets/sprites/fortress/aether_3.png"),
		preload("res://assets/sprites/fortress/aether_4.png"),
	],
}
## Big drops are split into at most this many piles.
const MAX_PILES := 6


static func display_name(type: StringName) -> String:
	return NAMES.get(type, String(type).capitalize())


static func icon(type: StringName) -> Texture2D:
	return ICONS[type][0]


## Scatters `amount` of a resource around `at` as pickups under `parent`.
static func drop(parent: Node, at: Vector2, type: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var piles := mini(amount, MAX_PILES)
	for i in piles:
		# Share the amount out evenly; earlier piles take any remainder.
		var value := amount / piles + (1 if i < amount % piles else 0)
		var pickup: Pickup = PICKUP_SCENE.instantiate()
		pickup.type = type
		pickup.amount = value
		pickup.position = at
		parent.add_child(pickup)
		pickup.pop_to(at + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 30.0))
