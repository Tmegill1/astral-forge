extends SceneTree
## Headless checks for the run's wave data (scenes/waves/first_run.tscn).
## Run: godot --headless --path . --script tests/test_waves.gd
## Prints each failure and "waves: N passed, M failed"; exits 1 on failure.

var passed := 0
var failed := 0


func _init() -> void:
	var tree = load("res://scenes/waves/first_run.tscn").instantiate()
	var run = tree.to_definition()
	tree.free()
	check("10 waves", run.waves.size(), 10)
	# Waves 1-5 as they were: [enemy id, count, sector, interval, delay] per group.
	var before := {
		0: [["goblin", 6, "west", 2.0, 0.0]],
		1: [["goblin", 5, "west", 1.8, 0.0], ["goblin", 5, "north", 1.8, 4.0], ["goblin_shaman", 1, "west", 2.0, 5.0]],
		2: [["goblin", 7, "east", 1.5, 0.0], ["goblin", 7, "south", 1.5, 3.0], ["armored_goblin", 2, "east", 2.5, 0.0], ["goblin_shaman", 1, "east", 2.0, 4.0]],
	}
	for w in before:
		var groups := []
		for g in run.waves[w].groups:
			groups.append([String(g.enemy.id), g.count, g.sector, g.interval, g.delay])
		check("wave %d unchanged" % (w + 1), groups, before[w])
	var totals := {}
	var bosses := {}
	for w in run.waves.size():
		for g in run.waves[w].groups:
			totals[g.enemy.id] = totals.get(g.enemy.id, 0) + g.count
			if g.enemy.is_boss:
				bosses[g.enemy.id] = w + 1
	check("goblins", totals.get(&"goblin", 0), 236)
	check("armored", totals.get(&"armored_goblin", 0), 39)
	check("shamans", totals.get(&"goblin_shaman", 0), 24)
	check("warchief wave 6", bosses.get(&"goblin_warchief", 0), 6)
	check("king wave 10", bosses.get(&"goblin_shaman_king", 0), 10)
	check("one warchief", totals.get(&"goblin_warchief", 0), 1)
	check("one king", totals.get(&"goblin_shaman_king", 0), 1)
	check("banner 6", run.waves[5].banner, "Wave 6 — The Warchief approaches")
	check("banner 9", run.waves[8].banner, "Wave 9 — They're everywhere")
	check("banner 10", run.waves[9].banner, "Final wave — The Shaman-King")
	check("banner 7 default", run.waves[6].banner, "")
	check("prep times 6-10", [run.waves[5].prep_time, run.waves[6].prep_time, run.waves[7].prep_time, run.waves[8].prep_time, run.waves[9].prep_time], [35.0, 30.0, 30.0, 25.0, 45.0])
	var king: Resource = load("res://data/enemies/goblin_shaman_king.tres")
	check("king ends run", [king.is_boss, king.ends_run, king.projectile_count, king.phase2_at], [true, true, 5, 0.5])
	var chief: Resource = load("res://data/enemies/goblin_warchief.tres")
	check("warchief", [chief.is_boss, chief.ends_run, chief.ignores_walls, chief.structure_damage_multiplier, chief.drops_lodestone], [true, false, true, 3.0, true])
	print("waves: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(label: String, got: Variant, want: Variant) -> void:
	if got == want:
		passed += 1
	else:
		failed += 1
		print("FAIL %s: got %s, want %s" % [label, got, want])
