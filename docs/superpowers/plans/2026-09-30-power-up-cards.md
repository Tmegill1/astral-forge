# XP and Power-up Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enemies drop XP orbs (and rarely a Lodestone that pulls every orb in); XP levels the player up on a ×1.5 curve; each level-up pauses the game and offers 3 of 14 run-long cards (stat bonuses for hero, towers and fortress, plus Arc Bolts / Split Shot / Ember Rounds hero mods).

**Architecture:** A per-run `RunCards` node in `world.tscn` owns XP, level and card ranks, and answers `bonus(stat)` / `mod_rank(mod)`; a static `RunCards.multiplier(node, stat)` lets any script fold card bonuses into its own stat functions. Cards are `CardDefinition` data files in `data/cards/`. `XpOrb` and `Lodestone` are small drawn pickups. `CardMenu` shows the pick screen on `leveled_up`.

**Tech Stack:** Godot 4.7 GDScript; headless test scripts (`godot --headless --path . --script tests/…`) plus the Godot MCP tools in the running game.

**Spec:** `docs/superpowers/specs/2026-09-30-power-up-cards-design.md`

## Global Constraints

- XP: Goblin 1, Goblin Shaman 3, Armored Goblin 3 (`EnemyDefinition.xp_value`). Level cost `roundi(8 × 1.5^(level − 1))` = 8, 12, 18, 27, 41, 61, 91; overflow kept; several level-ups from one gain each emit `leveled_up`.
- Orbs: drawn teal orb; pull radius 140 px × (1 + `pull_radius` bonus), speed 320 px/s; never despawn; XP never lost; dead heroes don't attract.
- Lodestone: 3% per kill, never two on the map; on touch every orb rushes to the hero at 900 px/s regardless of distance.
- Cards (id → per rank, max): sharpened_bolts hero_damage 0.2 ×5; quick_trigger hero_fire_rate 0.15 ×5; fleet_foot hero_move_speed 0.1 ×3; thick_hide hero_max_health 0.2 ×3; arc_bolts mod ×3; split_shot mod ×2; ember_rounds mod ×3; calibrated_barrels tower_damage 0.15 ×5; oiled_gears tower_fire_rate 0.1 ×3; long_sight tower_range 0.1 ×3; reinforced_plating structure_health 0.25 ×3; core_plating core_max_health 0.2 ×3; salvager scrap_drops 0.25 ×3; wide_pull pull_radius 0.5 ×2.
- Mods: Split Shot rank r → r extra bolts each side at ±12°, ±24°. Arc Bolts → on a bolt hit, chain to up to `rank` other living enemies within 120 px (nearest to the previous link, no repeats), 50% of the bolt's damage each, magic, Spire `LightningArc` visual. Ember Rounds → hit enemy gets `rank` burn stacks via `add_burn(2.0, 5, 3.0, rank)`.
- Bonuses multiply: hero damage / fire rate / move speed / max health (on top of Core upgrades; extra max health added to current); `Tower.damage()` / `fire_rate()` / `attack_range()`; tower and wall max health; Core max health; Scrap drop amounts `maxi(n, roundi(n × mult))` (Aether unchanged); Scrap and orb pull radius.
- Pick screen: layer 5, pauses, title "Level N — choose a card", 3 different cards (fewer if fewer remain; skip if none), category tag colours Hero `Color(1, 0.82, 0.45)` / Towers `Color(0.55, 0.75, 1)` / Fortress `Color(0.55, 0.9, 0.6)`, "Rank r / max", click or 1/2/3, no skip, Esc does nothing; queued level-ups show back to back; never over Game Over / Win (run ends → pending dropped).
- HUD: XP row as the last row of the hero panel: "Lv N" + 8 px teal bar + "x / y XP".
- Branch `feature/power-up-cards`; one commit per task (`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`); stage only the task's files. New `class_name` → `godot --headless --editor --path . --import`.
- MCP: first `game_eval` after `run_project` says "Not connected" (retry; if the bridge isn't in `[autoload]`, stop, clean, run again). Clean `project.godot` after `stop_project` (bridge lines only). Evals: untyped `=` not `:=`, ≤ ~25 s, disconnect lambdas. Start scene is the main menu: `get_tree().current_scene.play_button.pressed.emit()`, await 4 frames. Hold wave 1 with `world.waves.break_left = 99999.0`. Menus are under `UI` (`world.get_node("UI/CardMenu")`). Delete `user://codex.cfg` / `user://settings.cfg` at the end.

## Review Focus

1. **The run ends with a level-up pending or arriving** (Core dies, last wave cleared): Game Over / Win shows, no card screen appears over or after it, Restart starts clean (Task 3 test).
2. **The hero dies while orbs are rushing from a Lodestone**: orbs stop and wait; after the respawn they keep flying in and their XP counts (Task 2 test).
3. **Thick Hide / Core Plating / Reinforced Plating taken while damaged**: max health rises and the same amount is added to current health; never exceeds the new max; a destroyed (dead) wall/tower isn't revived (Task 4 test).
4. **Card bonuses and Core upgrades together**: buying a hero upgrade at the Core after taking Sharpened Bolts keeps both (and vice versa); operated-tower bonuses stack with Calibrated Barrels (Task 4 test).
5. **Hundreds of orbs on the map** (a missed wave of drops): the game stays smooth — physics time with 300 orbs stays under 8 ms (Task 2 test).

---

### Task 1: Card data and RunCards logic

**Files:** Create `scripts/cards/card_definition.gd`, `scripts/cards/run_cards.gd`, `data/cards/*.tres` (14 files), `tests/test_cards.gd`.

**Interfaces:**
- Consumes: nothing new.
- Produces: `class_name CardDefinition extends Resource` (`id: StringName`, `title: String`, `description: String`, `category: String`, `max_rank: int`, `stat_bonuses: Dictionary[StringName, float]`, `mod: StringName`); `class_name RunCards extends Node` with `signal leveled_up(new_level: int)`, `signal xp_changed`, `signal changed`, `const FIRST_LEVEL_XP := 8`, `const LEVEL_GROWTH := 1.5`, vars `xp: int`, `level: int`, `ranks: Dictionary[StringName, int]`, `ended: bool`, `pool: Array[CardDefinition]`; methods `static load_pool() -> Array[CardDefinition]`, `static xp_for_level(level: int) -> int`, `add_xp(amount: int)`, `offer(count := 3) -> Array[CardDefinition]`, `rank_of(card: CardDefinition) -> int`, `take(card: CardDefinition)`, `bonus(stat: StringName) -> float`, `mod_rank(mod: StringName) -> int`, `end_run()`, `static multiplier(node: Node, stat: StringName) -> float`. Group `run_cards`. Test command: `godot --headless --path . --script tests/test_cards.gd`.

- [ ] **Step 1: Write the failing test** `tests/test_cards.gd`:
```gdscript
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
```
- [ ] **Step 2: Run it.** `godot --headless --path . --script tests/test_cards.gd`. Expected: `FAIL: scripts/cards/run_cards.gd missing`.
- [ ] **Step 3: CardDefinition** `scripts/cards/card_definition.gd`:
```gdscript
class_name CardDefinition
extends Resource
## One power-up card. Each rank adds `stat_bonuses` again (e.g. 0.2 =
## +20% per rank); a `mod` id turns on special behaviour the hero code checks
## with RunCards.mod_rank(). New card = new .tres in data/cards/.

@export var id: StringName
@export var title := ""
## One line saying what one rank does.
@export var description := ""
## "Hero", "Towers" or "Fortress".
@export var category := "Hero"
@export var max_rank := 3
## Stat id -> bonus per rank. Stat ids: hero_damage, hero_fire_rate,
## hero_move_speed, hero_max_health, tower_damage, tower_fire_rate,
## tower_range, structure_health, core_max_health, scrap_drops, pull_radius.
@export var stat_bonuses: Dictionary[StringName, float] = {}
## Special behaviour: arc_bolts, split_shot or ember_rounds. Empty = none.
@export var mod: StringName
```
- [ ] **Step 4: RunCards** `scripts/cards/run_cards.gd`:
```gdscript
class_name RunCards
extends Node
## This run's XP, level and power-up cards (a node in the world scene, so a
## new run starts fresh). Other scripts fold card bonuses into their stats
## with RunCards.multiplier(self, &"stat").

## Emitted once per level gained; the card menu offers a pick for each.
signal leveled_up(new_level: int)
signal xp_changed
## A card was taken.
signal changed

const FIRST_LEVEL_XP := 8
## Each level costs this many times the one before.
const LEVEL_GROWTH := 1.5
const CARD_DIR := "res://data/cards/"

var xp := 0
var level := 1
## Card id -> rank owned.
var ranks: Dictionary[StringName, int] = {}
## Set when the run is over: no more XP or level-ups.
var ended := false
var pool: Array[CardDefinition] = []


func _ready() -> void:
	add_to_group(&"run_cards")
	if pool.is_empty():
		pool = load_pool()


## Every card in data/cards/.
static func load_pool() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for file in ResourceLoader.list_directory(CARD_DIR):
		if not file.ends_with(".tres"):
			continue
		var card := load(CARD_DIR + file) as CardDefinition
		if card:
			cards.append(card)
	return cards


## XP needed to go from `for_level` to the next: 8, 12, 18, 27, 41, ...
static func xp_for_level(for_level: int) -> int:
	return roundi(FIRST_LEVEL_XP * pow(LEVEL_GROWTH, for_level - 1))


## 1 + this run's card bonus for `stat`, or 1 outside a run.
static func multiplier(node: Node, stat: StringName) -> float:
	if node == null or not node.is_inside_tree():
		return 1.0
	var cards := node.get_tree().get_first_node_in_group(&"run_cards") as RunCards
	return 1.0 + cards.bonus(stat) if cards else 1.0


func add_xp(amount: int) -> void:
	if ended or amount <= 0:
		return
	xp += amount
	while xp >= xp_for_level(level):
		xp -= xp_for_level(level)
		level += 1
		leveled_up.emit(level)
	xp_changed.emit()


## Up to `count` different cards that still have ranks to give.
func offer(count := 3) -> Array[CardDefinition]:
	var open: Array[CardDefinition] = []
	for card in pool:
		if rank_of(card) < card.max_rank:
			open.append(card)
	open.shuffle()
	return open.slice(0, count)


func rank_of(card: CardDefinition) -> int:
	return ranks.get(card.id, 0)


func take(card: CardDefinition) -> void:
	ranks[card.id] = rank_of(card) + 1
	changed.emit()


## Total bonus for `stat` from every card owned (0.4 = +40%).
func bonus(stat: StringName) -> float:
	var total := 0.0
	for card in pool:
		var rank := rank_of(card)
		if rank > 0 and card.stat_bonuses.has(stat):
			total += card.stat_bonuses[stat] * rank
	return total


## Rank of the card with this mod (0 if not owned).
func mod_rank(mod: StringName) -> int:
	for card in pool:
		if card.mod == mod:
			return rank_of(card)
	return 0


func end_run() -> void:
	ended = true
```
- [ ] **Step 5: The 14 cards.** One file each in `data/cards/`, in this format (example `sharpened_bolts.tres`):
```
[gd_resource type="Resource" script_class="CardDefinition" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/cards/card_definition.gd" id="1_card"]

[resource]
script = ExtResource("1_card")
id = &"sharpened_bolts"
title = "Sharpened Bolts"
description = "+20% hero damage."
category = "Hero"
max_rank = 5
stat_bonuses = Dictionary[StringName, float]({
&"hero_damage": 0.2
})
```
  For mod cards drop `stat_bonuses` and add `mod = &"arc_bolts"` (etc.). The values:

| file | title | description | category | max_rank | stat_bonuses / mod |
|---|---|---|---|---|---|
| sharpened_bolts | Sharpened Bolts | +20% hero damage. | Hero | 5 | hero_damage 0.2 |
| quick_trigger | Quick Trigger | +15% hero fire rate. | Hero | 5 | hero_fire_rate 0.15 |
| fleet_foot | Fleet Foot | +10% move speed. | Hero | 3 | hero_move_speed 0.1 |
| thick_hide | Thick Hide | +20% max health (and heals that much). | Hero | 3 | hero_max_health 0.2 |
| arc_bolts | Arc Bolts | Your bolts chain lightning to 1 more nearby enemy (half damage, magic). | Hero | 3 | mod arc_bolts |
| split_shot | Split Shot | Fire 1 extra bolt to each side. | Hero | 2 | mod split_shot |
| ember_rounds | Ember Rounds | Your bolts add 1 burn stack. | Hero | 3 | mod ember_rounds |
| calibrated_barrels | Calibrated Barrels | All towers +15% damage. | Towers | 5 | tower_damage 0.15 |
| oiled_gears | Oiled Gears | All towers +10% fire rate. | Towers | 3 | tower_fire_rate 0.1 |
| long_sight | Long Sight | All towers +10% range. | Towers | 3 | tower_range 0.1 |
| reinforced_plating | Reinforced Plating | Towers and walls +25% max health. | Towers | 3 | structure_health 0.25 |
| core_plating | Core Plating | Command Core +20% max health (and heals that much). | Fortress | 3 | core_max_health 0.2 |
| salvager | Salvager | +25% Scrap from enemies. | Fortress | 3 | scrap_drops 0.25 |
| wide_pull | Wide Pull | XP orbs and Scrap drift to you from 50% further away. | Fortress | 2 | pull_radius 0.5 |
- [ ] **Step 6: Run it.** Import, then the test. Expected: `cards: … passed, 0 failed`. Also run `tests/test_help_text.gd` (still 0 failed).
- [ ] **Step 7: Commit** `Add the power-up cards and RunCards (XP, levels, offers)`.

---

### Task 2: XP orbs, the Lodestone, drops and the HUD bar

**Files:** Create `scripts/loot/xp_orb.gd`, `scenes/loot/xp_orb.tscn`, `scripts/loot/lodestone.gd`, `scenes/loot/lodestone.tscn`. Modify `scripts/enemies/enemy_definition.gd`, `data/enemies/goblin.tres`, `data/enemies/armored_goblin.tres`, `data/enemies/goblin_shaman.tres`, `scenes/world.tscn`, `scripts/world.gd`, `scenes/ui/hud.tscn`, `scripts/ui/hud.gd`.

**Interfaces:**
- Consumes: `RunCards` (`add_xp`, `xp`, `level`, `xp_for_level`, `xp_changed`, `multiplier`) (Task 1).
- Produces: `EnemyDefinition.xp_value: int`; `class_name XpOrb` (`amount: int`, `rushing: bool`, `static drop(parent: Node, at: Vector2, amount: int)`, consts `PULL_RADIUS := 140.0`, `PULL_SPEED := 320.0`, `RUSH_SPEED := 900.0`), group `xp_orbs`; `class_name Lodestone` (`static drop(parent: Node, at: Vector2)`), group `lodestones`; `World.run_cards: RunCards`, `World.LODESTONE_CHANCE := 0.03`; `HUD.bind_run_cards(cards: RunCards)`.

- [ ] **Step 1: Failing check.** Run the game, Play, eval `return get_tree().current_scene.has_node("RunCards")`. Expected `false`. Stop.
- [ ] **Step 2: Enemy XP.** `enemy_definition.gd` Loot group, after `rare_drops`:
```gdscript
## XP in the orb this enemy drops when killed.
@export var xp_value := 1
```
  Add `xp_value = 3` to `armored_goblin.tres` and `goblin_shaman.tres` (goblin keeps the default 1; add `xp_value = 1` explicitly to `goblin.tres` too).
- [ ] **Step 3: XpOrb** `scripts/loot/xp_orb.gd`:
```gdscript
class_name XpOrb
extends Area2D
## XP dropped by an enemy: a glowing teal orb (drawn, no art). Drifts to a
## nearby living hero and adds its XP to RunCards on touch. A Lodestone sets
## `rushing`, sending it to the hero from anywhere. Never despawns.

const SCENE_PATH := "res://scenes/loot/xp_orb.tscn"
const PULL_RADIUS := 140.0
const PULL_SPEED := 320.0
const RUSH_SPEED := 900.0
## The hero's body centre, from its feet.
const HERO_CENTRE := Vector2(0, -8)

var amount := 1
var rushing := false
var _popping := false
var _time := 0.0


## Drops an orb worth `amount` at `at` (deferred: kills happen mid-physics).
static func drop(parent: Node, at: Vector2, amount: int) -> void:
	if amount > 0:
		_drop_now.call_deferred(parent, at, amount)


static func _drop_now(parent: Node, at: Vector2, amount: int) -> void:
	if not is_instance_valid(parent):
		return
	var orb: XpOrb = load(SCENE_PATH).instantiate()
	orb.amount = amount
	orb.position = at
	parent.add_child(orb)
	orb.pop_to(at + Vector2.from_angle(randf() * TAU) * randf_range(8.0, 24.0))


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func pop_to(landing: Vector2) -> void:
	_popping = true
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position", landing, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_land)


func _land() -> void:
	_popping = false
	for body in get_overlapping_bodies():
		_on_body_entered(body)


func _physics_process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _popping:
		return
	var hero := get_tree().get_first_node_in_group(&"hero") as Hero
	if hero == null or hero.health.is_dead:
		return
	var target := hero.global_position + HERO_CENTRE
	if rushing:
		global_position = global_position.move_toward(target, RUSH_SPEED * delta)
	elif global_position.distance_to(target) <= PULL_RADIUS * RunCards.multiplier(self, &"pull_radius"):
		global_position = global_position.move_toward(target, PULL_SPEED * delta)


func _on_body_entered(body: Node2D) -> void:
	var hero := body as Hero
	if hero == null or hero.health.is_dead or _popping:
		return
	var cards := get_tree().get_first_node_in_group(&"run_cards") as RunCards
	if cards:
		cards.add_xp(amount)
	queue_free()


func _draw() -> void:
	var pulse := 1.0 + 0.15 * sin(_time * 6.0)
	draw_circle(Vector2(0, -6), 12.0 * pulse, Color(0.3, 1.0, 0.85, 0.18))
	draw_circle(Vector2(0, -6), 7.0 * pulse, Color(0.35, 0.95, 0.85, 0.9))
	draw_circle(Vector2(0, -7), 3.0, Color(0.9, 1.0, 1.0, 0.95))
```
  `scenes/loot/xp_orb.tscn`:
```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/loot/xp_orb.gd" id="1_orb"]

[sub_resource type="CircleShape2D" id="CircleShape2D_orb"]
radius = 10.0

[node name="XpOrb" type="Area2D" groups=["xp_orbs"]]
collision_layer = 0
collision_mask = 2
monitorable = false
script = ExtResource("1_orb")

[node name="Shape" type="CollisionShape2D" parent="."]
position = Vector2(0, -6)
shape = SubResource("CircleShape2D_orb")
```
- [ ] **Step 4: Lodestone** `scripts/loot/lodestone.gd`:
```gdscript
class_name Lodestone
extends Area2D
## Rare drop: a spinning gold-and-blue crystal (drawn). When the hero touches
## it, every XP orb on the map rushes to them.

const SCENE_PATH := "res://scenes/loot/lodestone.tscn"

var _time := 0.0


## Drops one at `at` (deferred: kills happen mid-physics).
static func drop(parent: Node, at: Vector2) -> void:
	_drop_now.call_deferred(parent, at)


static func _drop_now(parent: Node, at: Vector2) -> void:
	if not is_instance_valid(parent):
		return
	var stone: Lodestone = load(SCENE_PATH).instantiate()
	stone.position = at + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
	parent.add_child(stone)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_time += delta
	queue_redraw()
	var hero := get_tree().get_first_node_in_group(&"hero") as Hero
	if hero == null or hero.health.is_dead:
		return
	var target := hero.global_position + XpOrb.HERO_CENTRE
	if global_position.distance_to(target) <= XpOrb.PULL_RADIUS * RunCards.multiplier(self, &"pull_radius"):
		global_position = global_position.move_toward(target, XpOrb.PULL_SPEED * delta)


func _on_body_entered(body: Node2D) -> void:
	var hero := body as Hero
	if hero == null or hero.health.is_dead:
		return
	for orb in get_tree().get_nodes_in_group(&"xp_orbs"):
		(orb as XpOrb).rushing = true
	queue_free()


func _draw() -> void:
	var spin := _time * 2.0
	var ring := 14.0 + 3.0 * sin(_time * 4.0)
	draw_arc(Vector2(0, -8), ring, 0.0, TAU, 32, Color(1.0, 0.85, 0.4, 0.5), 2.0)
	var points := PackedVector2Array()
	for i in 4:
		var radius := 11.0 if i % 2 == 0 else 7.0
		points.append(Vector2(0, -8) + Vector2.from_angle(spin + i * TAU / 4.0) * radius)
	draw_colored_polygon(points, Color(1.0, 0.8, 0.3))
	draw_circle(Vector2(0, -8), 3.5, Color(0.45, 0.8, 1.0))
```
  `scenes/loot/lodestone.tscn`: same as the orb scene but `name="Lodestone"`, `groups=["lodestones"]`, script `res://scripts/loot/lodestone.gd`, radius 12.
- [ ] **Step 5: World.** `world.tscn`: add `[ext_resource type="Script" path="res://scripts/cards/run_cards.gd" id="22_run_cards"]` after the last ext_resource and, after the `WaveDirector` node, `[node name="RunCards" type="Node" parent="."]` with `script = ExtResource("22_run_cards")`. `world.gd`:
  - `const LODESTONE_CHANCE := 0.03` with comment "## Chance per kill of a Lodestone, unless one is already on the map."
  - `@onready var run_cards: RunCards = $RunCards`
  - in `_ready()`, after `hud.bind_core(core)`: `hud.bind_run_cards(run_cards)`
  - `_on_enemy_killed` becomes:
```gdscript
func _on_enemy_killed(enemy: Enemy) -> void:
	kills += 1
	var at := enemy.global_position
	var drops := enemy.definition.drops
	for type in drops:
		var amount := randi_range(drops[type].x, drops[type].y)
		if type == Loot.SCRAP:
			amount = maxi(amount, roundi(amount * RunCards.multiplier(self, &"scrap_drops")))
		Loot.drop(units, at, type, amount)
	var rare := enemy.definition.rare_drops
	for type in rare:
		if randf() < rare[type]:
			Loot.drop(units, at, type, 1)
	XpOrb.drop(units, at, enemy.definition.xp_value)
	if randf() < LODESTONE_CHANCE and get_tree().get_nodes_in_group(&"lodestones").is_empty():
		Lodestone.drop(units, at)
```
  - `scripts/loot/pickup.gd` `_physics_process`: `<= magnet_radius` → `<= magnet_radius * RunCards.multiplier(self, &"pull_radius")`.
- [ ] **Step 6: HUD XP row.** `hud.tscn`, appended under `HeroPanel/Margin/Rows` after `StatsText`:
```
[node name="XpRow" type="HBoxContainer" parent="HeroPanel/Margin/Rows"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="LevelText" type="Label" parent="HeroPanel/Margin/Rows/XpRow"]
unique_name_in_owner = true
layout_mode = 2
theme_override_colors/font_color = Color(0.45, 1, 0.9, 1)
theme_override_font_sizes/font_size = 13
text = "Lv 1"

[node name="XpBar" type="ProgressBar" parent="HeroPanel/Margin/Rows/XpRow"]
unique_name_in_owner = true
custom_minimum_size = Vector2(0, 8)
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 4
max_value = 8.0
show_percentage = false
theme_override_styles/fill = SubResource("StyleBoxFlat_xp")

[node name="XpText" type="Label" parent="HeroPanel/Margin/Rows/XpRow"]
unique_name_in_owner = true
layout_mode = 2
theme_override_font_sizes/font_size = 12
text = "0 / 8 XP"
```
  plus a sub_resource near the other sub_resources: `[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_xp"]` with `bg_color = Color(0.3, 0.95, 0.85, 1)`. (Nodes must be appended where their parent already exists: put them right after the `StatsText` node block.)
  `hud.gd`: add `@onready var level_text: Label = %LevelText`, `@onready var xp_bar: ProgressBar = %XpBar`, `@onready var xp_text: Label = %XpText`, and
```gdscript
func bind_run_cards(cards: RunCards) -> void:
	var update := func() -> void:
		var needed := RunCards.xp_for_level(cards.level)
		level_text.text = "Lv %d" % cards.level
		xp_bar.max_value = needed
		xp_bar.value = cards.xp
		xp_text.text = "%d / %d XP" % [cards.xp, needed]
	cards.xp_changed.connect(update)
	update.call()
```
- [ ] **Step 7: Verify.** Import, `validate_scripts`, both test scripts, run the game, Play, `break_left = 99999`, eval:
  - **Drops:** spawn a goblin beside the hero (frozen) and kill it: within 2 frames an `XpOrb` (amount 1) is in `world.units`; with the hero next to it, it's collected: `run_cards.xp == 1`, HUD reads "Lv 1" and "1 / 8 XP". Kill an Armored Goblin: its orb is worth 3.
  - **Pull radius:** an orb 200 px away doesn't move over 30 frames; at 120 px it reaches the hero.
  - **Level up signal:** collecting 8 XP worth (spawn and kill 8 goblins next to the hero, or set orbs) makes `run_cards.level == 2` and the HUD "Lv 2 · 0 / 12 XP". (No pick screen yet — that's Task 3; if one level-up pauses something, it's a bug.)
  - **Lodestone:** call `Lodestone.drop(world.units, hero.global_position + Vector2(300, 0))` and drop 10 orbs (`XpOrb.drop`) scattered ≥ 600 px from the hero; teleport the hero next to the Lodestone: within 1.5 s all 10 orbs are collected (`xp` rose by their sum) and the Lodestone is gone.
  - **Only one at a time:** with a Lodestone already on the map, spawn and kill 200 goblins far from the hero (call `world._on_enemy_killed(goblin)` path by killing them): the `lodestones` group never holds more than 1.
  - **Review Focus 2:** start a Lodestone rush with orbs far away, kill the hero (`hero.health.take_damage(999999)`) mid-rush: orbs stop moving; `hero.revive(core position)`: they reach the hero and `xp` includes them.
  - **Review Focus 5:** drop 300 orbs scattered around the map (not near the hero); measure `Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)` averaged over 60 frames: < 8 ms. If not, cache the hero lookup in the orb (`_hero` resolved once and reused while valid).
  - Screenshot an orb and a Lodestone on the grass.
  - Clean up; stop; clean `project.godot`.
- [ ] **Step 8: Commit** `Drop XP orbs and Lodestones; show XP in the HUD`.

---

### Task 3: The card pick screen

**Files:** Create `scripts/ui/card_menu.gd`, `scenes/ui/card_menu.tscn`, `scripts/ui/power_card.gd`, `scenes/ui/power_card.tscn`. Modify `scenes/world.tscn`, `scripts/world.gd`.

**Interfaces:**
- Consumes: `RunCards` (`leveled_up`, `offer`, `take`, `rank_of`, `level`, `ended`, `end_run`) (Task 1); `World.run_cards` (Task 2).
- Produces: `class_name CardMenu extends CanvasLayer` (`pending: int`, `is_open() -> bool`, `pick(index: int)`); `class_name PowerCard extends PanelContainer` (`signal chosen`, `show_card(card: CardDefinition, next_rank: int, key: int)`, `card: CardDefinition`); node `UI/CardMenu`.

- [ ] **Step 1: Failing check.** `test -f scenes/ui/card_menu.tscn` → missing.
- [ ] **Step 2: PowerCard.** `scripts/ui/power_card.gd`:
```gdscript
class_name PowerCard
extends PanelContainer
## One choice on the level-up screen: category, title, what it does, the
## rank it would reach, and its number key.

signal chosen

const CATEGORY_COLORS := {
	"Hero": Color(1.0, 0.82, 0.45), "Towers": Color(0.55, 0.75, 1.0),
	"Fortress": Color(0.55, 0.9, 0.6)}

var card: CardDefinition

@onready var category_label: Label = %Category
@onready var title_label: Label = %Title
@onready var description_label: Label = %Description
@onready var rank_label: Label = %Rank
@onready var choose_button: Button = %Choose


func _ready() -> void:
	choose_button.pressed.connect(chosen.emit)


func show_card(card_definition: CardDefinition, next_rank: int, key: int) -> void:
	card = card_definition
	category_label.text = card.category.to_upper()
	category_label.add_theme_color_override(&"font_color",
			CATEGORY_COLORS.get(card.category, Color.WHITE))
	title_label.text = card.title
	description_label.text = card.description
	rank_label.text = "Rank %d / %d" % [next_rank, card.max_rank]
	choose_button.text = "Choose  [%d]" % key


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit()
		accept_event()
```
  `scenes/ui/power_card.tscn`:
```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/ui/power_card.gd" id="1_card"]

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_card"]
bg_color = Color(0.16, 0.17, 0.21, 1)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.85, 0.68, 0.35, 0.6)
corner_radius_top_left = 6
corner_radius_top_right = 6
corner_radius_bottom_right = 6
corner_radius_bottom_left = 6

[node name="PowerCard" type="PanelContainer"]
custom_minimum_size = Vector2(220, 230)
mouse_filter = 0
theme_override_styles/panel = SubResource("StyleBoxFlat_card")
script = ExtResource("1_card")

[node name="Margin" type="MarginContainer" parent="."]
layout_mode = 2
mouse_filter = 2
theme_override_constants/margin_left = 14
theme_override_constants/margin_top = 12
theme_override_constants/margin_right = 14
theme_override_constants/margin_bottom = 12

[node name="Rows" type="VBoxContainer" parent="Margin"]
layout_mode = 2
mouse_filter = 2
theme_override_constants/separation = 8

[node name="Category" type="Label" parent="Margin/Rows"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 2
theme_override_font_sizes/font_size = 12
text = "HERO"

[node name="Title" type="Label" parent="Margin/Rows"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 2
theme_override_colors/font_color = Color(1, 0.92, 0.6, 1)
theme_override_font_sizes/font_size = 20
text = "Sharpened Bolts"
autowrap_mode = 3

[node name="Description" type="Label" parent="Margin/Rows"]
unique_name_in_owner = true
custom_minimum_size = Vector2(190, 70)
layout_mode = 2
size_flags_vertical = 3
mouse_filter = 2
theme_override_font_sizes/font_size = 15
text = "+20% hero damage."
autowrap_mode = 3

[node name="Rank" type="Label" parent="Margin/Rows"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 2
theme_override_colors/font_color = Color(0.75, 0.9, 1, 1)
theme_override_font_sizes/font_size = 13
text = "Rank 1 / 5"

[node name="Choose" type="Button" parent="Margin/Rows"]
unique_name_in_owner = true
custom_minimum_size = Vector2(0, 36)
layout_mode = 2
text = "Choose  [1]"
```
- [ ] **Step 3: CardMenu.** `scripts/ui/card_menu.gd`:
```gdscript
class_name CardMenu
extends CanvasLayer
## The level-up screen: pauses the game and offers 3 cards; click one or
## press 1-3. Several level-ups show back to back. A pick is required (Esc
## does nothing). Never opens once the run is over.

const CARD_SCENE := preload("res://scenes/ui/power_card.tscn")

## Level-ups still waiting for a pick (not counting the one on screen).
var pending := 0

var _cards: RunCards
var _shown: Array[PowerCard] = []

@onready var title: Label = %Title
@onready var row: HBoxContainer = %Cards


func _ready() -> void:
	visible = false
	_cards = get_tree().get_first_node_in_group(&"run_cards") as RunCards
	if _cards:
		_cards.leveled_up.connect(_on_leveled_up)


func is_open() -> bool:
	return visible


## Takes the card at `index` (0-2) of the current offer.
func pick(index: int) -> void:
	if not visible or index < 0 or index >= _shown.size():
		return
	_cards.take(_shown[index].card)
	_show_next()


func _on_leveled_up(_new_level: int) -> void:
	if _cards.ended:
		return
	pending += 1
	if not visible:
		_show_next()


func _show_next() -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	_shown.clear()
	while pending > 0 and not _cards.ended:
		var offer := _cards.offer(3)
		if offer.is_empty():
			pending = 0
			break
		pending -= 1
		title.text = "Level %d — choose a card" % (_cards.level - pending)
		for i in offer.size():
			var power_card: PowerCard = CARD_SCENE.instantiate()
			row.add_child(power_card)
			power_card.show_card(offer[i], _cards.rank_of(offer[i]) + 1, i + 1)
			power_card.chosen.connect(pick.bind(i))
			_shown.append(power_card)
		visible = true
		get_tree().paused = true
		_shown[0].choose_button.grab_focus()
		return
	if visible:
		visible = false
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = event.physical_keycode - KEY_1
		if index >= 0 and index < _shown.size():
			pick(index)
	# The pick is required: swallow everything else (Esc included).
	get_viewport().set_input_as_handled()
```
  `scenes/ui/card_menu.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/card_menu.gd" id="1_menu"]

[node name="CardMenu" type="CanvasLayer"]
process_mode = 3
layer = 5
script = ExtResource("1_menu")

[node name="Dim" type="ColorRect" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0, 0, 0, 0.6)

[node name="Center" type="CenterContainer" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Rows" type="VBoxContainer" parent="Center"]
layout_mode = 2
theme_override_constants/separation = 18

[node name="Title" type="Label" parent="Center/Rows"]
unique_name_in_owner = true
layout_mode = 2
theme_override_colors/font_color = Color(0.45, 1, 0.9, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 6
theme_override_font_sizes/font_size = 30
text = "Level 2 — choose a card"
horizontal_alignment = 1

[node name="Cards" type="HBoxContainer" parent="Center/Rows"]
unique_name_in_owner = true
layout_mode = 2
alignment = 1
theme_override_constants/separation = 18
```
- [ ] **Step 4: Wire it.** `world.tscn`: add `[ext_resource type="PackedScene" path="res://scenes/ui/card_menu.tscn" id="23_card_menu"]` and `[node name="CardMenu" parent="UI" instance=ExtResource("23_card_menu")]` after the `CodexToast` node. Note the CardMenu's `_ready` finds `run_cards` by group: the `RunCards` node must come **before** `UI` in the tree (it does: it's placed after `WaveDirector`). `world.gd`: in `_on_core_destroyed()` and `_on_run_won()` call `run_cards.end_run()` first (before showing the end screen).
- [ ] **Step 5: Verify.** Import, both test scripts, run the game, Play, `break_left = 99999`, eval:
  - **Opens:** `run_cards.add_xp(8)`: within 1 frame `UI/CardMenu` visible, `get_tree().paused` true, title "Level 2 — choose a card", 3 `PowerCard`s with distinct titles, each "Rank 1 / max". Screenshot.
  - **Pick by key:** parse a pressed `KEY_2`: the middle card's id has rank 1 in `run_cards.ranks`; menu closed; unpaused.
  - **Pick by click:** `add_xp(12)` → menu; emit the first card's `chosen` → its rank +1, closed.
  - **Queue:** `add_xp(18 + 27 + 3)` (two levels): first title "Level 4 — choose a card", after a pick "Level 5 — choose a card", after the second pick closed and unpaused.
  - **Esc does nothing:** with the menu open, parse Esc: still open, pause menu not visible.
  - **Review Focus 1:** with the menu closed, `world.core.health.take_damage(999999)`; then `run_cards.add_xp(500)`: Game Over visible, CardMenu not visible, `pending == 0`. Restart (`game_over.restart()`), Play-state: new `run_cards.level == 1`, xp 0. Also: open a pick, then (via eval, bypassing pause) call `world._on_run_won()`: `ended` true; picking still closes cleanly and Game Over/Win stays on top (layer 10 > 5).
  - Stop; clean `project.godot`.
