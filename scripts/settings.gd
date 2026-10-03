extends Node
## Player settings: key bindings, fullscreen, auto-fire, volume and touch
## (autoloaded as "Settings"). Loaded from user://settings.cfg at startup,
## applied, and saved again on every change. Anything missing or unreadable
## in the file falls back to its default.

signal changed

const PATH := "user://settings.cfg"
const SLOTS := 2
## Rebindable actions, in the order the Options screen lists them.
const ACTIONS: Array[StringName] = [&"move_up", &"move_down", &"move_left",
		&"move_right", &"move_to", &"fire", &"interact", &"manage",
		&"tower_ability", &"start_wave", &"toggle_fullscreen"]
const LABELS := {
	&"move_up": "Move Up", &"move_down": "Move Down", &"move_left": "Move Left",
	&"move_right": "Move Right", &"move_to": "Walk to Spot", &"fire": "Fire",
	&"interact": "Interact", &"manage": "Manage / Upgrade",
	&"tower_ability": "Tower Ability", &"start_wave": "Start Wave",
	&"toggle_fullscreen": "Fullscreen",
}
const BUSES: Array[StringName] = [&"Master", &"Music", &"Effects"]
const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Left Mouse", MOUSE_BUTTON_RIGHT: "Right Mouse",
	MOUSE_BUTTON_MIDDLE: "Middle Mouse", MOUSE_BUTTON_WHEEL_UP: "Wheel Up",
	MOUSE_BUTTON_WHEEL_DOWN: "Wheel Down", MOUSE_BUTTON_XBUTTON1: "Mouse Back",
	MOUSE_BUTTON_XBUTTON2: "Mouse Forward",
}
const KEY_NAMES := {KEY_UP: "Up Arrow", KEY_DOWN: "Down Arrow",
		KEY_LEFT: "Left Arrow", KEY_RIGHT: "Right Arrow"}

## How much bigger the HUD and menus are in touch mode. The hero camera
## divides its zoom by this so the map view stays the same.
const TOUCH_UI_SCALE := 1.4

var fullscreen := false
var auto_fire := true
var volumes: Dictionary[StringName, float] = {&"Master": 1.0, &"Music": 1.0, &"Effects": 1.0}

## True on phones and tablets (or with the --touch user arg): on-screen
## controls, bigger UI, auto-fire always on, no key names in prompts.
var touch_mode := false

## Action -> [event or null, event or null].
var _bindings: Dictionary[StringName, Array] = {}
## The project's shipped bindings, captured before the file is applied.
var _defaults: Dictionary[StringName, Array] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action in ACTIONS:
		var events := InputMap.action_get_events(action)
		var slots: Array = []
		for i in SLOTS:
			slots.append(_clean(events[i]) if i < events.size() else null)
		_defaults[action] = slots
	_load()
	if OS.has_feature("web"):
		# Browsers only allow fullscreen after a click, so a page starts windowed.
		fullscreen = false
	_apply_all()
	get_tree().root.size_changed.connect(_sync_fullscreen)
	if OS.has_feature("web_android") or OS.has_feature("web_ios") \
			or OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--touch") \
			or (OS.has_feature("web_macos") and DisplayServer.is_touchscreen_available()):
		set_touch_mode(true)


## Binds `event` to `slot` (0 = primary, 1 = secondary) of `action`.
func bind(action: StringName, slot: int, event: InputEvent) -> void:
	var clean := _clean(event)
	if clean == null:
		return
	_bindings[action][slot] = clean
	_input_changed()


func clear(action: StringName, slot: int) -> void:
	_bindings[action][slot] = null
	_input_changed()


func reset_to_defaults() -> void:
	for action in ACTIONS:
		_bindings[action] = _defaults[action].duplicate()
	# Touch play keeps its fullscreen; desktop goes back to windowed.
	if not touch_mode:
		fullscreen = false
	auto_fire = true
	for bus in BUSES:
		volumes[bus] = 1.0
	_apply_all()
	_save()
	changed.emit()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_window()
	_save()
	changed.emit()


func set_auto_fire(on: bool) -> void:
	auto_fire = on or touch_mode
	_save()
	changed.emit()


## Switches touch mode on or off (detected at startup; tests switch it by
## hand). Auto-fire is forced on without saving over the desktop choice.
func set_touch_mode(on: bool) -> void:
	touch_mode = on
	get_tree().root.content_scale_factor = TOUCH_UI_SCALE if on else 1.0
	if on:
		auto_fire = true
	changed.emit()


## "[E] " for the first key or button bound to `action`, to put in front of
## a prompt; "" in touch mode (the on-screen buttons replace keys) or when
## nothing is bound.
func key_hint(action: StringName) -> String:
	if touch_mode or not _bindings.has(action):
		return ""
	for event in _bindings[action]:
		if event:
			return "[%s] " % event_label(event)
	return ""


