extends SceneTree
## Headless checks for touch controls: the joystick math, key hints and
## that no prompt hard-codes a key.
## Run: timeout 60 godot --headless --path . --script tests/test_touch.gd
## Prints each failure and "touch: N passed, M failed"; exits 1 on failure.
## (Lines about autoloads not being found are harmless in --script mode.)

var passed := 0
var failed := 0


func _init() -> void:
	_test_stick()
	_test_key_hint()
	print("touch: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_stick() -> void:
	var script: GDScript = load("res://scripts/ui/touch_stick.gd")
	if script == null:
		failed += 1
		print("FAIL scripts/ui/touch_stick.gd missing")
		return
	var stick = script.new()
	check("idle not held", stick.is_held(), false)
	check("idle vector", stick.vector(), Vector2.ZERO)
	stick.begin(2, Vector2(100, 300))
	check("held", stick.is_held(), true)
	check("finger", stick.finger, 2)
	check("origin", stick.origin, Vector2(100, 300))
	check("just pressed", stick.vector(), Vector2.ZERO)
	stick.drag(2, Vector2(130, 300))
	check("half right", stick.vector(), Vector2(0.5, 0))
	stick.drag(2, Vector2(100, 240))
	check("rim up", stick.vector(), Vector2(0, -1))
	stick.drag(2, Vector2(100, 600))
	check("past rim clamped", stick.vector(), Vector2(0, 1))
	check("knob clamped", stick.knob_offset(), Vector2(0, 60))
	stick.begin(5, Vector2(10, 10))
	check("second finger can't take it", stick.finger, 2)
	stick.drag(5, Vector2(500, 500))
	check("other finger's drag ignored", stick.vector(), Vector2(0, 1))
	stick.end(5)
	check("other finger's lift ignored", stick.is_held(), true)
	stick.end(2)
	check("lifted", stick.is_held(), false)
	check("lifted vector", stick.vector(), Vector2.ZERO)
	stick.begin(0, Vector2(50, 50))
	stick.drag(0, Vector2(80, 50))
	stick.reset()
	check("reset", [stick.is_held(), stick.vector()], [false, Vector2.ZERO])


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
