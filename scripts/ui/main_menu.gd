extends Control
## The first screen: Play, Options, Help and Quit. Quit is hidden on the web,
## where a page can't close itself.

const WORLD := "res://scenes/world.tscn"

@onready var buttons: VBoxContainer = %Buttons
@onready var play_button: Button = %Play
@onready var options_button: Button = %Options
@onready var quit_button: Button = %Quit
@onready var options: OptionsMenu = $OptionsMenu
@onready var help_button: Button = %Help
@onready var help: HelpMenu = $HelpMenu


func _ready() -> void:
	play_button.pressed.connect(_play)
	options_button.pressed.connect(_open_options)
	quit_button.pressed.connect(get_tree().quit)
	quit_button.visible = not OS.has_feature("web")
	options.closed.connect(_on_options_closed)
	help_button.pressed.connect(_open_help)
	help.closed.connect(_on_help_closed)
	play_button.grab_focus()


func _play() -> void:
	get_tree().change_scene_to_file(WORLD)


func _open_options() -> void:
	buttons.visible = false
	options.open()


func _on_options_closed() -> void:
	buttons.visible = true
	options_button.grab_focus()


func _open_help() -> void:
	buttons.visible = false
	help.open()


func _on_help_closed() -> void:
	buttons.visible = true
	help_button.grab_focus()
