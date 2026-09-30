extends Node
## Run-wide state that survives scene changes (autoloaded as "Game").
## A hero-select screen will set selected_hero; until then it's the Artificer.

var selected_hero: HeroDefinition = preload("res://data/heroes/artificer.tres")


func _ready() -> void:
	# Keep listening while the game is paused (build and upgrade menus).
	process_mode = Node.PROCESS_MODE_ALWAYS


## F11 switches between a window and fullscreen (saved in Settings). Unhandled
## input, so a click or menu key bound to it can't take input from the menus.
## It flips the real window, which may have left fullscreen some other way.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_fullscreen"):
		Settings.set_fullscreen(DisplayServer.window_get_mode() < DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
