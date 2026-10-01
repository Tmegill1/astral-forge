extends SceneTree
## Headless checks for tower evolutions: the data files and the rules that
## don't need a running game.
## Run: godot --headless --path . --script tests/test_evolutions.gd
## Prints each failure and "evolutions: N passed, M failed"; exits 1 on failure.
## (Lines about autoloads not being found are harmless in --script mode.)

## Base tower id -> its two branch ids, in menu order. Each branch task adds
## its pair here.
const EXPECTED := {
	&"gearshot": [&"gatling_engine"],
}
## Stats an evolution copies unchanged from its base tower, so it starts at
## exactly the base tower's Lv3 numbers.
const COPIED := [&"max_health", &"attack_damage", &"attacks_per_second", &"attack_range",
		&"projectile_speed", &"level_damage_multiplier", &"level_fire_rate_multiplier",
		&"level_range_multiplier", &"level_health_multiplier", &"operated_damage_multiplier",
		&"operated_fire_rate_multiplier", &"operated_range_multiplier"]
const BASES := [&"gearshot", &"rune_mortar", &"embercaster", &"aether_spire"]

var passed := 0
var failed := 0


func _init() -> void:
	var help_text = load("res://scripts/ui/help_text.gd")
	var slot_script = load("res://scripts/towers/build_slot.gd")
	var gearshot = load("res://data/towers/gearshot.tres")
	if help_text == null or slot_script == null or gearshot == null:
		print("FAIL: a script or data file failed to load")
		quit(1)
		return

	check("base not evolved", gearshot.evolved, false)
	check("default tint", gearshot.tint, Color.WHITE)
	check("default glow", gearshot.glow.a, 0.0)
	check("base icon", gearshot.icon() != null, true)

	# Selling refunds half of everything invested, Aether from evolving included.
	var slot = slot_script.new()
	var invested: Dictionary[StringName, int] = {&"scrap": 50, &"aether": 9}
	slot.invested = invested
	var want: Dictionary[StringName, int] = {&"scrap": 25, &"aether": 4}
	check("sell value with evolve aether", slot.sell_value(), want)
	slot.free()

	for base_id in BASES:
		var base = load("res://data/towers/%s.tres" % base_id)
		var ids: Array = EXPECTED.get(base_id, [])
		var got_ids := []
		for branch in base.evolutions:
			got_ids.append(branch.id)
		check("%s branches" % base_id, got_ids, ids)
		var help: String = help_text.tower_bbcode(base)
		check("%s help mentions evolutions" % base_id, help.contains("Evolutions"), not ids.is_empty())
		for branch in base.evolutions:
			check_branch(base, branch, help, help_text)

	var gatling = load("res://data/towers/gatling_engine.tres")
	if gatling:
		check("spin up half", gatling.spin_after(0.0, 1.0, true), 0.5)
		check("spin up capped", gatling.spin_after(0.9, 1.0, true), 1.0)
		check("spin down", gatling.spin_after(1.0, 0.5, false), 0.5)
		check("spin floor", gatling.spin_after(0.2, 1.0, false), 0.0)
		check("spin x1", gatling.spin_multiplier(0.0), 1.0)
		check("spin x4", gatling.spin_multiplier(1.0), 4.0)
	else:
		check("gatling data exists", false, true)

	print("evolutions: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check_branch(base, branch, help: String, help_text) -> void:
	var id: StringName = branch.id
	check("%s evolved" % id, branch.evolved, true)
	check("%s no further evolutions" % id, branch.evolutions.is_empty(), true)
	var cost: Dictionary[StringName, int] = {&"aether": 6}
	check("%s costs 6 aether" % id, branch.evolve_cost, cost)
	check("%s has help line" % id, branch.help_line != "", true)
	check("%s has ability" % id, branch.ability_name != "" and branch.ability_text != "", true)
	check("%s in base help" % id, help.contains(branch.display_name) and help.contains(branch.help_line), true)
	check("%s has lv3 art" % id, branch.sprite_frames.has_animation(&"lv3_idle")
			and branch.sprite_frames.has_animation(&"lv3_fire"), true)
	check("%s icon" % id, branch.icon() != null, true)
	check("%s same kind as base" % id, inherits(branch.get_script(), base.get_script()), true)
	for stat in COPIED:
		check("%s copies %s" % [id, stat], branch.get(stat), base.get(stat))


## True when `script` is `ancestor` or extends it.
func inherits(script: Script, ancestor: Script) -> bool:
	while script != null:
		if script == ancestor:
			return true
		script = script.get_base_script()
	return false


func check(label: String, got: Variant, want: Variant) -> void:
	if got == want:
		passed += 1
	else:
		failed += 1
		print("FAIL %s: got %s, want %s" % [label, got, want])
