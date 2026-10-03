class_name RotateOverlay
extends CanvasLayer
## Touch mode only: covers the screen with "Rotate your device" while it is
## taller than wide. In a run it also pauses the game, and only unpauses if
## it was the one that paused (a menu that had the game paused stays so).

## False on the main menu, where there is nothing to pause.
@export var pauses := true

var _paused_it := false

@onready var cover: Control = $Cover


func _ready() -> void:
	if not Settings.touch_mode:
		queue_free()
		return
	get_viewport().size_changed.connect(_update)
	_update()


func is_portrait() -> bool:
	var size := get_viewport().get_visible_rect().size
	return size.y > size.x


func _update() -> void:
	var portrait := is_portrait()
	cover.visible = portrait
	if not pauses:
		return
	if portrait and not get_tree().paused:
		get_tree().paused = true
		_paused_it = true
	elif not portrait and _paused_it:
		get_tree().paused = false
		_paused_it = false
