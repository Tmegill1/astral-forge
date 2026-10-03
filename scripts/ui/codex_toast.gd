class_name CodexToast
extends CanvasLayer
## "New Codex entry" notice near the top of the screen: one at a time, about
## 3 s each, queued. Never takes mouse input.

const SHOW_TIME := 3.0
const FADE_TIME := 0.25

var _queue: Array[String] = []
var _busy := false

@onready var panel: Control = %Panel
@onready var title: Label = %Title
@onready var hint: Label = %Hint


func _ready() -> void:
	panel.visible = false
	panel.modulate.a = 0.0
	Codex.discovered.connect(_on_discovered)
	if Settings.touch_mode:
		hint.text = "⏸ → Help to read it"


func is_showing() -> bool:
	return _busy


func _on_discovered(definition: EnemyDefinition) -> void:
	_queue.append(definition.display_name)
	if not _busy:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	title.text = "New Codex entry: %s" % _queue.pop_front()
	panel.visible = true
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, FADE_TIME)
	tween.tween_interval(SHOW_TIME)
	tween.tween_property(panel, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(_on_shown)


func _on_shown() -> void:
	panel.visible = false
	_show_next()
