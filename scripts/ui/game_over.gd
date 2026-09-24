class_name GameOverScreen
extends CanvasLayer
## Shown when the run ends. Pauses the game; Restart (or R) starts over.

@onready var title: Label = %Title
@onready var summary: Label = %Summary
@onready var restart_button: Button = %RestartButton


func _ready() -> void:
	visible = false
	restart_button.pressed.connect(restart)


func show_defeat(seconds_survived: float, kills: int) -> void:
	title.text = "The Core has fallen"
	summary.text = "Survived %d:%02d   ·   Goblins defeated: %d" % [
		int(seconds_survived) / 60, int(seconds_survived) % 60, kills]
	visible = true
	get_tree().paused = true
	restart_button.grab_focus()


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		restart()
