class_name GameOverScreen
extends CanvasLayer
## Shown when the run ends. Pauses the game; Restart (or R) starts over.

@onready var title: Label = %Title
@onready var summary: Label = %Summary
@onready var restart_button: Button = %RestartButton


func _ready() -> void:
	visible = false
	restart_button.pressed.connect(restart)


func show_defeat(seconds_survived: float, kills: int, waves_cleared: int) -> void:
	title.text = "The Core has fallen"
	title.add_theme_color_override(&"font_color", Color(1, 0.45, 0.35))
	summary.text = "Survived %d:%02d   ·   Waves cleared: %d   ·   Goblins defeated: %d" % [
		int(seconds_survived) / 60, int(seconds_survived) % 60, waves_cleared, kills]
	_show()


func show_victory(seconds: float, kills: int) -> void:
	title.text = "The Core holds!"
	title.add_theme_color_override(&"font_color", Color(0.55, 0.95, 0.6))
	summary.text = "Every wave defeated in %d:%02d   ·   Goblins defeated: %d" % [
		int(seconds) / 60, int(seconds) % 60, kills]
	_show()


func _show() -> void:
	visible = true
	get_tree().paused = true
	restart_button.grab_focus()


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		restart()
