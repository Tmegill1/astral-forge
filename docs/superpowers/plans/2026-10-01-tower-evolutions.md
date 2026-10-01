# Tower Evolutions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let every Lv3 tower evolve once, for 6 Aether, into one of two branches that change how it plays (8 branches in all).

**Architecture:** An evolution is its own `TowerDefinition` data file (same class as its base tower or a subclass) that copies the base tower's stats and always runs at level 3; branch changes live in named fields and per-branch scripts that extend the base tower's script. `BuildSlot.evolve(branch)` pays and swaps the tower node in place; `TowerMenu` gets an evolve view with two branch cards. Placeholder looks: tint + glow ring + 10% larger, or a spare sprite sheet re-labelled by `tools/alias_frames.py`.

**Tech Stack:** Godot 4.7 GDScript; headless tests (`godot --headless --path . --script tests/…`); in-game checks via the Godot MCP tools; Python 3 for the art tool.

**Spec:** `docs/superpowers/specs/2026-10-01-tower-evolutions-design.md`

## Global Constraints

- Unlock: tower at Lv3 → F menu → **Evolve — 6 Aether** → choose 1 of 2. One evolution per tower; can't be undone.
- Evolution cost `{aether: 6}` on every evolution file; added to the slot's `invested`, so selling refunds 50% (floored) of it like everything else.
- An evolution runs at **level 3** with the base tower's base stats and level multipliers copied unchanged: `max_health, attack_damage, attacks_per_second, attack_range, projectile_speed, level_damage_multiplier, level_fire_rate_multiplier, level_range_multiplier, level_health_multiplier, operated_damage_multiplier, operated_fire_rate_multiplier, operated_range_multiplier`. Branch changes go in separate named fields.
- Evolving keeps the walls untouched, keeps the damage taken, and keeps the operating hero on the new tower.
- Branch numbers (from the spec): Gatling 0→1 spin over 2 s, down over 1 s, ×1→×4 fire rate, 65% damage, Overspin 4 s / 12 s · Rune Cannon magic, ×0.3 rate, ×3.5 damage, pierce 3, 40% splash in 50 px, Overcharge 4× pierce-all 1.5× distance / 12 s · Siege 3-shell salvo (40 px scatter, 0.1 s apart), 70% damage, ×1.3 blast, ×0.6 rate, Bombardment 6 full shells in 120 px / 14 s · Frost ×0.8 damage, frost circle 60% slower for 6 s, freeze 0.6 s within 30 px, Glacial Shell 2× blast freeze 2 s / 14 s · Inferno cone ×1.4, 10 burn stacks, Overpressure kept · Oil ×0.5 flame, oil 4 s: 30% slower and fire damage taken ×1.5, Ignite 3× fire burst + max burn + clears oil / 10 s · Storm 8 jumps no falloff, every 5th bolt stuns 0.5 s, Thunderstorm 4 s, a strike every 0.25 s, 2 jumps, 0.5 s stun / 14 s · Focus Lens no chain, 10 ticks/s, 1×→5× over 3 s on one target (reset on switch), auto target = most health, Overload max ramp ×1.5 for 4 s / 12 s.
- Tints: Rune Cannon violet `Color(0.78, 0.55, 1)`, Siege orange `Color(1, 0.7, 0.4)`, Frost icy blue `Color(0.65, 0.9, 1)`, Inferno deep red `Color(1, 0.5, 0.45)`, Oil dark amber `Color(0.8, 0.65, 0.35)`, Focus Lens white-gold `Color(1, 0.95, 0.75)`; tinted ones also get a glow ring in the same hue (alpha 0.8) and `sprite_scale = 0.605` (0.55 × 1.1). Gatling and Storm use their own sheets, white tint, no glow.
- Work on branch `tower-evolutions` (already created; the spec is committed there). One commit per task, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Stage only the task's files.
- A new `class_name` needs `godot --headless --editor --path . --import` before scripts or tests that use it parse.
- Headless tests: `godot --headless --path . --script tests/test_evolutions.gd` (and the existing `tests/test_help_text.gd`, `tests/test_cards.gd`, `tests/test_waves.gd`, `tests/test_run_summary.gd` must keep passing). "Identifier not found" lines about autoloads are harmless noise.
- MCP in-game checks: `run_project`, then the first `game_eval` usually says "Not connected" (retry once). The game starts at the main menu: in an eval do `get_tree().change_scene_to_file("res://scenes/world.tscn")`, await ~4 process frames, then `var world = get_tree().current_scene`. Set `world.run_cards.ended = true` so XP level-ups don't open the pausing CardMenu. Core: `get_tree().get_first_node_in_group(&"core")`; hero: `…group(&"hero")`; slots: `world.find_child("BuildSlotWest", true, false)` (also `BuildSlotEast`, `BuildSlotNorth`, `BuildSlotSouth`; set `slot.locked = false`). Resources: `var d: Dictionary[StringName, int] = {&"scrap": 200, &"aether": 30}; core.stored.add_all(d)`. Enemies: `world.get_node("WaveDirector").spawn_at(load("res://data/enemies/goblin.tres"), pos)`; freeze one with `set_physics_process(false)` (this also freezes its burn/stun/oil timers); give test enemies big health with `e.health.reset(99999)`. Kill with `health.take_damage(999999, Health.DamageType.MAGIC)`, never `queue_free` a living enemy, never disable the WaveDirector. Do timing checks inside one `game_eval` (keep each under ~25 s). Disconnect any lambda you connect before the eval returns. A script error freezes the game: check `get_debug_output`, then `stop_project` + `run_project`. After `stop_project`, `git checkout project.godot` (or strip only the stray blank lines / McpInteractionServer autoload).
- Wave 1 starts 45 s after the world loads; do each check soon after loading or drive shots directly (`t._fire_at(point)`, `t.use_ability()`).

## Review Focus

1. **Evolving while the hero is operating the tower** — the hero ends up operating the new tower (HUD shows it, Q uses the new ability), with no errors (Task 2 check).
2. **Not enough Aether / wrong tower state** — Evolve with 5 Aether, on a Lv2 tower, on a wrecked tower, on an already-evolved tower, or with a branch from another tower: returns false and spends nothing (Task 2 check).
3. **Oil applied and removed many times** — an Armored Goblin's fire `damage_taken` goes back to exactly 0.6 after repeated oil → expire / oil → Ignite / oil → die cycles; oil never stacks past ×1.5 (Task 8 check).
4. **Focus Lens target dies or is freed mid-beam** — no errors, the beam disappears, the ramp resets to 0, and the next target starts at 1× (Task 10 check).
5. **Rune Cannon round through overlapping enemies** — two enemies stacked on one spot are each hit once (not twice), splash never adds to the enemy the round itself hit, and pierce counts distinct enemies (Task 4 check).

---

### Task 1: Evolution data model, Help text and the test file

**Files:**
- Modify: `scripts/towers/tower_definition.gd`
- Modify: `scripts/ui/help_text.gd`
- Create: `tests/test_evolutions.gd`

**Interfaces:**
- Produces: `TowerDefinition.evolutions: Array[TowerDefinition]`, `.evolved: bool`, `.evolve_cost: Dictionary[StringName, int]`, `.help_line: String`, `.tint: Color` (default `Color.WHITE`), `.glow: Color` (default `Color(0, 0, 0, 0)`); `TowerDefinition.icon()` uses `lv3_idle` when `evolved`; `HelpText.evolution_lines(t: TowerDefinition) -> PackedStringArray`; `tests/test_evolutions.gd` with an `EXPECTED` dictionary (base id → `[branch id, branch id]`) that later tasks fill in.

- [ ] **Step 1: Write the failing test** `tests/test_evolutions.gd`:

```gdscript
extends SceneTree
## Headless checks for tower evolutions: the data files and the rules that
## don't need a running game.
## Run: godot --headless --path . --script tests/test_evolutions.gd
## Prints each failure and "evolutions: N passed, M failed"; exits 1 on failure.
## (Lines about autoloads not being found are harmless in --script mode.)

## Base tower id -> its two branch ids, in menu order. Each branch task adds
## its pair here.
const EXPECTED := {
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
```

- [ ] **Step 2: Run it to see it fail**

