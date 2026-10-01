class_name CardMenu
extends CanvasLayer
## The level-up screen: pauses the game and offers 3 cards; click one or
## press 1-3. Several level-ups show back to back. A pick is required (Esc
## does nothing). Never opens once the run is over.

const CARD_SCENE := preload("res://scenes/ui/power_card.tscn")

## Level-ups still waiting for a pick (not counting the one on screen).
var pending := 0

var _cards: RunCards
var _shown: Array[PowerCard] = []

@onready var title: Label = %Title
@onready var row: HBoxContainer = %Cards


func _ready() -> void:
	visible = false
	_cards = get_tree().get_first_node_in_group(&"run_cards") as RunCards
	if _cards:
		_cards.leveled_up.connect(_on_leveled_up)


func is_open() -> bool:
	return visible


## Takes the card at `index` (0-2) of the current offer.
func pick(index: int) -> void:
	if not visible or index < 0 or index >= _shown.size():
		return
	_cards.take(_shown[index].card)
	_show_next()


func _on_leveled_up(_new_level: int) -> void:
	if _cards.ended:
		return
	pending += 1
	if not visible:
		_show_next()


func _show_next() -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	_shown.clear()
	while pending > 0 and not _cards.ended:
		var offer := _cards.offer(3)
		if offer.is_empty():
			pending = 0
			break
		pending -= 1
		title.text = "Level %d — choose a card" % (_cards.level - pending)
		for i in offer.size():
			var power_card: PowerCard = CARD_SCENE.instantiate()
			row.add_child(power_card)
			power_card.show_card(offer[i], _cards.rank_of(offer[i]) + 1, i + 1)
			power_card.chosen.connect(pick.bind(i))
			_shown.append(power_card)
		visible = true
		get_tree().paused = true
		_shown[0].choose_button.grab_focus()
		return
	if visible:
		visible = false
		# Once the run is over its end screen keeps the game paused.
		if not _cards.ended:
			get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = event.physical_keycode - KEY_1
		if index >= 0 and index < _shown.size():
			pick(index)
	# The pick is required: swallow everything else (Esc included).
	get_viewport().set_input_as_handled()
