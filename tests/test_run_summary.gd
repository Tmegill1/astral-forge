extends SceneTree
## Headless checks for the end-of-run screen's text helpers.
## Run: godot --headless --path . --script tests/test_run_summary.gd
## Prints each failure and "run_summary: N passed, M failed"; exits 1 on failure.
## (Lines about autoloads not being found are harmless in --script mode.)

var passed := 0
var failed := 0


func _init() -> void:
	var screen = load("res://scripts/ui/game_over.gd")
	if screen == null or not screen.has_method(&"time_text"):
		print("FAIL: GameOverScreen text helpers missing")
		quit(1)
		return
	check("time 0", screen.time_text(0.0), "0:00")
	check("time 65.9", screen.time_text(65.9), "1:05")
	check("time 13 min", screen.time_text(783.0), "13:03")
	check("chip rank 1", screen.card_chip("Arc Bolts", 1), "Arc Bolts")
	check("chip rank 2", screen.card_chip("Arc Bolts", 2), "Arc Bolts ×2")
	var gathered: Dictionary[StringName, int] = {&"aether": 12, &"scrap": 140}
	check("gathered", screen.gathered_text(gathered), "140 Scrap · 12 Aether")
	var nothing: Dictionary[StringName, int] = {}
	check("gathered none", screen.gathered_text(nothing), "Nothing")
	check("waves text", screen.waves_text(3, 5), "3 / 5")
	print("run_summary: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(label: String, got: Variant, want: Variant) -> void:
	if got == want:
		passed += 1
	else:
		failed += 1
		print("FAIL %s: got %s, want %s" % [label, got, want])
