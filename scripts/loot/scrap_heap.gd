class_name ScrapHeap
extends Node2D
## A pile of salvage out in the world. Interact to break it open; it bursts
## into Scrap pickups. The world makes heaps farther from the Core richer.

@export var amount := 4

@onready var pieces: Node2D = $Pieces


func _ready() -> void:
	# A few random gear pieces make up the heap's look.
	var icons: Array = Loot.ICONS[Loot.SCRAP]
	for i in pieces.get_child_count():
		(pieces.get_child(i) as Sprite2D).texture = icons.pick_random()


func interact(_hero: Hero) -> void:
	Loot.drop(get_parent(), global_position, Loot.SCRAP, amount)
	queue_free()


func get_interact_prompt(_hero: Hero) -> String:
	return "[E] Salvage heap (%d Scrap)" % amount
