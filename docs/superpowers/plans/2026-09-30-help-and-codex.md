# Help and Codex Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Help screen (Towers tab with descriptions, costs and upgrade bonuses; Codex tab with number-free enemy entries) reachable from the main and pause menus, plus a `Codex` that unlocks enemies the first time one comes on screen, saved across runs, with a "New Codex entry" notice.

**Architecture:** Text lives in the tower/enemy data files (new Help / Codex export groups); a static `HelpText` helper turns data into display text (numbers for towers, word ratings for enemies) and is covered by a headless test script. A `Codex` autoload tracks and saves sightings; enemies report themselves via a `VisibleOnScreenNotifier2D`; a `CodexToast` layer shows notices. `HelpMenu` is one overlay instanced by the main menu and the pause menu.

**Tech Stack:** Godot 4.7 GDScript; `ConfigFile`, `ResourceLoader.list_directory`, `VisibleOnScreenNotifier2D`, `RichTextLabel` (BBCode); a headless test script (`godot --headless --script`) plus the Godot MCP tools in the running game.

**Spec:** `docs/superpowers/specs/2026-09-30-help-and-codex-design.md`

## Global Constraints

- Tower order: Gearshot Turret, Rune Mortar, Embercaster, Aether Spire (`res://data/towers/{gearshot,rune_mortar,embercaster,aether_spire}.tres`).
- Tower detail: description; "Damage:"; "Good against:"; "Weak against:"; "Ability (while operated): {name} — {ability_text} (Cooldown: {n} s)"; "Operated: +35% damage, +50% fire rate, +15% range" (percent = round((m − 1) × 100), multipliers of 1 left out); "Upgrade path": "Lv1 — Build: 10 Scrap", "Lv2 — 15 Scrap: +30% damage, +15% fire rate, +10% range, +40% health", "Lv3 — 25 Scrap + 3 Aether: … (again)". Costs list Scrap first, joined with " + ".
- Enemy ratings vs the Goblin: ratio < 0.8 Low; ≤ 1.5 Average; ≤ 2.5 High; else Very high. Health = max_health, Speed = move_speed, Hits = attack_damage × attacks_per_second. Glance line: "Health: X · Speed: Y · Hits: Z".
- Resistances: taken ≤ 0.5 → "Shrugs off {Type} damage"; 0.5 < taken < 1 → "Resists {Type} damage"; if any type is below 1 and not all equal, the highest-taken type(s) → "Weak to {A}" / "Weak to {A} and {B}". Types in order Physical, Fire, Magic.
- Unseen enemies: black silhouette icon, name "???", detail "Not yet encountered."
- Codex save: `user://codex.cfg`, section `[seen]`, key = enemy id, value `true`; missing/broken/non-bool → not seen; never errors. Separate from `settings.cfg`.
- Notice: "New Codex entry: {name}" + smaller "Esc → Help to read it"; ~3 s, fade in/out; queued; layer 5; never blocks mouse input.
- Help look: same as Options (black 60% dim; solid dark panel `Color(0.09, 0.08, 0.11, 0.96)`, 2 px gold border `Color(0.85, 0.68, 0.35)`, radius 6); ≈900×560; tabs Towers / Codex; Back; Escape closes Help only.
- Main menu: Play / Options / Help / Quit (Quit hidden on web). Pause menu: Help enabled.
- Branch `feature/help-codex`; one commit per task (`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`); stage only the task's files. New `class_name`/autoload → `godot --headless --editor --path . --import` before checks.
- MCP: first `game_eval` after `run_project` says "Not connected" (retry; if the bridge isn't in `[autoload]`, stop, clean, run again). After `stop_project`, strip only the bridge's blank lines / autoload from `project.godot`. Evals: untyped `=` not `:=`, finish within ~25 s, disconnect any lambdas connected. Start scene is the main menu: `get_tree().current_scene.play_button.pressed.emit()` then await 4 frames for the map; `world.waves.break_left = 99999.0` holds wave 1. Delete `user://codex.cfg` and `user://settings.cfg` at the end of tests.

## Review Focus

1. **An enemy that spawns already inside the camera view** (spawn point on screen) is still discovered — `screen_entered` fires for it — and exactly one notice shows (Task 2 test).
2. **The notice never blocks clicks**: while it shows, clicking the HUD / map / a build slot still works (its controls ignore the mouse) (Task 2 test).
3. **Codex list in the exported web build**: `list_directory` still finds all three enemies when files are remapped (Task 4 web test).
4. **Help reopened after a new sighting** shows the new entry unlocked (the list is rebuilt on every open) (Task 3 test).
5. **A `codex.cfg` with an unknown id or a non-bool value**: unknown ids don't break the list, non-bool values count as unseen, no errors (Task 2 test).

---

### Task 1: Help text in the data, and the HelpText helper

**Files:** Modify `scripts/towers/tower_definition.gd`, `scripts/enemies/enemy_definition.gd`, `data/towers/gearshot.tres`, `data/towers/rune_mortar.tres`, `data/towers/embercaster.tres`, `data/towers/aether_spire.tres`, `data/enemies/goblin.tres`, `data/enemies/armored_goblin.tres`, `data/enemies/goblin_shaman.tres`, `export_presets.cfg`. Create `scripts/ui/help_text.gd`, `tests/test_help_text.gd`.

**Interfaces:**
- Consumes: `Loot.display_name(type: StringName) -> String`; existing tower/enemy fields.
- Produces: `TowerDefinition.damage_type_label`, `.good_against`, `.weak_against`, `.ability_text` (String); `EnemyDefinition.codex_summary: String`, `.codex_strengths: PackedStringArray`, `.codex_weaknesses: PackedStringArray`, `.codex_tip: String`; `class_name HelpText` with static `percent(m: float) -> String`, `cost_text(cost: Dictionary) -> String`, `operated_line(t: TowerDefinition) -> String`, `upgrade_lines(t: TowerDefinition) -> PackedStringArray`, `tower_bbcode(t: TowerDefinition) -> String`, `rating(value: float, base: float) -> String`, `glance(e: EnemyDefinition, base: EnemyDefinition) -> String`, `resistance_strengths(e) -> PackedStringArray`, `resistance_weaknesses(e) -> PackedStringArray`, `enemy_bbcode(e: EnemyDefinition, base: EnemyDefinition) -> String`. Test command: `godot --headless --path . --script tests/test_help_text.gd`.

- [ ] **Step 1: Write the failing test** `tests/test_help_text.gd`:
```gdscript
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
	print("help_text: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(label: String, got: Variant, want: Variant) -> void:
	if got == want:
		passed += 1
	else:
		failed += 1
		print("FAIL %s: got %s, want %s" % [label, got, want])
```
- [ ] **Step 2: Run it.** `godot --headless --path . --script tests/test_help_text.gd`. Expected: prints `FAIL: scripts/ui/help_text.gd missing`, exit code 1.
- [ ] **Step 3: Data fields.** `tower_definition.gd`, after the Ability group's fields (before `@export_group("Rotating head")`):
```gdscript
@export_group("Help")
## Shown in the Help screen; the damage type itself is set in each tower's code.
@export var damage_type_label := "Physical"
## One short line each for the Help screen.
@export var good_against := ""
@export var weak_against := ""
## What the ability does, in words.
@export var ability_text := ""
```
`enemy_definition.gd`, at the end:
```gdscript
@export_group("Codex")
## One line saying what this enemy is.
@export var codex_summary := ""
## Hand-written lines, shown after the ones worked out from resistances.
@export var codex_strengths: PackedStringArray = []
@export var codex_weaknesses: PackedStringArray = []
@export var codex_tip := ""
```
- [ ] **Step 4: Fill in the text.** Add these lines to each `.tres` `[resource]` block (after `description` for towers; at the end for enemies):
  - `gearshot.tres`: `damage_type_label = "Physical"`, `good_against = "Swarms of basic goblins"`, `weak_against = "Armour (bullets glance off)"`, `ability_text = "Triples the fire rate for 3 s."`
  - `rune_mortar.tres`: `damage_type_label = "Magic"`, `good_against = "Tight groups and armour, far away"`, `weak_against = "Anything right next to it (can't fire that close)"`, `ability_text = "Fires a double-strength shell that leaves a slowing rune circle for 4 s."`
  - `embercaster.tres`: `damage_type_label = "Fire"`, `good_against = "Crowds at close range; burning finishes them off"`, `weak_against = "Long range; it has to refuel"`, `ability_text = "3 s of free fuel, a wider cone and maximum burn."`
  - `aether_spire.tres`: `damage_type_label = "Magic"`, `good_against = "Spread-out groups and armour"`, `weak_against = "Lone tough enemies (the chain has nothing to jump to)"`, `ability_text = "Double-strength lightning that jumps 8 times without weakening and stuns for 1 s."`
  - `goblin.tres`:
```
codex_summary = "The basic raider: comes in numbers and goes for the Core."
codex_strengths = PackedStringArray("Arrives in large groups")
codex_weaknesses = PackedStringArray("Fragile on its own")
codex_tip = "Gearshots and the hero's bolts handle them well."
```
  - `armored_goblin.tres`:
```
codex_summary = "A heavy brute in padded armour with a cleaver."
codex_strengths = PackedStringArray("Hits hard up close", "Takes a beating")
codex_weaknesses = PackedStringArray("Slow on its feet")
codex_tip = "Bring magic: a Rune Mortar or Aether Spire cuts right through."
```
  - `goblin_shaman.tres`:
```
codex_summary = "A caster that hangs back, throws magic orbs and drives nearby goblins into a frenzy."
codex_strengths = PackedStringArray("Makes nearby goblins faster and deadlier", "Attacks from range", "Walls don't stop it casting")
codex_weaknesses = PackedStringArray("Frail", "Stuns and kills interrupt its frenzy")
codex_tip = "Kill it first — frenzied packs break walls quickly."
```
- [ ] **Step 5: HelpText** `scripts/ui/help_text.gd`:
```gdscript
class_name HelpText
extends RefCounted
## Words for the Help screen, built from tower and enemy data: numbers for
## towers (costs and bonuses), word ratings for enemies (no numbers).

const TYPES: Array[String] = ["Physical", "Fire", "Magic"]


## 1.3 -> "+30%".
static func percent(multiplier: float) -> String:
	return "+%d%%" % roundi((multiplier - 1.0) * 100.0)


## {"aether": 3, "scrap": 25} -> "25 Scrap + 3 Aether" (Scrap first).
static func cost_text(cost: Dictionary) -> String:
	var types: Array = cost.keys()
	types.sort_custom(func(a: StringName, b: StringName) -> bool:
		return (0 if a == &"scrap" else 1) < (0 if b == &"scrap" else 1))
	var parts: PackedStringArray = []
	for type in types:
		parts.append("%d %s" % [cost[type], Loot.display_name(type)])
	return " + ".join(parts) if not parts.is_empty() else "Free"


## "+35% damage, +50% fire rate, +15% range"; multipliers of 1 are left out.
static func operated_line(t: TowerDefinition) -> String:
	return _bonuses([[t.operated_damage_multiplier, "damage"],
			[t.operated_fire_rate_multiplier, "fire rate"],
			[t.operated_range_multiplier, "range"]])


static func upgrade_lines(t: TowerDefinition) -> PackedStringArray:
	var bonus := _bonuses([[t.level_damage_multiplier, "damage"],
			[t.level_fire_rate_multiplier, "fire rate"],
			[t.level_range_multiplier, "range"],
			[t.level_health_multiplier, "health"]])
	return PackedStringArray([
		"Lv1 — Build: %s" % cost_text(t.cost),
		"Lv2 — %s: %s" % [cost_text(t.lv2_cost), bonus],
		"Lv3 — %s: %s (again)" % [cost_text(t.lv3_cost), bonus],
	])


static func tower_bbcode(t: TowerDefinition) -> String:
	var lines: PackedStringArray = [t.description, ""]
	lines.append("[b]Damage:[/b] " + t.damage_type_label)
	lines.append("[b]Good against:[/b] " + t.good_against)
	lines.append("[b]Weak against:[/b] " + t.weak_against)
	lines.append("")
	lines.append("[b]Ability (while operated):[/b] %s — %s (Cooldown: %s s)" % [
			t.ability_name, t.ability_text, _number(t.ability_cooldown)])
	var operated := operated_line(t)
	if operated != "":
		lines.append("[b]Operated:[/b] " + operated)
	lines.append("")
	lines.append("[b]Upgrade path[/b]")
	for line in upgrade_lines(t):
		lines.append("  " + line)
	return "\n".join(lines)


## `value` compared with `base`: "Low", "Average", "High" or "Very high".
static func rating(value: float, base: float) -> String:
	var ratio := value / base if base > 0.0 else 1.0
	if ratio < 0.8:
		return "Low"
	if ratio <= 1.5:
		return "Average"
	if ratio <= 2.5:
		return "High"
	return "Very high"


## "Health: High · Speed: Low · Hits: Average", compared with `base`.
static func glance(e: EnemyDefinition, base: EnemyDefinition) -> String:
	return "Health: %s · Speed: %s · Hits: %s" % [
		rating(e.max_health, base.max_health),
		rating(e.move_speed, base.move_speed),
		rating(e.attack_damage * e.attacks_per_second, base.attack_damage * base.attacks_per_second),
	]


static func resistance_strengths(e: EnemyDefinition) -> PackedStringArray:
	var lines: PackedStringArray = []
	var taken := _taken(e)
	for i in TYPES.size():
		if taken[i] <= 0.5:
			lines.append("Shrugs off %s damage" % TYPES[i])
		elif taken[i] < 1.0:
			lines.append("Resists %s damage" % TYPES[i])
	return lines


static func resistance_weaknesses(e: EnemyDefinition) -> PackedStringArray:
	var taken := _taken(e)
	var lowest: float = taken.min()
	var highest: float = taken.max()
	if lowest >= 1.0 or is_equal_approx(lowest, highest):
		return PackedStringArray()
	var weak: PackedStringArray = []
	for i in TYPES.size():
		if is_equal_approx(taken[i], highest):
			weak.append(TYPES[i])
	return PackedStringArray(["Weak to " + " and ".join(weak)])


static func enemy_bbcode(e: EnemyDefinition, base: EnemyDefinition) -> String:
	var lines: PackedStringArray = [e.codex_summary, ""]
	lines.append("[b]At a glance:[/b] " + glance(e, base))
	var strengths := resistance_strengths(e) + e.codex_strengths
	if not strengths.is_empty():
		lines.append("")
		lines.append("[b]Strengths[/b]")
		for line in strengths:
			lines.append("  • " + line)
	var weaknesses := resistance_weaknesses(e) + e.codex_weaknesses
	if not weaknesses.is_empty():
		lines.append("")
		lines.append("[b]Weaknesses[/b]")
		for line in weaknesses:
			lines.append("  • " + line)
	if e.codex_tip != "":
		lines.append("")
		lines.append("[b]Tip:[/b] " + e.codex_tip)
	return "\n".join(lines)


static func _bonuses(pairs: Array) -> String:
	var parts: PackedStringArray = []
	for pair in pairs:
		if not is_equal_approx(pair[0], 1.0):
			parts.append("%s %s" % [percent(pair[0]), pair[1]])
	return ", ".join(parts)


static func _taken(e: EnemyDefinition) -> Array[float]:
	return [e.physical_taken, e.fire_taken, e.magic_taken]


## 12.0 -> "12", 2.5 -> "2.5".
static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
```
  `export_presets.cfg`: `exclude_filter="docs/*, tools/*, export/*"` → `exclude_filter="docs/*, tools/*, export/*, tests/*"`.
- [ ] **Step 6: Run it.** Import, then `godot --headless --path . --script tests/test_help_text.gd`. Expected: `help_text: 48 passed, 0 failed` (count may differ by the loops; zero failures), exit 0. If the Gearshot ability line fails, check its data: `ability_duration` 3 and multiplier 3 come from the defaults, cooldown 12.
- [ ] **Step 7: Commit** `Add Help and Codex text to the tower and enemy data`.

---

### Task 2: Codex autoload, on-screen discovery and the notice

**Files:** Create `scripts/codex.gd`, `scripts/ui/codex_toast.gd`, `scenes/ui/codex_toast.tscn`. Modify `project.godot` (`[autoload]`), `scenes/enemies/enemy.tscn`, `scripts/enemies/enemy.gd`, `scenes/world.tscn`.

**Interfaces:**
- Consumes: `EnemyDefinition` (`id`, `display_name`).
- Produces: autoload `Codex` with `signal discovered(definition: EnemyDefinition)`, `const PATH := "user://codex.cfg"`, `is_seen(id: StringName) -> bool`, `mark_seen(definition: EnemyDefinition)`, `all_enemies() -> Array[EnemyDefinition]`, `_load()`; `Enemy` node `OnScreen` (`VisibleOnScreenNotifier2D`); `class_name CodexToast` with `is_showing() -> bool`; `CodexToast` node in `world.tscn`.

- [ ] **Step 1: Failing check.** Run the game, Play, and eval `return get_tree().root.has_node("Codex")`. Expected `false`. Stop.
- [ ] **Step 2: Codex** `scripts/codex.gd`:
```gdscript
extends Node
## Which enemies the player has seen (autoloaded as "Codex"). An enemy is
## added the first time one comes on screen, saved to user://codex.cfg and
## kept across runs. Anything unreadable in the file counts as unseen.

signal discovered(definition: EnemyDefinition)

const PATH := "user://codex.cfg"
const ENEMY_DIR := "res://data/enemies/"

var _seen: Dictionary[StringName, bool] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()


func is_seen(id: StringName) -> bool:
	return _seen.get(id, false)


## Records the first sighting of `definition`'s enemy type and announces it.
func mark_seen(definition: EnemyDefinition) -> void:
	if definition == null or is_seen(definition.id):
		return
	_seen[definition.id] = true
	_save()
	discovered.emit(definition)


## Every enemy type in data/enemies/, by name.
func all_enemies() -> Array[EnemyDefinition]:
	var enemies: Array[EnemyDefinition] = []
	for file in ResourceLoader.list_directory(ENEMY_DIR):
		if not file.ends_with(".tres"):
			continue
		var definition := load(ENEMY_DIR + file) as EnemyDefinition
		if definition:
			enemies.append(definition)
	enemies.sort_custom(func(a: EnemyDefinition, b: EnemyDefinition) -> bool:
		return a.display_name < b.display_name)
	return enemies


func _load() -> void:
	_seen.clear()
	var file := ConfigFile.new()
	if file.load(PATH) != OK or not file.has_section("seen"):
		return
	for key in file.get_section_keys("seen"):
		var value = file.get_value("seen", key)
		if value is bool and value:
			_seen[StringName(key)] = true


func _save() -> void:
	var file := ConfigFile.new()
	for id in _seen:
		file.set_value("seen", String(id), true)
	file.save(PATH)
```
  `project.godot` `[autoload]`: add `Codex="*res://scripts/codex.gd"` after the `Settings=` line.
- [ ] **Step 3: Discovery.** `scenes/enemies/enemy.tscn`: append
```
[node name="OnScreen" type="VisibleOnScreenNotifier2D" parent="."]
```
  `enemy.gd`: add `@onready var on_screen: VisibleOnScreenNotifier2D = $OnScreen` after the `hurtbox_shape` onready; in `_ready()` after `_fit_hurtbox()` add `on_screen.screen_entered.connect(_on_screen_entered, CONNECT_ONE_SHOT)`; at the end of `_fit_hurtbox()` add `on_screen.rect = visible`; and add
```gdscript
## The first time any enemy of this type is on screen, it joins the Codex.
func _on_screen_entered() -> void:
	Codex.mark_seen(definition)
```
- [ ] **Step 4: Notice.** `scripts/ui/codex_toast.gd`:
```gdscript
class_name CodexToast
extends CanvasLayer
## "New Codex entry" notice near the top of the screen: one at a time, about
## 3 s each, queued. Never takes mouse input.

const SHOW_TIME := 3.0
const FADE_TIME := 0.25

var _queue: Array[String] = []
var _busy := false

@onready var panel: Control = %Panel
@onready var title: Label = %Title


func _ready() -> void:
	panel.visible = false
	panel.modulate.a = 0.0
	Codex.discovered.connect(_on_discovered)


func is_showing() -> bool:
	return _busy


func _on_discovered(definition: EnemyDefinition) -> void:
	_queue.append(definition.display_name)
	if not _busy:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	title.text = "New Codex entry: %s" % _queue.pop_front()
	panel.visible = true
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, FADE_TIME)
	tween.tween_interval(SHOW_TIME)
	tween.tween_property(panel, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(_on_shown)


func _on_shown() -> void:
	panel.visible = false
	_show_next()
```
  `scenes/ui/codex_toast.tscn`:
```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/ui/codex_toast.gd" id="1_toast"]

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_toast"]
bg_color = Color(0.09, 0.08, 0.11, 0.92)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.85, 0.68, 0.35, 1)
corner_radius_top_left = 6
corner_radius_top_right = 6
corner_radius_bottom_right = 6
corner_radius_bottom_left = 6

[node name="CodexToast" type="CanvasLayer"]
process_mode = 3
layer = 5
script = ExtResource("1_toast")

[node name="Top" type="VBoxContainer" parent="."]
anchors_preset = 10
anchor_right = 1.0
offset_top = 110.0
offset_bottom = 180.0
grow_horizontal = 2
mouse_filter = 2

[node name="Panel" type="PanelContainer" parent="Top"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 4
mouse_filter = 2
theme_override_styles/panel = SubResource("StyleBoxFlat_toast")

[node name="Margin" type="MarginContainer" parent="Top/Panel"]
layout_mode = 2
mouse_filter = 2
theme_override_constants/margin_left = 16
theme_override_constants/margin_top = 8
theme_override_constants/margin_right = 16
theme_override_constants/margin_bottom = 8

[node name="Rows" type="VBoxContainer" parent="Top/Panel/Margin"]
layout_mode = 2
mouse_filter = 2

[node name="Title" type="Label" parent="Top/Panel/Margin/Rows"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 2
theme_override_colors/font_color = Color(1, 0.85, 0.5, 1)
theme_override_font_sizes/font_size = 18
text = "New Codex entry: Goblin"
horizontal_alignment = 1

[node name="Hint" type="Label" parent="Top/Panel/Margin/Rows"]
layout_mode = 2
mouse_filter = 2
theme_override_font_sizes/font_size = 13
text = "Esc → Help to read it"
horizontal_alignment = 1
```
  `scenes/world.tscn`: add `[ext_resource type="PackedScene" path="res://scenes/ui/codex_toast.tscn" id="21_toast"]` after the last `ext_resource` and append `[node name="CodexToast" parent="." instance=ExtResource("21_toast")]`.
- [ ] **Step 5: Verify.** Import, `validate_scripts`, delete `user://codex.cfg`, run the game, Play, `break_left = 99999`, and eval:
  - **Off screen, then on:** spawn a goblin far outside the camera (≥ 900 px from the hero, e.g. at the map corner away from the hero) and freeze it; 10 frames: `Codex.is_seen(&"goblin")` false, toast not showing. Move the hero next to it (`reset_physics_interpolation()`, `camera.reset_smoothing()`), wait 10 frames: seen true, `CodexToast.is_showing()` true, title "New Codex entry: Goblin"; `user://codex.cfg` has `seen/goblin = true`. Spawn a second goblin on screen: no second notice (the queue stays empty). Screenshot the notice.
  - **Review Focus 1:** spawn an Armored Goblin right next to the hero (on screen from the start): discovered within 10 frames.
  - **Queue:** wait until no notice is showing (~4 s); delete `user://codex.cfg` and call `Codex._load()` so nothing is seen; spawn a goblin and a Goblin Shaman on screen in the same frame: the first notice's title names one of them, and ~3.5 s later the title names the other.
  - **Review Focus 2:** while a notice shows, `panel.mouse_filter == MOUSE_FILTER_IGNORE` for the Panel and every child Control; `get_viewport().gui_get_hovered_control()` over the notice's centre (warp the mouse there) is not part of the notice.
  - **Persistence:** stop and run again: `Codex.is_seen(&"goblin")` still true.
  - **Review Focus 5:** write `user://codex.cfg` with `[seen]` `goblin=true`, `ghost_king=true`, `goblin_shaman=1`, call `Codex._load()`: goblin seen, shaman not, `all_enemies()` still returns 3 definitions, no errors. Then write garbage and `_load()`: nothing seen, no script errors.
  - `all_enemies()` names are `["Armored Goblin", "Goblin", "Goblin Shaman"]`.
  - Delete `user://codex.cfg`; stop; clean `project.godot` (keep the `Codex` line).
- [ ] **Step 6: Commit** `Add the Codex: enemies join it the first time they're on screen`.

---

### Task 3: The Help screen

**Files:** Create `scripts/ui/help_menu.gd`, `scenes/ui/help_menu.tscn`.

**Interfaces:**
- Consumes: `HelpText` (Task 1); `Codex.all_enemies()`, `Codex.is_seen()` (Task 2); `TowerDefinition.icon()`.
- Produces: `class_name HelpMenu extends CanvasLayer` with `signal closed`, `open()`, `close()`, `show_tab(tab: StringName)` (`&"towers"` / `&"codex"`); scene `res://scenes/ui/help_menu.tscn`.

- [ ] **Step 1: Failing check.** `test -f scenes/ui/help_menu.tscn`. Expected: missing.
- [ ] **Step 2: Script** `scripts/ui/help_menu.gd`:
```gdscript
class_name HelpMenu
extends CanvasLayer
## Tower guide and enemy Codex, opened from the main menu and the pause menu.
## Each tab is a list on the left and the chosen entry's details on the right.
## Back or Esc closes it.

signal closed

const TOWERS: Array[String] = [
	"res://data/towers/gearshot.tres", "res://data/towers/rune_mortar.tres",
	"res://data/towers/embercaster.tres", "res://data/towers/aether_spire.tres"]
## Enemy ratings are words relative to this one.
const BASE_ENEMY := "res://data/enemies/goblin.tres"
const SELECTED := Color(1.0, 0.85, 0.5)

var _entries: Array[Button] = []
var _preview: AnimatedSprite2D

@onready var towers_tab: Button = %TowersTab
@onready var codex_tab: Button = %CodexTab
@onready var entry_list: VBoxContainer = %List
@onready var sprite_holder: Control = %SpriteHolder
@onready var picture: TextureRect = %Picture
@onready var entry_name: Label = %EntryName
@onready var body: RichTextLabel = %Body
@onready var back_button: Button = %Back


func _ready() -> void:
	visible = false
	towers_tab.pressed.connect(show_tab.bind(&"towers"))
	codex_tab.pressed.connect(show_tab.bind(&"codex"))
	back_button.pressed.connect(close)


## Opens on the Towers tab; the lists are rebuilt each time, so new Codex
## entries appear.
func open() -> void:
	visible = true
	show_tab(&"towers")
	back_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	_clear_preview()
	closed.emit()


func show_tab(tab: StringName) -> void:
	towers_tab.set_pressed_no_signal(tab == &"towers")
	codex_tab.set_pressed_no_signal(tab == &"codex")
	for child in entry_list.get_children():
		entry_list.remove_child(child)
		child.queue_free()
	_entries.clear()
	if tab == &"towers":
		for path in TOWERS:
			var tower: TowerDefinition = load(path)
			_add_entry(tower.display_name, tower.icon(), false, _show_tower.bind(tower))
	else:
		for enemy in Codex.all_enemies():
			var seen := Codex.is_seen(enemy.id)
			_add_entry(enemy.display_name if seen else "???", _enemy_icon(enemy),
					not seen, _show_enemy.bind(enemy))
	if not _entries.is_empty():
		_entries[0].pressed.emit()


func _add_entry(text: String, icon: Texture2D, silhouette: bool, on_pick: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.icon = icon
	button.expand_icon = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 46)
	button.add_theme_constant_override(&"icon_max_width", 40)
	if silhouette:
		for state in [&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color",
				&"icon_focus_color", &"icon_hover_pressed_color"]:
			button.add_theme_color_override(state, Color.BLACK)
	button.pressed.connect(_select.bind(button, on_pick))
	entry_list.add_child(button)
	_entries.append(button)


func _select(button: Button, on_pick: Callable) -> void:
	for entry in _entries:
		entry.remove_theme_color_override(&"font_color")
	button.add_theme_color_override(&"font_color", SELECTED)
	on_pick.call()


func _show_tower(tower: TowerDefinition) -> void:
	_set_picture(tower.icon(), false)
	entry_name.text = tower.display_name + ("" if tower.available else "  (Coming soon)")
	body.text = HelpText.tower_bbcode(tower)


func _show_enemy(enemy: EnemyDefinition) -> void:
	if Codex.is_seen(enemy.id):
		_set_sprite(enemy)
		entry_name.text = enemy.display_name
		body.text = HelpText.enemy_bbcode(enemy, load(BASE_ENEMY))
	else:
		_set_picture(_enemy_icon(enemy), true)
		entry_name.text = "???"
		body.text = "Not yet encountered."


static func _enemy_icon(enemy: EnemyDefinition) -> Texture2D:
	return enemy.sprite_frames.get_frame_texture(&"idle", 0)


func _set_picture(texture: Texture2D, silhouette: bool) -> void:
	_clear_preview()
	picture.visible = true
	picture.texture = texture
	picture.modulate = Color.BLACK if silhouette else Color.WHITE


## The seen enemy's idle animation, fitted to the picture box.
func _set_sprite(enemy: EnemyDefinition) -> void:
	_clear_preview()
	picture.visible = false
	var box := sprite_holder.custom_minimum_size
	var frame := _enemy_icon(enemy).get_size()
	_preview = AnimatedSprite2D.new()
	_preview.sprite_frames = enemy.sprite_frames
	_preview.scale = Vector2.ONE * minf(box.x / frame.x, box.y / frame.y)
	_preview.position = box / 2.0
	sprite_holder.add_child(_preview)
	_preview.play(&"idle")


func _clear_preview() -> void:
	if _preview:
		_preview.queue_free()
		_preview = null


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
```
- [ ] **Step 3: Scene** `scenes/ui/help_menu.tscn`:
```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/ui/help_menu.gd" id="1_help"]

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_panel"]
bg_color = Color(0.09, 0.08, 0.11, 0.96)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.85, 0.68, 0.35, 1)
corner_radius_top_left = 6
corner_radius_top_right = 6
corner_radius_bottom_right = 6
corner_radius_bottom_left = 6

[sub_resource type="ButtonGroup" id="ButtonGroup_tabs"]

[node name="HelpMenu" type="CanvasLayer"]
process_mode = 3
layer = 20
script = ExtResource("1_help")

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

[node name="Panel" type="PanelContainer" parent="Center"]
custom_minimum_size = Vector2(900, 560)
layout_mode = 2
theme_override_styles/panel = SubResource("StyleBoxFlat_panel")

[node name="Margin" type="MarginContainer" parent="Center/Panel"]
layout_mode = 2
theme_override_constants/margin_left = 18
theme_override_constants/margin_top = 12
theme_override_constants/margin_right = 18
theme_override_constants/margin_bottom = 12

[node name="Rows" type="VBoxContainer" parent="Center/Panel/Margin"]
layout_mode = 2
theme_override_constants/separation = 10

[node name="Title" type="Label" parent="Center/Panel/Margin/Rows"]
layout_mode = 2
theme_override_font_sizes/font_size = 24
text = "Help"
horizontal_alignment = 1

[node name="Tabs" type="HBoxContainer" parent="Center/Panel/Margin/Rows"]
layout_mode = 2
alignment = 1
theme_override_constants/separation = 8

[node name="TowersTab" type="Button" parent="Center/Panel/Margin/Rows/Tabs"]
unique_name_in_owner = true
custom_minimum_size = Vector2(140, 34)
layout_mode = 2
toggle_mode = true
button_pressed = true
button_group = SubResource("ButtonGroup_tabs")
text = "Towers"

[node name="CodexTab" type="Button" parent="Center/Panel/Margin/Rows/Tabs"]
unique_name_in_owner = true
custom_minimum_size = Vector2(140, 34)
layout_mode = 2
toggle_mode = true
button_group = SubResource("ButtonGroup_tabs")
text = "Codex"

[node name="Main" type="HBoxContainer" parent="Center/Panel/Margin/Rows"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 16

[node name="ListScroll" type="ScrollContainer" parent="Center/Panel/Margin/Rows/Main"]
custom_minimum_size = Vector2(230, 0)
layout_mode = 2
horizontal_scroll_mode = 0

[node name="List" type="VBoxContainer" parent="Center/Panel/Margin/Rows/Main/ListScroll"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 4

[node name="Detail" type="VBoxContainer" parent="Center/Panel/Margin/Rows/Main"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 8

[node name="Header" type="HBoxContainer" parent="Center/Panel/Margin/Rows/Main/Detail"]
layout_mode = 2
theme_override_constants/separation = 14

[node name="SpriteHolder" type="Control" parent="Center/Panel/Margin/Rows/Main/Detail/Header"]
unique_name_in_owner = true
clip_contents = true
custom_minimum_size = Vector2(130, 110)
layout_mode = 2

[node name="Picture" type="TextureRect" parent="Center/Panel/Margin/Rows/Main/Detail/Header/SpriteHolder"]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
expand_mode = 1
stretch_mode = 5

[node name="EntryName" type="Label" parent="Center/Panel/Margin/Rows/Main/Detail/Header"]
unique_name_in_owner = true
layout_mode = 2
size_flags_vertical = 4
theme_override_colors/font_color = Color(1, 0.85, 0.5, 1)
theme_override_font_sizes/font_size = 24
text = "Gearshot Turret"

[node name="Body" type="RichTextLabel" parent="Center/Panel/Margin/Rows/Main/Detail"]
unique_name_in_owner = true
layout_mode = 2
size_flags_vertical = 3
theme_override_font_sizes/normal_font_size = 15
theme_override_font_sizes/bold_font_size = 15
bbcode_enabled = true
text = "Description"

[node name="Buttons" type="HBoxContainer" parent="Center/Panel/Margin/Rows"]
layout_mode = 2
alignment = 1

[node name="Back" type="Button" parent="Center/Panel/Margin/Rows/Buttons"]
unique_name_in_owner = true
custom_minimum_size = Vector2(170, 36)
layout_mode = 2
text = "Back"
```
- [ ] **Step 4: Verify.** Import, `validate_scripts`, the Task 1 test script (still passes), delete `user://codex.cfg`, run the game and eval (a test instance: `var h = load("res://scenes/ui/help_menu.tscn").instantiate(); get_tree().root.add_child(h); h.open()`; free it at the end):
  - Towers tab: entries `["Gearshot Turret", "Rune Mortar", "Embercaster", "Aether Spire"]`; first selected (gold font); `entry_name.text == "Gearshot Turret"`; `body.get_parsed_text()` contains "Lv3 — 25 Scrap + 3 Aether" and "Operated: +35% damage, +50% fire rate, +15% range". Click Aether Spire: name and body switch. Screenshot.
  - Codex tab (nothing seen — after deleting the file, call `Codex._load()`): 3 entries all "???"; detail "Not yet encountered."; picture modulate black. Screenshot.
  - **Review Focus 4:** `Codex.mark_seen(load("res://data/enemies/armored_goblin.tres"))`; close and reopen, Codex tab: "Armored Goblin" listed (others "???"); select it: body contains "Health: High · Speed: Low · Hits: Average", "Shrugs off Physical damage", "Resists Fire damage", "Weak to Magic", "Tip:"; an `AnimatedSprite2D` child of `SpriteHolder` is playing `idle`. Screenshot.
  - Escape closes it and emits `closed` once; `_preview` freed.
  - Delete `user://codex.cfg`; stop; clean `project.godot`.
- [ ] **Step 5: Commit** `Add the Help screen: tower guide and enemy Codex`.

---

### Task 4: Help in the menus, web check and roadmap

**Files:** Modify `scripts/ui/pause_menu.gd`, `scenes/ui/pause_menu.tscn`, `scripts/ui/main_menu.gd`, `scenes/ui/main_menu.tscn`, `ROADMAP.md`.

**Interfaces:**
- Consumes: `HelpMenu` (`open()`, `closed`, `visible`) (Task 3).
- Produces: `PauseMenu.help: HelpMenu`; `MainMenu.help_button: Button`, `MainMenu.help: HelpMenu`.

- [ ] **Step 1: Failing check.** Run the game, Play, pause, eval `return [pm.help_button.disabled, pm.has_node("HelpMenu")]`. Expected `[true, false]`. Stop.
- [ ] **Step 2: Pause menu.**
  - `pause_menu.tscn`: header `load_steps=3` → `load_steps=4`; add `[ext_resource type="PackedScene" path="res://scenes/ui/help_menu.tscn" id="3_help"]`; append `[node name="HelpMenu" parent="." instance=ExtResource("3_help")]`.
  - `pause_menu.gd`: add `@onready var help: HelpMenu = $HelpMenu` after `options`; in `_ready()` replace `help_button.disabled = true` and the tooltip line with
```gdscript
	help_button.pressed.connect(_open_help)
	help.closed.connect(_show_panel)
```
    add after `_open_options()`:
```gdscript
func _open_help() -> void:
	panel.visible = false
	help.open()
```
    and in `_unhandled_input` change `elif options.visible:` to `elif options.visible or help.visible:`. Update the class comment's first line to "Esc during a run pauses the game and shows Resume / Options / Help / Quit." (drop nothing else).
- [ ] **Step 3: Main menu.**
  - `main_menu.tscn`: header `load_steps=4` → `load_steps=5`; add `[ext_resource type="PackedScene" path="res://scenes/ui/help_menu.tscn" id="4_help"]`; add, between the Options and Quit button nodes:
```
[node name="Help" type="Button" parent="Center/Rows/Buttons"]
unique_name_in_owner = true
custom_minimum_size = Vector2(220, 46)
layout_mode = 2
theme_override_font_sizes/font_size = 20
text = "Help"
```
    and append `[node name="HelpMenu" parent="." instance=ExtResource("4_help")]`.
  - `main_menu.gd`: class comment "The first screen: Play, Options, Help and Quit. …"; add `@onready var help_button: Button = %Help` and `@onready var help: HelpMenu = $HelpMenu`; in `_ready()` add `help_button.pressed.connect(_open_help)` and `help.closed.connect(_on_help_closed)`; add
```gdscript
func _open_help() -> void:
	buttons.visible = false
	help.open()


func _on_help_closed() -> void:
	buttons.visible = true
	help_button.grab_focus()
```
- [ ] **Step 4: Verify.** Import, `validate_scripts`, the Task 1 test script, run the game and eval:
  - **Main menu:** buttons Play, Options, Help, Quit; Help opens the Help screen (buttons hidden); Escape closes it (buttons back, Help focused). Screenshot the main menu.
  - **Pause menu:** Play, Escape to pause; Help enabled, no tooltip; pressing it hides the panel and opens Help (still paused); Escape closes Help (panel back, still paused); Escape again resumes.
  - **Discovery in play:** with `codex.cfg` deleted, play wave 1 at `Engine.time_scale = 3.0` with the hero near the west edge until a goblin comes on screen: the notice shows; pause → Help → Codex: "Goblin" unlocked, the others "???". Reset time scale.
  - Delete `user://codex.cfg` and `user://settings.cfg`; stop; clean `project.godot`.
- [ ] **Step 5: Web check.** `mkdir -p export/web && godot --headless --export-release "Web" export/web/index.html`; serve it (`python3 -m http.server 8765 -d export/web &`, remember the PID); Playwright (headless Chromium from `~/.cache/ms-playwright/chromium-*/chrome-linux64/chrome`, `--use-angle=swiftshader --enable-unsafe-swiftshader`): wait 22 s; screenshot: main menu shows Play / Options / Help and no Quit (find the buttons' y from the screenshot). Click Help → Codex tab: **Review Focus 3** — three "???" entries listed. Back; Play; wait ~40 s (wave 1 arrives; press Enter to start it early) with the camera on the west side (hold A for 2 s) until the notice shows; press Escape → Help → Codex: Goblin unlocked. Reload the page: Help → Codex still shows Goblin. No console errors. Kill the server by PID; `rm -rf export`.
- [ ] **Step 6: Roadmap.** Phase 11: `- [ ] **[AI]** Help: tower guide with upgrade paths, and an enemy Codex (part 2)` →
  `- [x] **[AI]** Help (main and pause menus): tower guide (what each does, damage type, ability, operated bonus, upgrade path with costs) and an enemy Codex (unlocks when first seen on screen, "???" until then, number-free strengths / weaknesses / tip; saved in `user://codex.cfg`)`
- [ ] **Step 7: Commit** `Open Help from the main and pause menus; tick it on the roadmap`.
