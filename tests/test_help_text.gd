extends SceneTree
## Headless checks for HelpText and the Help/Codex text in the data files.
## Run: godot --headless --path . --script tests/test_help_text.gd
## Prints each failure and "help_text: N passed, M failed"; exits 1 on failure.

var passed := 0
var failed := 0


func _init() -> void:
	var help_text = load("res://scripts/ui/help_text.gd")
	if help_text == null:
		print("FAIL: scripts/ui/help_text.gd missing")
		quit(1)
		return
	var gearshot: Resource = load("res://data/towers/gearshot.tres")
	var goblin: Resource = load("res://data/enemies/goblin.tres")
	var armored: Resource = load("res://data/enemies/armored_goblin.tres")
	var shaman: Resource = load("res://data/enemies/goblin_shaman.tres")

	check("percent 1.3", help_text.percent(1.3), "+30%")
	check("percent 1.15", help_text.percent(1.15), "+15%")
	check("rating low", help_text.rating(0.79, 1.0), "Low")
	check("rating average low edge", help_text.rating(0.8, 1.0), "Average")
	check("rating average high edge", help_text.rating(1.5, 1.0), "Average")
	check("rating high", help_text.rating(2.5, 1.0), "High")
	check("rating very high", help_text.rating(2.6, 1.0), "Very high")
	var lv3: Dictionary[StringName, int] = {&"aether": 3, &"scrap": 25}
	check("cost order", help_text.cost_text(lv3), "25 Scrap + 3 Aether")
	check("gearshot operated", help_text.operated_line(gearshot), "+35% damage, +50% fire rate, +15% range")
	check("gearshot upgrades", Array(help_text.upgrade_lines(gearshot)), [
		"Lv1 — Build: 10 Scrap",
		"Lv2 — 15 Scrap: +30% damage, +15% fire rate, +10% range, +40% health",
		"Lv3 — 25 Scrap + 3 Aether: +30% damage, +15% fire rate, +10% range, +40% health (again)",
	])
	check("armored glance", help_text.glance(armored, goblin), "Health: High · Speed: Low · Hits: Average")
	check("shaman glance", help_text.glance(shaman, goblin), "Health: Average · Speed: Average · Hits: Low")
	check("goblin glance", help_text.glance(goblin, goblin), "Health: Average · Speed: Average · Hits: Average")
	check("armored strengths", Array(help_text.resistance_strengths(armored)), ["Shrugs off Physical damage", "Resists Fire damage"])
	check("armored weakness", Array(help_text.resistance_weaknesses(armored)), ["Weak to Magic"])
	check("shaman strengths", Array(help_text.resistance_strengths(shaman)), ["Resists Magic damage"])
	check("shaman weakness", Array(help_text.resistance_weaknesses(shaman)), ["Weak to Physical and Fire"])
	check("goblin no resist", Array(help_text.resistance_strengths(goblin)), [])
	check("goblin no weakness", Array(help_text.resistance_weaknesses(goblin)), [])
	check("gearshot bbcode damage", help_text.tower_bbcode(gearshot).contains("[b]Damage:[/b] Physical"), true)
	check("gearshot bbcode ability", help_text.tower_bbcode(gearshot).contains("Rapid Fire — Triples the fire rate for 3 s. (Cooldown: 12 s)"), true)
	check("armored bbcode", help_text.enemy_bbcode(armored, goblin).contains("Weak to Magic"), true)
	for path in ["gearshot", "rune_mortar", "embercaster", "aether_spire"]:
		var tower: Resource = load("res://data/towers/%s.tres" % path)
		for field in ["damage_type_label", "good_against", "weak_against", "ability_text"]:
			check("%s.%s set" % [path, field], String(tower.get(field)) != "", true)
	for enemy in [goblin, armored, shaman]:
		check("%s summary" % enemy.id, enemy.codex_summary != "", true)
		check("%s strengths" % enemy.id, enemy.codex_strengths.size() > 0, true)
		check("%s weaknesses" % enemy.id, enemy.codex_weaknesses.size() > 0, true)
		check("%s tip" % enemy.id, enemy.codex_tip != "", true)
	# The Codex notice sits above the HUD (layer 1) but below every menu.
	var toast_layer := _layer("res://scenes/ui/codex_toast.tscn")
	for menu in ["build_menu", "tower_menu", "hero_upgrade_menu", "game_over", "pause_menu"]:
		check("toast below %s" % menu, toast_layer < _layer("res://scenes/ui/%s.tscn" % menu), true)
	check("toast above hud", toast_layer > 1, true)
	print("help_text: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(label: String, got: Variant, want: Variant) -> void:
	if got == want:
		passed += 1
	else:
		failed += 1
		print("FAIL %s: got %s, want %s" % [label, got, want])


## A CanvasLayer scene's `layer` without instancing it (1 when not set).
func _layer(path: String) -> int:
	var state := (load(path) as PackedScene).get_state()
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == &"layer":
			return state.get_node_property_value(0, i)
	return 1
