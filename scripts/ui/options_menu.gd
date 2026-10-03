class_name OptionsMenu
extends CanvasLayer
## Controls and general settings, shared by the main menu and the pause
## menu. Settings applies and saves every change at once. Back or Esc closes.

signal closed

const ROW_SCENE := preload("res://scenes/ui/binding_row.tscn")

@onready var bindings: VBoxContainer = %Bindings
@onready var fullscreen_box: CheckButton = %Fullscreen
@onready var controls_header: Label = $Center/Panel/Margin/Rows/ControlsHeader
@onready var bindings_scroll: ScrollContainer = $Center/Panel/Margin/Rows/Scroll
@onready var auto_fire_box: CheckButton = %AutoFire
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
	if Settings.touch_mode:
		controls_header.visible = false
		bindings_scroll.visible = false
		auto_fire_box.visible = false
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
	# Spelled out too: the theme's "off" switch is easy to miss.
	fullscreen_box.text = ("Fullscreen: " if Settings.touch_mode else "Fullscreen (F11): ") + ("On" if Settings.fullscreen else "Off")
	auto_fire_box.text = "Auto-fire: " + ("On" if Settings.auto_fire else "Off")
	for bus in sliders:
		sliders[bus].set_value_no_signal(Settings.volumes[bus] * 100.0)


func _on_slider(value: float, bus: StringName) -> void:
	Settings.set_volume(bus, value / 100.0)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