- [ ] **Step 6: Commit** `Add the level-up card pick screen`.

---

### Task 4: Stat card effects

**Files:** Modify `scripts/heroes/hero.gd`, `scripts/towers/tower.gd`, `scripts/structures/wall.gd`, `scripts/structures/command_core.gd`, `scripts/world.gd`.

**Interfaces:**
- Consumes: `RunCards.multiplier(node, stat)`, `RunCards.changed` (Task 1); `World.run_cards` (Task 2).
- Produces: `Hero.rebuild_stats()`; `Tower.refresh_max_health()`; `Wall.refresh_max_health()`; `CommandCore.refresh_max_health()`.

- [ ] **Step 1: Failing check.** Run the game, Play, eval: note `hero.stats.attack_damage` (10), take Sharpened Bolts (`run_cards.take(card with id sharpened_bolts)`), read it again. Expected: still 10 (no effect yet). Stop.
- [ ] **Step 2: Hero.** In `hero.gd`, replace the body of `add_rank()` after its first line with a call, and add `rebuild_stats()`:
```gdscript
func add_rank(upgrade: HeroUpgrade) -> void:
	upgrade_ranks[upgrade.id] = rank_of(upgrade) + 1
	rebuild_stats()


## Stats = base × Core upgrades × power-up cards. Extra max health is added
## on top of the current health.
func rebuild_stats() -> void:
	stats = base_stats.duplicate()
	for owned in definition.upgrades:
		var rank := rank_of(owned)
		if rank > 0:
			stats.set(owned.stat, base_stats.get(owned.stat) * owned.multiplier(rank))
	stats.attack_damage *= RunCards.multiplier(self, &"hero_damage")
	stats.attacks_per_second *= RunCards.multiplier(self, &"hero_fire_rate")
	stats.move_speed *= RunCards.multiplier(self, &"hero_move_speed")
	stats.max_health *= RunCards.multiplier(self, &"hero_max_health")
	if not is_equal_approx(stats.max_health, health.max_health):
		health.grow_max(stats.max_health)
	stats_changed.emit()
```
  Keep the `add_rank` doc comment. At the end of `_ready()` add:
