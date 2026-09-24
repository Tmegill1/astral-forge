class_name BuildMenu
extends CanvasLayer
## Pop-up for choosing what to build on a pad. Pauses the game while open.
## Click a card's Build button or press its number; Esc (or E) closes.

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
		cards.add_child(_card(i + 1, tower, stored))


func _card(number: int, tower: TowerDefinition, stored: ResourceBag) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(190, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.17, 0.21)
	style.set_corner_radius_all(4)
	card.add_theme_stylebox_override(&"panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	card.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	margin.add_child(rows)

	var icon := TextureRect.new()
	icon.texture = tower.icon()
	icon.custom_minimum_size = Vector2(0, 90)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rows.add_child(icon)
	rows.add_child(_label("%d. %s" % [number, tower.display_name], 16, Color(1, 0.92, 0.6)))
	var desc := _label(tower.description, 12, Color(0.85, 0.85, 0.9))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(170, 48)
	rows.add_child(desc)
	if tower.available:
		rows.add_child(_label("Damage %.0f · %.1f/s · Range %.0f" % [
				tower.attack_damage, tower.attacks_per_second, tower.attack_range], 12, Color(0.75, 0.9, 1)))

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 34)
	var missing := stored.shortfall(tower.cost)
	if not tower.available:
		button.text = "Coming soon"
		button.disabled = true
	elif not missing.is_empty():
		button.text = "Need %s more" % Loot.describe(missing)
		button.disabled = true
	else:
		button.text = "Build — %s" % Loot.describe(tower.cost)
		button.pressed.connect(_choose.bind(tower))
	rows.add_child(button)
	if not tower.available or not missing.is_empty():
		card.modulate = Color(1, 1, 1, 0.55)
	return card


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


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
