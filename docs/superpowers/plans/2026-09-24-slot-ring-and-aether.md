# Slot Ring and Aether Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Grow the base to a ring of 12 build slots (8 unlocked with Scrap) whose walls join into one line per side, and add Aether as a rare second resource from far-off crystals and rare goblin drops.

**Architecture:** Mostly data and small extensions of existing systems. `BuildSlot` gains an unlock step; the existing wall planner already runs walls at right angles to the Core, so the ring only needs positions and wall lengths in `world.tscn`. `ScrapHeap` becomes a typed `ResourceHeap` so the same heap scene holds Scrap or Aether; `World` places both kinds each break. `EnemyDefinition` gets `rare_drops`. The HUD shows Aether next to Scrap.

**Tech Stack:** Godot 4.7, GDScript, `.tscn`/`.tres` text resources. Verification by driving the running game with the Godot MCP tools (`run_project`, `game_eval`, `game_screenshot`, `get_debug_output`, `stop_project`).

**Spec:** `docs/superpowers/specs/2026-09-24-slot-ring-and-aether-design.md`

## Global Constraints

- Core stays at `(640, 384)`; the map is 40×26 tiles of 64 px (x −640…1920, y −448…1216).
- Unlock cost default: `{&"scrap": 6}`.
- Locked prompt: `[E] Unlock slot (6 Scrap)`; when short: `Unlock slot: need 4 more Scrap` (built with `Loot.describe`).
- Heap prompts: `[E] Salvage heap (5 Scrap)` and `[E] Break crystal (3 Aether)`.
- Crystals: `aether_per_break = Vector2i(1, 2)`, `max_aether = 3`, `aether_amount = Vector2i(2, 4)`, `AETHER_MIN_DISTANCE = 800.0`.
- Goblin `rare_drops = {&"aether": 0.05}` (chance of exactly 1).
- `max_heaps` caps **Scrap** heaps only.
- Aether shows in the HUD even at 0.
- Follow existing style: tabs, `##` doc comments on exports and public funcs, typed GDScript, StringName literals (`&"scrap"`).
- Commit on `main` (the project's workflow), one commit per task, message ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- After each MCP test run, `git checkout project.godot` if the MCP tool left a stray edit in it.

## Review Focus

1. **Unlocking while short on Scrap** must spend nothing and leave the slot locked (Task 5 test).
2. **Pressing E on a locked slot** must never open the build menu (Task 5 test).
3. **Selling a tower whose walls meet a neighbour's** must remove only its own pieces; the neighbour's wall stays, and the slot stays unlocked (Task 6 test).
4. **Crystal cap reached**: further breaks add no crystals until one is broken (Task 3 test).
5. **A fully built side** must still let enemies in through the corner gaps rather than making them smash walls (Task 7 test).

## How to test (applies to every task)

1. Start: `mcp__godot__run_project` with `projectPath: /home/tylermegill/astral-forge`. The first `game_eval` sometimes returns "Not connected"; repeat it once.
2. Handy eval prelude (paste at the top of eval snippets):
   ```gdscript
   var world = get_tree().current_scene
   var hero = world.hero
   var core = world.core
   ```
3. After testing: `mcp__godot__get_debug_output` must show no new errors or warnings from files this plan touches (the existing warnings in `loot.gd`, `enemy.gd`, `hud.gd:63`, `game_over.gd` and `mcp_interaction_server.gd` are known). Then run `mcp__godot__stop_project`, then `git checkout project.godot` if `git status` shows it modified.
4. If a changed image or scene doesn't seem to load, run `godot --headless --editor --path . --import` once (stale import cache).

---

### Task 1: Aether in the HUD

**Files:**
- Modify: `scenes/ui/hud.tscn` (add an Aether icon + label to `CarriedRow` and `StoredRow`)
- Modify: `scripts/ui/hud.gd` (`bind_hero`, `bind_core`)

**Interfaces:**
- Consumes: `Loot.AETHER`, `ResourceBag.get_amount`, `ResourceBag.changed`
- Produces: `%CarriedAetherText`, `%StoredAetherText` labels (text is the plain number)

- [ ] **Step 1: Check the current HUD ignores Aether (fails)**

Run the game, then eval:
```gdscript
var world = get_tree().current_scene
world.hero.carried.add(&"aether", 2)
world.core.stored.add(&"aether", 5)
var hud = world.get_node("HUD")
return [hud.find_child("CarriedAetherText", true, false), hud.find_child("StoredAetherText", true, false)]
```
Expected: `[null, null]`. Stop the game.

- [ ] **Step 2: Add the scene nodes**

In `scenes/ui/hud.tscn`, change the header to `load_steps=5` and add after the `2_scrap` ext_resource:
```
[ext_resource type="Texture2D" path="res://assets/sprites/fortress/aether_1.png" id="4_aether"]
```
Directly after the `CarriedText` node block, add:
```
[node name="AetherIcon" type="TextureRect" parent="HeroPanel/Margin/Rows/CarriedRow"]
custom_minimum_size = Vector2(20, 20)
layout_mode = 2
texture = ExtResource("4_aether")
expand_mode = 1
stretch_mode = 5

[node name="CarriedAetherText" type="Label" parent="HeroPanel/Margin/Rows/CarriedRow"]
unique_name_in_owner = true
layout_mode = 2
theme_override_font_sizes/font_size = 14
text = "0"
```
Directly after the `StoredText` node block, add:
```
[node name="AetherIcon" type="TextureRect" parent="CorePanel/Margin/Rows/StoredRow"]
custom_minimum_size = Vector2(20, 20)
layout_mode = 2
texture = ExtResource("4_aether")
expand_mode = 1
stretch_mode = 5

[node name="StoredAetherText" type="Label" parent="CorePanel/Margin/Rows/StoredRow"]
unique_name_in_owner = true
layout_mode = 2
theme_override_font_sizes/font_size = 14
text = "0"
```

- [ ] **Step 3: Update the script**

In `scripts/ui/hud.gd`, add after `@onready var stored_text`:
```gdscript
@onready var carried_aether_text: Label = %CarriedAetherText
@onready var stored_aether_text: Label = %StoredAetherText
```
In `bind_hero`, replace the `show_carried` lambda with:
```gdscript
	var show_carried := func() -> void:
		carried_text.text = "Carrying %d" % hero.carried.get_amount(Loot.SCRAP)
		carried_aether_text.text = str(hero.carried.get_amount(Loot.AETHER))
```
In `bind_core`, replace the `show_stored` lambda with:
```gdscript
	var show_stored := func() -> void:
		stored_text.text = "Stored %d" % core.stored.get_amount(Loot.SCRAP)
		stored_aether_text.text = str(core.stored.get_amount(Loot.AETHER))
```
Update the class doc comment's "carried resources" / "stored resources" wording if needed (it already says resources, so no change is required).

- [ ] **Step 4: Verify**

Run the game and eval:
```gdscript
var world = get_tree().current_scene
var hud = world.get_node("HUD")
var before = [hud.find_child("CarriedAetherText", true, false).text, hud.find_child("StoredAetherText", true, false).text]
world.hero.carried.add(&"aether", 2)
world.core.stored.add(&"aether", 5)
return [before, hud.find_child("CarriedAetherText", true, false).text, hud.find_child("StoredAetherText", true, false).text]
```
Expected: `[["0", "0"], "2", "5"]`. Take a `game_screenshot` to check that both rows read `[gear] Carrying 0 [crystal] 2` and `[gear] Stored 0 [crystal] 5` and fit their panels. Check debug output; stop the game.

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/hud.tscn scripts/ui/hud.gd
git commit -m "Show carried and stored Aether in the HUD

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: ScrapHeap becomes ResourceHeap

**Files:**
- Rename: `scripts/loot/scrap_heap.gd` → `scripts/loot/resource_heap.gd` (and its `.uid` file)
- Rename: `scenes/loot/scrap_heap.tscn` → `scenes/loot/resource_heap.tscn`
- Modify: `scripts/world.gd` (scene preload, class and group names)

**Interfaces:**
- Consumes: `Loot.ICONS`, `Loot.drop`, `Loot.display_name`
- Produces: `class_name ResourceHeap` with `@export var type: StringName`, `@export var amount: int`; scene `res://scenes/loot/resource_heap.tscn` in group `resource_heaps`

- [ ] **Step 1: Rename with git**

```bash
git mv scripts/loot/scrap_heap.gd scripts/loot/resource_heap.gd
git mv scripts/loot/scrap_heap.gd.uid scripts/loot/resource_heap.gd.uid
git mv scenes/loot/scrap_heap.tscn scenes/loot/resource_heap.tscn
```

- [ ] **Step 2: Rewrite the script**

`scripts/loot/resource_heap.gd`:
```gdscript
class_name ResourceHeap
extends Node2D
## A pile of salvage (Scrap) or a crystal (Aether) out in the world. Interact
## to break it open; it bursts into pickups. The world makes farther Scrap
## heaps richer and only places crystals far from the Core.

@export var type: StringName = Loot.SCRAP
@export var amount := 4

@onready var pieces: Node2D = $Pieces


func _ready() -> void:
	# A few random pieces of this resource's art make up the heap's look.
	var icons: Array = Loot.ICONS[type]
	for i in pieces.get_child_count():
		(pieces.get_child(i) as Sprite2D).texture = icons.pick_random()


func interact(_hero: Hero) -> void:
	Loot.drop(get_parent(), global_position, type, amount)
	queue_free()


func get_interact_prompt(_hero: Hero) -> String:
	var action := "Break crystal" if type == Loot.AETHER else "Salvage heap"
	return "[E] %s (%d %s)" % [action, amount, Loot.display_name(type)]
```

- [ ] **Step 3: Update the scene**

In `scenes/loot/resource_heap.tscn`, change the script path and the root node:
```
[ext_resource type="Script" path="res://scripts/loot/resource_heap.gd" id="1_heap"]
```
```
[node name="ResourceHeap" type="Node2D" groups=["resource_heaps"]]
```

- [ ] **Step 4: Update the world script**

In `scripts/world.gd`:
- `const HEAP_SCENE := preload("res://scenes/loot/resource_heap.tscn")`
- in `_scatter_heaps`, both `&"scrap_heaps"` → `&"resource_heaps"`, and `var heap: ScrapHeap` → `var heap: ResourceHeap`.

(Task 3 restructures this function; this step only keeps it working.)

Confirm nothing else refers to the old names:
```bash
grep -rn "scrap_heap\|ScrapHeap\|scrap_heaps" --include='*.gd' --include='*.tscn' --include='*.tres' .
```
Expected: no output.

- [ ] **Step 5: Verify**

Run the game and eval:
```gdscript
var world = get_tree().current_scene
var heaps = get_tree().get_nodes_in_group(&"resource_heaps")
var first = heaps[0]
var crystal = preload("res://scenes/loot/resource_heap.tscn").instantiate()
crystal.type = &"aether"
crystal.amount = 3
crystal.position = world.hero.global_position + Vector2(40, 0)
world.units.add_child(crystal)
var prompts = [first.get_interact_prompt(world.hero), crystal.get_interact_prompt(world.hero)]
crystal.interact(world.hero)
for i in 90:
	await get_tree().physics_frame
return [heaps.size(), prompts, world.hero.carried.get_amount(&"aether")]
```
Expected: 4 heaps at game start (`heaps_per_break`); prompts `"[E] Salvage heap (N Scrap)"` and `"[E] Break crystal (3 Aether)"`. The third value is 3: the pickups spawn 40 px away and drift to the hero, so all 3 Aether are picked up within 90 frames. If it's lower, wait longer; it must reach 3. Screenshot to see the crystal art in a heap before breaking (optional). Check debug output; stop.

- [ ] **Step 6: Commit**

```bash
git add scripts/loot/resource_heap.gd scripts/loot/resource_heap.gd.uid scenes/loot/resource_heap.tscn scripts/world.gd
git commit -m "Generalise ScrapHeap into ResourceHeap with a resource type

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Aether crystals each break

**Files:**
- Modify: `scripts/waves/run_definition.gd` (three new exports; `max_heaps` doc)
- Modify: `scripts/world.gd` (`_scatter_heaps` split into helpers, new const)

**Interfaces:**
- Consumes: `ResourceHeap` (`type`, `amount`), group `resource_heaps` (Task 2)
- Produces: `RunDefinition.aether_per_break: Vector2i`, `RunDefinition.max_aether: int`, `RunDefinition.aether_amount: Vector2i`; `World.AETHER_MIN_DISTANCE`; `World._scatter_heaps(map: Rect2)` (unchanged signature, still connected to `break_started`)

- [ ] **Step 1: Check there are no crystals yet (fails)**

Run the game and eval:
```gdscript
return get_tree().get_nodes_in_group(&"resource_heaps").filter(func(h): return h.type == &"aether").size()
```
Expected: `0`. Stop.

- [ ] **Step 2: Add the run settings**

In `scripts/waves/run_definition.gd`, replace the heap exports with:
```gdscript
## Scrap heaps scattered around the map at the start of each break.
@export var heaps_per_break := 4
## Never more than this many Scrap heaps on the map at once.
@export var max_heaps := 8
## Aether crystals added each break: a random count from x to y.
@export var aether_per_break := Vector2i(1, 2)
## Never more than this many Aether crystals on the map at once.
@export var max_aether := 3
## Aether in each crystal: a random amount from x to y.
@export var aether_amount := Vector2i(2, 4)
```

- [ ] **Step 3: Place crystals in the world**

In `scripts/world.gd`, add after `HEAP_DISTANCE_PER_SCRAP`:
```gdscript
## Aether crystals never appear closer to the Core than this, in pixels.
const AETHER_MIN_DISTANCE := 800.0
```
Update the class doc's first lines to say "scatters scrap heaps and Aether crystals each break". Replace the whole `_scatter_heaps` function with:
```gdscript
## Each break: Scrap heaps at random open spots away from the Core (farther
## ones hold more, rewarding the risk of going out), plus a few Aether
## crystals only far from the Core.
func _scatter_heaps(map: Rect2) -> void:
	var run := waves.run
	var scrap_room := run.max_heaps - _heaps_of(Loot.SCRAP).size()
	_place_heaps(map, Loot.SCRAP, mini(run.heaps_per_break, scrap_room), HEAP_MIN_DISTANCE,
			func(distance: float) -> int: return 3 + floori(distance / HEAP_DISTANCE_PER_SCRAP))
	var aether_room := run.max_aether - _heaps_of(Loot.AETHER).size()
	var aether_count := randi_range(run.aether_per_break.x, run.aether_per_break.y)
	_place_heaps(map, Loot.AETHER, mini(aether_count, aether_room), AETHER_MIN_DISTANCE,
			func(_distance: float) -> int: return randi_range(run.aether_amount.x, run.aether_amount.y))


## Heaps of one resource type currently on the map.
func _heaps_of(type: StringName) -> Array[Node]:
	return get_tree().get_nodes_in_group(&"resource_heaps").filter(
			func(heap: ResourceHeap) -> bool: return heap.type == type)


## Places up to `count` heaps of `type` at random open spots at least
## `min_distance` from the Core and apart from other heaps.
## `amount_for(distance)` decides how much each one holds.
func _place_heaps(map: Rect2, type: StringName, count: int, min_distance: float,
		amount_for: Callable) -> void:
	var placed := 0
	var tries := 0
	var inner := map.grow(-60.0)
	while placed < count and tries < 200:
		tries += 1
		var at := Vector2(randf_range(inner.position.x, inner.end.x), randf_range(inner.position.y, inner.end.y))
		var distance := at.distance_to(core.global_position)
		if distance < min_distance or nav.is_solid_at(at):
			continue
		if get_tree().get_nodes_in_group(&"resource_heaps").any(
				func(h: Node2D) -> bool: return h.global_position.distance_to(at) < 120.0):
			continue
		var heap: ResourceHeap = HEAP_SCENE.instantiate()
		heap.type = type
		heap.amount = amount_for.call(distance)
		heap.position = at
		units.add_child(heap)
		placed += 1
```
If GDScript rejects the typed return of `filter` (it returns an untyped `Array`), change `_heaps_of` to return `Array` instead.

- [ ] **Step 4: Verify counts, distances and the cap**

Run the game and eval:
```gdscript
var world = get_tree().current_scene
var map = world._map_rect()
var crystals = func(): return get_tree().get_nodes_in_group(&"resource_heaps").filter(func(h): return h.type == &"aether")
var counts = [crystals.call().size()]
for i in 4:
	world._scatter_heaps(map)
	counts.append(crystals.call().size())
var nearest = INF
var amounts = []
for c in crystals.call():
	nearest = min(nearest, c.global_position.distance_to(world.core.global_position))
	amounts.append(c.amount)
var scrap = get_tree().get_nodes_in_group(&"resource_heaps").filter(func(h): return h.type == &"scrap").size()
return {counts = counts, nearest = nearest, amounts = amounts, scrap = scrap}
```
Expected:
- `counts[0]` is 1 or 2 (the first break at game start).
- `counts` never goes down and never passes 3; it reaches 3 by the end.
- `nearest` ≥ 800.
- Every entry in `amounts` is 2–4.
- `scrap` ≤ 8.

Then break one crystal and re-scatter to confirm the cap frees up:
```gdscript
var world = get_tree().current_scene
var cs = get_tree().get_nodes_in_group(&"resource_heaps").filter(func(h): return h.type == &"aether")
cs[0].interact(world.hero)
await get_tree().process_frame
world._scatter_heaps(world._map_rect())
return get_tree().get_nodes_in_group(&"resource_heaps").filter(func(h): return h.type == &"aether" and not h.is_queued_for_deletion()).size()
```
Expected: `3`. Check debug output; stop.

- [ ] **Step 5: Commit**

```bash
git add scripts/waves/run_definition.gd scripts/world.gd
git commit -m "Scatter Aether crystals far from the Core each break

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Rare Aether drops from goblins

**Files:**
- Modify: `scripts/enemies/enemy_definition.gd` (`rare_drops` export)
- Modify: `data/enemies/goblin.tres` (`rare_drops`)
- Modify: `scripts/world.gd` (`_on_enemy_killed`)

**Interfaces:**
- Consumes: `Loot.drop(parent, at, type, amount)`
- Produces: `EnemyDefinition.rare_drops: Dictionary[StringName, float]`

- [ ] **Step 1: Add the export**

In `scripts/enemies/enemy_definition.gd`, after `drops`:
```gdscript
## Resource type -> chance (0 to 1) of also dropping exactly one on death,
## e.g. {"aether": 0.05}.
@export var rare_drops: Dictionary[StringName, float] = {}
```

- [ ] **Step 2: Give goblins the drop**

In `data/enemies/goblin.tres`, after the `drops` block:
```
rare_drops = Dictionary[StringName, float]({
&"aether": 0.05
})
```

- [ ] **Step 3: Roll it on kill**

In `scripts/world.gd` `_on_enemy_killed`, after the regular drops loop:
```gdscript
	var rare := enemy.definition.rare_drops
	for type in rare:
		if randf() < rare[type]:
			Loot.drop(units, enemy.global_position, type, 1)
```

- [ ] **Step 4: Verify**

Run the game and eval (forces the chance to 1, kills 3 goblins, counts Aether pickups, then restores the chance):
```gdscript
var world = get_tree().current_scene
var goblin_def = load("res://data/enemies/goblin.tres")
var loaded_chance = goblin_def.rare_drops.get(&"aether", -1.0)
goblin_def.rare_drops[&"aether"] = 1.0
var far = world.core.global_position + Vector2(-900, 0)
for i in 3:
	# spawn_at emits enemy_spawned, which World already hooks to _on_enemy_killed.
	var g = world.waves.spawn_at(goblin_def, far + Vector2(0, i * 60))
	await get_tree().physics_frame
	g.health.take_damage(9999)
for i in 5:
	await get_tree().physics_frame
var aether_pickups = get_tree().current_scene.find_children("*", "Pickup", true, false).filter(func(p): return p.type == &"aether")
var total = 0
for p in aether_pickups:
	total += p.amount
goblin_def.rare_drops[&"aether"] = loaded_chance
return {loaded_chance = loaded_chance, aether = total}
```
Expected: `loaded_chance` is `0.05` (the data file loaded) and `aether` is `3`; scrap pickups also appear, as normal. Check debug output; stop.

- [ ] **Step 5: Commit**

```bash
git add scripts/enemies/enemy_definition.gd data/enemies/goblin.tres scripts/world.gd
git commit -m "Give goblins a rare Aether drop

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Unlocking locked slots with Scrap

**Files:**
- Modify: `scripts/towers/build_slot.gd` (export, `interact`, `get_interact_prompt`, new `unlock`)

**Interfaces:**
- Consumes: `CommandCore.stored: ResourceBag` (`spend_all`, `shortfall`), `Loot.describe`
- Produces: `BuildSlot.unlock_cost: Dictionary[StringName, int]`, `BuildSlot.unlock() -> bool`

- [ ] **Step 1: Check locked slots can't be unlocked yet (fails)**

Run the game and eval:
```gdscript
var world = get_tree().current_scene
var slot = world.get_node("Units/BuildSlotWest")
slot.locked = true
world.core.stored.add(&"scrap", 10)
slot.interact(world.hero)
return [slot.locked, world.core.stored.get_amount(&"scrap"), slot.get_interact_prompt(world.hero)]
```
Expected: `[true, 10, ""]`. Stop.

- [ ] **Step 2: Implement**

In `scripts/towers/build_slot.gd`:

Update the class doc's first lines to add: `## Locked: Interact pays unlock_cost (Scrap) to open the pad.`

Add after `@export var locked := false`:
```gdscript
## Stored resources spent to unlock a locked pad.
@export var unlock_cost: Dictionary[StringName, int] = {&"scrap": 6}
```
Replace `interact`:
```gdscript
func interact(hero: Hero) -> void:
	if locked:
		unlock()
	elif built:
		built.interact(hero)
	else:
		get_tree().call_group(&"build_menu", &"open", self)
```
In `get_interact_prompt`, replace the `if locked: return ""` lines with:
```gdscript
	if locked:
		var missing := core().stored.shortfall(unlock_cost)
		if missing.is_empty():
			return "[E] Unlock slot (%s)" % Loot.describe(unlock_cost)
		return "Unlock slot: need %s more" % Loot.describe(missing)
```
Add under the `# --- Building, selling, repairing ---` section, after `core()`:
```gdscript
## Pays unlock_cost and opens the pad for building. False if it isn't
## locked or the Core can't afford it (nothing is spent then).
func unlock() -> bool:
	if not locked or not core().stored.spend_all(unlock_cost):
		return false
	locked = false
	return true
```

- [ ] **Step 3: Verify**

Run the game and eval:
```gdscript
var world = get_tree().current_scene
var slot = world.get_node("Units/BuildSlotWest")
var menu = world.get_node("BuildMenu")
slot.locked = true
var stored = world.core.stored
stored.take_all()
stored.add(&"scrap", 2)
var short_prompt = slot.get_interact_prompt(world.hero)
slot.interact(world.hero)
var after_short = [slot.locked, stored.get_amount(&"scrap"), menu.visible]
stored.add(&"scrap", 8)
var ok_prompt = slot.get_interact_prompt(world.hero)
slot.interact(world.hero)
var after_ok = [slot.locked, stored.get_amount(&"scrap"), menu.visible, slot.get_interact_prompt(world.hero)]
return {short_prompt = short_prompt, after_short = after_short, ok_prompt = ok_prompt, after_ok = after_ok}
```
Expected:
- `short_prompt`: `"Unlock slot: need 4 more Scrap"`
- `after_short`: `[true, 2, false]` (nothing spent, no menu)
- `ok_prompt`: `"[E] Unlock slot (6 Scrap)"`
- `after_ok`: `[false, 4, false, "[E] Build"]` (6 spent; this interact only unlocks and doesn't open the menu)

Then walk the hero onto a locked pad for a visual check: set `slot.locked = true`, put the hero on it, and screenshot. The pad shows the locked art and the prompt appears at the bottom. Check debug output; stop.

- [ ] **Step 4: Commit**

```bash
git add scripts/towers/build_slot.gd
git commit -m "Let locked build slots be unlocked with Scrap

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: The ring of 12 slots

**Files:**
- Modify: `scenes/world.tscn` (10 new `BuildSlot` instances; the 2 existing slots moved; wall settings)

**Interfaces:**
- Consumes: `BuildSlot` exports `locked`, `wall_length`, `wall_return`, `unlock_cost` (Task 5)
- Produces: 12 slots under `Units/`, named below; 4 middle ones unlocked

Starting layout (Core at `(640, 384)`; Task 7 tunes these):

| Node | Position | locked | wall_length |
|---|---|---|---|
| BuildSlotNorthWest | (470, 114) | true | 85 |
| BuildSlotNorth | (640, 114) | false | 85 |
| BuildSlotNorthEast | (810, 114) | true | 85 |
| BuildSlotWestNorth | (310, 250) | true | 75 |
| BuildSlotWest | (310, 400) | false | 75 |
| BuildSlotWestSouth | (310, 550) | true | 75 |
| BuildSlotEastNorth | (970, 250) | true | 75 |
| BuildSlotEast | (970, 400) | false | 75 |
| BuildSlotEastSouth | (970, 550) | true | 75 |
| BuildSlotSouthWest | (470, 654) | true | 85 |
| BuildSlotSouth | (640, 654) | false | 85 |
| BuildSlotSouthEast | (810, 654) | true | 85 |

All 12 get `wall_return = 0.0`.

- [ ] **Step 1: Edit the scene**

In `scenes/world.tscn`, keep the `BuildSlotWest` and `BuildSlotEast` node headers (with their `unique_id`s) but set their properties, and add the 10 others after them under `Units`. Each node looks like:
```
[node name="BuildSlotNorthWest" parent="Units" instance=ExtResource("8_build_slot")]
position = Vector2(470, 114)
locked = true
wall_length = 85.0
wall_return = 0.0
```
Unlocked slots leave out the `locked` line (it defaults to false). The `unique_id` attribute on the new nodes can be left off; Godot adds it on the next editor save.

- [ ] **Step 2: Verify slot count and locks**

Run the game and eval:
```gdscript
var slots = get_tree().get_nodes_in_group(&"build_slots")
var locked = slots.filter(func(s): return s.locked).map(func(s): return String(s.name))
var open = slots.filter(func(s): return not s.locked).map(func(s): return String(s.name))
return {count = slots.size(), locked = locked.size(), open = open}
```
Expected: `count` 12, `locked` 8, `open` = the four middle slots (North, West, East, South). Take a screenshot with the camera zoomed out (`world.hero.get_node("Camera").zoom = Vector2(0.6, 0.6)`). All 12 pads are visible around the Core, 8 with the locked art, and none overlap the Core sprite.

- [ ] **Step 3: Verify walls meet and selling only removes a tower's own walls**

Eval (unlocks and builds two neighbours on the West side, then sells one):
```gdscript
var world = get_tree().current_scene
var gearshot = load("res://data/towers/gearshot.tres")
world.core.stored.add(&"scrap", 100)
var a = world.get_node("Units/BuildSlotWest")
var b = world.get_node("Units/BuildSlotWestNorth")
b.unlock()
a.build(gearshot)
b.build(gearshot)
await get_tree().physics_frame
# Gap between the two slots' facing wall ends along the side (y axis).
var a_top = a.walls.filter(func(w): return is_instance_valid(w)).map(func(w): return w.global_position.y).min()
var b_bottom = b.walls.filter(func(w): return is_instance_valid(w)).map(func(w): return w.global_position.y).max()
var gap = a_top - b_bottom
b.sell()
await get_tree().physics_frame
var a_walls_left = a.walls.filter(func(w): return is_instance_valid(w)).size()
return {gap = gap, a_walls = a.walls.size(), a_walls_left = a_walls_left, b_locked = b.locked, b_built = b.built}
```
Expected:
- `gap` ≤ `POST_SPACING` (18). The facing posts meet or overlap; a small gap is fine as long as enemies can't fit through. The nav grid grows blockers, which Task 7's path test confirms.
- `a_walls_left == a_walls`: selling B didn't touch A's walls.
- `b_locked` false, `b_built` null.

Screenshot the West side to confirm the wall looks continuous between the two towers. Check debug output; stop.

- [ ] **Step 4: Commit**

```bash
git add scenes/world.tscn
git commit -m "Lay out 12 build slots in a ring around the Core

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Tune the ring in play, then wrap up

**Files:**
- Modify: `scenes/world.tscn` (position and wall-length tweaks only, if needed)
- Modify: `ROADMAP.md`

**Interfaces:**
- Consumes: `NavGrid.find_path(from, to) -> PackedVector2Array`, `WaveDirector.spawn_point(sector)`, `WaveDirector.spawn_at(def, at)`

- [ ] **Step 1: Build every slot and check the corners are open**

Run the game and eval:
```gdscript
var world = get_tree().current_scene
var gearshot = load("res://data/towers/gearshot.tres")
world.core.stored.add(&"scrap", 500)
for s in get_tree().get_nodes_in_group(&"build_slots"):
	s.unlock()
	s.build(gearshot)
world.nav.rebuild()
var results = {}
for sector in [&"north", &"east", &"south", &"west"]:
	var from = world.waves.spawn_point(sector)
	var path = world.nav.find_path(from, world.core.global_position)
	results[sector] = path[path.size() - 1].distance_to(world.core.global_position) if path.size() > 0 else -1.0
return results
```
Expected: every sector's value is small (the path reaches the Core's edge, well under 150 px). A large value means that sector is sealed off. If so, widen the corner gaps: shorten the flank slots' reach by moving flank slots 10–20 px toward the middle of their side, or lower `wall_length`, and repeat.

(`find_path` ends at the closest reachable point when the Core itself is solid, so "reaches the Core" means the end is next to the Core's footprint, radius about 85–110 px. Compare against a run where one side is fully walled with extra walls if unsure.)

- [ ] **Step 2: Watch goblins funnel through the corners**

With all slots built (same session), spawn a goblin on each side and watch:
```gdscript
var world = get_tree().current_scene
var goblin = load("res://data/enemies/goblin.tres")
for sector in [&"north", &"east", &"south", &"west"]:
	world.waves.spawn_at(goblin, world.waves.spawn_point(sector))
world.hero.get_node("Camera").zoom = Vector2(0.5, 0.5)
return "ok"
```
Take screenshots over time (`game_wait` about 300 physics frames between them). Goblins walk around to the corner gaps and in. None stop to smash a wall while a gap exists; a goblin attacking a wall piece means a gap is too narrow.

- [ ] **Step 3: Check the look**

Screenshot the whole ring zoomed out. Tune `scenes/world.tscn` positions and `wall_length`s until:
- no tower or wall overlaps the Core sprite or another tower
- each side's wall is continuous when fully built
- the 4 corner gaps are clearly visible and walkable for the hero

Walk the hero out through a corner to confirm (`game_key_hold` toward a gap, or set `hero._move_target` to a point outside the ring and wait).

Record the final numbers in the table in Task 6 of this plan if they changed.

- [ ] **Step 4: Update the roadmap**

In `ROADMAP.md` Phase 8, tick:
- `- [x] **[AI]** Aether (2nd resource: rare, found far from base)`
- `- [x] **[AI]** Expand to 12–16 build slots`

and add under the Phase 8 heading a one-line note of the order: `Order: 1) slots + Aether ✅ 2) levels 3) Mortar 4) Embercaster 5) Spire 6) Harvester. Each step: design → build → playtest.`

Also tick the Phase 0 art check `- [x] **[You]** Look over the sprite preview...` (confirmed as fine in chat on 2026-09-24).

- [ ] **Step 5: Final check and commit**

```bash
timeout 60 godot --headless --path . --quit 2>&1 | grep -iE "error" ; git status --short
```
Expected: no errors; only `scenes/world.tscn` (if tuned) and `ROADMAP.md` modified.
```bash
git add scenes/world.tscn ROADMAP.md
git commit -m "Tune the slot ring and tick Phase 8 slots and Aether

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 6: Hand over for playtest**

Tell the user what to try: unlocking slots, building a full side, walking out through a corner, finding crystals near the map edges, and watching the Aether count. Ask them to report how the corners and crystal distance feel. Don't push unless asked.