```gdscript
	var cards := get_tree().get_first_node_in_group(&"run_cards") as RunCards
	if cards:
		cards.changed.connect(rebuild_stats)
```
- [ ] **Step 3: Towers.** In `tower.gd`: `damage()` → `return value * RunCards.multiplier(self, &"tower_damage")` (replace its final `return value`); `fire_rate()` → `* RunCards.multiplier(self, &"tower_fire_rate")`; `attack_range()` → `* RunCards.multiplier(self, &"tower_range")`. In `_ready()` `health.reset(definition.max_health_at(level))` → `health.reset(_max_health())`; in `set_level()` `health.grow_max(definition.max_health_at(level))` → `health.grow_max(_max_health())`; add:
```gdscript
## This level's max health with Reinforced Plating.
func _max_health() -> float:
	return definition.max_health_at(level) * RunCards.multiplier(self, &"structure_health")


## Re-applies card bonuses to max health (adds the difference to current).
func refresh_max_health() -> void:
	if not health.is_dead and not is_equal_approx(health.max_health, _max_health()):
		health.grow_max(_max_health())
```
- [ ] **Step 4: Walls.** In `wall.gd` `_ready()`: `health.reset(max_health)` → `health.reset(max_health * RunCards.multiplier(self, &"structure_health"))`; in `restyle()`: `health.grow_max(new_max)` → `health.grow_max(new_max * RunCards.multiplier(self, &"structure_health"))`; add:
```gdscript
## Re-applies card bonuses to max health (adds the difference to current).
func refresh_max_health() -> void:
	var target := max_health * RunCards.multiplier(self, &"structure_health")
	if not health.is_dead and not is_equal_approx(health.max_health, target):
		health.grow_max(target)
```
- [ ] **Step 5: Core.** In `command_core.gd` add:
```gdscript
## Re-applies Core Plating to max health (adds the difference to current).
func refresh_max_health() -> void:
	var target := max_health * RunCards.multiplier(self, &"core_max_health")
	if not health.is_dead and not is_equal_approx(health.max_health, target):
		health.grow_max(target)
```
  In `world.gd` `_ready()`, after `hud.bind_run_cards(run_cards)`:
