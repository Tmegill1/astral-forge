# Hero Upgrades Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Buy hero stat ranks at the Command Core (sharing the stored pool with towers), and give the Core slow tunable regeneration.

**Architecture:** `HeroUpgrade` data resources are listed on `HeroDefinition.upgrades`. `Hero` keeps its starting stats and a rank per upgrade id, and recomputes `stats` from them. `CommandCore` sells ranks (`buy_upgrade`), opens the new `HeroUpgradeMenu` on F, and ticks regeneration.

**Tech Stack:** Godot 4.7 GDScript, `.tscn`/`.tres`; verification via Godot MCP in the running game.

**Spec:** `docs/superpowers/specs/2026-09-25-hero-upgrades-design.md`

## Global Constraints

- Ranks 1–5. Costs: scrap `[12, 20, 30, 40, 55]`, aether `[0, 0, 1, 2, 3]`.
- Per-rank bonus (additive on the starting value): damage 0.2, fire rate 0.2, max health 0.2, move speed 0.08.
- Core regen: `regen_amount = 10.0` every `regen_interval = 5.0` s, always, alive only, never above max.
- Wording: prompt `[F] Upgrade hero` (with deposit: `[E] Deposit 12 Scrap    [F] Upgrade hero`); rows `Damage — Rank 2/5 · 12 → 14`; buttons `Upgrade — 30 Scrap, 1 Aether` / `Need 5 Scrap more` / `Maxed`.
- Branch `hero-upgrades`; one commit per task ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. After MCP runs, `git checkout project.godot` if modified. New `class_name` → run `godot --headless --editor --path . --import` before the headless check.

## Review Focus

1. **Buying while short on only Aether** at rank 3 spends nothing (Task 3 test).
2. **Buying max health while damaged** adds the new health on top rather than refilling (Task 2 test).
3. **Ranks after death**: revive restores the upgraded max health, not the base (Task 2 test).
4. **Core at full or destroyed** never regenerates (Task 1 test).
5. **Menu open while a wave runs**: the game is paused, so enemies don't act (Task 3: `get_tree().paused` is true while open).

---

### Task 1: Core regeneration

**Files:** Modify `scripts/structures/command_core.gd`

- [ ] **Step 1: Failing check.** Run the game and eval: damage the Core by 50, wait 330 physics frames (5.5 s), and return `world.core.health.current`. Expected: `450` (no regen yet).
- [ ] **Step 2: Implement.** Add exports after `hit_radius`:
```gdscript
## Health regained every regen_interval seconds while the Core stands.
@export var regen_amount := 10.0
## Seconds between regeneration ticks. 0 turns regeneration off.
@export var regen_interval := 5.0
```
a var `var _regen_left := 0.0`, set `_regen_left = regen_interval` at the end of `_ready`, and:
```gdscript
func _process(delta: float) -> void:
	if regen_interval <= 0.0 or health.is_dead:
		return
	_regen_left -= delta
	if _regen_left <= 0.0:
		_regen_left += regen_interval
		if health.current < health.max_health:
			health.heal(regen_amount)
```
Update the class doc: add `It slowly regenerates (regen_amount every regen_interval seconds).`
- [ ] **Step 3: Verify.** Eval, all in one session:
  1. Damage the Core by 50. After 270 frames it's `450`; after 330 frames it's `460` (one tick).
  2. Heal it to full (`health.heal(999)`), wait 330 frames: still `500`.
  3. Damage by 5, wait 330 frames: `500`. `heal` clamps to max, so it never goes over.
  4. For "destroyed": set `world.core.health.invulnerable = false`, `take_damage(99999)` → `0`. The game-over screen pauses the tree, so set `get_tree().paused = false`, wait 330 frames, and read `health.current` → still `0`.
- [ ] **Step 4: Commit** `Regenerate the Command Core's health over time`.

---

### Task 2: HeroUpgrade data and hero ranks

