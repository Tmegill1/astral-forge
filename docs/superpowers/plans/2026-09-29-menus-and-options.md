# Menus and Options Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A main menu (Play / Options / Quit), an Escape pause menu (Resume / Options / Help (disabled) / Quit), and an Options screen with two-slot rebinding for every action plus fullscreen, auto-fire and volume, all saved to `user://settings.cfg`.

**Architecture:** A `Settings` autoload owns bindings and settings; it loads, applies (`InputMap`, window mode, audio buses) and saves them, and emits `changed`. `OptionsMenu` (with a `BindingRow` per action) is one scene instanced by both `MainMenu` (the new start scene) and `PauseMenu` (instanced in `world.tscn`). The pause menu only opens when the game isn't already paused, so existing menus keep Escape.

**Tech Stack:** Godot 4.7 GDScript; `ConfigFile`, `InputMap`, `AudioServer`, `DisplayServer`; verification via the Godot MCP tools in the running game.

**Spec:** `docs/superpowers/specs/2026-09-29-menus-and-options-design.md`

## Global Constraints

- Rebindable actions, in this order with these labels: move_up "Move Up", move_down "Move Down", move_left "Move Left", move_right "Move Right", move_to "Walk to Spot", fire "Fire", interact "Interact", manage "Manage / Upgrade", tower_ability "Tower Ability", start_wave "Start Wave", toggle_fullscreen "Fullscreen".
- Two slots per action (primary, secondary); keyboard keys (by physical keycode, no modifiers) and mouse buttons; Escape can't be bound; Delete/Backspace clears; shared inputs allowed and shown amber with "Also used by: …".
- Settings: fullscreen (default false), auto_fire (default true), volumes Master/Music/Effects 0–1 (default 1.0; 0 = muted). Defaults for bindings = the project's shipped InputMap (first two events per action).
- Save file `user://settings.cfg` (`ConfigFile`): `[input]` action = array of 2 entries (`{"type": "key", "physical_keycode": n}`, `{"type": "mouse", "button_index": n}` or `null`); `[general]` fullscreen, auto_fire; `[audio]` Master, Music, Effects. Every change saves at once. A missing / garbage file, missing action or unreadable entry falls back to defaults for that part, never errors.
- Pause menu: opens on `ui_cancel` only when `get_tree().paused` is false; dim black 50%; centred panel ≈220×190 px with Resume, Options, Help (disabled, tooltip "Coming soon"), Quit; Quit → "Abandon this run?" Abandon / Cancel; Abandon → main menu.
- Main menu: start scene; title "Astral Forge"; Play / Options / Quit; Quit hidden when `OS.has_feature("web")`; background = a capture of the map with the Core, dimmed.
- Branch `feature/menus`; one commit per task (`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`); stage only the task's files. New `class_name`/autoload/scenes → `godot --headless --editor --path . --import` before checks.
- MCP: `run_project` injects its bridge into `project.godot` and may leave blank lines; after `stop_project`, `git diff project.godot` and remove only the bridge's lines (keep this plan's autoload and main-scene edits). The first `game_eval` after `run_project` says "Not connected" (retry; if the bridge isn't in `[autoload]`, stop, `git checkout`-free cleanup, run again). A script error in an eval freezes the game (check `get_debug_output`, restart). Evals must finish within ~25 s and disconnect any lambdas they connect. Never `queue_free` living enemies or disable the WaveDirector; set `world.waves.break_left = 99999.0` to hold wave 1 during tests. In evals, untyped values use `=` not `:=`.
- In evals after Task 3: the start scene is the main menu; get to the map with `get_tree().change_scene_to_file("res://scenes/world.tscn")` then await 3 process frames; `var world = get_tree().current_scene`.

## Review Focus

1. **Escape with the tower menu or hero upgrade menu open** closes just that menu (like the build menu), never also the pause menu, and the game stays unpaused after (Task 4 test).
2. **A movement key held when pausing and released while paused**: after Resume the hero is standing still, not stuck walking (Task 4 test).
3. **A saved file with one good and one garbage entry for an action** keeps the good binding and uses the default for the garbage slot (Task 1 test).
4. **Quit to the main menu and Play again, twice**: each run starts unpaused with wave 1, auto-fire still follows the setting, and no errors about freed objects (Task 4 test).
5. **Web build with fullscreen saved on**: the page loads with no script errors even though a browser may refuse fullscreen without a click (Task 4 test).

---

### Task 1: Settings autoload, audio buses, F11 and auto-fire

**Files:** Create `scripts/settings.gd`, `default_bus_layout.tres`. Modify `project.godot` (`[autoload]`), `scripts/game.gd`, `scripts/heroes/hero.gd`.

**Interfaces:**
- Consumes: the existing InputMap actions.
- Produces: autoload `Settings` with `signal changed`; `const ACTIONS: Array[StringName]`, `const LABELS: Dictionary`, `const BUSES: Array[StringName]`, `const PATH := "user://settings.cfg"`; vars `fullscreen: bool`, `auto_fire: bool`, `volumes: Dictionary[StringName, float]`; `bind(action: StringName, slot: int, event: InputEvent)`, `clear(action: StringName, slot: int)`, `reset_to_defaults()`, `set_fullscreen(on: bool)`, `set_auto_fire(on: bool)`, `set_volume(bus: StringName, value: float)`, `events_for(action: StringName) -> Array`, `actions_sharing(action: StringName, event: InputEvent) -> Array[StringName]`, `event_label(event: InputEvent) -> String`; audio buses Music and Effects.

- [ ] **Step 1: Failing check.** Run the game and eval `return [Engine.has_singleton("Settings"), get_tree().root.has_node("Settings"), AudioServer.get_bus_index(&"Music")]`. Expected: `[false, false, -1]`. Stop the game.
- [ ] **Step 2: Settings** `scripts/settings.gd`:
```gdscript
extends Node
## Player settings: key bindings, fullscreen, auto-fire and volume
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

var fullscreen := false
var auto_fire := true
var volumes: Dictionary[StringName, float] = {&"Master": 1.0, &"Music": 1.0, &"Effects": 1.0}

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
	_apply_all()


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
	auto_fire = on
	_save()
	changed.emit()


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
		return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(physical))
	if event is InputEventMouseButton:
		return MOUSE_NAMES.get(event.button_index, "Mouse %d" % event.button_index)
	return "—"


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
				key.physical_keycode = int(code)
				return key
		"mouse":
			var button = data.get("button_index")
			if (button is int or button is float) and int(button) > 0:
				var mouse := InputEventMouseButton.new()
				mouse.button_index = int(button)
				return mouse
	return null


func _load() -> void:
	for action in ACTIONS:
		_bindings[action] = _defaults[action].duplicate()
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	for action in ACTIONS:
		var saved = file.get_value("input", action, null)
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
```
- [ ] **Step 3: Buses** `default_bus_layout.tres`:
```
[gd_resource type="AudioBusLayout" format=3]

[resource]
bus/1/name = &"Music"
bus/1/solo = false
bus/1/mute = false
bus/1/bypass_fx = false
bus/1/volume_db = 0.0
bus/1/send = &"Master"
bus/2/name = &"Effects"
bus/2/solo = false
bus/2/mute = false
bus/2/bypass_fx = false
bus/2/volume_db = 0.0
bus/2/send = &"Master"
```
- [ ] **Step 4: Register and hook up.**
  - `project.godot` `[autoload]`: add `Settings="*res://scripts/settings.gd"` on the line after `Game=…`.
  - `scripts/game.gd` `_input`: replace the two lines that compute `fullscreen` and call `window_set_mode` with `Settings.set_fullscreen(not Settings.fullscreen)`, and update the doc comment to "F11 switches between a window and fullscreen (saved in Settings)."
  - `scripts/heroes/hero.gd`: at the end of `_ready()` add
```gdscript
	auto_fire = Settings.auto_fire
	Settings.changed.connect(_on_settings_changed)
```
  and after `_ready()`:
```gdscript
## Auto-fire follows the Options setting, even mid-run.
func _on_settings_changed() -> void:
	auto_fire = Settings.auto_fire
```
  Update the `auto_fire` export comment to "When false, the hero only shoots while the "fire" action is held. Set from Settings (Options → Auto-fire)."
- [ ] **Step 5: Verify.** Import, `validate_scripts`, delete any old `user://settings.cfg` (eval `DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))`), run the game, `world.waves.break_left = 99999.0`, and eval:
  - **Defaults:** `Settings.events_for(&"move_up")` labels are `["W", "Up Arrow"]`; `tower_ability` is `["Q", "Right Mouse"]`; `AudioServer.get_bus_index(&"Music")` ≥ 1 and `&"Effects"` ≥ 1.
  - **Rebind moves the hero:** `Settings.bind(&"move_up", 0, key_I)` (an `InputEventKey` with `physical_keycode = KEY_I`). Parse a pressed I event with `Input.parse_input_event`, wait 20 physics frames: the hero's y decreased; release it. Do the same with W: y unchanged. With the Up arrow: y decreased.
  - **Saved:** read `user://settings.cfg` with `ConfigFile`: `input/move_up` is `[{"type": "key", "physical_keycode": 73}, {"type": "key", "physical_keycode": 4194320}]`.
  - **Sharing:** `Settings.bind(&"interact", 0, key_Q)`: `actions_sharing(&"interact", key_Q) == [&"tower_ability"]` and `actions_sharing(&"tower_ability", key_Q) == [&"interact"]`; `Input.parse_input_event(Q pressed)` makes both `Input.is_action_pressed(&"interact")` and `&"tower_ability"` true.
  - **Clear:** `Settings.clear(&"move_up", 1)`: the Up arrow no longer moves the hero; `event_label(null) == "—"`.
  - **Auto-fire mid-run:** `Settings.set_auto_fire(false)`: `hero.auto_fire == false`, and over 2 s with a goblin in range no `HeroBolt` spawns; `set_auto_fire(true)`: bolts spawn again.
  - **Volume:** `set_volume(&"Effects", 0.5)` → bus volume ≈ −6.02 dB, not muted; `set_volume(&"Effects", 0.0)` → muted; `set_volume(&"Effects", 1.0)` → 0 dB, unmuted.
  - **Fullscreen:** `set_fullscreen(true)` → window mode ≥ FULLSCREEN; simulate F11 (`Input.parse_input_event` of a pressed F11 key) → windowed and `Settings.fullscreen == false`.
  - **Survives a restart:** stop and run the game again: `events_for(&"move_up")` labels are `["I", "—"]` and `interact` is still Q.
  - **Review Focus 3:** write a file by hand with `input/move_down = [{"type": "key", "physical_keycode": 75}, "garbage"]`, call `Settings._load()` and `Settings._apply_all()`: `move_down` labels are `["K", "Down Arrow"]`.
  - **Garbage file:** write `"%%%% not a config [[[\n=="` to `user://settings.cfg` with `FileAccess`, call `Settings._load()`: defaults everywhere (`move_up` = W / Up Arrow), no errors in `get_debug_output`.
  - **Reset:** after some changes, `Settings.reset_to_defaults()`: every action matches the defaults, fullscreen false, auto-fire true, volumes 1.0.
  - Delete `user://settings.cfg` at the end so later tasks start from defaults. Stop the game; clean `project.godot` (keep the `Settings` line).
- [ ] **Step 6: Commit** `Add Settings: saved bindings, fullscreen, auto-fire and volume`.

---

### Task 2: Options screen and binding rows

**Files:** Create `scripts/ui/options_menu.gd`, `scenes/ui/options_menu.tscn`, `scripts/ui/binding_row.gd`, `scenes/ui/binding_row.tscn`.

**Interfaces:**
- Consumes: `Settings` (Task 1).
- Produces: `class_name OptionsMenu extends CanvasLayer` with `signal closed`, `open()`, `close()`; scene `res://scenes/ui/options_menu.tscn`. `class_name BindingRow extends HBoxContainer` with `setup(action: StringName)`, `refresh()`, `is_listening() -> bool`.

- [ ] **Step 1: Failing check.** Eval `ResourceLoader.exists("res://scenes/ui/options_menu.tscn")`. Expected: `false`.
- [ ] **Step 2: Binding row.** `scripts/ui/binding_row.gd`:
```gdscript
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
```
`scenes/ui/binding_row.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/binding_row.gd" id="1_row"]

[node name="BindingRow" type="HBoxContainer"]
theme_override_constants/separation = 10
script = ExtResource("1_row")

[node name="Name" type="Label" parent="."]
unique_name_in_owner = true
custom_minimum_size = Vector2(170, 0)
layout_mode = 2
theme_override_font_sizes/font_size = 15
text = "Move Up"

[node name="Primary" type="Button" parent="."]
unique_name_in_owner = true
custom_minimum_size = Vector2(170, 30)
layout_mode = 2
theme_override_font_sizes/font_size = 14
text = "W"
clip_text = true

[node name="Secondary" type="Button" parent="."]
unique_name_in_owner = true
custom_minimum_size = Vector2(170, 30)
layout_mode = 2
theme_override_font_sizes/font_size = 14
text = "Up Arrow"
clip_text = true
```
- [ ] **Step 3: Options menu.** `scripts/ui/options_menu.gd`:
```gdscript
class_name OptionsMenu
extends CanvasLayer
## Controls and general settings, shared by the main menu and the pause
## menu. Settings applies and saves every change at once. Back or Esc closes.

signal closed

const ROW_SCENE := preload("res://scenes/ui/binding_row.tscn")

@onready var bindings: VBoxContainer = %Bindings
@onready var fullscreen_box: CheckBox = %Fullscreen
@onready var auto_fire_box: CheckBox = %AutoFire
@onready var sliders: Dictionary[StringName, HSlider] = {
	&"Master": %Master, &"Music": %Music, &"Effects": %Effects}
@onready var reset_button: Button = %Reset
@onready var back_button: Button = %Back

var _rows: Array[BindingRow] = []


func _ready() -> void:
	visible = false
	for action in Settings.ACTIONS:
		var row: BindingRow = ROW_SCENE.instantiate()
		row.setup(action)
		bindings.add_child(row)
		_rows.append(row)
	fullscreen_box.toggled.connect(Settings.set_fullscreen)
	auto_fire_box.toggled.connect(Settings.set_auto_fire)
	for bus in sliders:
		sliders[bus].value_changed.connect(_on_slider.bind(bus))
	reset_button.pressed.connect(Settings.reset_to_defaults)
	back_button.pressed.connect(close)
	Settings.changed.connect(_refresh)
	_refresh()


func open() -> void:
	_refresh()
	visible = true
	back_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _refresh() -> void:
	fullscreen_box.set_pressed_no_signal(Settings.fullscreen)
	auto_fire_box.set_pressed_no_signal(Settings.auto_fire)
	for bus in sliders:
		sliders[bus].set_value_no_signal(Settings.volumes[bus] * 100.0)


func _on_slider(value: float, bus: StringName) -> void:
	Settings.set_volume(bus, value / 100.0)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
```
`scenes/ui/options_menu.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/options_menu.gd" id="1_options"]

[node name="OptionsMenu" type="CanvasLayer"]
process_mode = 3
layer = 20
script = ExtResource("1_options")

[node name="Dim" type="ColorRect" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0, 0, 0, 0.6)

[node name="Center" type="CenterContainer" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Panel" type="PanelContainer" parent="Center"]
custom_minimum_size = Vector2(580, 0)
layout_mode = 2

[node name="Margin" type="MarginContainer" parent="Center/Panel"]
layout_mode = 2
theme_override_constants/margin_left = 18
theme_override_constants/margin_top = 14
theme_override_constants/margin_right = 18
theme_override_constants/margin_bottom = 14

[node name="Rows" type="VBoxContainer" parent="Center/Panel/Margin"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="Title" type="Label" parent="Center/Panel/Margin/Rows"]
layout_mode = 2
theme_override_font_sizes/font_size = 24
text = "Options"
horizontal_alignment = 1

[node name="ControlsHeader" type="Label" parent="Center/Panel/Margin/Rows"]
layout_mode = 2
theme_override_colors/font_color = Color(1, 0.85, 0.5, 1)
theme_override_font_sizes/font_size = 16
text = "Controls"

[node name="Scroll" type="ScrollContainer" parent="Center/Panel/Margin/Rows"]
custom_minimum_size = Vector2(0, 250)
layout_mode = 2
horizontal_scroll_mode = 0

[node name="Bindings" type="VBoxContainer" parent="Center/Panel/Margin/Rows/Scroll"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 4

[node name="GeneralHeader" type="Label" parent="Center/Panel/Margin/Rows"]
layout_mode = 2
theme_override_colors/font_color = Color(1, 0.85, 0.5, 1)
theme_override_font_sizes/font_size = 16
text = "General"

[node name="Toggles" type="HBoxContainer" parent="Center/Panel/Margin/Rows"]
layout_mode = 2
theme_override_constants/separation = 30

[node name="Fullscreen" type="CheckBox" parent="Center/Panel/Margin/Rows/Toggles"]
unique_name_in_owner = true
layout_mode = 2
text = "Fullscreen (F11)"

[node name="AutoFire" type="CheckBox" parent="Center/Panel/Margin/Rows/Toggles"]
unique_name_in_owner = true
layout_mode = 2
text = "Auto-fire"

[node name="Volumes" type="GridContainer" parent="Center/Panel/Margin/Rows"]
layout_mode = 2
theme_override_constants/h_separation = 12
columns = 2

[node name="MasterLabel" type="Label" parent="Center/Panel/Margin/Rows/Volumes"]
custom_minimum_size = Vector2(170, 0)
layout_mode = 2
text = "Master volume"

[node name="Master" type="HSlider" parent="Center/Panel/Margin/Rows/Volumes"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 4
value = 100.0

[node name="MusicLabel" type="Label" parent="Center/Panel/Margin/Rows/Volumes"]
layout_mode = 2
text = "Music volume"

[node name="Music" type="HSlider" parent="Center/Panel/Margin/Rows/Volumes"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 4
value = 100.0

[node name="EffectsLabel" type="Label" parent="Center/Panel/Margin/Rows/Volumes"]
layout_mode = 2
text = "Effects volume"

[node name="Effects" type="HSlider" parent="Center/Panel/Margin/Rows/Volumes"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 4
value = 100.0

[node name="Buttons" type="HBoxContainer" parent="Center/Panel/Margin/Rows"]
layout_mode = 2
alignment = 1
theme_override_constants/separation = 16

[node name="Reset" type="Button" parent="Center/Panel/Margin/Rows/Buttons"]
unique_name_in_owner = true
custom_minimum_size = Vector2(170, 36)
layout_mode = 2
text = "Reset to defaults"

[node name="Back" type="Button" parent="Center/Panel/Margin/Rows/Buttons"]
unique_name_in_owner = true
custom_minimum_size = Vector2(170, 36)
layout_mode = 2
text = "Back"
```
- [ ] **Step 4: Verify.** Import, `validate_scripts`, run the game, and eval (add a test instance: `var o = load("res://scenes/ui/options_menu.tscn").instantiate(); get_tree().root.add_child(o); o.open()`; free it at the end):
  - 11 `BindingRow`s in order; Move Up shows "W" / "Up Arrow"; Tower Ability shows "Q" / "Right Mouse".
  - **Listen and bind:** `row._listen(0)` on Move Up: its primary button reads "Press a key or mouse button…"; `Input.parse_input_event` a pressed `KEY_I` → primary reads "I", `Settings.events_for(&"move_up")[0]` is I, `is_listening()` false.
  - **Mouse:** listen on Fire's secondary, parse a pressed middle mouse button → "Middle Mouse".
  - **Escape cancels:** listen on Interact's primary, parse Esc → still "E", and `o.visible` is still true (Esc didn't close Options).
  - **Delete clears:** listen on Start Wave's secondary (Keypad Enter), parse Delete → it reads "—" and `Settings.events_for(&"start_wave")[1] == null`.
  - **Amber:** bind Interact primary to Q: Interact's and Tower Ability's Q buttons have the amber font colour override and tooltips "Also used by: Tower Ability" / "Also used by: Interact".
  - **General:** `fullscreen_box.button_pressed = true` (emits toggled) → `Settings.fullscreen` true; `auto_fire_box` off → `Settings.auto_fire` false; `sliders[&"Music"].value = 40` → `Settings.volumes[&"Music"] == 0.4`.
  - **Reset:** press Reset (`reset_button.pressed.emit()`): rows back to defaults, checkboxes and sliders back (fullscreen off, auto-fire on, all 100).
  - **Close:** parse Esc (not listening) → `o.visible` false and `closed` emitted (count with a local var; disconnect after).
  - Screenshot the open Options screen (all rows readable, nothing clipped; if the panel runs off the 648 px window, lower the Scroll's minimum height).
  - Delete `user://settings.cfg`, stop, clean `project.godot`.
- [ ] **Step 5: Commit** `Add the Options screen with key rebinding`.

---

### Task 3: Main menu as the start scene

**Files:** Create `scripts/ui/main_menu.gd`, `scenes/ui/main_menu.tscn`, `assets/ui/menu_background.png`. Modify `project.godot` (`run/main_scene`).

**Interfaces:**
- Consumes: `OptionsMenu` (Task 2).
- Produces: scene `res://scenes/ui/main_menu.tscn` (the start scene); `MainMenu.WORLD := "res://scenes/world.tscn"`.

- [ ] **Step 1: Failing check.** `grep run/main_scene project.godot`. Expected: `res://scenes/world.tscn`.
- [ ] **Step 2: Background.** Run the game, and eval:
```gdscript
var world = get_tree().current_scene
world.waves.break_left = 99999.0
for n in world.get_children():
	if n is CanvasLayer:
		n.visible = false
world.hero.visible = false
world.hero.camera.zoom = Vector2(0.8, 0.8)
world.hero.global_position = world.core.global_position + Vector2(0, 40)
world.hero.reset_physics_interpolation()
world.hero.camera.reset_smoothing()
for i in 20:
	await get_tree().process_frame
DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui"))
return get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://assets/ui/menu_background.png"))
```
  Expected `0` (OK). Stop the game; open the PNG (Read tool): grass, slots and the Core, no HUD. Import.
- [ ] **Step 3: Main menu.** `scripts/ui/main_menu.gd`:
```gdscript
extends Control
## The first screen: Play, Options and Quit. Quit is hidden on the web,
## where a page can't close itself.

const WORLD := "res://scenes/world.tscn"

@onready var buttons: VBoxContainer = %Buttons
@onready var play_button: Button = %Play
@onready var options_button: Button = %Options
@onready var quit_button: Button = %Quit
@onready var options: OptionsMenu = $OptionsMenu


func _ready() -> void:
	play_button.pressed.connect(_play)
	options_button.pressed.connect(_open_options)
	quit_button.pressed.connect(get_tree().quit)
	quit_button.visible = not OS.has_feature("web")
	options.closed.connect(_on_options_closed)
	play_button.grab_focus()


func _play() -> void:
	get_tree().change_scene_to_file(WORLD)


func _open_options() -> void:
	buttons.visible = false
	options.open()


func _on_options_closed() -> void:
	buttons.visible = true
	options_button.grab_focus()
```
`scenes/ui/main_menu.tscn`:
```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/ui/main_menu.gd" id="1_menu"]
[ext_resource type="Texture2D" path="res://assets/ui/menu_background.png" id="2_bg"]
[ext_resource type="PackedScene" path="res://scenes/ui/options_menu.tscn" id="3_options"]

[node name="MainMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_menu")

[node name="Background" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
texture = ExtResource("2_bg")
expand_mode = 1
stretch_mode = 6

[node name="Dim" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.03, 0.02, 0.06, 0.55)

[node name="Center" type="CenterContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Rows" type="VBoxContainer" parent="Center"]
layout_mode = 2
theme_override_constants/separation = 28

[node name="Title" type="Label" parent="Center/Rows"]
layout_mode = 2
theme_override_colors/font_color = Color(1, 0.85, 0.5, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 10
theme_override_font_sizes/font_size = 56
text = "Astral Forge"
horizontal_alignment = 1

[node name="Buttons" type="VBoxContainer" parent="Center/Rows"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 4
theme_override_constants/separation = 10

[node name="Play" type="Button" parent="Center/Rows/Buttons"]
unique_name_in_owner = true
custom_minimum_size = Vector2(220, 46)
layout_mode = 2
theme_override_font_sizes/font_size = 20
text = "Play"

[node name="Options" type="Button" parent="Center/Rows/Buttons"]
unique_name_in_owner = true
custom_minimum_size = Vector2(220, 46)
layout_mode = 2
theme_override_font_sizes/font_size = 20
text = "Options"

[node name="Quit" type="Button" parent="Center/Rows/Buttons"]
unique_name_in_owner = true
custom_minimum_size = Vector2(220, 46)
layout_mode = 2
theme_override_font_sizes/font_size = 20
text = "Quit"

[node name="OptionsMenu" parent="." instance=ExtResource("3_options")]
```
  `project.godot`: `run/main_scene="res://scenes/ui/main_menu.tscn"`.
- [ ] **Step 4: Verify.** Import, `validate_scripts`, run the game, and eval:
  - `get_tree().current_scene.name == "MainMenu"`; Play has focus; Quit visible (desktop). Screenshot.
  - **Options round trip:** press Options → `options.visible` true and `buttons.visible` false; parse Esc → Options closed, buttons visible, Options button focused.
  - **Keyboard:** parse Down then `ui_accept` (Enter) from Play-focused → Options opens (focus moved to Options). Close it.
  - **Play:** `play_button.pressed.emit()`, await 3 frames: `current_scene.name == "World"`, `get_tree().paused == false`, wave index 0.
  - **Web:** Quit's visibility is `not OS.has_feature("web")` (checked for real in Task 4's web export).
  - Stop, clean `project.godot` (keep the new `run/main_scene`).
