class_name BindingRow
extends HBoxContainer
## One action in the Options controls list: its name and two binding slots.
## Click a slot, then press a key or mouse button to bind it. Esc cancels;
## Delete or Backspace clears the slot.

const AMBER := Color(1.0, 0.75, 0.3)

var action: StringName
## The slot waiting for input, or -1.
var _listening_slot := -1

@onready var name_label: Label = %Name
@onready var slot_buttons: Array[Button] = [%Primary, %Secondary]


## Call before adding the row to the tree.
func setup(for_action: StringName) -> void:
	action = for_action


func _ready() -> void:
	name_label.text = Settings.LABELS[action]
	for i in slot_buttons.size():
		slot_buttons[i].pressed.connect(_listen.bind(i))
	Settings.changed.connect(refresh)
	refresh()


func refresh() -> void:
	var events := Settings.events_for(action)
	for i in slot_buttons.size():
		var button := slot_buttons[i]
		button.remove_theme_color_override(&"font_color")
		button.tooltip_text = ""
		if i == _listening_slot:
			button.text = "Press a key or mouse button…"
			continue
		button.text = Settings.event_label(events[i])
		var others := Settings.actions_sharing(action, events[i])
		if not others.is_empty():
			button.add_theme_color_override(&"font_color", AMBER)
			button.tooltip_text = "Also used by: " + ", ".join(
					others.map(func(other: StringName) -> String: return Settings.LABELS[other]))


func is_listening() -> bool:
	return _listening_slot >= 0


func _listen(slot: int) -> void:
	_listening_slot = slot
	refresh()


func _input(event: InputEvent) -> void:
	if _listening_slot < 0 or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey:
		match event.physical_keycode:
			KEY_ESCAPE:
				pass
			KEY_DELETE, KEY_BACKSPACE:
				Settings.clear(action, _listening_slot)
			_:
				Settings.bind(action, _listening_slot, event)
	elif event is InputEventMouseButton:
		Settings.bind(action, _listening_slot, event)
	else:
		return
	get_viewport().set_input_as_handled()
	_listening_slot = -1
	refresh()