**Files:**
- Create: `scripts/heroes/hero_upgrade.gd`, `data/hero_upgrades/damage.tres`, `fire_rate.tres`, `max_health.tres`, `move_speed.tres`
- Modify: `scripts/heroes/hero_definition.gd` (`upgrades`), `data/heroes/artificer.tres`, `scripts/heroes/hero.gd` (ranks), `scripts/ui/hud.gd` (stats line refresh)

**Interfaces:**
- Produces: `class_name HeroUpgrade` with `id`, `display_name`, `stat`, `bonus_per_rank`, `scrap_costs`, `aether_costs`, `max_rank() -> int`, `cost_for(rank: int) -> Dictionary[StringName, int]`, `multiplier(rank: int) -> float`; `HeroDefinition.upgrades: Array[HeroUpgrade]`; `Hero.stats_changed` signal; `Hero.rank_of(upgrade: HeroUpgrade) -> int`; `Hero.add_rank(upgrade: HeroUpgrade) -> void`; `Hero.base_stats: HeroStats`

- [ ] **Step 1: Failing check.** Eval `return [world.hero.has_method(&"add_rank"), "upgrades" in world.hero.definition]`. Expected `[false, false]`.
- [ ] **Step 2: Resource** `scripts/heroes/hero_upgrade.gd`:
```gdscript
class_name HeroUpgrade
extends Resource
## One stat the hero can buy ranks in at the Command Core. Each rank adds
## bonus_per_rank of the hero's starting value (not compounding). To add
## one, create a .tres in data/hero_upgrades/ and list it on the hero.

@export var id: StringName
@export var display_name: String
## The HeroStats property it raises, e.g. &"attack_damage".
@export var stat: StringName
## Share of the starting value added per rank (0.2 = +20%).
@export var bonus_per_rank := 0.2
## Price of each rank in order (index 0 = rank 1); one entry per rank.
@export var scrap_costs: PackedInt32Array = [12, 20, 30, 40, 55]
@export var aether_costs: PackedInt32Array = [0, 0, 1, 2, 3]


func max_rank() -> int:
	return scrap_costs.size()


## What buying `rank` (1 = the first) costs.
func cost_for(rank: int) -> Dictionary[StringName, int]:
	var cost: Dictionary[StringName, int] = {Loot.SCRAP: scrap_costs[rank - 1]}
	if aether_costs[rank - 1] > 0:
		cost[Loot.AETHER] = aether_costs[rank - 1]
	return cost


## Multiplier on the starting value at `rank`.
func multiplier(rank: int) -> float:
	return 1.0 + bonus_per_rank * rank
```
Data files (same shape; `damage.tres` shown; the others change `id`/`display_name`/`stat`/`bonus_per_rank`: `fire_rate` "Fire rate" `attacks_per_second` 0.2; `max_health` "Max health" `max_health` 0.2; `move_speed` "Move speed" `move_speed` 0.08):
```
[gd_resource type="Resource" script_class="HeroUpgrade" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/heroes/hero_upgrade.gd" id="1_up"]

[resource]
script = ExtResource("1_up")
id = &"damage"
display_name = "Damage"
stat = &"attack_damage"
bonus_per_rank = 0.2
```
`HeroDefinition`: add after `stat_multipliers`:
```gdscript
## Stat upgrades this hero can buy at the Command Core, in menu order.
@export var upgrades: Array[HeroUpgrade] = []
```
`artificer.tres`: add ext_resources for the 4 data files plus the script (`3_up`), and `upgrades = Array[ExtResource("3_up")]([ExtResource("4_damage"), ExtResource("5_fire"), ExtResource("6_health"), ExtResource("7_speed")])`.
- [ ] **Step 3: Hero ranks.** In `scripts/heroes/hero.gd`:
  - `signal stats_changed` (doc: `## Stats changed (an upgrade was bought).`)
  - vars: `## Stats at the start of the run, before upgrades.` `var base_stats: HeroStats` and `## Ranks bought at the Core, by upgrade id. They last the whole run.` `var upgrade_ranks: Dictionary[StringName, int] = {}`
  - `setup()`: `base_stats = definition.build_stats()` then `stats = base_stats.duplicate()`
  - add:
```gdscript
# --- Upgrades ---

func rank_of(upgrade: HeroUpgrade) -> int:
	return upgrade_ranks.get(upgrade.id, 0)


## Adds one rank of `upgrade` (the Core has already been paid). Extra max
## health is added on top of the current health.
func add_rank(upgrade: HeroUpgrade) -> void:
	upgrade_ranks[upgrade.id] = rank_of(upgrade) + 1
	stats = base_stats.duplicate()
	for owned in definition.upgrades:
		var rank := rank_of(owned)
		if rank > 0:
			stats.set(owned.stat, base_stats.get(owned.stat) * owned.multiplier(rank))
	if not is_equal_approx(stats.max_health, health.max_health):
		health.grow_max(stats.max_health)
	stats_changed.emit()
```
  (`revive` already resets health to `stats.max_health`, so ranks survive death.)
- [ ] **Step 4: HUD.** In `scripts/ui/hud.gd` `bind_hero`, replace the one-off `stats_text` assignment with a lambda `show_stats` (same text) connected to `hero.stats_changed` and called once.
- [ ] **Step 5: Verify.** Import, headless check, then eval:
```gdscript
var world = get_tree().current_scene
var h = world.hero
var ups = h.definition.upgrades
var out = {names = ups.map(func(u): return u.id), base = [h.stats.attack_damage, h.stats.attacks_per_second, h.stats.max_health, h.stats.move_speed]}
h.health.take_damage(30)
for u in ups:
	h.add_rank(u)
	h.add_rank(u)
out.rank2 = [h.stats.attack_damage, h.stats.attacks_per_second, h.stats.max_health, snappedf(h.stats.move_speed, 0.01), h.health.current, h.health.max_health]
await get_tree().process_frame
out.hud = world.get_node("HUD").stats_text.text
h.health.take_damage(9999)
h.revive(h.global_position)
out.after_revive = [h.health.current, h.health.max_health, h.stats.attack_damage]
return out
```
Expected: names `[damage, fire_rate, max_health, move_speed]`; base `[10, 1, 90, 220]`; rank2 `[14, 1.4, 126, 255.2, 96, 126]` (90 − 30 = 60, +36 → 96); hud `"Damage 14   Fire rate 1.4/s\nSpeed 255   Range 500"`; after_revive `[126, 126, 14]`. Stop; check debug output.
- [ ] **Step 6: Commit** `Add hero stat upgrades (data, ranks, HUD refresh)`.

---

### Task 3: Buying at the Core, prompt and menu

**Files:**
- Create: `scripts/ui/hero_upgrade_menu.gd`, `scenes/ui/hero_upgrade_menu.tscn`
- Modify: `scripts/structures/command_core.gd` (`manage`, `buy_upgrade`, prompt), `scenes/world.tscn` (menu instance)

**Interfaces:**
- Consumes: `Hero.rank_of`/`add_rank`, `HeroUpgrade.cost_for`/`max_rank`/`multiplier` (Task 2)
- Produces: `CommandCore.buy_upgrade(hero: Hero, upgrade: HeroUpgrade) -> bool`; `CommandCore.manage(hero: Hero)`; group `hero_upgrade_menu` with `open(core: CommandCore, hero: Hero)`

