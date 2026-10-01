class_name WaveBanner
extends Control
## Big text when a wave starts: fades in, holds, fades out. Boss waves use
## gold text with a coloured outline.

const GOLD := Color(1, 0.85, 0.45)

var _tween: Tween

@onready var label: Label = %BannerText


func _ready() -> void:
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_text(text: String, outline: Color) -> void:
	label.text = text
	var boss := outline.a > 0.0
	label.add_theme_color_override(&"font_color", GOLD if boss else Color.WHITE)
	label.add_theme_color_override(&"font_outline_color", outline if boss else Color.BLACK)
	if _tween:
		_tween.kill()
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.3)
	_tween.tween_interval(2.0)
	_tween.tween_property(self, "modulate:a", 0.0, 0.5)
