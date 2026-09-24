class_name SectorWarnings
extends Control
## Pulsing arrows at the screen edges for the sectors (north/east/south/
## west) the WaveDirector says are threatened. Amber during a break (where
## the next wave will come from), red while a wave is attacking.

var director: WaveDirector

const LABELS := {&"north": "NORTH", &"east": "EAST", &"south": "SOUTH", &"west": "WEST"}


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if director == null or director.state == WaveDirector.State.WON:
		return
	var attacking := director.state == WaveDirector.State.WAVE
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 180.0)
	var color := Color(1.0, 0.3, 0.25, pulse) if attacking else Color(1.0, 0.75, 0.3, pulse)
	var font := get_theme_default_font()
	for sector in director.threatened_sectors():
		var tip: Vector2
		var dir: Vector2
		match sector:
			&"north":
				tip = Vector2(size.x / 2.0, 108.0)
				dir = Vector2.UP
			&"south":
				tip = Vector2(size.x / 2.0, size.y - 12.0)
				dir = Vector2.DOWN
			&"east":
				tip = Vector2(size.x - 12.0, size.y / 2.0)
				dir = Vector2.RIGHT
			_:
				tip = Vector2(12.0, size.y / 2.0)
				dir = Vector2.LEFT
		var back := tip - dir * 26.0
		var side := dir.orthogonal() * 18.0
		draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), color)
		var text: String = LABELS[sector]
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var at := back - dir * 10.0 - Vector2(text_size.x / 2.0, -5.0)
		if dir == Vector2.LEFT:
			at = back + Vector2(8.0, 5.0)
		elif dir == Vector2.RIGHT:
			at = back - Vector2(text_size.x + 8.0, -5.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