Run: `godot --headless --path . --script tests/test_evolutions.gd`
Expected: script errors / FAIL lines about `evolved`, `tint`, `glow` (the fields don't exist yet), exit code 1.

- [ ] **Step 3: Add the fields to `scripts/towers/tower_definition.gd`.** Update the header comment and `icon()`, and add an `Evolution` group after the `Help` group:

```gdscript
## Everything that makes one tower type different. To add a tower, create a
## new .tres in data/towers/. Sprites need lv1_idle and lv1_fire animations
## (and lv2_/lv3_ for levels) and must face right. An evolution (evolved =
## true) is its own .tres too: it always runs at Lv3, so it only needs
## lv3_idle, lv3_fire and a wreck.
```

```gdscript
## Picture for menus: the first idle frame (Lv3 for evolutions).
func icon() -> Texture2D:
	return sprite_frames.get_frame_texture(&"lv3_idle" if evolved else &"lv1_idle", 0)
```

```gdscript
@export_group("Evolution")
## The two branches a Lv3 tower can evolve into (base towers only).
@export var evolutions: Array[TowerDefinition] = []
## True for an evolution: it runs at Lv3, never shows in the build menu and
## can't evolve again. It copies its base tower's stats; its own changes
## live in its own fields.
@export var evolved := false
## Stored resources spent to evolve into this branch, e.g. {"aether": 6}.
@export var evolve_cost: Dictionary[StringName, int] = {}
## One line for the evolve choice and the Help screen.
@export var help_line := ""
## Placeholder look until evolution art exists: colours the tower's art...
@export var tint := Color.WHITE
## ...and draws a glow ring of this colour underneath (transparent = none).
@export var glow := Color(0, 0, 0, 0)
```

- [ ] **Step 4: Add the Help lines to `scripts/ui/help_text.gd`.** Add this function after `upgrade_lines`:

```gdscript
## A base tower's evolutions for the Help screen; empty if it has none.
static func evolution_lines(t: TowerDefinition) -> PackedStringArray:
	var lines := PackedStringArray()
	if t.evolutions.is_empty():
		return lines
	lines.append("[b]Evolutions[/b] (at Lv3, %s, pick one)" % cost_text(t.evolutions[0].evolve_cost))
	for branch in t.evolutions:
		lines.append("  [b]%s[/b] — %s" % [branch.display_name, branch.help_line])
		lines.append("    Q: %s — %s (Cooldown: %s s)" % [
				branch.ability_name, branch.ability_text, _number(branch.ability_cooldown)])
	return lines
```

and at the end of `tower_bbcode`, before `return "\n".join(lines)`:

```gdscript
	var evolutions := evolution_lines(t)
	if not evolutions.is_empty():
		lines.append("")
		lines.append_array(evolutions)
```

- [ ] **Step 5: Run the tests**

Run: `godot --headless --path . --script tests/test_evolutions.gd && godot --headless --path . --script tests/test_help_text.gd`
Expected: `evolutions: N passed, 0 failed` (no branches yet, so the four "branches" checks compare `[]` with `[]`) and `help_text: … 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add scripts/towers/tower_definition.gd scripts/ui/help_text.gd tests/test_evolutions.gd
git commit -m "Add evolution fields to tower definitions and the Help text

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Evolving: BuildSlot, tower look, F-menu evolve view, HUD and end screen

**Files:**
- Modify: `scripts/towers/build_slot.gd` (`build()` and new `can_evolve()`, `evolve()`, `_spawn_tower()`)
- Modify: `scripts/towers/tower.gd` (`_ready`, `_on_died`, new `_apply_look()`)
- Create: `scripts/towers/tower_glow.gd`, `scenes/towers/tower_glow.tscn`
- Create: `scripts/ui/evolve_card.gd`, `scenes/ui/evolve_card.tscn`
- Modify: `scripts/ui/tower_menu.gd`, `scenes/ui/tower_menu.tscn`
- Modify: `scripts/ui/hud.gd:44` (operate title), `scripts/ui/game_over.gd:113-115,154` (tower icons)

**Interfaces:**
- Consumes: Task 1 fields.
- Produces: `BuildSlot.can_evolve() -> bool`, `BuildSlot.evolve(branch: TowerDefinition) -> bool`; `class_name TowerGlow` (vars `color: Color`, `radius: float`); `class_name EvolveCard` (signal `chosen(branch: TowerDefinition)`, `show_branch(branch: TowerDefinition, stored: ResourceBag) -> void`).

- [ ] **Step 1: Failing check (in game).** `run_project`, load the world (see Global Constraints), and eval `world.find_child("BuildSlotWest", true, false).has_method(&"evolve")`. Expected: `false`. `stop_project`.

- [ ] **Step 2: BuildSlot.** In `scripts/towers/build_slot.gd`, replace the tower-creating lines of `build()` with a helper and add `can_evolve` / `evolve` after `upgrade()`:

```gdscript
## Pays for and builds `tower`, plus any missing walls. False if it can't.
func build(tower: TowerDefinition) -> bool:
	if built or locked or not tower.available or not core().stored.spend_all(tower.cost):
		return false
	invested = tower.cost.duplicate()
	built = _spawn_tower(tower, 1)
	_raise_walls()
	get_tree().call_group(&"nav_grid", &"mark_dirty")
	return true
```

(Keep whatever `build()` already does after `add_child(built)` — at the time of writing that is exactly `_raise_walls()`, the nav-grid call and `return true`.)

```gdscript
## True when the tower can evolve now (cost aside): standing, Lv3, not yet
## evolved, and it has branches.
func can_evolve() -> bool:
	return built != null and not built.is_destroyed() \
			and built.level >= TowerDefinition.MAX_LEVEL \
			and not built.definition.evolved and not built.definition.evolutions.is_empty()


## Pays for `branch` and swaps the tower for it, in place: same spot, Lv3,
## the same damage taken, walls untouched, and an operating hero stays on.
## False if it can't evolve, `branch` isn't one of its branches, or the Core
## can't afford it (nothing is spent then).
func evolve(branch: TowerDefinition) -> bool:
	if not can_evolve() or branch not in built.definition.evolutions:
		return false
	if not core().stored.spend_all(branch.evolve_cost):
		return false
	for type in branch.evolve_cost:
		invested[type] = invested.get(type, 0) + branch.evolve_cost[type]
	var old := built
	var missing := old.health.max_health - old.health.current
	var hero := old.operator
	if hero:
		hero.stop_operating()
	remove_child(old)
	old.queue_free()
	built = _spawn_tower(branch, TowerDefinition.MAX_LEVEL)
	if missing > 0.0:
		built.health.take_damage(minf(missing, built.health.max_health - 1.0))
	if hero:
		hero.start_operating(built)
	get_tree().call_group(&"nav_grid", &"mark_dirty")
	return true
```

and under `# --- Walls ---`'s section above it (next to `_clear_tower`):

```gdscript
## Creates `tower` at `tower_level` on this pad and hooks it up.
func _spawn_tower(tower: TowerDefinition, tower_level: int) -> Tower:
	var spawned: Tower = (tower.scene if tower.scene else TOWER_SCENE).instantiate()
	spawned.setup(tower)
	spawned.level = tower_level
	spawned.position = tower_offset
	spawned.projectile_parent = get_parent()
	spawned.destroyed.connect(_on_tower_destroyed)
	add_child(spawned)
	return spawned
```

Also change the header comment line "Built: Interact operates the tower; Manage (F) opens repair / upgrade / sell." to "… opens repair / upgrade / evolve / sell."

- [ ] **Step 3: Glow ring.** `scripts/towers/tower_glow.gd`:

```gdscript
class_name TowerGlow
extends Node2D
## Placeholder look for evolved towers: a soft, slowly pulsing coloured ring
## on the ground under the tower.

var color := Color.WHITE
var radius := 30.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.004)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, radius * 1.4, Color(color, 0.12 * pulse))
	draw_circle(Vector2.ZERO, radius, Color(color, 0.22 * pulse))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, 0.7 * pulse), 2.0)
	draw_set_transform(Vector2.ZERO)
```

`scenes/towers/tower_glow.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/towers/tower_glow.gd" id="1_glow"]

[node name="TowerGlow" type="Node2D"]
script = ExtResource("1_glow")
```

- [ ] **Step 4: Tower look.** In `scripts/towers/tower.gd`: add `const GLOW_SCENE := preload("res://scenes/towers/tower_glow.tscn")` next to `BOLT_SCENE`, `var _glow: TowerGlow` next to `_head`, call `_apply_look()` in `_ready()` right after `_setup_head()`, add `if _glow: _glow.visible = false` at the top of `_on_died()` (after the operator line), and add under `# --- Levels ---`:

```gdscript
## Evolutions' placeholder look: their tint on every part of the art, and a
## glow ring on the ground underneath.
func _apply_look() -> void:
	for part: CanvasItem in [sprite, base_sprite, head]:
		part.modulate = definition.tint
	if definition.glow.a > 0.0:
		_glow = GLOW_SCENE.instantiate()
		_glow.color = definition.glow
		add_child(_glow)
		# First child: drawn under the tower's art.
		move_child(_glow, 0)
```

- [ ] **Step 5: Evolve card.** `scripts/ui/evolve_card.gd`:

```gdscript
class_name EvolveCard
extends PanelContainer
## One evolution branch in the tower menu's evolve view: picture, name, what
## changes, its Q ability and a Choose button. Layout in
## scenes/ui/evolve_card.tscn; show_branch() fills it in.

signal chosen(branch: TowerDefinition)

var _branch: TowerDefinition

@onready var icon: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var description: Label = %Description
@onready var ability: Label = %Ability
@onready var choose_button: Button = %ChooseButton


func _ready() -> void:
	choose_button.pressed.connect(func() -> void: chosen.emit(_branch))


## Fills the card in for `branch`; greyed out when `stored` can't pay.
func show_branch(branch: TowerDefinition, stored: ResourceBag) -> void:
	_branch = branch
	icon.texture = branch.icon()
	icon.modulate = branch.tint
	name_label.text = branch.display_name
	description.text = branch.help_line
	ability.text = "Q: %s — %s" % [branch.ability_name, branch.ability_text]
	var missing := stored.shortfall(branch.evolve_cost)
	choose_button.disabled = not missing.is_empty()
	if missing.is_empty():
		choose_button.text = "Choose — %s" % Loot.describe(branch.evolve_cost)
	else:
		choose_button.text = "Need %s more" % Loot.describe(missing)
	modulate = Color.WHITE if missing.is_empty() else Color(1, 1, 1, 0.55)
```

`scenes/ui/evolve_card.tscn` (same style as `build_card.tscn`):

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/ui/evolve_card.gd" id="1_card"]

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_card"]
bg_color = Color(0.16, 0.17, 0.21, 1)
corner_radius_top_left = 4
corner_radius_top_right = 4
corner_radius_bottom_right = 4
corner_radius_bottom_left = 4

[node name="EvolveCard" type="PanelContainer"]
custom_minimum_size = Vector2(210, 0)
theme_override_styles/panel = SubResource("StyleBoxFlat_card")
script = ExtResource("1_card")

[node name="Margin" type="MarginContainer" parent="."]
layout_mode = 2
theme_override_constants/margin_left = 10
theme_override_constants/margin_top = 10
theme_override_constants/margin_right = 10
theme_override_constants/margin_bottom = 10

[node name="Rows" type="VBoxContainer" parent="Margin"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="Icon" type="TextureRect" parent="Margin/Rows"]
unique_name_in_owner = true
custom_minimum_size = Vector2(0, 90)
layout_mode = 2
expand_mode = 1
stretch_mode = 5

[node name="NameLabel" type="Label" parent="Margin/Rows"]
unique_name_in_owner = true
layout_mode = 2
theme_override_colors/font_color = Color(1, 0.92, 0.6, 1)
theme_override_font_sizes/font_size = 16
text = "Branch"

[node name="Description" type="Label" parent="Margin/Rows"]
unique_name_in_owner = true
custom_minimum_size = Vector2(190, 48)
layout_mode = 2
theme_override_colors/font_color = Color(0.85, 0.85, 0.9, 1)
theme_override_font_sizes/font_size = 12
text = "What changes."
autowrap_mode = 3

[node name="Ability" type="Label" parent="Margin/Rows"]
unique_name_in_owner = true
custom_minimum_size = Vector2(190, 32)
layout_mode = 2
theme_override_colors/font_color = Color(0.75, 0.9, 1, 1)
theme_override_font_sizes/font_size = 12
text = "Q: Ability — what it does."
autowrap_mode = 3

[node name="ChooseButton" type="Button" parent="Margin/Rows"]
unique_name_in_owner = true
custom_minimum_size = Vector2(0, 34)
layout_mode = 2
text = "Choose"
```

- [ ] **Step 6: Tower menu scene.** In `scenes/ui/tower_menu.tscn`, append these nodes after `CloseButton` (all under `Center/Panel/Margin/Rows`):

```
[node name="EvolveView" type="VBoxContainer" parent="Center/Panel/Margin/Rows"]
unique_name_in_owner = true
visible = false
layout_mode = 2
theme_override_constants/separation = 10

[node name="EvolveHint" type="Label" parent="Center/Panel/Margin/Rows/EvolveView"]
layout_mode = 2
theme_override_font_sizes/font_size = 14
text = "Choose one evolution. It can't be undone."
horizontal_alignment = 1

[node name="Branches" type="HBoxContainer" parent="Center/Panel/Margin/Rows/EvolveView"]
unique_name_in_owner = true
layout_mode = 2
theme_override_constants/separation = 10
alignment = 1

[node name="BackButton" type="Button" parent="Center/Panel/Margin/Rows/EvolveView"]
unique_name_in_owner = true
custom_minimum_size = Vector2(0, 32)
layout_mode = 2
text = "Back (Esc)"
```

- [ ] **Step 7: Tower menu script.** In `scripts/ui/tower_menu.gd`:
  - Header comment: "Pop-up for a built tower: repair it and its walls, upgrade it (walls too), evolve it at Lv3, or sell it …".
  - Add `const EVOLVE_CARD_SCENE := preload("res://scenes/ui/evolve_card.tscn")` and the new nodes:

```gdscript
@onready var evolve_view: VBoxContainer = %EvolveView
@onready var branches: HBoxContainer = %Branches
@onready var back_button: Button = %BackButton
## Everything hidden while the evolve view shows.
@onready var _main_rows: Array[Control] = [info, repair_button, upgrade_button, sell_button, close_button]
```

  - In `_ready()`: `back_button.pressed.connect(_show_evolve.bind(false))`.
  - In `open()`, before `_refresh()`: `_show_evolve(false)`.
  - In `_refresh()`, the title line becomes:

```gdscript
	var def := tower.definition
	title.text = ("%s (Evolved)" % def.display_name) if def.evolved \
			else "%s — Lv%d" % [def.display_name, tower.level]
```

  - At the top of `_refresh_upgrade()`, replace the max-level block with:

```gdscript
	if tower.definition.evolved:
		upgrade_button.disabled = true
		upgrade_button.text = "Fully evolved"
		return
	if tower.level >= TowerDefinition.MAX_LEVEL:
		if not _slot.can_evolve():
			upgrade_button.disabled = true
			upgrade_button.text = "Max level"
			return
		# Every branch costs the same; the evolve view greys out what can't be paid.
		var evolve_cost := tower.definition.evolutions[0].evolve_cost
		var short := _slot.core().stored.shortfall(evolve_cost)
		upgrade_button.disabled = false
		upgrade_button.text = "Evolve — %s" % Loot.describe(evolve_cost) if short.is_empty() \
				else "Evolve — need %s more" % Loot.describe(short)
		return
```

  - `_on_upgrade()` becomes:

```gdscript
func _on_upgrade() -> void:
	if _slot.can_evolve():
		_show_evolve(true)
		return
	_slot.upgrade()
	_refresh()
```

  - New functions:

```gdscript
## Switches between the normal view and the two evolution cards.
func _show_evolve(on: bool) -> void:
	for control in _main_rows:
		control.visible = not on
	evolve_view.visible = on
	for child in branches.get_children():
		branches.remove_child(child)
		child.queue_free()
	if not on:
		return
	for branch in _slot.built.definition.evolutions:
		var card: EvolveCard = EVOLVE_CARD_SCENE.instantiate()
		branches.add_child(card)
		card.show_branch(branch, _slot.core().stored)
		card.chosen.connect(_on_evolve)
	back_button.grab_focus()


func _on_evolve(branch: TowerDefinition) -> void:
	if _slot.evolve(branch):
		_show_evolve(false)
		_refresh()
```

  - In `_unhandled_input`, inside the cancel/manage branch, go back first:

```gdscript
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"manage"):
		if evolve_view.visible:
			_show_evolve(false)
		else:
			close()
		get_viewport().set_input_as_handled()
```

- [ ] **Step 8: HUD and end screen.** In `scripts/ui/hud.gd`, the operate title becomes:

```gdscript
	operate_title.text = ("Operating %s (Evolved)" % def.display_name) if def.evolved \
			else "Operating %s Lv%d" % [def.display_name, tower.level]