- [ ] **Step 1: Failing check.** Eval `return [world.core.has_method(&"buy_upgrade"), world.core.get_interact_prompt(world.hero)]`. Expected `[false, ""]`.
- [ ] **Step 2: Core.**
```gdscript
func manage(hero: Hero) -> void:
	if not hero.definition.upgrades.is_empty():
		get_tree().call_group(&"hero_upgrade_menu", &"open", self, hero)


## Pays for the next rank of `upgrade` from stored resources and gives it to
## the hero. False if it's maxed or unaffordable (nothing is spent then).
func buy_upgrade(hero: Hero, upgrade: HeroUpgrade) -> bool:
	var rank := hero.rank_of(upgrade)
	if rank >= upgrade.max_rank() or not stored.spend_all(upgrade.cost_for(rank + 1)):
		return false
	hero.add_rank(upgrade)
	return true
```
Prompt:
```gdscript
func get_interact_prompt(hero: Hero) -> String:
	var parts: PackedStringArray = []
	if not hero.carried.is_empty():
		parts.append("[E] Deposit %s" % hero.carried.describe())
	if not hero.definition.upgrades.is_empty():
		parts.append("[F] Upgrade hero")
	return "    ".join(parts)
```
Class doc: add `Manage (F) opens the hero upgrade menu; ranks are paid from stored resources.`
- [ ] **Step 3: Menu scene.** `scenes/ui/hero_upgrade_menu.tscn`: copy `tower_menu.tscn`'s structure (CanvasLayer `process_mode = 3`, `layer = 5`, Dim, Center, Panel with the same StyleBoxFlat, Margin, Rows) with `custom_minimum_size = Vector2(460, 0)`, and in Rows: `Title` (22 px, unique), `StoredText` (14 px, unique), `List` (VBoxContainer, unique, separation 8), `CloseButton` (unique, "Close (Esc)"). Root named `HeroUpgradeMenu`.
- [ ] **Step 4: Menu script** `scripts/ui/hero_upgrade_menu.gd`:
```gdscript
class_name HeroUpgradeMenu
extends CanvasLayer
## Pop-up at the Command Core for buying hero stat ranks with stored
## resources. Pauses the game while open. Esc or F closes.

@onready var title: Label = %Title
@onready var stored_text: Label = %StoredText
@onready var list: VBoxContainer = %List
@onready var close_button: Button = %CloseButton

var _core: CommandCore
var _hero: Hero
var _opened_frame := -1


func _ready() -> void:
	add_to_group(&"hero_upgrade_menu")
	visible = false
	close_button.pressed.connect(close)


func open(core: CommandCore, hero: Hero) -> void:
	_core = core
	_hero = hero
	_opened_frame = Engine.get_process_frames()
	_refresh()
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


func _refresh() -> void:
	title.text = "Upgrade %s" % _hero.definition.display_name
	var have := _core.stored.describe()
	stored_text.text = "Stored: %s" % (have if have != "" else "nothing")
	for child in list.get_children():
		child.queue_free()
	for upgrade in _hero.definition.upgrades:
		list.add_child(_row(upgrade))


## One upgrade: "Damage — Rank 2/5 · 12 → 14" and its buy button.
func _row(upgrade: HeroUpgrade) -> Control:
	var rank := _hero.rank_of(upgrade)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override(&"font_size", 14)
	var now := _value(upgrade, rank)
	var button := Button.new()
	button.custom_minimum_size = Vector2(210, 32)
	if rank >= upgrade.max_rank():
		label.text = "%s — Rank %d/%d · %s" % [upgrade.display_name, rank, upgrade.max_rank(), now]
		button.text = "Maxed"
		button.disabled = true
	else:
		label.text = "%s — Rank %d/%d · %s → %s" % [
			upgrade.display_name, rank, upgrade.max_rank(), now, _value(upgrade, rank + 1)]
		var cost := upgrade.cost_for(rank + 1)
		var missing := _core.stored.shortfall(cost)
		button.disabled = not missing.is_empty()
		button.text = "Upgrade — %s" % Loot.describe(cost) if missing.is_empty() \
				else "Need %s more" % Loot.describe(missing)
		button.pressed.connect(func() -> void:
			_core.buy_upgrade(_hero, upgrade)
			_refresh())
	row.add_child(label)
	row.add_child(button)
	return row


## The stat's value at `rank`, e.g. "14" or "1.4/s".
func _value(upgrade: HeroUpgrade, rank: int) -> String:
	var value: float = _hero.base_stats.get(upgrade.stat) * upgrade.multiplier(rank)
	if upgrade.stat == &"attacks_per_second":
		return "%.1f/s" % value
	return "%.0f" % value


func _unhandled_input(event: InputEvent) -> void:
	if not visible or Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"manage"):
		close()
		get_viewport().set_input_as_handled()
```
World: add `[ext_resource type="PackedScene" path="res://scenes/ui/hero_upgrade_menu.tscn" id="12_hero_menu"]` and `[node name="HeroUpgradeMenu" parent="." instance=ExtResource("12_hero_menu")]` after TowerMenu.
- [ ] **Step 5: Verify.** Import, headless check, then eval:
```gdscript
var world = get_tree().current_scene
var h = world.hero
var core = world.core
var st = core.stored
var dmg = h.definition.upgrades[0]
var out = {prompt_empty = core.get_interact_prompt(h)}
h.carried.add(&"scrap", 12)
out.prompt_carry = core.get_interact_prompt(h)
h.carried.take_all()
st.take_all(); st.add(&"scrap", 11)
out.short = [core.buy_upgrade(h, dmg), h.rank_of(dmg), st.get_amount(&"scrap")]
st.add(&"scrap", 21)
out.r1r2 = [core.buy_upgrade(h, dmg), core.buy_upgrade(h, dmg), h.rank_of(dmg), st.get_amount(&"scrap")]
st.add(&"scrap", 100)
out.no_aether = [core.buy_upgrade(h, dmg), h.rank_of(dmg), st.get_amount(&"scrap")]
st.add(&"aether", 6)
out.r3r5 = [core.buy_upgrade(h, dmg), core.buy_upgrade(h, dmg), core.buy_upgrade(h, dmg), h.rank_of(dmg), st.get_amount(&"scrap"), st.get_amount(&"aether"), h.stats.attack_damage]
st.add(&"scrap", 25)
out.r5 = [core.buy_upgrade(h, dmg), h.rank_of(dmg), h.stats.attack_damage]
out.maxed = core.buy_upgrade(h, dmg)
core.manage(h)
var m = world.get_node("HeroUpgradeMenu")
await get_tree().process_frame
out.menu = [m.visible, get_tree().paused, m.title.text, m.list.get_child_count()]
out.rows = m.list.get_children().filter(func(r): return not r.is_queued_for_deletion()).map(func(r): return [r.get_child(0).text, r.get_child(1).text, r.get_child(1).disabled])
return out
```
Expected:
- `prompt_empty`: `"[F] Upgrade hero"`
- `prompt_carry`: `"[E] Deposit 12 Scrap    [F] Upgrade hero"`
- `short`: `[false, 0, 11]`
- `r1r2`: `[true, true, 2, 0]`
- `no_aether`: `[false, 2, 100]`
- `r3r5`: `[true, true, false, 4, 30, 3, 18]`. Stored was 100 Scrap + 6 Aether: rank 3 costs 30 + 1, rank 4 costs 40 + 2, and rank 5 (55 + 3) is 25 Scrap short.
- `r5`: `[true, 5, 20]`
- `maxed`: `false`
- `menu`: `[true, true, "Upgrade Artificer", 4]`
- rows: Damage `"Damage — Rank 5/5 · 20"`, `"Maxed"`, true; the other rows at rank 0 with `→` values and cost/need text per stored amount.

Screenshot the open menu; close it with `m.close()`. Check debug output; stop.

- [ ] **Step 6: Commit** `Buy hero upgrades at the Command Core`.

---

### Task 4: Roadmap

- [ ] In `ROADMAP.md` Phase 10, add before the "Upgrade choices after waves" line:
  - `- [x] **[AI]** Hero upgrades at the Core (F): Damage, Fire rate, Max health (+20%/rank), Move speed (+8%/rank); 5 ranks, 12 / 20 / 30+1 Aether / 40+2 / 55+3, from the same stored pool as towers`
  - `- [ ] **[AI]** Specialized roguelite hero upgrades, picked during a run: chain-lightning shots, flamethrower, and similar`
  and change the "Upgrade choices" line's `— include fire-rate upgrades (hero starts at 1 shot/sec)` to `— stat ranks now live at the Core; these picks are the specialized ones`. Under Phase 2, add after the Core line: `Core regenerates 10 health every 5 s (regen_amount / regen_interval on the CommandCore).` Commit `Note hero upgrades and Core regen on the roadmap`.