- [ ] **Step 5: Commit** `Start at a main menu`.

---

### Task 4: Pause menu, web check and roadmap

**Files:** Create `scripts/ui/pause_menu.gd`, `scenes/ui/pause_menu.tscn`. Modify `scenes/world.tscn`, `ROADMAP.md`.

**Interfaces:**
- Consumes: `OptionsMenu` (Task 2); `res://scenes/ui/main_menu.tscn` (Task 3); `Settings` (Task 1).
- Produces: `class_name PauseMenu extends CanvasLayer` with `open()`, `close()`; a `PauseMenu` node in `world.tscn`.

- [ ] **Step 1: Failing check.** Run the game, Play, and eval: parse a pressed Escape; await 2 frames; return `get_tree().paused`. Expected: `false` (nothing handles Escape yet). Stop.
- [ ] **Step 2: Pause menu.** `scripts/ui/pause_menu.gd`:
```gdscript
class_name PauseMenu
extends CanvasLayer
## Esc during a run pauses the game and shows Resume / Options / Help /
## Quit. It only opens when nothing else has paused the game, so Esc still
## just closes the build, tower and upgrade menus. Quit asks first, then
## goes back to the main menu.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"

@onready var panel: Control = %Panel
@onready var confirm: Control = %Confirm
@onready var resume_button: Button = %Resume
@onready var options_button: Button = %Options
@onready var help_button: Button = %Help
@onready var quit_button: Button = %Quit
@onready var abandon_button: Button = %Abandon
@onready var cancel_button: Button = %Cancel
@onready var options: OptionsMenu = $OptionsMenu


func _ready() -> void:
	visible = false
	resume_button.pressed.connect(close)
	options_button.pressed.connect(_open_options)
	quit_button.pressed.connect(_ask_quit)
	abandon_button.pressed.connect(_abandon)
	cancel_button.pressed.connect(_show_panel)
	options.closed.connect(_show_panel)
	help_button.disabled = true
	help_button.tooltip_text = "Coming soon"


func open() -> void:
	visible = true
	get_tree().paused = true
	_show_panel()


func close() -> void:
	visible = false
	get_tree().paused = false


func _show_panel() -> void:
	panel.visible = true
	confirm.visible = false
	resume_button.grab_focus()


func _open_options() -> void:
	panel.visible = false
	options.open()


func _ask_quit() -> void:
	panel.visible = false
	confirm.visible = true
	cancel_button.grab_focus()


func _abandon() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if not visible:
		# Another menu (build, tower, upgrade, game over) has the game paused.
		if get_tree().paused:
			return
		open()
	elif options.visible:
		return
	elif confirm.visible:
		_show_panel()
	else:
		close()
	get_viewport().set_input_as_handled()
```
`scenes/ui/pause_menu.tscn`:
```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/ui/pause_menu.gd" id="1_pause"]
[ext_resource type="PackedScene" path="res://scenes/ui/options_menu.tscn" id="2_options"]

[node name="PauseMenu" type="CanvasLayer"]
process_mode = 3
layer = 15
script = ExtResource("1_pause")

[node name="Dim" type="ColorRect" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0, 0, 0, 0.5)

[node name="Center" type="CenterContainer" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Panel" type="PanelContainer" parent="Center"]
unique_name_in_owner = true
custom_minimum_size = Vector2(220, 190)
layout_mode = 2

[node name="Margin" type="MarginContainer" parent="Center/Panel"]
layout_mode = 2
theme_override_constants/margin_left = 12
theme_override_constants/margin_top = 10
theme_override_constants/margin_right = 12
theme_override_constants/margin_bottom = 10

[node name="Buttons" type="VBoxContainer" parent="Center/Panel/Margin"]
layout_mode = 2
alignment = 1
theme_override_constants/separation = 8

[node name="Resume" type="Button" parent="Center/Panel/Margin/Buttons"]
unique_name_in_owner = true
custom_minimum_size = Vector2(0, 36)
layout_mode = 2
theme_override_font_sizes/font_size = 17
text = "Resume"

[node name="Options" type="Button" parent="Center/Panel/Margin/Buttons"]
unique_name_in_owner = true
custom_minimum_size = Vector2(0, 36)
layout_mode = 2
theme_override_font_sizes/font_size = 17
text = "Options"

[node name="Help" type="Button" parent="Center/Panel/Margin/Buttons"]
unique_name_in_owner = true
custom_minimum_size = Vector2(0, 36)
layout_mode = 2
theme_override_font_sizes/font_size = 17
text = "Help"

[node name="Quit" type="Button" parent="Center/Panel/Margin/Buttons"]
unique_name_in_owner = true
custom_minimum_size = Vector2(0, 36)
layout_mode = 2
theme_override_font_sizes/font_size = 17
text = "Quit"

[node name="Confirm" type="PanelContainer" parent="Center"]
unique_name_in_owner = true
visible = false
custom_minimum_size = Vector2(260, 0)
layout_mode = 2

[node name="Margin" type="MarginContainer" parent="Center/Confirm"]
layout_mode = 2
theme_override_constants/margin_left = 14
theme_override_constants/margin_top = 12
theme_override_constants/margin_right = 14
theme_override_constants/margin_bottom = 12

[node name="Rows" type="VBoxContainer" parent="Center/Confirm/Margin"]
layout_mode = 2
theme_override_constants/separation = 12

[node name="Question" type="Label" parent="Center/Confirm/Margin/Rows"]
layout_mode = 2
theme_override_font_sizes/font_size = 18
text = "Abandon this run?"
horizontal_alignment = 1

[node name="Choices" type="HBoxContainer" parent="Center/Confirm/Margin/Rows"]
layout_mode = 2
alignment = 1
theme_override_constants/separation = 12

[node name="Abandon" type="Button" parent="Center/Confirm/Margin/Rows/Choices"]
unique_name_in_owner = true
custom_minimum_size = Vector2(110, 34)
layout_mode = 2
text = "Abandon"

[node name="Cancel" type="Button" parent="Center/Confirm/Margin/Rows/Choices"]
unique_name_in_owner = true
custom_minimum_size = Vector2(110, 34)
layout_mode = 2
text = "Cancel"

[node name="OptionsMenu" parent="." instance=ExtResource("2_options")]
```
  `scenes/world.tscn`: add `[ext_resource type="PackedScene" path="res://scenes/ui/pause_menu.tscn" id="20_pause"]` after the last `ext_resource` line, and append at the end of the file:
