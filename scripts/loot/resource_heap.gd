class_name ResourceHeap
extends Node2D
## A pile of salvage (Scrap) or a crystal (Aether) out in the world. Interact
## to break it open; it bursts into pickups. The world makes farther Scrap
## heaps richer and only places crystals far from the Core.

@export var type: StringName = Loot.SCRAP
@export var amount := 4

@onready var pieces: Node2D = $Pieces


func _ready() -> void:
	# A few random pieces of this resource's art make up the heap's look.
	var icons: Array = Loot.ICONS[type]
	for i in pieces.get_child_count():
		(pieces.get_child(i) as Sprite2D).texture = icons.pick_random()


func interact(_hero: Hero) -> void:
	Loot.drop(get_parent(), global_position, type, amount)
	queue_free()


func get_interact_prompt(_hero: Hero) -> String:
	var action := "Break crystal" if type == Loot.AETHER else "Salvage heap"
	return "%s%s (%d %s)" % [Settings.key_hint(&"interact"), action, amount, Loot.display_name(type)]
