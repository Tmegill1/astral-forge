extends Node
## Run-wide state that survives scene changes (autoloaded as "Game").
## A hero-select screen will set selected_hero; until then it's the Artificer.

var selected_hero: HeroDefinition = preload("res://data/heroes/artificer.tres")


func _ready() -> void:
	# Keep listening while the game is paused (build and upgrade menus).
	process_mode = Node.PROCESS_MODE_ALWAYS


## F11 switches between a window and fullscreen.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_fullscreen"):
		var fullscreen := DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