## `value` 0–1; 0 mutes the bus.
func set_volume(bus: StringName, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_audio()
	_save()
	changed.emit()


## [primary, secondary]; null for an empty slot.
func events_for(action: StringName) -> Array:
	return _bindings[action].duplicate()


## The other actions that `event` is also bound to.
func actions_sharing(action: StringName, event: InputEvent) -> Array[StringName]:
	var others: Array[StringName] = []
	if event == null:
		return others
	for other in ACTIONS:
		if other == action:
			continue
		for bound in _bindings[other]:
			if bound and _same(bound, event):
				others.append(other)
				break
	return others


## "W", "Up Arrow", "Right Mouse", "Enter"; "—" for an empty slot.
func event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		var physical: Key = event.physical_keycode
		if KEY_NAMES.has(physical):
			return KEY_NAMES[physical]
		# Show the key as printed on this keyboard's layout. The web can't look
		# that up (it logs an error), so there it's the US-layout name.
		var keycode := physical
		if not OS.has_feature("web"):
			keycode = DisplayServer.keyboard_get_keycode_from_physical(physical)
		return OS.get_keycode_string(keycode)
	if event is InputEventMouseButton:
		return MOUSE_NAMES.get(event.button_index, "Mouse %d" % event.button_index)
	return "—"


## Keeps the setting true to the window when something else changes it (the
## browser's Esc, the window manager).
func _sync_fullscreen() -> void:
	var is_fullscreen := DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN
	if is_fullscreen != fullscreen:
		fullscreen = is_fullscreen
		_save()
		changed.emit()


func _input_changed() -> void:
	_apply_input()
	_save()
	changed.emit()


## A fresh event holding only what a binding needs (no modifiers or position).
static func _clean(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var key := InputEventKey.new()
		key.physical_keycode = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		return key if key.physical_keycode != KEY_NONE else null
	if event is InputEventMouseButton:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = event.button_index
		return mouse
	return null


static func _same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	return false


static func _to_data(event: InputEvent) -> Variant:
	if event is InputEventKey:
		return {"type": "key", "physical_keycode": int(event.physical_keycode)}
	if event is InputEventMouseButton:
		return {"type": "mouse", "button_index": int(event.button_index)}
	return null


## The event saved as `data`, or null if it can't be read.
static func _from_data(data: Variant) -> InputEvent:
	if not data is Dictionary:
		return null
	match data.get("type"):
		"key":
			var code = data.get("physical_keycode")
			if (code is int or code is float) and int(code) > 0:
				var key := InputEventKey.new()
				key.physical_keycode = int(code) as Key
				return key
		"mouse":
			var button = data.get("button_index")
			if (button is int or button is float) and int(button) > 0:
				var mouse := InputEventMouseButton.new()
				mouse.button_index = int(button) as MouseButton
				return mouse
	return null


func _load() -> void:
	for action in ACTIONS:
		_bindings[action] = _defaults[action].duplicate()
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	for action in ACTIONS:
		if not file.has_section_key("input", action):
			continue
		var saved = file.get_value("input", action)
		if not saved is Array:
			continue
		for i in mini(saved.size(), SLOTS):
			if saved[i] == null:
				_bindings[action][i] = null
			else:
				var event := _from_data(saved[i])
				if event:
					_bindings[action][i] = event
	var saved_fullscreen = file.get_value("general", "fullscreen", false)
	fullscreen = saved_fullscreen if saved_fullscreen is bool else false
	var saved_auto_fire = file.get_value("general", "auto_fire", true)
	auto_fire = saved_auto_fire if saved_auto_fire is bool else true
	for bus in BUSES:
		var value = file.get_value("audio", bus, 1.0)
		volumes[bus] = clampf(float(value), 0.0, 1.0) if (value is float or value is int) else 1.0


func _save() -> void:
	var file := ConfigFile.new()
	for action in ACTIONS:
		file.set_value("input", action, _bindings[action].map(_to_data))
	file.set_value("general", "fullscreen", fullscreen)
	file.set_value("general", "auto_fire", auto_fire)
	for bus in BUSES:
		file.set_value("audio", bus, volumes[bus])
	file.save(PATH)


func _apply_all() -> void:
	_apply_input()
	_apply_window()
	_apply_audio()


func _apply_input() -> void:
	for action in ACTIONS:
		InputMap.action_erase_events(action)
		for event in _bindings[action]:
			if event:
				InputMap.action_add_event(action, event)


func _apply_window() -> void:
	var is_fullscreen := DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN
	if is_fullscreen != fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
				else DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_audio() -> void:
	for bus in BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volumes[bus], 0.0001)))
		AudioServer.set_bus_mute(index, volumes[bus] <= 0.0)
