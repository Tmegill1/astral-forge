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