```gdscript
	run_cards.changed.connect(_on_cards_changed)
```
  and add:
```gdscript
## A card was taken: re-apply max-health bonuses to everything built.
func _on_cards_changed() -> void:
	core.refresh_max_health()
	get_tree().call_group(&"breakables", &"refresh_max_health")
```
- [ ] **Step 6: Verify.** Import, both test scripts, run the game, Play, `break_left = 99999`, eval (helper: `func card(id)` = the pool entry with that id):
  - **Hero:** Sharpened Bolts ×2 → `hero.stats.attack_damage == 14`; a hero bolt fired at a frozen goblin deals 14. Quick Trigger ×1 → `attacks_per_second == 1.15`. Fleet Foot ×1 → `move_speed == 242`. Thick Hide ×1 at full health 90 → max 108, current 108.
  - **Review Focus 3:** damage the hero to 50/108, take Thick Hide again → max ≈ 126, current ≈ 68. Damage the Core to 300/500, take Core Plating → max 600, current 400. Build a Gearshot and damage it to half; take Reinforced Plating → its max ×1.25 and the difference added; a wall piece too; a destroyed wall (`take_damage(999999)` first) stays dead.
  - **Review Focus 4:** with Sharpened Bolts ×2, buy one Damage rank at the Core (`hero.add_rank(damage upgrade)`): `attack_damage == 10 × 1.2 × 1.4 = 16.8`; take another Sharpened Bolts: 10 × 1.2 × 1.6 = 19.2. Calibrated Barrels ×1 on a built Gearshot (Lv1, 8 damage): `damage() == 9.2`; while operated (`hero.start_operating(tower)`): `8 × 1.35 × 1.15 = 12.42`.
  - Oiled Gears / Long Sight: `fire_rate()` ×1.1, `attack_range()` ×1.1 (also on an Embercaster's `attack_range()`).
  - **Salvager:** ×1 then kill 20 goblins next to the hero: every Scrap drop ≥ the normal 1–2, and the total is higher than 20 × 1.5 on average (log the amounts).
  - **Wide Pull:** ×1: a Scrap pickup 90 px away (normally 70) moves toward the hero; an orb at 190 px (normally 140) moves.
  - Stop; clean `project.godot`.
- [ ] **Step 7: Commit** `Apply stat cards to the hero, towers, walls, Core, Scrap and pull`.

---

### Task 5: Hero mod cards, web check and roadmap

**Files:** Modify `scripts/projectiles/projectile.gd`, `scripts/heroes/hero.gd`, `ROADMAP.md`.

**Interfaces:**
- Consumes: `RunCards.mod_rank()` (Task 1); `LightningArc` (`points`, `burst`), `Enemy.add_burn(dps, max_stacks, seconds, stacks)`.
- Produces: `Projectile.struck(target: Node)` signal; `Hero.ARC_RANGE := 120.0`, `Hero.SPLIT_ANGLE := 12.0`.

- [ ] **Step 1: Failing check.** Run the game, Play, take Split Shot; call `hero._fire()` once and count new `HeroBolt` nodes. Expected: 1. Stop.
- [ ] **Step 2: Projectile.** In `projectile.gd` add below the `hit` signal:
```gdscript
## Emitted with the node that owns the Health it damaged (e.g. the Enemy).
signal struck(target: Node)
```
  and in `_on_hit`, right after `var dealt := health.take_damage(damage, damage_type)`: `struck.emit(health.get_parent())`.
- [ ] **Step 3: Hero mods.** In `hero.gd`:
  - Add constants after `BOLT_SCENE`:
```gdscript
const ARC_SCENE := preload("res://scenes/projectiles/lightning_arc.tscn")
## Arc Bolts: how far lightning can jump from one enemy to the next, in pixels.
const ARC_RANGE := 120.0
## Split Shot: degrees between neighbouring bolts.
const SPLIT_ANGLE := 12.0
```
  - `_fire()` becomes:
```gdscript
func _fire() -> void:
	var aim := get_global_mouse_position() - muzzle.global_position
	if aim.is_zero_approx():
		aim = Vector2.LEFT if _facing_left else Vector2.RIGHT
	var split := _mod_rank(&"split_shot")
	for i in range(-split, split + 1):
		var bolt: Projectile = BOLT_SCENE.instantiate()
		bolt.global_position = muzzle.global_position
		bolt.direction = aim.normalized().rotated(deg_to_rad(SPLIT_ANGLE * i))
		bolt.speed = stats.projectile_speed
		bolt.damage = stats.attack_damage
		bolt.max_distance = stats.attack_range
		bolt.struck.connect(_on_bolt_struck.bind(bolt.damage))
		get_parent().add_child(bolt)


func _mod_rank(mod: StringName) -> int:
	var cards := get_tree().get_first_node_in_group(&"run_cards") as RunCards
	return cards.mod_rank(mod) if cards else 0


## Ember Rounds burns the enemy hit; Arc Bolts chains lightning from it.
func _on_bolt_struck(target: Node, bolt_damage: float) -> void:
	var enemy := target as Enemy
	if enemy == null:
		return
	var embers := _mod_rank(&"ember_rounds")
	if embers > 0 and not enemy.health.is_dead:
		enemy.add_burn(2.0, 5, 3.0, embers)
	var jumps := _mod_rank(&"arc_bolts")
	if jumps > 0:
		_chain_lightning(enemy, jumps, bolt_damage * 0.5)


## Lightning from `from` to up to `jumps` more enemies, each the nearest
## living one within ARC_RANGE of the last, never the same one twice.
func _chain_lightning(from: Enemy, jumps: int, arc_damage: float) -> void:
	var hit: Array[Enemy] = [from]
	var points := PackedVector2Array([from.hurtbox_shape.global_position])
	var last := from
	for i in jumps:
		var next: Enemy = null
		var best := ARC_RANGE
		for node in get_tree().get_nodes_in_group(&"enemies"):
			var other := node as Enemy
			if other in hit or other.health.is_dead:
				continue
			var distance := last.global_position.distance_to(other.global_position)
			if distance <= best:
				next = other
				best = distance
		if next == null:
			break
		next.health.take_damage(arc_damage, Health.DamageType.MAGIC)
		hit.append(next)
		points.append(next.hurtbox_shape.global_position)
		last = next
	if points.size() < 2:
		return
	var arc: LightningArc = ARC_SCENE.instantiate()
	arc.points = points
	get_parent().add_child(arc)
```
- [ ] **Step 4: Verify.** Import, both test scripts, run the game, Play, `break_left = 99999`, hero facing right, mouse warped to the right of the hero, eval:
  - **Split Shot:** ×1 → `hero._fire()` spawns 3 `HeroBolt`s with directions at −12°, 0°, +12° from the aim; ×2 → 5 bolts (±24°).
  - **Arc Bolts:** ×1: two frozen goblins A (in the bolt's path, 200 px right) and B (80 px from A, off the path), C (300 px from A). Fire one bolt: A takes 10 physical; B takes 5 magic (`health.damaged` records); C untouched; a `LightningArc` appears in `units`. ×3 with 4 goblins spaced 100 px in a line from A: the chain reaches 3 more. Screenshot an arc.
  - **Ember Rounds:** ×2: a bolt hit leaves `A.burn_stacks() == 2` (and burning damage over 1 s).
  - **No mods:** a run without cards fires 1 bolt and connects `struck` without errors.
  - Stop; clean `project.godot`.
- [ ] **Step 5: Web check.** Export (`mkdir -p export/web && godot --headless --export-release "Web" export/web/index.html`), serve, Playwright headless Chromium (as before): main menu → Play (y≈321 on web) → hold A to the west edge, Enter to start wave 1, wait ~30 s with auto-fire on so goblins die near the hero and orbs get collected; screenshot shows the HUD "Lv"/XP row with XP > 0; if a level-up happens the card screen shows (screenshot it, press 1). No console errors. Kill the server by PID; `rm -rf export`.
- [ ] **Step 6: Roadmap.** Phase 10: replace `- [ ] **[AI]** Player XP earned during a run — **[You]** decide how it's earned (kills, damage, waves survived)` with `- [x] **[AI]** Player XP: enemies drop XP orbs (Goblin 1, Shaman 3, Armored 3) you pick up; levels cost 8 × 1.5^(level−1); a rare Lodestone (3%) pulls every orb on the map to you` and `- [ ] **[AI]** Power-up cards: after waves, pick 1 of 3 cards that make you stronger for the run (chain-lightning shots, flamethrower, and similar)` with `- [x] **[AI]** Power-up cards: each level-up pauses and offers 3 of 14 run-long cards (hero / tower / fortress stats; Arc Bolts, Split Shot, Ember Rounds hero mods); data in `data/cards/``.
- [ ] **Step 7: Commit** `Add Arc Bolts, Split Shot and Ember Rounds; tick XP and cards on the roadmap`.
