extends Node
## Run-wide state that survives scene changes (autoloaded as "Game").
## A hero-select screen will set selected_hero; until then it's the Artificer.

var selected_hero: HeroDefinition = preload("res://data/heroes/artificer.tres")


func _ready() -> void:
	# Keep listening while the game is paused (build and upgrade menus).
	process_mode = Node.PROCESS_MODE_ALWAYS


## F11 switches between a window and fullscreen (saved in Settings).
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_fullscreen"):
		Settings.set_fullscreen(not Settings.fullscreen)
		get_viewport().set_input_as_handled()
