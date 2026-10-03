extends SceneTree
## Headless checks for touch controls: the joystick math, key hints and
## that no prompt hard-codes a key.
## Run: timeout 60 godot --headless --path . --script tests/test_touch.gd
## Prints each failure and "touch: N passed, M failed"; exits 1 on failure.
## (Lines about autoloads not being found are harmless in --script mode.)

var passed := 0
var failed := 0


func _init() -> void:
	_test_key_hint()
	print("touch: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_key_hint() -> void:
	var settings: Node = load("res://scripts/settings.gd").new()
	var up := InputEventKey.new()
	up.physical_keycode = KEY_UP
	var right_mouse := InputEventMouseButton.new()
	right_mouse.button_index = MOUSE_BUTTON_RIGHT
	settings._bindings[&"interact"] = [up, null]
	settings._bindings[&"manage"] = [null, right_mouse]
	settings._bindings[&"start_wave"] = [null, null]
	settings.touch_mode = false
	check("hint key", settings.key_hint(&"interact"), "[Up Arrow] ")
	check("hint second slot", settings.key_hint(&"manage"), "[Right Mouse] ")
	check("hint unbound", settings.key_hint(&"start_wave"), "")
	check("hint unknown action", settings.key_hint(&"no_such_action"), "")
	settings.touch_mode = true
	check("hint touch", settings.key_hint(&"interact"), "")
	settings.free()


func check(label: String, got: Variant, want: Variant) -> void:
	if got == want:
		passed += 1
	else:
		failed += 1
		print("FAIL %s: got %s, want %s" % [label, var_to_str(got), var_to_str(want)])