```
[node name="PauseMenu" parent="." instance=ExtResource("20_pause")]
```
- [ ] **Step 3: Verify.** Import, `validate_scripts`, run the game, Play, `world.waves.break_left = 99999.0`, and eval (Escape = parse a pressed then released `KEY_ESCAPE` `InputEventKey` with `physical_keycode` and `keycode` set):
  - **Pause:** spawn a goblin 400 px from the Core; Escape → `paused` true, pause panel visible with Resume focused, Help disabled; the goblin's position doesn't change over 30 frames; Escape → unpaused, the goblin moves again. Screenshot the pause panel (compare its height to the Core's on screen).
  - **Other menus keep Escape:** open the build menu on an empty slot (`slot.interact(hero)`), Escape → build menu closed, `paused` false, pause menu not visible. **Review Focus 1:** same with the tower menu (`slot.manage(hero)` on a built tower) and the hero upgrade menu (`world.core.manage(hero)`).
  - **Game over:** `world.core.health.take_damage(999999)`, await 5 frames; Escape → pause menu not visible (Lose screen stays).
  - (Restart the game after the game-over check.)
  - **Options from pause:** open pause, `options_button.pressed.emit()` → Options visible, panel hidden; Escape → Options closed, panel back, still paused; Escape → unpaused.
  - **Review Focus 2:** hold W (parse pressed), Escape to pause, release W while paused, Resume: over 30 physics frames the hero's position doesn't change.
  - **Quit:** pause, Quit → "Abandon this run?" shown; Escape → back to the panel; Quit → Abandon → `current_scene.name == "MainMenu"`, `paused` false.
  - **Review Focus 4:** from the main menu Play → wave 1, Core full, no towers, not paused; `Settings.set_auto_fire(false)` → new hero's `auto_fire` false; Quit → Abandon → Play again: new hero's `auto_fire` still false; `set_auto_fire(true)`; no errors in `get_debug_output`.
  - Stop, clean `project.godot`.
- [ ] **Step 4: Web check.** Export: `mkdir -p export/web && godot --headless --export-release "Web" export/web/index.html`, serve `export/web` with `python3 -m http.server 8765 -d export/web` in the background, and load it with a Playwright script (headless Chromium from `~/.cache/ms-playwright/chromium-*/chrome-linux64/chrome`, `--use-angle=swiftshader --enable-unsafe-swiftshader`; `npm i playwright-core` in the scratchpad):
  - Wait 20 s; screenshot: the main menu shows Play and Options and **no Quit**.
  - Click Options, then press Escape; click Play: the map appears.
  - **Persistence:** in page JS via `page.evaluate` there's no Godot access, so instead: in Options, click Auto-fire (uncheck it), reload the page, open Options: Auto-fire is still unchecked.
  - **Review Focus 5:** check Fullscreen, reload: the page loads to the main menu with no `PAGEERROR`/`error:` console lines.
  - Stop the server (kill it by PID, not `pkill -f` with a pattern that matches your own shell); `rm -rf export`.
- [ ] **Step 5: Roadmap.** Phase 11: `- [ ] **[AI]** Main menu, hero select screen, pause menu, settings` →
```
- [x] **[AI]** Main menu (Play / Options / Quit), Esc pause menu (Resume / Options / Help / Quit), Options (rebind every action incl. mouse, two slots each; fullscreen, auto-fire, volume), saved to `user://settings.cfg`
- [ ] **[AI]** Help: tower guide with upgrade paths, and an enemy Codex (part 2)
- [ ] **[AI]** Hero select screen
```
- [ ] **Step 6: Commit** `Add the pause menu; tick menus on the roadmap`.
