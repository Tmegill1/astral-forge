class_name BuildMenu
extends CanvasLayer
## Pop-up for choosing what to build on a pad. Pauses the game while open.
## Click a card's Build button or press its number; Esc (or E) closes.

const CARD_SCENE := preload("res://scenes/ui/build_card.tscn")

@onready var title: Label = %Title
@onready var cards: HBoxContainer = %Cards

var _slot: BuildSlot
var _opened_frame := -1


func _ready() -> void:
	add_to_group(&"build_menu")
	visible = false


func open(slot: BuildSlot) -> void:
	_slot = slot
	_opened_frame = Engine.get_process_frames()
	title.text = "Build a tower"
	_fill_cards()
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	_slot = null
	get_tree().paused = false


func _fill_cards() -> void:
	for child in cards.get_children():
		child.queue_free()
	var stored := _slot.core().stored
	for i in _slot.buildable.size():
		var tower := _slot.buildable[i]
		var card: BuildCard = CARD_SCENE.instantiate()
		cards.add_child(card)
		card.show_tower(i + 1, tower, stored)
		card.chosen.connect(_choose)


func _choose(tower: TowerDefinition) -> void:
	var slot := _slot
	close()
	slot.build(tower)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"interact"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var index: int = event.physical_keycode - KEY_1
		if index >= 0 and index < _slot.buildable.size():
			var tower := _slot.buildable[index]
			if tower.available and _slot.core().stored.can_afford(tower.cost):
				_choose(tower)
			get_viewport().set_input_as_handled()