```

In `scripts/ui/game_over.gd`, give `_icon_entry` a tint and use it for towers:

```gdscript
func _icon_entry(texture: Texture2D, caption: String, tint := Color.WHITE) -> HBoxContainer:
	...
	icon.modulate = tint
	...
```

```gdscript
		var definition: TowerDefinition = tower[0]
		towers_row.add_child(_icon_entry(definition.icon(),
				"Evolved" if definition.evolved else "Lv%d" % tower[1], definition.tint))
```

- [ ] **Step 9: Import and validate.** `godot --headless --editor --path . --import`, then `validate_scripts` on the changed scripts. Run the headless tests (all five files). Expected: all pass.

- [ ] **Step 10: In-game checks** (no branch data exists yet, so make two test branches inside the eval). After loading the world:

```gdscript
var gearshot = load("res://data/towers/gearshot.tres")
var cost: Dictionary[StringName, int] = {&"aether": 6}
var a = gearshot.duplicate()
a.id = &"test_a"; a.display_name = "Test A"; a.evolved = true; a.evolve_cost = cost
a.help_line = "Test branch A."; a.tint = Color(0.78, 0.55, 1); a.glow = Color(0.78, 0.55, 1, 0.8)
var b = a.duplicate(); b.id = &"test_b"; b.display_name = "Test B"; b.tint = Color(1, 0.7, 0.4)
gearshot.evolutions = [a, b]
```
  Build a Gearshot on `BuildSlotWest` (give plenty of Scrap first), then check the following, recording `core.stored` before and after each call:
  - **Review Focus 2:** `slot.evolve(a)` on Lv1 → false, nothing spent. Upgrade to Lv3 (adds 3 Aether to the cost, so top up to leave exactly 5) → `slot.evolve(a)` false, nothing spent. `slot.evolve(load("res://data/towers/rune_mortar.tres"))` false. Add 1 Aether → `slot.evolve(a)` true, 6 Aether gone, `slot.invested[&"aether"] == 9`, `slot.built.definition == a`, `slot.built.level == 3`. Then `slot.evolve(b)` false (already evolved).
  - **Walls and health:** before evolving, damage the tower by 50 (`built.health.take_damage(50)`) and record each wall's instance id. After: the new tower's `health.max_health - health.current ≈ 50`, every wall is the same instance, `slot.walls.size()` unchanged.
  - **Review Focus 1:** with the hero operating the Lv3 tower (`hero.start_operating(slot.built)`), evolve → `hero.operating == slot.built` (the new one), `slot.built.operator == hero`, no errors. Leave again.
  - **Look:** `slot.built.sprite.modulate` / `head.modulate` equal the tint; a `TowerGlow` child exists at index 0. Screenshot the tower (move the hero next to it first).
  - **Menu:** open `world.get_node("UI/TowerMenu").open(slot)` on a fresh Lv3 Gearshot (with ≥ 6 Aether): button text "Evolve — 6 Aether"; `menu._on_upgrade()` shows the evolve view with 2 `EvolveCard`s; screenshot it; `menu._show_evolve(false)` returns to the normal view; pressing Choose on card 0 (`card.choose_button.pressed.emit()`) evolves it and the title reads "Test A (Evolved)" with the button "Fully evolved". With 5 Aether the main button reads "Evolve — need 1 Aether more" and both cards' buttons are disabled. Close the menu.
  - **Wreck:** kill the evolved tower (`built.health.take_damage(99999)`): glow hidden, no errors; after 4 s the pad is free.
  - **End screen:** with an evolved tower standing, trigger defeat (`core.health.take_damage(99999)`), wait for the end screen and screenshot it: the towers row shows the tinted icon labelled "Evolved".
  - Reset `gearshot.evolutions = []` at the end. `game_get_errors` shows nothing new. `stop_project`, `git checkout project.godot`.

- [ ] **Step 11: Commit**

```bash
git add scripts/towers/build_slot.gd scripts/towers/tower.gd scripts/towers/tower_glow.gd scenes/towers/tower_glow.tscn scripts/ui/evolve_card.gd scenes/ui/evolve_card.tscn scripts/ui/tower_menu.gd scenes/ui/tower_menu.tscn scripts/ui/hud.gd scripts/ui/game_over.gd
git add scripts/towers/*.uid scripts/ui/*.uid
git commit -m "Evolve Lv3 towers from the F menu

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Alias art tool and the Gatling Engine

**Files:**
- Create: `tools/alias_frames.py`, `assets/sprites/gatling_engine.tres`, `assets/sprites/storm_array.tres` (both generated)
- Create: `scripts/towers/gatling_definition.gd`, `scripts/towers/gatling_tower.gd`, `scenes/towers/gatling_tower.tscn`, `data/towers/gatling_engine.tres`
- Modify: `scripts/towers/tower.gd` (split `_fire_at` into `_fire_at` + `_launch_bolt`)
- Modify: `tests/test_evolutions.gd`

**Interfaces:**
- Consumes: Task 1–2.
- Produces: `Tower._launch_bolt(bolt: Projectile, point: Vector2) -> void` (positions, aims, sets `damage = damage()` and `max_distance`, adds it, shows the shot); `class_name GatlingDefinition` (`spin_up_time`, `spin_down_time`, `max_spin_multiplier`, `shot_damage_multiplier`, `muzzle_offset`, `spin_after(spin, delta, firing) -> float`, `spin_multiplier(spin) -> float`); `class_name GatlingTower` (`spin: float`).

- [ ] **Step 1: Failing test.** In `tests/test_evolutions.gd` set `EXPECTED` to `{&"gearshot": [&"gatling_engine"]}` (Task 4 adds `rune_cannon`) and add, before the final `print`:

```gdscript
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
```

Run `godot --headless --path . --script tests/test_evolutions.gd`. Expected: FAIL on "gearshot branches" and "gatling data exists".

- [ ] **Step 2: The alias tool** `tools/alias_frames.py`:

```python
"""Write SpriteFrames that reuse another sheet's frames under new animation
names, so a spare sheet can stand in for an evolved tower (which only needs
lv3_idle, lv3_fire and destroyed).

Run from the project root after tools/slice_sprites.py:
    python3 tools/alias_frames.py
"""
import os
import re

OUT_DIR = "assets/sprites"

# New SpriteFrames -> (source sheet, [(new animation, source animation,
# frame indices or None for all, frames per second, loops)]).
ALIASES = {
    # The blaster faces right; its idle row turns the barrel, so idle is the
    # first frame only. Fire frames 1-5 glow; the last destroy frame is the wreck.
    "gatling_engine": ("blaster_turret", [
        ("lv3_idle", "idle", [0], 1, True),
        ("lv3_fire", "fire", [1, 2, 3, 4, 5], 30, False),
        ("destroyed", "destroy", [7], 1, False)]),
    "storm_array": ("aether_harvester", [
        ("lv3_idle", "lv3_idle", None, 6, True),
        ("lv3_fire", "lv3_pulse", None, 8, True),
        ("destroyed", "destroyed", None, 1, False)]),
}


def parse(name):
    """Animation name -> list of Rect2 regions, and the foot offset."""
    with open(os.path.join(OUT_DIR, name + ".tres")) as fh:
        text = fh.read()
    regions = dict(re.findall(
        r'id="(AtlasTexture_\d+)"\]\natlas = ExtResource\("1"\)\nregion = (Rect2\([^)]*\))', text))
    anims = {}
    for frames, anim in re.findall(r'"frames": \[(.*?)\],\n"loop": \w+,\n"name": &"([^"]+)"', text, re.S):
        anims[anim] = [regions[i] for i in re.findall(r'SubResource\("(AtlasTexture_\d+)"\)', frames)]
    foot = re.search(r'metadata/foot_offset = (Vector2\([^)]*\))', text).group(1)
    return anims, foot


def write(name, source, aliases):
    anims, foot = parse(source)
    subs, defs, sid = [], [], 0
    for new, src, picks, speed, loop in aliases:
        regions = anims[src] if picks is None else [anims[src][i] for i in picks]
        refs = []
        for region in regions:
            sid += 1
            subs.append(f'[sub_resource type="AtlasTexture" id="AtlasTexture_{sid}"]\n'
                        f'atlas = ExtResource("1")\nregion = {region}\n')
            refs.append(f'{{\n"duration": 1.0,\n"texture": SubResource("AtlasTexture_{sid}")\n}}')
        defs.append(f'{{\n"frames": [{", ".join(refs)}],\n"loop": {str(loop).lower()},\n'
                    f'"name": &"{new}",\n"speed": {speed}.0\n}}')
    path = os.path.join(OUT_DIR, name + ".tres")
    # Keep the uid Godot gave the file, so resources that point at it stay valid.
    uid = ""
    if os.path.exists(path):
        with open(path) as fh:
            found = re.search(r' uid="([^"]+)"', fh.readline())
        uid = f' uid="{found.group(1)}"' if found else ""
    text = (f'[gd_resource type="SpriteFrames" load_steps={sid + 2} format=3{uid}]\n\n'
            f'[ext_resource type="Texture2D" path="res://{OUT_DIR}/{source}.png" id="1"]\n\n'
            + "\n".join(subs)
            + f'\n[resource]\nanimations = [{", ".join(defs)}]\n'
            + f'metadata/foot_offset = {foot}\n')
    with open(path, "w") as fh:
        fh.write(text)
    print(f"{name}: " + ", ".join(f"{a[0]}:{len(anims[a[1]]) if a[2] is None else len(a[2])}" for a in aliases))


if __name__ == "__main__":
    for out, (src, aliases) in ALIASES.items():
        write(out, src, aliases)
```

Run: `python3 tools/alias_frames.py`
Expected: `gatling_engine: lv3_idle:1, lv3_fire:5, destroyed:1` and `storm_array: lv3_idle:4, lv3_fire:4, destroyed:2`. Add a line about it to the docstring of `tools/slice_sprites.py` ("Evolved towers that borrow a spare sheet: run tools/alias_frames.py afterwards.").

- [ ] **Step 3: Tower refactor.** In `scripts/towers/tower.gd`, replace `_fire_at` with:

```gdscript
func _fire_at(point: Vector2) -> void:
	_launch_bolt(BOLT_SCENE.instantiate(), point)


## Fires `bolt` from the muzzle toward `point` with this tower's damage and
## reach, and shows the shot (flash and recoil, or the fire frame).
func _launch_bolt(bolt: Projectile, point: Vector2) -> void:
	var base := _muzzle_base()
	var direction := (point - base).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	bolt.global_position = base + direction * _barrel_length()
	bolt.direction = direction
	bolt.speed = definition.projectile_speed
	bolt.damage = damage()
	# Operated shots fly exactly the (boosted) range; automatic ones a bit
	# past it so they can reach a target that walked out while in flight.
	bolt.max_distance = attack_range() if operator else attack_range() + 60.0
	projectile_parent.add_child(bolt)
	if _has_head():
		muzzle_flash.flash(FIRE_FRAME_TIME)
		head.position = _head_rest - direction * RECOIL
	else:
		_show(&"fire")
		_fire_frame_left = FIRE_FRAME_TIME
```

- [ ] **Step 4: Gatling definition** `scripts/towers/gatling_definition.gd`:

```gdscript
class_name GatlingDefinition
extends TowerDefinition
## A Gatling Engine's extra settings (an evolved Gearshot): it spins up while
## it keeps firing, each shot weaker than a Gearshot's.

@export_group("Spin")
## Seconds of continuous firing to reach full spin.
@export var spin_up_time := 2.0
## Seconds to wind down from full spin once it stops firing.
@export var spin_down_time := 1.0
## Fire rate multiplier at full spin (1 when still).
@export var max_spin_multiplier := 4.0
## Share of the Gearshot's damage each shot deals.
@export var shot_damage_multiplier := 0.65
## Where shots leave from, relative to the base point, facing right.
@export var muzzle_offset := Vector2(50, -55)


## Spin (0..1) after `delta` more seconds of firing or not firing.
func spin_after(spin: float, delta: float, firing: bool) -> float:
	if firing:
		return minf(spin + delta / spin_up_time, 1.0)
	return maxf(spin - delta / spin_down_time, 0.0)


## Fire rate multiplier at `spin`.
func spin_multiplier(spin: float) -> float:
	return 1.0 + (max_spin_multiplier - 1.0) * spin
```

- [ ] **Step 5: Gatling tower** `scripts/towers/gatling_tower.gd`:

```gdscript
class_name GatlingTower
extends Tower
## The Gatling Engine (an evolved Gearshot): spins up while it keeps firing,
## from 1× to 4× fire rate over 2 s, each shot weaker, and winds down over
## 1 s once it stops. Faces left or right (mirrored art). Q = Overspin: full
## spin at once, held for the ability's duration.

## Still counts as firing this long past the gap to its next shot.
const SPIN_GRACE := 0.1

var gatling: GatlingDefinition
## 0 = still, 1 = full spin.
var spin := 0.0
var _since_shot := INF
var _facing_left := false


func _ready() -> void:
	gatling = definition as GatlingDefinition
	assert(gatling != null, "A GatlingTower needs a GatlingDefinition")
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	_since_shot += delta
	if _ability_left > 0.0:
		spin = 1.0
	else:
		spin = gatling.spin_after(spin, delta, _since_shot <= 1.0 / fire_rate() + SPIN_GRACE)


func damage() -> float:
	return super() * gatling.shot_damage_multiplier


func fire_rate() -> float:
	return super() * gatling.spin_multiplier(spin)


func _aim_at(point: Vector2) -> void:
	_facing_left = point.x < global_position.x
	sprite.flip_h = _facing_left


func _muzzle_base() -> Vector2:
	var offset := gatling.muzzle_offset
	return global_position + Vector2(-offset.x if _facing_left else offset.x, offset.y)


func _fire_at(point: Vector2) -> void:
	super(point)
	_since_shot = 0.0
```

`scenes/towers/gatling_tower.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://scenes/towers/tower.tscn" id="1_tower"]
[ext_resource type="Script" path="res://scripts/towers/gatling_tower.gd" id="2_gatling"]

[node name="GatlingTower" instance=ExtResource("1_tower")]
script = ExtResource("2_gatling")
```

- [ ] **Step 6: Gatling data** `data/towers/gatling_engine.tres` (Gearshot's stats are the defaults, so none are listed; `barrel_length = 0` because `muzzle_offset` already ends at the barrel tip):

```
[gd_resource type="Resource" script_class="GatlingDefinition" format=3]

[ext_resource type="Script" path="res://scripts/towers/gatling_definition.gd" id="1_def"]
[ext_resource type="SpriteFrames" path="res://assets/sprites/gatling_engine.tres" id="2_frames"]
[ext_resource type="PackedScene" path="res://scenes/towers/gatling_tower.tscn" id="3_scene"]

[resource]
script = ExtResource("1_def")
id = &"gatling_engine"
display_name = "Gatling Engine"
description = "Spins up while firing until it pours out bullets. Shreds swarms."
evolved = true
evolve_cost = Dictionary[StringName, int]({
&"aether": 6
})
help_line = "Spins up while it keeps firing: up to 4× fire rate, 65% damage per shot. Shreds swarms."
damage_type_label = "Physical"
good_against = "Big swarms that keep it firing"
weak_against = "Armour; short fights (it has to spin up)"
ability_name = "Overspin"
ability_text = "Instantly at full spin, and it won't slow down for 4 s."
ability_duration = 4.0
ability_cooldown = 12.0
ability_fire_rate_multiplier = 1.0
sprite_frames = ExtResource("2_frames")
sprite_scale = 0.45
scene = ExtResource("3_scene")
barrel_length = 0.0
```

In `data/towers/gearshot.tres`, add `[ext_resource type="Resource" path="res://data/towers/gatling_engine.tres" id="10_gatling"]` and, in `[resource]`, `evolutions = Array[ExtResource("1_def")]([ExtResource("10_gatling")])` (Rune Cannon is added in Task 4). Note: the typed-array syntax for a Resource subtype written by Godot is `Array[Resource]([...])` if `Array[ExtResource(...)]` fails to parse; if loading the file errors, open it in the editor once (`launch_editor`), set the array there and save.

- [ ] **Step 7: Import, test.** `godot --headless --editor --path . --import`, then the headless tests. Expected: all pass.

- [ ] **Step 8: In-game checks.** Load the world, build + upgrade a Gearshot on `BuildSlotWest` to Lv3, evolve into `gatling_engine`.
  - **Art fit:** screenshot it beside a normal Lv3 Gearshot on `BuildSlotEast`. Tune `sprite_scale` (target: about the same footprint as the Lv3 Gearshot) and `muzzle_offset` (bullets leave the barrel tip, both facings) in the .tres; re-check. Its wreck shows the `destroyed` frame when killed.
  - **Spin-up:** one frozen 99999-health goblin 180 px left. Over 4 s, sample `t.spin` and `t.fire_rate()` every 0.5 s: spin ≈ 0.25 per 0.5 s up to 1.0 by ~2 s; fire rate goes from ≈ 1.98 (Lv3) to ≈ 7.9. Count shots in the 2nd second vs the 4th (the 4th is ≈ 3–4× more). Damage per bullet ≈ 0.65 × Lv3 (`t.damage()` ≈ 8 × 1.69 × 0.65 ≈ 8.8).
  - **Wind-down:** kill the goblin; after 0.5 s spin ≈ 0.5, after 1 s ≈ 0.
  - **Overspin:** operate it (`hero.start_operating(t)`), `t.use_ability()` with no target: spin is 1.0 at once and stays 1.0 for 4 s; cooldown 12 s; HUD reads "Overspin active".
  - No new errors. `stop_project`, `git checkout project.godot`.

- [ ] **Step 9: Commit**

```bash
git add tools/alias_frames.py tools/slice_sprites.py assets/sprites/gatling_engine.tres assets/sprites/storm_array.tres scripts/towers/tower.gd scripts/towers/gatling_definition.gd scripts/towers/gatling_tower.gd scenes/towers/gatling_tower.tscn data/towers/gatling_engine.tres data/towers/gearshot.tres tests/test_evolutions.gd scripts/towers/*.uid
git commit -m "Add the Gatling Engine evolution and the alias art tool

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Rune Cannon

**Files:**
- Modify: `scripts/projectiles/projectile.gd` (extract `_health_of`)
- Create: `scripts/projectiles/piercing_projectile.gd`, `scenes/projectiles/rune_round.tscn`
- Create: `scripts/towers/cannon_definition.gd`, `scripts/towers/rune_cannon_tower.gd`, `scenes/towers/rune_cannon_tower.tscn`, `data/towers/rune_cannon.tres`
- Modify: `data/towers/gearshot.tres`

**Interfaces:**
- Consumes: `Tower._launch_bolt(bolt, point)` (Task 3).
- Produces: `Projectile._health_of(target: Node) -> Health` (static); `class_name PiercingProjectile` (`pierce: int` — 0 = unlimited, `splash_share: float`, `splash_radius: float`); `class_name CannonDefinition`; `class_name RuneCannonTower`.

- [ ] **Step 1: Failing test.** In `EXPECTED`, make the Gearshot entry `[&"gatling_engine", &"rune_cannon"]`; run the test. Expected: FAIL "gearshot branches".

- [ ] **Step 2: Projectile helper.** In `scripts/projectiles/projectile.gd`, replace the two lookup lines in `_on_hit` with `var health := _health_of(target)` and add:

```gdscript
## The Health on the hit body/area or on its parent, or null.
static func _health_of(target: Node) -> Health:
	var health := target.get_node_or_null(^"Health") as Health
	if health == null:
		health = target.get_parent().get_node_or_null(^"Health") as Health
	return health
```

- [ ] **Step 3: Piercing projectile** `scripts/projectiles/piercing_projectile.gd`:

```gdscript
class_name PiercingProjectile
extends Projectile
## A round that passes through enemies: it hits each one once, splashes
## part of every hit onto other enemies near it, and is spent after `pierce`
## different enemies (0 = never; it flies its whole distance).

var pierce := 3
## Share of each hit's damage dealt to other enemies within splash_radius.
var splash_share := 0.4
var splash_radius := 50.0

## Instance ids of the enemies already hit, so overlapping shapes on the same
## enemy never count twice.
var _hit_ids := {}


func _on_hit(target: Node) -> void:
	if _spent:
		return
	var health := _health_of(target)
	if health == null or health.is_dead or health.invulnerable:
		return
	var victim := health.get_parent()
	if _hit_ids.has(victim.get_instance_id()):
		return
	_hit_ids[victim.get_instance_id()] = true
	var dealt := health.take_damage(damage, damage_type)
	struck.emit(victim)
	hit.emit(dealt, health.is_dead)
	_splash(victim as Node2D)
	if pierce > 0 and _hit_ids.size() >= pierce:
		_spent = true
		queue_free()


## Damages every other living enemy within splash_radius of `centre`.
func _splash(centre: Node2D) -> void:
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == centre or enemy.health.is_dead:
			continue
		if enemy.global_position.distance_to(centre.global_position) <= splash_radius:
			var dealt := enemy.health.take_damage(damage * splash_share, damage_type)
			hit.emit(dealt, enemy.health.is_dead)
```

`scenes/projectiles/rune_round.tscn` (like `hero_bolt.tscn`, violet and a bit bigger):

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/projectiles/piercing_projectile.gd" id="1_round"]

[sub_resource type="CircleShape2D" id="CircleShape2D_round"]
radius = 8.0

[node name="RuneRound" type="Area2D"]
collision_layer = 0
collision_mask = 4
monitorable = false
script = ExtResource("1_round")
color = Color(0.78, 0.55, 1, 1)
radius = 7.0

[node name="Shape" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_round")
```

- [ ] **Step 4: Cannon definition** `scripts/towers/cannon_definition.gd`:

```gdscript
class_name CannonDefinition
extends TowerDefinition
## A Rune Cannon's extra settings (an evolved Gearshot): slow, heavy magic
## rounds that pierce and splash, and the Overcharge Round ability.

@export_group("Rune rounds")
@export var fire_rate_multiplier := 0.3
@export var damage_multiplier := 3.5
## Different enemies one round hits before it's spent.
@export var pierce_count := 3
## Share of each hit's damage splashed onto other enemies within splash_radius.
@export var splash_share := 0.4
@export var splash_radius := 50.0

@export_group("Overcharge Round")
@export var overcharge_damage_multiplier := 4.0
## How much farther than its range the round flies.
@export var overcharge_range_multiplier := 1.5
```

- [ ] **Step 5: Cannon tower** `scripts/towers/rune_cannon_tower.gd`:

```gdscript
class_name RuneCannonTower
extends Tower
## The Rune Cannon (an evolved Gearshot): slow, heavy magic rounds that pass
## through up to 3 enemies and splash each hit. Q = Overcharge Round: one 4×
## round at the mouse that pierces everything and flies farther.

const ROUND_SCENE := preload("res://scenes/projectiles/rune_round.tscn")

var cannon: CannonDefinition


func _ready() -> void:
	cannon = definition as CannonDefinition
	assert(cannon != null, "A RuneCannonTower needs a CannonDefinition")
	super()


func damage() -> float:
	return super() * cannon.damage_multiplier


func fire_rate() -> float:
	return super() * cannon.fire_rate_multiplier


func _fire_at(point: Vector2) -> void:
	_launch_bolt(_make_round(cannon.pierce_count), point)


## Fires an Overcharge Round at the mouse if it's recharged.
func use_ability() -> void:
	if operator == null or _ability_cooldown_left > 0.0:
		return
	_ability_cooldown_left = definition.ability_cooldown
	var shot := _make_round(0)
	_launch_bolt(shot, _operated_aim_point())
	shot.damage *= cannon.overcharge_damage_multiplier
	shot.max_distance = attack_range() * cannon.overcharge_range_multiplier
	shot.radius *= 1.6


func _make_round(pierce: int) -> PiercingProjectile:
	var shot: PiercingProjectile = ROUND_SCENE.instantiate()
	shot.pierce = pierce
	shot.splash_share = cannon.splash_share
	shot.splash_radius = cannon.splash_radius
	shot.damage_type = Health.DamageType.MAGIC
	return shot
```

`scenes/towers/rune_cannon_tower.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://scenes/towers/tower.tscn" id="1_tower"]
[ext_resource type="Script" path="res://scripts/towers/rune_cannon_tower.gd" id="2_cannon"]

[node name="RuneCannonTower" instance=ExtResource("1_tower")]
script = ExtResource("2_cannon")
```

- [ ] **Step 6: Cannon data** `data/towers/rune_cannon.tres`. It keeps the Gearshot's rotating heads, so copy the Gearshot's three `TurretHead` sub-resources and their texture ext_resources **verbatim** from `data/towers/gearshot.tres` (ids `3_base`…`9_head3`, `5_head`, `TurretHead_lv1..3`), then:

```
[gd_resource type="Resource" script_class="CannonDefinition" format=3]

[ext_resource type="Script" path="res://scripts/towers/cannon_definition.gd" id="1_def"]
[ext_resource type="SpriteFrames" uid="uid://dj8ebqumbyqy1" path="res://assets/sprites/gearshot.tres" id="2_frames"]
[ext_resource type="PackedScene" path="res://scenes/towers/rune_cannon_tower.tscn" id="10_scene"]
… (the Gearshot's head textures, turret_head.gd and TurretHead sub-resources, copied) …

[resource]
script = ExtResource("1_def")
id = &"rune_cannon"
display_name = "Rune Cannon"
description = "Slow, heavy magic rounds that punch through a line of enemies."
evolved = true
evolve_cost = Dictionary[StringName, int]({
&"aether": 6
})
help_line = "Slow, heavy magic rounds that pierce 3 enemies and splash each hit. Answers armour."
damage_type_label = "Magic"
good_against = "Armour and enemies coming in a line"
weak_against = "Fast swarms (few shots)"
ability_name = "Overcharge Round"
ability_text = "One 4× round that pierces every enemy in its path and flies 1.5× as far."
ability_cooldown = 12.0
ability_fire_rate_multiplier = 1.0
tint = Color(0.78, 0.55, 1, 1)
glow = Color(0.78, 0.55, 1, 0.8)
sprite_frames = ExtResource("2_frames")
sprite_scale = 0.605
scene = ExtResource("10_scene")
heads = Array[ExtResource("5_head")]([SubResource("TurretHead_lv1"), SubResource("TurretHead_lv2"), SubResource("TurretHead_lv3")])
muzzle_height = 50.0
barrel_length = 30.0
```

Add it to the Gearshot's `evolutions` after `gatling_engine`.

- [ ] **Step 7: Import, test.** `godot --headless --editor --path . --import`; run all headless tests. Expected: all pass.

- [ ] **Step 8: In-game checks.** Evolve a Lv3 Gearshot on `BuildSlotWest` into `rune_cannon`.
  - **Look:** violet tint + glow, 10% bigger; screenshot.
  - **Rate and damage:** `t.fire_rate()` ≈ 1.98 × 0.3 ≈ 0.59; `t.damage()` ≈ 13.5 × 3.5 ≈ 47.3.
  - **Pierce:** four frozen 99999-health goblins in a row 140, 170, 200, 230 px left of the tower (same y). Fire one round at the first (`t._fire_at(first.hurtbox_shape.global_position)`); after 0.6 s: the first three each lost ≈ 47.3 + splash from neighbours within 50 px (each of those hits splashes 40% = 18.9 on neighbours), the 4th only splash (≈ 18.9 from the 3rd's hit); the round is gone. Damage type is magic (an Armored Goblin in the row takes 100%).
  - **Review Focus 5:** two goblins at the exact same spot plus one 30 px behind: each stacked goblin is hit once directly (≈ 47.3) plus 18.9 splash from the other's hit — never 2 × 47.3; the struck enemy never takes splash from its own hit. Pierce counts 3 distinct enemies.
  - **Overcharge:** operated, mouse on a line of 5 frozen goblins: `use_ability()` hits all 5 for ≈ 47.3 × 1.35 (operated) × 4 each, flies `attack_range() × 1.5`; cooldown 12 s. Q again while cooling: nothing.
  - No new errors. `stop_project`, `git checkout project.godot`.

- [ ] **Step 9: Commit**

```bash
git add scripts/projectiles/projectile.gd scripts/projectiles/piercing_projectile.gd scenes/projectiles/rune_round.tscn scripts/towers/cannon_definition.gd scripts/towers/rune_cannon_tower.gd scenes/towers/rune_cannon_tower.tscn data/towers/rune_cannon.tres data/towers/gearshot.tres scripts/projectiles/*.uid scripts/towers/*.uid
git commit -m "Add the Rune Cannon evolution with piercing rune rounds

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Siege Battery

**Files:**
- Modify: `scripts/towers/mortar_tower.gd` (split `_launch` into `_make_shell` + `_launch`)
- Create: `scripts/towers/siege_definition.gd`, `scripts/towers/siege_tower.gd`, `scenes/towers/siege_tower.tscn`, `data/towers/siege_battery.tres`
- Modify: `data/towers/rune_mortar.tres`, `tests/test_evolutions.gd`

**Interfaces:**
- Produces: `MortarTower._make_shell(point: Vector2, shell_damage: float, radius: float, rune_duration: float) -> Shell` (not yet added to the tree); `class_name SiegeDefinition extends MortarDefinition`; `class_name SiegeTower extends MortarTower`.

- [ ] **Step 1: Failing test.** Add `&"rune_mortar": [&"siege_battery"]` to `EXPECTED`. Run. Expected: FAIL "rune_mortar branches".

- [ ] **Step 2: Mortar refactor.** In `scripts/towers/mortar_tower.gd` replace `_launch` with:

```gdscript
func _launch(point: Vector2, shell_damage: float, radius: float, rune_duration: float) -> void:
	projectile_parent.add_child(_make_shell(point, shell_damage, radius, rune_duration))


## A shell from the muzzle to `point`, set up but not fired yet.
func _make_shell(point: Vector2, shell_damage: float, radius: float, rune_duration: float) -> Shell:
	var shell: Shell = SHELL_SCENE.instantiate()
	shell.from = _muzzle_base()
	shell.target = point
	shell.flight_time = mortar.shell_flight_time
	shell.arc_height = mortar.shell_arc_height
	shell.damage = shell_damage
	shell.radius = radius
	shell.rune_duration = rune_duration
	shell.rune_slow = mortar.rune_slow
	return shell
```

- [ ] **Step 3: Siege definition** `scripts/towers/siege_definition.gd`:

```gdscript
class_name SiegeDefinition
extends MortarDefinition
## A Siege Battery's extra settings (an evolved Rune Mortar): salvos of
## shells, and the Bombardment ability.

@export_group("Salvo")
@export var salvo_shells := 3
## The extra shells land within this of the target, in pixels.
@export var salvo_scatter := 40.0
## Seconds between the shells of a salvo.
@export var salvo_gap := 0.1
## Share of the Mortar's damage each shell deals.
@export var shell_damage_multiplier := 0.7
## Blast radius multiplier.
@export var blast_multiplier := 1.3
@export var fire_rate_multiplier := 0.6

@export_group("Bombardment")
@export var bombard_shells := 6
## Bombardment shells land within this of the mouse, in pixels.
@export var bombard_scatter := 120.0
```

- [ ] **Step 4: Siege tower** `scripts/towers/siege_tower.gd`:

```gdscript
class_name SiegeTower
extends MortarTower
## The Siege Battery (an evolved Rune Mortar): each shot is a salvo of 3
## weaker shells with bigger blasts, the first on the target and the rest
## scattered around it. Q = Bombardment: 6 full-strength shells scattered
## around the mouse.

var siege: SiegeDefinition
## Shells still to launch this salvo: [seconds left, point, damage].
var _queued: Array = []


func _ready() -> void:
	siege = definition as SiegeDefinition
	assert(siege != null, "A SiegeTower needs a SiegeDefinition")
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	for i in range(_queued.size() - 1, -1, -1):
		_queued[i][0] -= delta
		if _queued[i][0] <= 0.0:
			var shot: Array = _queued[i]
			_queued.remove_at(i)
			_launch(shot[1], shot[2], splash_radius(), 0.0)


func fire_rate() -> float:
	return super() * siege.fire_rate_multiplier


func splash_radius() -> float:
	return super() * siege.blast_multiplier


func _fire_at(point: Vector2) -> void:
	_salvo(point, siege.salvo_shells, siege.salvo_scatter, damage() * siege.shell_damage_multiplier)
	_show(&"fire")
	_fire_frame_left = 0.35


## Fires a Bombardment around the mouse if it's recharged.
func use_ability() -> void:
	if operator == null or _ability_cooldown_left > 0.0:
		return
	_ability_cooldown_left = definition.ability_cooldown
	var point := _operated_aim_point()
	_aim_at(point)
	_salvo(point, siege.bombard_shells, siege.bombard_scatter, damage())
	_show(&"fire")
	_fire_frame_left = 0.35


## Launches one shell at `point` now and queues `count - 1` more, salvo_gap
## apart, at random spots within `scatter` of it.
func _salvo(point: Vector2, count: int, scatter: float, shell_damage: float) -> void:
	_launch(point, shell_damage, splash_radius(), 0.0)
	for i in range(1, count):
		var spot := point + Vector2.from_angle(randf() * TAU) * scatter * sqrt(randf())
		_queued.append([siege.salvo_gap * i, spot, shell_damage])
```

`scenes/towers/siege_tower.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://scenes/towers/mortar_tower.tscn" id="1_mortar"]
[ext_resource type="Script" path="res://scripts/towers/siege_tower.gd" id="2_siege"]

[node name="SiegeTower" instance=ExtResource("1_mortar")]
script = ExtResource("2_siege")
```

- [ ] **Step 5: Siege data** `data/towers/siege_battery.tres` (copies the Rune Mortar's stats; take the Mortar's `sprite_frames` ext_resource line, with its uid, from `data/towers/rune_mortar.tres`):

```
[gd_resource type="Resource" script_class="SiegeDefinition" format=3]

[ext_resource type="Script" path="res://scripts/towers/siege_definition.gd" id="1_def"]
[ext_resource type="SpriteFrames" path="res://assets/sprites/rune_mortar.tres" id="2_frames"]
[ext_resource type="PackedScene" path="res://scenes/towers/siege_tower.tscn" id="3_scene"]

[resource]
script = ExtResource("1_def")
id = &"siege_battery"
display_name = "Siege Battery"
description = "Fires salvos of rune shells over a wide area."
evolved = true
evolve_cost = Dictionary[StringName, int]({
&"aether": 6
})
help_line = "Fires 3-shell salvos with bigger blasts (70% damage each). Crushes clusters."
damage_type_label = "Magic"
good_against = "Big clusters, far away"
weak_against = "Anything right next to it (can't fire that close)"
ability_name = "Bombardment"
ability_text = "6 full-strength shells rain down around the mouse."
ability_cooldown = 14.0
tint = Color(1, 0.7, 0.4, 1)
glow = Color(1, 0.7, 0.4, 0.8)
sprite_frames = ExtResource("2_frames")
sprite_scale = 0.605
scene = ExtResource("3_scene")
max_health = 150.0
attack_damage = 14.0
attacks_per_second = 0.5
attack_range = 420.0
operated_damage_multiplier = 1.35
operated_fire_rate_multiplier = 1.0
operated_range_multiplier = 1.15
```

Add it to `data/towers/rune_mortar.tres`'s `evolutions` (Frost is added in Task 6).

- [ ] **Step 6: Import, test.** Expected: all pass.

- [ ] **Step 7: In-game checks.** Evolve a Lv3 Mortar on `BuildSlotEast` into `siege_battery`.
  - **Look:** orange tint + glow; screenshot.
  - **Salvo:** a cluster of 5 frozen 99999-health goblins 260 px right. `t._fire_at(cluster_centre)`: within 0.25 s, 3 `Shell`s exist (filter children by `scene_file_path`); each has `damage ≈ 14 × 1.69 × 0.7 ≈ 16.6` and `radius ≈ 70 × 1.3 = 91`; the 2nd and 3rd targets lie within 40 px of the first.
  - **Rate:** `t.fire_rate()` ≈ 0.5 × 1.32 × 0.6 ≈ 0.40.
  - **Bombardment:** operated, `use_ability()`: 6 shells over 0.5 s, each `damage ≈ 22.8 × 1.35`, targets within 120 px of the mouse; cooldown 14 s.
  - **Sold mid-salvo:** fire a salvo and sell the tower on the same frame: no errors (queued shells just don't launch).
  - No new errors. `stop_project`, `git checkout project.godot`.

- [ ] **Step 8: Commit**

```bash
git add scripts/towers/mortar_tower.gd scripts/towers/siege_definition.gd scripts/towers/siege_tower.gd scenes/towers/siege_tower.tscn data/towers/siege_battery.tres data/towers/rune_mortar.tres tests/test_evolutions.gd scripts/towers/*.uid
git commit -m "Add the Siege Battery evolution

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Frost Rune Mortar

**Files:**
- Modify: `scripts/projectiles/shell.gd` (freeze on landing)
- Create: `scripts/towers/frost_definition.gd`, `scripts/towers/frost_tower.gd`, `scenes/towers/frost_tower.tscn`, `data/towers/frost_mortar.tres`
- Modify: `data/towers/rune_mortar.tres`

**Interfaces:**
- Consumes: `MortarTower._make_shell(...)` (Task 5), `Enemy.stun(seconds)`.
- Produces: `Shell.freeze_radius: float`, `Shell.freeze_time: float`; `class_name FrostDefinition extends MortarDefinition`; `class_name FrostTower extends MortarTower`.

- [ ] **Step 1: Failing test.** Make the `EXPECTED` Mortar entry `[&"siege_battery", &"frost_mortar"]`; run the test. Expected: FAIL "rune_mortar branches".

- [ ] **Step 2: Shell freeze.** In `scripts/projectiles/shell.gd`, add under `rune_slow`:

```gdscript
## Enemies within this of the landing spot are frozen (stunned)...
var freeze_radius := 0.0
## ...for this many seconds; 0 = no freeze.
var freeze_time := 0.0
```

and make the loop in `_land()`:

```gdscript
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		var distance := enemy.global_position.distance_to(target)
		if enemy.health.is_dead or distance > radius:
			continue
		var dealt := enemy.health.take_damage(damage, Health.DamageType.MAGIC)
		hit.emit(dealt, enemy.health.is_dead)
		if freeze_time > 0.0 and distance <= freeze_radius:
			enemy.stun(freeze_time)
```

Update the class comment: "…and can leave a RuneCircle that slows enemies, and freeze the ones closest to the impact."

- [ ] **Step 3: Frost definition** `scripts/towers/frost_definition.gd`:

```gdscript
class_name FrostDefinition
extends MortarDefinition
## A Frost Rune Mortar's extra settings (an evolved Rune Mortar): every shell
## leaves a frost circle and freezes what it lands on; Glacial Shell ability.

@export_group("Frost")
## Share of the Mortar's damage each shell deals.
@export var damage_multiplier := 0.8
## Share of speed taken away inside a frost circle (0.6 = 60% slower).
@export var frost_slow := 0.6
## Seconds a frost circle lasts.
@export var frost_duration := 6.0
## Enemies this close to the impact are frozen, in pixels...
@export var freeze_radius := 30.0
## ...for this many seconds.
@export var freeze_time := 0.6
@export var frost_color := Color(0.65, 0.9, 1.0)

@export_group("Glacial Shell")
@export var glacial_radius_multiplier := 2.0
## Seconds everything in a Glacial Shell's blast is frozen.
@export var glacial_freeze := 2.0
```

- [ ] **Step 4: Frost tower** `scripts/towers/frost_tower.gd`:

```gdscript
class_name FrostTower
extends MortarTower
## The Frost Rune Mortar (an evolved Rune Mortar): weaker shells that leave
## an icy circle slowing enemies 60% for 6 s and freeze anything within 30 px
## of the impact. Q = Glacial Shell: a double-size blast that freezes
## everything in it for 2 s.

var frost: FrostDefinition


func _ready() -> void:
	frost = definition as FrostDefinition
	assert(frost != null, "A FrostTower needs a FrostDefinition")
	super()


func damage() -> float:
	return super() * frost.damage_multiplier


func _fire_at(point: Vector2) -> void:
	var shell := _frost_shell(point, splash_radius())
	shell.freeze_radius = frost.freeze_radius
	shell.freeze_time = frost.freeze_time
	projectile_parent.add_child(shell)
	_show(&"fire")
	_fire_frame_left = 0.35


## Fires a Glacial Shell at the aim point if it's recharged.
func use_ability() -> void:
	if operator == null or _ability_cooldown_left > 0.0:
		return
	_ability_cooldown_left = definition.ability_cooldown
	var point := _operated_aim_point()
	_aim_at(point)
	var radius := splash_radius() * frost.glacial_radius_multiplier
	var shell := _frost_shell(point, radius)
	shell.freeze_radius = radius
	shell.freeze_time = frost.glacial_freeze
	projectile_parent.add_child(shell)
	_show(&"fire")
	_fire_frame_left = 0.35


## An icy shell that leaves a frost circle the size of its blast.
func _frost_shell(point: Vector2, radius: float) -> Shell:
	var shell := _make_shell(point, damage(), radius, frost.frost_duration)
	shell.rune_slow = frost.frost_slow
	shell.color = frost.frost_color
	return shell
```

`scenes/towers/frost_tower.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://scenes/towers/mortar_tower.tscn" id="1_mortar"]
[ext_resource type="Script" path="res://scripts/towers/frost_tower.gd" id="2_frost"]

[node name="FrostTower" instance=ExtResource("1_mortar")]
script = ExtResource("2_frost")
```

- [ ] **Step 5: Frost data** `data/towers/frost_mortar.tres`: same header and stat lines as `siege_battery.tres` but with `script_class="FrostDefinition"`, `res://scripts/towers/frost_definition.gd`, `res://scenes/towers/frost_tower.tscn`, and:

```
id = &"frost_mortar"
display_name = "Frost Rune Mortar"
description = "Icy rune shells that slow and freeze where they land."
help_line = "Shells leave frost circles (60% slower for 6 s) and freeze what they hit directly. Controls lanes."
damage_type_label = "Magic"
good_against = "Holding a lane; slowing big waves"
weak_against = "Raw damage (80% per shell); anything right next to it"
ability_name = "Glacial Shell"
ability_text = "A double-size blast that freezes everything in it for 2 s."
ability_cooldown = 14.0
tint = Color(0.65, 0.9, 1, 1)
glow = Color(0.65, 0.9, 1, 0.8)
```

(plus `evolved = true`, the 6-Aether `evolve_cost`, `sprite_frames`, `sprite_scale = 0.605`, `scene`, and the Mortar stat lines exactly as in Task 5). Add it to `rune_mortar.tres`'s `evolutions` after `siege_battery`.

- [ ] **Step 6: Import, test.** All headless tests pass.

- [ ] **Step 7: In-game checks.** Evolve a Lv3 Mortar into `frost_mortar`.
  - **Look:** icy tint + glow; frost circles are pale blue; screenshot one.
  - **Circle and freeze:** a walking 99999-health goblin 260 px away and a second one 60 px from it. `t._fire_at(goblin1.global_position)`: after landing, goblin 1 `is_stunned()` for ≈ 0.6 s; goblin 2 (60 px, outside 30 px) is not stunned but `speed_multiplier()` ≈ 0.4 while inside the circle; the circle is gone after 6 s. Damage per shell ≈ 14 × 1.69 × 0.8 ≈ 18.9.
  - **Glacial Shell:** operated, mouse on a group of 4 goblins spread over 100 px: `use_ability()` freezes all of them within `splash_radius() × 2` for ≈ 2 s; cooldown 14 s.
  - **Bosses:** spawn `goblin_warchief.tres` and hit it with a Glacial Shell: it is stunned for 2 s (full strength, as decided).
  - Base Rune Mortar still behaves as before (Rune Shell leaves a normal blue circle, 40% slower).
  - No new errors. `stop_project`, `git checkout project.godot`.

- [ ] **Step 8: Commit**

```bash
git add scripts/projectiles/shell.gd scripts/towers/frost_definition.gd scripts/towers/frost_tower.gd scenes/towers/frost_tower.tscn data/towers/frost_mortar.tres data/towers/rune_mortar.tres scripts/towers/*.uid
git commit -m "Add the Frost Rune Mortar evolution

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Inferno

**Files:**
- Modify: `scripts/towers/ember_definition.gd`, `scripts/towers/ember_tower.gd:63-64` (`attack_range`)
- Create: `data/towers/inferno.tres`
- Modify: `data/towers/embercaster.tres`, `tests/test_evolutions.gd`

**Interfaces:**
- Produces: `EmberDefinition.cone_length_multiplier: float` (default 1.0).

- [ ] **Step 1: Failing test.** Add `&"embercaster": [&"inferno"]` to `EXPECTED`. Run. Expected: FAIL "embercaster branches".

- [ ] **Step 2: Cone length.** In `scripts/towers/ember_definition.gd`'s `Flame` group:

```gdscript
## Multiplies how far the flame reaches (the Inferno's longer cone).
@export var cone_length_multiplier := 1.0
```

and in `scripts/towers/ember_tower.gd`:

```gdscript
func attack_range() -> float:
	return super() * ember.cone_length_multiplier \
			* (ember.overpressure_range_multiplier if overpressure_active() else 1.0)
```

- [ ] **Step 3: Inferno data** `data/towers/inferno.tres` (uses the Embercaster's script and scene; take the `sprite_frames` and `scene` ext_resource lines, with uids, from `data/towers/embercaster.tres`):

```
[gd_resource type="Resource" script_class="EmberDefinition" format=3]

[ext_resource type="Script" path="res://scripts/towers/ember_definition.gd" id="1_def"]
[ext_resource type="SpriteFrames" path="res://assets/sprites/embercaster.tres" id="2_frames"]
[ext_resource type="PackedScene" path="res://scenes/towers/ember_tower.tscn" id="3_scene"]

[resource]
script = ExtResource("1_def")
id = &"inferno"
display_name = "Inferno"
description = "A longer, hotter flame whose burn stacks twice as high."
evolved = true
evolve_cost = Dictionary[StringName, int]({
&"aether": 6
})
help_line = "40% longer flame, and burn stacks up to 10. Melts crowds that reach it."
damage_type_label = "Fire"
good_against = "Crowds that reach it; tough enemies that stay in the fire"
weak_against = "Long range; it still has to refuel"
ability_name = "Overpressure"
ability_text = "3 s of free fuel, a wider cone and maximum burn."
ability_cooldown = 15.0
ability_fire_rate_multiplier = 1.0
tint = Color(1, 0.5, 0.45, 1)
glow = Color(1, 0.5, 0.45, 0.8)
sprite_frames = ExtResource("2_frames")
sprite_scale = 0.605
scene = ExtResource("3_scene")
max_health = 180.0
attack_damage = 3.0
attacks_per_second = 5.0
attack_range = 150.0
operated_fire_rate_multiplier = 1.0
cone_length_multiplier = 1.4
burn_max_stacks = 10
```

Add it to `embercaster.tres`'s `evolutions` (Oil Sprayer in Task 8).

- [ ] **Step 4: Import, test.** All pass.

- [ ] **Step 5: In-game checks.** Evolve a Lv3 Embercaster into `inferno`.
  - **Look:** deep red tint + glow; the flame visibly longer; screenshot while spraying.
  - **Reach:** `t.attack_range()` ≈ 150 × 1.21 × 1.4 ≈ 254; a frozen goblin 230 px away is hit, one at 270 px isn't.
  - **Stacks:** spray a frozen 99999-health goblin for 3 s: `burn_stacks()` reaches 10 (not 5). Overpressure: one tick sets it to 10.
  - Base Embercaster: still 5 stacks, range ≈ 182 at Lv3.
  - No new errors. `stop_project`, `git checkout project.godot`.

- [ ] **Step 6: Commit**

```bash
git add scripts/towers/ember_definition.gd scripts/towers/ember_tower.gd data/towers/inferno.tres data/towers/embercaster.tres tests/test_evolutions.gd
git commit -m "Add the Inferno evolution

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Oil Sprayer and enemy oil

**Files:**
- Modify: `scripts/enemies/enemy.gd` (oil state, `_physics_process`, `_update_tint`)
- Create: `scripts/towers/oil_definition.gd`, `scripts/towers/oil_tower.gd`, `scenes/towers/oil_tower.tscn`, `data/towers/oil_sprayer.tres`
- Modify: `data/towers/embercaster.tres`

**Interfaces:**
- Consumes: `EmberTower._enemies_in_cone(point)`, `burn_dps()`, `Enemy.add_burn(...)`, `Enemy.slow(factor, seconds)`.
- Produces: `Enemy.oil(seconds: float, slow_share: float, fire_bonus: float) -> void`, `Enemy.is_oiled() -> bool`, `Enemy.clear_oil() -> void`; `class_name OilDefinition extends EmberDefinition`; `class_name OilTower extends EmberTower`.

- [ ] **Step 1: Failing check.** Make the `EXPECTED` Embercaster entry `[&"inferno", &"oil_sprayer"]` and run the headless test (FAIL "embercaster branches"). In game: a spawned goblin `has_method(&"oil")` → `false`.

- [ ] **Step 2: Enemy oil.** In `scripts/enemies/enemy.gd`, next to the burn vars:

```gdscript
## Oil from an Oil Sprayer: slower, and more fire damage taken while it lasts.
var _oiled := false
var _oil_left := 0.0
## The extra fire damage this oil added (0.5 = +50%), so it can be taken off.
var _oil_bonus := 0.0
```

after `stun()`:

```gdscript
## Oils it for `seconds`: `slow_share` slower (0.3 = 30%) and `fire_bonus`
## more fire damage taken (0.5 = +50%). Oiling it again only refreshes the
## time; the bonus never stacks.
func oil(seconds: float, slow_share: float, fire_bonus: float) -> void:
	if health.is_dead:
		return
	if not _oiled:
		_oiled = true
		_oil_bonus = fire_bonus
		health.damage_taken[Health.DamageType.FIRE] *= 1.0 + fire_bonus
	_oil_left = maxf(_oil_left, seconds)
	slow(1.0 - slow_share, seconds)


func is_oiled() -> bool:
	return _oiled


## Takes the oil off (it burned away or wore off).
func clear_oil() -> void:
	if not _oiled:
		return
	_oiled = false
	_oil_left = 0.0
	health.damage_taken[Health.DamageType.FIRE] /= 1.0 + _oil_bonus
	_oil_bonus = 0.0
```

In `_physics_process`, right after the burn block (before `_update_tint()`):

```gdscript
	if _oiled:
		_oil_left -= delta
		if _oil_left <= 0.0:
			clear_oil()
```

In `_update_tint()`, after the frenzy branch and before burn:

```gdscript
	elif _oiled:
		sprite.modulate = Color.WHITE.lerp(Color(0.35, 0.3, 0.15), 0.45 + 0.1 * flicker) * definition.tint
```

and update its comment to "Stun (pale blue) shows over frenzy (red) over oil (dark) over burn (orange); all flicker."

- [ ] **Step 3: Oil definition** `scripts/towers/oil_definition.gd`:

```gdscript
class_name OilDefinition
extends EmberDefinition
## An Oil Sprayer's extra settings (an evolved Embercaster): a weaker flame
## that oils enemies, and the Ignite ability.

@export_group("Oil")
## Share of the Embercaster's flame (and burn) damage it deals.
@export var flame_damage_multiplier := 0.5
## Seconds oil lasts after the last hit.
@export var oil_seconds := 4.0
## Share of speed taken away while oiled.
@export var oil_slow := 0.3
## Extra fire damage an oiled enemy takes (0.5 = +50%).
@export var oil_fire_bonus := 0.5

@export_group("Ignite")
## Ignite's fire burst, as a multiple of the flame's damage.
@export var ignite_damage_multiplier := 3.0
```

- [ ] **Step 4: Oil tower** `scripts/towers/oil_tower.gd`:

```gdscript
class_name OilTower
extends EmberTower
## The Oil Sprayer (an evolved Embercaster): a weaker flame that oils
## everything it hits for 4 s (30% slower, +50% fire damage from any
## source). Q = Ignite: every oiled enemy in range takes a fire burst, goes
## to max burn and loses its oil.

var oil: OilDefinition


func _ready() -> void:
	oil = definition as OilDefinition
	assert(oil != null, "An OilTower needs an OilDefinition")
	super()


func damage() -> float:
	return super() * oil.flame_damage_multiplier


## Oils everything in the cone first, so the tick itself gets the bonus.
func _fire_at(point: Vector2) -> void:
	for enemy in _enemies_in_cone(point):
		enemy.oil(oil.oil_seconds, oil.oil_slow, oil.oil_fire_bonus)
	super(point)


## Ignites every oiled enemy in range, if it's recharged.
func use_ability() -> void:
	if operator == null or _ability_cooldown_left > 0.0:
		return
	_ability_cooldown_left = definition.ability_cooldown
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy.health.is_dead or not enemy.is_oiled() \
				or global_position.distance_to(enemy.global_position) > attack_range():
			continue
		enemy.health.take_damage(damage() * oil.ignite_damage_multiplier, Health.DamageType.FIRE)
		enemy.add_burn(burn_dps(), ember.burn_max_stacks, ember.burn_duration, ember.burn_max_stacks)
		enemy.clear_oil()
```

`scenes/towers/oil_tower.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://scenes/towers/ember_tower.tscn" id="1_ember"]
[ext_resource type="Script" path="res://scripts/towers/oil_tower.gd" id="2_oil"]

[node name="OilTower" instance=ExtResource("1_ember")]
script = ExtResource("2_oil")
```

- [ ] **Step 5: Oil data** `data/towers/oil_sprayer.tres`: same as `inferno.tres` but `script_class="OilDefinition"`, script `res://scripts/towers/oil_definition.gd`, scene `res://scenes/towers/oil_tower.tscn`, no `cone_length_multiplier` / `burn_max_stacks` lines, and:

```
id = &"oil_sprayer"
display_name = "Oil Sprayer"
description = "Sprays burning oil that slows enemies and makes them take more fire damage."
help_line = "Weaker flame (50%) that oils enemies: 30% slower and +50% fire damage from any source. Combos with fire."
damage_type_label = "Fire"
good_against = "Setting up other fire: Embercasters, burn, Ember Rounds"
weak_against = "Damage on its own (half an Embercaster's)"
ability_name = "Ignite"
ability_text = "Every oiled enemy in range bursts into flame: a big fire hit and maximum burn."
ability_cooldown = 10.0
tint = Color(0.8, 0.65, 0.35, 1)
glow = Color(0.8, 0.65, 0.35, 0.8)
```

Add it to `embercaster.tres`'s `evolutions` after `inferno`.

- [ ] **Step 6: Import, test.** All headless tests pass.

- [ ] **Step 7: In-game checks.** Evolve a Lv3 Embercaster into `oil_sprayer`.
  - **Oiling:** a walking 99999-health goblin in the cone: after one tick `is_oiled()`, `health.damage_taken[1] ≈ 1.5`, `speed_multiplier() ≈ 0.7`, dark tint. Flame tick damage ≈ 3 × 1.69 × 0.5 × 1.5 (oiled) ≈ 3.8 per tick. 4 s after the last tick: not oiled, `damage_taken[1] == 1.0`.
  - **Review Focus 3:** an Armored Goblin (fire `damage_taken` 0.6): oil → wait out (back to exactly 0.6, `is_equal_approx`); oil 10 times in a row (still 0.9, never 1.35); oil → Ignite (0.6 after); oil → kill → no errors. Print the value after each.
  - **Ignite:** operated, three oiled goblins in range and one oiled out of range: `use_ability()` hits the three for ≈ 3 × 1.69 × 0.5 × 1.35 (operated) × 3 × 1.5 fire each, sets `burn_stacks() == 5`, clears their oil; the far one keeps its oil. Cooldown 10 s.
  - **Combo:** an oiled goblin hit by a normal Embercaster takes 1.5× its tick damage.
  - No new errors. `stop_project`, `git checkout project.godot`.

- [ ] **Step 8: Commit**

```bash
git add scripts/enemies/enemy.gd scripts/towers/oil_definition.gd scripts/towers/oil_tower.gd scenes/towers/oil_tower.tscn data/towers/oil_sprayer.tres data/towers/embercaster.tres scripts/towers/*.uid
git commit -m "Add the Oil Sprayer evolution and enemy oil

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Storm Array

**Files:**
- Create: `scripts/towers/storm_definition.gd`, `scripts/towers/storm_tower.gd`, `scenes/towers/storm_tower.tscn`, `data/towers/storm_array.tres`
- Modify: `data/towers/aether_spire.tres`, `tests/test_evolutions.gd`

**Interfaces:**
- Consumes: `SpireTower._first_target`, `chain_from`, `_strike`, `spire` (SpireDefinition); `assets/sprites/storm_array.tres` (Task 3).
- Produces: `class_name StormDefinition extends SpireDefinition`; `class_name StormTower extends SpireTower` (`bolts_fired: int`).

- [ ] **Step 1: Failing test.** Add `&"aether_spire": [&"storm_array"]` to `EXPECTED`. Run. Expected: FAIL "aether_spire branches".

- [ ] **Step 2: Storm definition** `scripts/towers/storm_definition.gd`:

```gdscript
class_name StormDefinition
extends SpireDefinition
## A Storm Array's extra settings (an evolved Aether Spire): stunning bolts,
## and the Thunderstorm ability. Its jump_count and jump_falloff are set in
## its data file (8 jumps, no falloff).

@export_group("Storm")
## Every this-many-th bolt stuns everything it hits...
@export var stun_every := 5
## ...for this many seconds.
@export var stun_time := 0.5

@export_group("Thunderstorm")
## Seconds between strikes while the storm lasts (ability_duration).
@export var storm_interval := 0.25
## Jumps from each strike's target.
@export var storm_jumps := 2
@export var storm_stun := 0.5
```

- [ ] **Step 3: Storm tower** `scripts/towers/storm_tower.gd`:

```gdscript
class_name StormTower
extends SpireTower
## The Storm Array (an evolved Aether Spire): lightning that jumps 8 times
## with no falloff, and every 5th bolt stuns everything it hits. Q =
## Thunderstorm: for 4 s, a stunning strike on a random enemy in range every
## 0.25 s.

var storm: StormDefinition
## Bolts fired so far; every stun_every-th one stuns.
var bolts_fired := 0
var _storm_tick := 0.0


func _ready() -> void:
	storm = definition as StormDefinition
	assert(storm != null, "A StormTower needs a StormDefinition")
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	if _ability_left > 0.0:
		_storm_tick -= delta
		if _storm_tick <= 0.0:
			_storm_tick += storm.storm_interval
			_storm_strike()


func _fire_at(point: Vector2) -> void:
	var first := _first_target(point)
	if first == null:
		return
	bolts_fired += 1
	var stun := storm.stun_time if bolts_fired % storm.stun_every == 0 else 0.0
	_strike(chain_from(first, spire.jump_count), damage(), spire.jump_falloff, stun)


## Starts a Thunderstorm if it's recharged.
func use_ability() -> void:
	if operator == null or _ability_cooldown_left > 0.0:
		return
	_ability_left = definition.ability_duration
	_ability_cooldown_left = definition.ability_cooldown
	_storm_tick = 0.0


## One storm strike on a random living enemy in range, if there is one.
func _storm_strike() -> void:
	var targets: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if not enemy.health.is_dead and global_position.distance_to(enemy.global_position) <= attack_range():
			targets.append(enemy)
	if targets.is_empty():
		return
	_strike(chain_from(targets.pick_random(), storm.storm_jumps), damage(), 0.0, storm.storm_stun)
```

`scenes/towers/storm_tower.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://scenes/towers/spire_tower.tscn" id="1_spire"]
[ext_resource type="Script" path="res://scripts/towers/storm_tower.gd" id="2_storm"]

[node name="StormTower" instance=ExtResource("1_spire")]
script = ExtResource("2_storm")
```

- [ ] **Step 4: Storm data** `data/towers/storm_array.tres` (its own art, so no tint/glow; `bolt_heights` and `sprite_scale` are first guesses, tuned in Step 6):

```
[gd_resource type="Resource" script_class="StormDefinition" format=3]

[ext_resource type="Script" path="res://scripts/towers/storm_definition.gd" id="1_def"]
[ext_resource type="SpriteFrames" path="res://assets/sprites/storm_array.tres" id="2_frames"]
[ext_resource type="PackedScene" path="res://scenes/towers/storm_tower.tscn" id="3_scene"]

[resource]
script = ExtResource("1_def")
id = &"storm_array"
display_name = "Storm Array"
description = "Lightning that jumps 8 times at full strength and stuns."
evolved = true
evolve_cost = Dictionary[StringName, int]({
&"aether": 6
})
help_line = "Lightning jumps 8 times with no falloff, and every 5th bolt stuns for 0.5 s. Crowd control."
damage_type_label = "Magic"
good_against = "Big spread-out groups; holding them in place"
weak_against = "Lone tough enemies (the chain has nothing to jump to)"
ability_name = "Thunderstorm"
ability_text = "For 4 s, a stunning strike hits a random enemy in range every 0.25 s."
ability_duration = 4.0
ability_cooldown = 14.0
ability_fire_rate_multiplier = 1.0
sprite_frames = ExtResource("2_frames")
sprite_scale = 0.5
scene = ExtResource("3_scene")
attack_damage = 10.0
attacks_per_second = 0.8
attack_range = 280.0
operated_fire_rate_multiplier = 1.0
jump_count = 8
jump_falloff = 0.0
bolt_heights = PackedFloat32Array(90, 100, 110)
```

Add it to `aether_spire.tres`'s `evolutions` (Focus Lens in Task 10).

- [ ] **Step 5: Import, test.** All pass.

- [ ] **Step 6: In-game checks.** Evolve a Lv3 Spire on `BuildSlotNorth` into `storm_array`.
  - **Art fit:** screenshot beside a Lv3 Spire; tune `sprite_scale` and `bolt_heights[2]` (bolts leave the crystal tip). The pulse plays when firing; wreck shows `destroyed`.
  - **Chain:** 10 frozen 99999-health goblins 60 px apart in a line inside range: one `t._fire_at(...)` hits 9 (first + 8 jumps), each for the same ≈ 10 × 1.69 = 16.9.
  - **Every 5th stuns:** fire 5 bolts (set `t.bolts_fired = 0` first): bolts 1–4 stun nobody, bolt 5 stuns all hit for 0.5 s.
  - **Thunderstorm:** operated, `use_ability()`: over 4 s about 16 strikes (count `LightningArc` children), each stunning; leaving the tower ends it (`set_operator(null)` resets `_ability_left`); cooldown 14 s. With no enemies in range nothing errors.
  - No new errors. `stop_project`, `git checkout project.godot`.

- [ ] **Step 7: Commit**

```bash
git add scripts/towers/storm_definition.gd scripts/towers/storm_tower.gd scenes/towers/storm_tower.tscn data/towers/storm_array.tres data/towers/aether_spire.tres tests/test_evolutions.gd scripts/towers/*.uid
git commit -m "Add the Storm Array evolution

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Focus Lens

**Files:**
- Create: `scripts/towers/lens_definition.gd`, `scripts/towers/lens_tower.gd`, `scenes/towers/lens_tower.tscn`, `data/towers/focus_lens.tres`
- Modify: `data/towers/aether_spire.tres`, `tests/test_evolutions.gd`

**Interfaces:**
- Consumes: `SpireTower._first_target`, `_muzzle_base`, `_draw`, `CHARGE_FRAME_TIME`.
- Produces: `class_name LensDefinition extends SpireDefinition` (`tick_rate`, `ramp_time`, `max_ramp`, `beam_color`, `overload_multiplier`, `ramp_multiplier(ramp) -> float`); `class_name LensTower extends SpireTower` (`beam_target: Enemy`, `ramp: float`, `tick_damage() -> float`).

- [ ] **Step 1: Failing test.** Make the `EXPECTED` Spire entry `[&"storm_array", &"focus_lens"]`, and add before the final `print` in `tests/test_evolutions.gd`:

```gdscript
	var lens = load("res://data/towers/focus_lens.tres")
	if lens:
		check("ramp x1", lens.ramp_multiplier(0.0), 1.0)
		check("ramp x3", lens.ramp_multiplier(0.5), 3.0)
		check("ramp x5", lens.ramp_multiplier(1.0), 5.0)
		check("ramp clamped", lens.ramp_multiplier(2.0), 5.0)
	else:
		check("focus lens data exists", false, true)
```

Run. Expected: FAIL "aether_spire branches" and "focus lens data exists".

- [ ] **Step 2: Lens definition** `scripts/towers/lens_definition.gd`:

```gdscript
class_name LensDefinition
extends SpireDefinition
## A Focus Lens's extra settings (an evolved Aether Spire): a ramping beam on
## one target instead of chain lightning, and the Overload ability.

@export_group("Beam")
## Beam damage ticks per second.
@export var tick_rate := 10.0
## Seconds on the same target to reach full ramp.
@export var ramp_time := 3.0
## Damage multiplier at full ramp (1 at the start).
@export var max_ramp := 5.0
@export var beam_color := Color(1.0, 0.95, 0.75)

@export_group("Overload")
## Extra multiplier on top of full ramp while Overload lasts (ability_duration).
@export var overload_multiplier := 1.5


## Damage multiplier at `ramp` (0..1).
func ramp_multiplier(ramp: float) -> float:
	return 1.0 + (max_ramp - 1.0) * clampf(ramp, 0.0, 1.0)
```

- [ ] **Step 3: Lens tower** `scripts/towers/lens_tower.gd`:

```gdscript
class_name LensTower
extends SpireTower
## The Focus Lens (an evolved Aether Spire): no chaining; a continuous beam
## on one target, ticking 10 times a second, whose damage ramps from 1× to
## 5× over 3 s and resets when it changes target. On its own it picks the
## enemy with the most health in range and stays on it; operated, the enemy
## in range nearest the mouse. Q = Overload: full ramp at once and 1.5× on
## top for 4 s.

## The beam stays drawn, and the ramp kept, this long after its last tick.
const BEAM_HOLD := 0.15

var lens: LensDefinition
var beam_target: Enemy
## 0..1 toward full ramp on beam_target.
var ramp := 0.0
var _beam_left := 0.0


func _ready() -> void:
	lens = definition as LensDefinition
	assert(lens != null, "A LensTower needs a LensDefinition")
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	_beam_left -= delta
	if _beam_left <= 0.0 or not _target_ok(beam_target):
		beam_target = null
		ramp = 0.0
	elif _ability_left > 0.0:
		ramp = 1.0
	else:
		ramp = minf(ramp + delta / lens.ramp_time, 1.0)
	queue_redraw()


## Beam ticks per second (not the Spire's bolt rate).
func fire_rate() -> float:
	return lens.tick_rate


## One beam tick: the Spire's single-target damage per second spread over
## the ticks, times the ramp (and Overload).
func tick_damage() -> float:
	var value := damage() * super.fire_rate() / lens.tick_rate * lens.ramp_multiplier(ramp)
	if _ability_left > 0.0:
		value *= lens.overload_multiplier
	return value


## Keeps its current target while it's alive and in range; otherwise the
## enemy in range with the most health.
func _find_target() -> Enemy:
	if _target_ok(beam_target):
		return beam_target
	var best: Enemy = null
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy.health.is_dead or global_position.distance_to(enemy.global_position) > attack_range():
			continue
		if best == null or enemy.health.current > best.health.current:
			best = enemy
	return best


func _target_ok(enemy: Enemy) -> bool:
	return enemy != null and is_instance_valid(enemy) and not enemy.health.is_dead \
			and global_position.distance_to(enemy.global_position) <= attack_range()


func _fire_at(point: Vector2) -> void:
	var target := beam_target if operator == null and _target_ok(beam_target) else _first_target(point)
	if target == null:
		return
	if target != beam_target:
		beam_target = target
		ramp = 0.0
	target.health.take_damage(tick_damage(), Health.DamageType.MAGIC)
	_beam_left = BEAM_HOLD
	sprite.animation = StringName("lv%d_fire" % level)
	sprite.stop()
	sprite.frame = 0
	_fire_frame_left = CHARGE_FRAME_TIME


## Starts Overload if it's recharged.
func use_ability() -> void:
	if operator == null or _ability_cooldown_left > 0.0:
		return
	_ability_left = definition.ability_duration
	_ability_cooldown_left = definition.ability_cooldown


## The range ring and aim marker while operated (SpireTower), then the beam:
## wider and brighter as it ramps.
func _draw() -> void:
	super()
	if beam_target == null or not is_instance_valid(beam_target):
		return
	var from := to_local(_muzzle_base())
	var to := to_local(_aim_point(beam_target))
	var width := 2.0 + 6.0 * ramp
	draw_line(from, to, Color(lens.beam_color, 0.35), width * 2.5)
	draw_line(from, to, Color(Color.WHITE.lerp(lens.beam_color, 0.4), 0.9), width)
	draw_circle(to, width * 1.5, Color(lens.beam_color, 0.6))
```

`scenes/towers/lens_tower.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://scenes/towers/spire_tower.tscn" id="1_spire"]
[ext_resource type="Script" path="res://scripts/towers/lens_tower.gd" id="2_lens"]

[node name="LensTower" instance=ExtResource("1_spire")]
script = ExtResource("2_lens")
```

- [ ] **Step 4: Lens data** `data/towers/focus_lens.tres` (Spire Lv3 art, tinted; take the Spire's `sprite_frames` line with its uid from `aether_spire.tres`):

```
[gd_resource type="Resource" script_class="LensDefinition" format=3]

[ext_resource type="Script" path="res://scripts/towers/lens_definition.gd" id="1_def"]
[ext_resource type="SpriteFrames" path="res://assets/sprites/aether_spire.tres" id="2_frames"]
[ext_resource type="PackedScene" path="res://scenes/towers/lens_tower.tscn" id="3_scene"]

[resource]
script = ExtResource("1_def")
id = &"focus_lens"
display_name = "Focus Lens"
description = "A focused beam that burns hotter the longer it stays on one target."
evolved = true
evolve_cost = Dictionary[StringName, int]({
&"aether": 6
})
help_line = "No chaining: a beam on one target that ramps up to 5× damage over 3 s. Boss and armour killer."
damage_type_label = "Magic"
good_against = "Bosses, armour and lone tough enemies"
weak_against = "Swarms (one target at a time; switching resets the ramp)"
ability_name = "Overload"
ability_text = "The beam jumps to full power and deals 1.5× on top for 4 s."
ability_duration = 4.0
ability_cooldown = 12.0
ability_fire_rate_multiplier = 1.0
tint = Color(1, 0.95, 0.75, 1)
glow = Color(1, 0.95, 0.75, 0.8)
sprite_frames = ExtResource("2_frames")
sprite_scale = 0.605
scene = ExtResource("3_scene")
attack_damage = 10.0
attacks_per_second = 0.8
attack_range = 280.0
operated_fire_rate_multiplier = 1.0
```

Add it to `aether_spire.tres`'s `evolutions` after `storm_array`.

- [ ] **Step 5: Import, test.** All headless tests pass (all four bases now have their two branches).

- [ ] **Step 6: In-game checks.** Evolve a Lv3 Spire into `focus_lens`.
  - **Look:** white-gold tint + glow; screenshot with the beam on a goblin (thin at first, thick after 3 s).
  - **Ramp:** one frozen 99999-health goblin in range. Over 4 s, sample damage per 1 s window: s1 ≈ 17.9 × avg ramp (≈ 1.7×) ≈ 30, s3 ≈ 17.9 × ≈ 4.3×, s4 ≈ 17.9 × 5 ≈ 89 (17.9 = 16.9 damage × 1.06/s).
  - **Auto targeting:** three frozen goblins with 200, 900 and 500 health: the beam picks the 900 one and stays on it even after its health drops below the others.
  - **Review Focus 4:** kill the beam target mid-beam (`take_damage(999999, MAGIC)`), and in a second test spawn-then-free one through a wave kill: no errors; within 0.15 s `beam_target == null`, `ramp == 0`; the next target starts at 1× (first tick ≈ 1.79).
  - **Operated switching:** with two goblins, moving the mouse from one to the other resets `ramp` to 0.
  - **Overload:** operated, `use_ability()`: `ramp == 1` at once and ticks are ≈ 1.79 × 1.35 × 5 × 1.5; after 4 s back to normal; cooldown 12 s.
  - No new errors. `stop_project`, `git checkout project.godot`.

- [ ] **Step 7: Commit**

```bash
git add scripts/towers/lens_definition.gd scripts/towers/lens_tower.gd scenes/towers/lens_tower.tscn data/towers/focus_lens.tres data/towers/aether_spire.tres tests/test_evolutions.gd scripts/towers/*.uid
git commit -m "Add the Focus Lens evolution

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Full pass, Help screen check and roadmap

**Files:**
- Modify: `ROADMAP.md`

- [ ] **Step 1: Every test.** Run all five headless test files. Expected: every one ends with `0 failed`.

- [ ] **Step 2: Full in-game pass.** Load the world, unlock four slots, build and evolve one of each branch pair in turn (8 evolutions over two rounds), let wave 1–2 play for ~30 s with all of them standing: no errors, every tower fires. Open Help (pause menu → Help): each base tower's page lists its two evolutions with lines and Q abilities; screenshot the Gearshot page. Open the F menu on each evolved tower: "(Evolved)" title, "Fully evolved" button. Trigger defeat: the end screen shows tinted icons labelled "Evolved". Sell an evolved tower: 4 Aether comes back (half of the 3 for Lv3 + 6 for evolving = 4.5, floored), plus half the Scrap.

- [ ] **Step 3: Web export smoke test** (the game ships to GitHub Pages): export the web build and load it in Playwright as in the workflow notes; build and evolve a Gearshot into a Gatling Engine; no console errors.

- [ ] **Step 4: Roadmap.** In `ROADMAP.md`, Phase 10, replace the evolution line with:

```markdown
- [x] **[AI]** Tower evolutions: at Lv3, the F menu offers **Evolve — 6 Aether** and a choice of two branches per tower, each with its own Q ability: Gearshot → Gatling Engine (spins up to 4× fire rate) / Rune Cannon (piercing magic rounds); Rune Mortar → Siege Battery (3-shell salvos) / Frost Rune Mortar (frost circles + freeze); Embercaster → Inferno (longer cone, 10 burn stacks) / Oil Sprayer (oil: slower, +50% fire damage taken); Aether Spire → Storm Array (8 jumps, stuns) / Focus Lens (ramping beam). Placeholder look (tint + glow, or the spare blaster/harvester sheets); real art: `docs/art/2026-09-30-boss-and-evolution-art-brief.md`
- [ ] **[Both]** Playtest evolutions: is 6 Aether right? Is each branch worth picking?
```

- [ ] **Step 5: Commit**

```bash
git add ROADMAP.md
git commit -m "Tick tower evolutions on the roadmap

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
