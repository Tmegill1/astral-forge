extends SceneTree
## Headless checks for building: every character the game shows exists in
## the default font, and how wall art is cropped at a tower's pad.
## Run: timeout 60 godot --headless --path . --script tests/test_build.gd
## Prints each failure and "build: N passed, M failed"; exits 1 on failure.
## (Lines about autoloads not being found are harmless in --script mode.)

var passed := 0
var failed := 0


func _init() -> void:
	_test_font_has_every_char()
	_test_wall_crop()
	print("build: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


## The web build has no system fonts to fall back on, so a character the
## default font lacks shows as a box with its hex code (e.g. "2192" for →).
func _test_font_has_every_char() -> void:
	var missing := {}
	for dir in ["res://scripts", "res://scenes", "res://data"]:
		_scan(dir, missing)
	for c in missing:
		failed += 1
		print("FAIL font lacks U+%04X '%s' (used in %s)" % [c, char(c), missing[c]])
	if missing.is_empty():
		passed += 1


func _scan(dir: String, missing: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	for file in DirAccess.get_files_at(dir):
		if not (file.ends_with(".gd") or file.ends_with(".tscn") or file.ends_with(".tres")):
			continue
		var text := FileAccess.get_file_as_string(dir + "/" + file)
		for i in text.length():
			var c := text.unicode_at(i)
			if c > 127 and not font.has_char(c):
				missing[c] = dir + "/" + file
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir + "/" + sub, missing)


func _test_wall_crop() -> void:
	var wall: GDScript = load("res://scripts/structures/wall.gd")
	# Pad from x 590 to 690.
	var pad := Vector2(590, 690)
	check("left of pad, overlapping", wall.kept_span(Vector2(545, 629), pad), Vector2(545, 590))
	check("right of pad, overlapping", wall.kept_span(Vector2(651, 735), pad), Vector2(690, 735))
	check("clear of pad", wall.kept_span(Vector2(400, 480), pad), Vector2(400, 480))
	check("touching edge only", wall.kept_span(Vector2(506, 590), pad), Vector2(506, 590))
	check("fully on pad", wall.kept_span(Vector2(600, 680), pad).y - wall.kept_span(Vector2(600, 680), pad).x, 0.0)


func check(label: String, got: Variant, want: Variant) -> void:
	if got == want:
		passed += 1
	else:
		failed += 1
		print("FAIL %s: got %s, want %s" % [label, var_to_str(got), var_to_str(want)])
