extends SceneTree
## Headless checks for RunCards (XP curve, level-ups, offers, bonuses) and
## the card data files.
## Run: godot --headless --path . --script tests/test_cards.gd
## Prints each failure and "cards: N passed, M failed"; exits 1 on failure.
## (Lines about autoloads not being found are harmless in --script mode.)

var passed := 0
var failed := 0


func _init() -> void:
	var run_cards_script = load("res://scripts/cards/run_cards.gd")
	if run_cards_script == null:
		print("FAIL: scripts/cards/run_cards.gd missing")
		quit(1)
		return
	var curve := []
	for level in range(1, 8):
		curve.append(run_cards_script.xp_for_level(level))
	check("xp curve", curve, [8, 12, 18, 27, 41, 61, 91])

	var pool: Array = run_cards_script.load_pool()
	check("14 cards", pool.size(), 14)
	for card in pool:
		check("%s has title" % card.id, card.title != "", true)
		check("%s has description" % card.id, card.description != "", true)
		check("%s category" % card.id, card.category in ["Hero", "Towers", "Fortress"], true)
		check("%s max_rank" % card.id, card.max_rank >= 1, true)
		check("%s does something" % card.id, not card.stat_bonuses.is_empty() or card.mod != &"", true)

	var cards = run_cards_script.new()
	cards.pool = pool
	var levels := []
	cards.leveled_up.connect(func(level: int) -> void: levels.append(level))
	cards.add_xp(7)
	check("7 xp no level", [cards.level, cards.xp, levels], [1, 7, []])
	cards.add_xp(1)
	check("8 xp level 2", [cards.level, cards.xp, levels], [2, 0, [2]])
	cards.add_xp(12 + 18 + 5)
	check("two levels at once", [cards.level, cards.xp, levels], [4, 5, [2, 3, 4]])

	var offer: Array = cards.offer(3)
	check("offer 3", offer.size(), 3)
	check("offer distinct", offer[0] != offer[1] and offer[1] != offer[2] and offer[0] != offer[2], true)

	var by_id := {}
	for card in pool:
		by_id[card.id] = card
	var bolts = by_id[&"sharpened_bolts"]
	cards.take(bolts)
	cards.take(bolts)
	check("bonus 2 ranks", is_equal_approx(cards.bonus(&"hero_damage"), 0.4), true)
	check("bonus none", cards.bonus(&"tower_damage"), 0.0)
	cards.take(by_id[&"arc_bolts"])
	check("mod rank", cards.mod_rank(&"arc_bolts"), 1)
	check("mod rank none", cards.mod_rank(&"split_shot"), 0)
	for i in 3:
		cards.take(bolts)
	check("maxed at 5", cards.rank_of(bolts), 5)
	for i in 50:
		if bolts in cards.offer(3):
			check("maxed never offered", true, false)
			break
	# Only two cards left with ranks to give.
	for card in pool:
		if card.id != &"fleet_foot" and card.id != &"wide_pull":
			while cards.rank_of(card) < card.max_rank:
				cards.take(card)
	var last: Array = cards.offer(3)
	check("two left", last.size(), 2)
	cards.end_run()
	var before: int = cards.level
	cards.add_xp(1000)
	check("no levels after end", cards.level, before)
	cards.free()

	print("cards: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(label: String, got: Variant, want: Variant) -> void:
	if got == want:
		passed += 1
	else:
		failed += 1
		print("FAIL %s: got %s, want %s" % [label, got, want])
