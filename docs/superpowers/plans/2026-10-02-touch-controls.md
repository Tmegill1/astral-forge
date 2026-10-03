# Touch Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a whole 10-wave run playable with touch on a phone or tablet browser (landscape), without changing desktop play.

**Architecture:** `Settings.touch_mode` (autodetected from `web_android` / `web_ios` / `mobile`) switches on a `TouchControls` CanvasLayer that turns a floating joystick and `TouchScreenButton`s into the input actions the game already reads. The hero gets `aim_position()` (touch aim point or mouse) which operated towers use, and auto-aims its own shots at the nearest enemy in touch mode. In touch mode the UI is scaled 1.4× through `content_scale_factor` and the hero camera zoom is divided by 1.4 so the map view stays the same. Key hints in prompts and menus come from `Settings.key_hint(action)`, which is empty in touch mode.

**Tech Stack:** Godot 4.7.1 GDScript; headless tests (`timeout 60 godot --headless --path . --script tests/…`); in-game checks with the Godot MCP tools; Python 3 + Pillow 12 for the placeholder button art; Playwright for the web check.

**Spec:** `docs/superpowers/specs/2026-10-02-touch-controls-design.md`

## Global Constraints

- Desktop (touch mode off) must behave exactly as before, apart from prompts now showing the real bound key and the build menu gaining a Close button.
- Touch mode turns on when `OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")` or `(OS.has_feature("web_macos") and DisplayServer.is_touchscreen_available())` (iPadOS), or when `OS.get_cmdline_user_args()` contains `--touch`. Evals switch it on with `Settings.set_touch_mode(true)`.
- `Settings.TOUCH_UI_SCALE := 1.4`. In touch mode: `get_tree().root.content_scale_factor = 1.4`, hero camera zoom = desktop zoom ÷ 1.4, auto-fire forced on (not saved).
- Joystick: starts on a touch in the left `0.45` of the visible width; knob radius `60.0` px; the dead zone is the move actions' existing `0.2` deadzone (applied by `Input.get_vector`), so `TouchStick` adds none.
- Buttons are `TouchScreenButton` (multi-touch), never `Button`, on CanvasLayer **3** (HUD 1, CodexToast 4, menus 5+). Portrait overlay on its own CanvasLayer **30**.
- Button art: placeholder PNGs in `assets/ui/touch/`, 80×80 (pause 56×56, stick base 140×140, knob 60×60).
- Work on branch `touch-controls` (created in Task 1 from `main`, which has the spec and this plan). One commit per task, message ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Stage only the task's files.
- A new `class_name` needs `godot --headless --editor --path . --import` before scripts or tests using it parse; new PNGs need it too.
- Headless tests: always `timeout 60 godot --headless --path . --script tests/<file>.gd`. The existing `tests/test_help_text.gd`, `tests/test_cards.gd`, `tests/test_waves.gd`, `tests/test_run_summary.gd`, `tests/test_evolutions.gd`, `tests/test_art.gd` must keep passing. "Identifier not found" lines about autoloads are harmless noise.
- MCP in-game checks: `run_project` (projectPath `/home/tylermegill/astral-forge`); the first `game_eval` usually says "Not connected" — retry once. The game starts at the main menu. For touch tests, in one eval: `Settings.set_touch_mode(true)`, then `get_tree().change_scene_to_file("res://scenes/world.tscn")`, await ~4 process frames, `var world = get_tree().current_scene`. Set `world.run_cards.ended = true` (XP level-ups otherwise open the pausing CardMenu) and `world.core.health.invulnerable = true`. Hero: `world.hero`; touch layer: `world.get_node("UI/TouchControls")`.
- Sending touches from an eval: positions are **viewport** coordinates (the 823×463-ish space in touch mode); convert to window coordinates with `get_tree().root.get_final_transform() * pos` before `Input.parse_input_event`. Helper to paste into evals:
  ```gdscript
  var touch := func(index: int, pos: Vector2, pressed: bool) -> void:
  	var e := InputEventScreenTouch.new()
  	e.index = index; e.pressed = pressed
  	e.position = get_tree().root.get_final_transform() * pos
  	Input.parse_input_event(e)
  var drag := func(index: int, pos: Vector2) -> void:
  	var e := InputEventScreenDrag.new()
  	e.index = index
  	e.position = get_tree().root.get_final_transform() * pos
  	Input.parse_input_event(e)
  ```
  (`mcp__godot__game_touch` also works, with window coordinates.)
- Do timing-sensitive checks inside one `game_eval` (keep each under ~25 s). Disconnect any lambda connected to a game signal before the eval returns. A script error freezes the game: check `get_debug_output`, then `stop_project` + `run_project`. After `stop_project`, `git checkout project.godot` (or strip only stray blank lines / the McpInteractionServer autoload).
- Wave 1 starts 45 s after the world loads (`world.waves.state == WaveDirector.State.BREAK` before that).
- Delete `user://settings.cfg` (`~/.local/share/godot/app_userdata/Astral forge/settings.cfg`) after tests that change settings.

## Review Focus

1. **A finger lifts while the tree is paused or after the hero starts operating or dies.** Movement must not stay stuck on. The stick resets and every move action it pressed is released (Task 5 check: hold the stick, open the build menu with Use, close it, and the hero is not walking).
2. **Two fingers at once: stick held plus Use, Q or ⏸.** The button fires and the stick keeps working. A button touch never starts the stick or moves the aim point (Task 5 check).
3. **Keyboard on a touch device, or WASD in `--touch` desktop testing.** The touch layer only releases actions it pressed itself, so a held key is never cancelled every frame (Task 5 check with `Input.action_press(&"move_up")` held while the stick is idle).
4. **Q in touch mode right after starting to operate, before any aim touch.** The ability lands just in front of the tower (the default aim point), not at a stale point or at the Q button's world position (Task 3 check with the Mortar).
5. **Window or orientation changes mid-run.** The buttons re-anchor to the new visible rect, and portrait shows the overlay and pauses without unpausing a menu that was already open (Task 6 check: open the build menu, go portrait, then landscape; the build menu is still open and the tree is still paused).

---

### Task 1: Touch mode and key hints in Settings

**Files:**
- Modify: `scripts/settings.gd`
- Create: `tests/test_touch.gd`

**Interfaces:**
- Produces: `Settings.TOUCH_UI_SCALE: float` (1.4); `Settings.touch_mode: bool`; `Settings.set_touch_mode(on: bool) -> void`; `Settings.key_hint(action: StringName) -> String` (`"[E] "`-style, or `""` in touch mode or when unbound).

- [ ] **Step 1: Create the branch**

```bash
git checkout -b touch-controls
```

- [ ] **Step 2: Write the failing test** `tests/test_touch.gd`:

```gdscript
extends SceneTree
## Headless checks for touch controls: the joystick math, key hints and
## that no prompt hard-codes a key.
## Run: timeout 60 godot --headless --path . --script tests/test_touch.gd
## Prints each failure and "touch: N passed, M failed"; exits 1 on failure.
## (Lines about autoloads not being found are harmless in --script mode.)

var passed := 0
var failed := 0


func _init() -> void:
	_test_key_hint()
	print("touch: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_key_hint() -> void:
	var settings: Node = load("res://scripts/settings.gd").new()
	var up := InputEventKey.new()
	up.physical_keycode = KEY_UP
	var right_mouse := InputEventMouseButton.new()
	right_mouse.button_index = MOUSE_BUTTON_RIGHT
	settings._bindings[&"interact"] = [up, null]
	settings._bindings[&"manage"] = [null, right_mouse]
	settings._bindings[&"start_wave"] = [null, null]
	settings.touch_mode = false
	check("hint key", settings.key_hint(&"interact"), "[Up Arrow] ")
	check("hint second slot", settings.key_hint(&"manage"), "[Right Mouse] ")
	check("hint unbound", settings.key_hint(&"start_wave"), "")
	check("hint unknown action", settings.key_hint(&"no_such_action"), "")
	settings.touch_mode = true
	check("hint touch", settings.key_hint(&"interact"), "")
	settings.free()


func check(label: String, got: Variant, want: Variant) -> void:
	if got == want:
		passed += 1
	else:
		failed += 1
		print("FAIL %s: got %s, want %s" % [label, var_to_str(got), var_to_str(want)])
```

- [ ] **Step 3: Run it to see it fail**

Run: `timeout 60 godot --headless --path . --script tests/test_touch.gd`
Expected: a script error about `touch_mode` / `key_hint` not found (non-zero exit).

- [ ] **Step 4: Implement in `scripts/settings.gd`**

Update the header comment's first line to `## Player settings: key bindings, fullscreen, auto-fire, volume and touch`.
Below `const KEY_NAMES ...` add:

```gdscript
## How much bigger the HUD and menus are in touch mode. The hero camera
## divides its zoom by this so the map view stays the same.
const TOUCH_UI_SCALE := 1.4
```

Below `var volumes ...` add:

```gdscript
## True on phones and tablets (or with the --touch user arg): on-screen
## controls, bigger UI, auto-fire always on, no key names in prompts.
var touch_mode := false
```

At the end of `_ready()` add:

```gdscript
	if OS.has_feature("web_android") or OS.has_feature("web_ios") \
			or OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--touch"):
		set_touch_mode(true)
```

After `set_auto_fire()` add:

```gdscript
## Switches touch mode on or off (detected at startup; tests switch it by
## hand). Auto-fire is forced on without saving over the desktop choice.
func set_touch_mode(on: bool) -> void:
	touch_mode = on
	get_tree().root.content_scale_factor = TOUCH_UI_SCALE if on else 1.0
	if on:
		auto_fire = true
	changed.emit()


## "[E] " for the first key or button bound to `action`, to put in front of
## a prompt; "" in touch mode (the on-screen buttons replace keys) or when
## nothing is bound.
func key_hint(action: StringName) -> String:
	if touch_mode or not _bindings.has(action):
		return ""
	for event in _bindings[action]:
		if event:
			return "[%s] " % event_label(event)
	return ""
```

`set_auto_fire()` must not undo the force: change its body to

```gdscript
func set_auto_fire(on: bool) -> void:
	auto_fire = on or touch_mode
	_save()
	changed.emit()
```

- [ ] **Step 5: Run the test to see it pass**

Run: `timeout 60 godot --headless --path . --script tests/test_touch.gd`
Expected: `touch: 5 passed, 0 failed`

- [ ] **Step 6: Run the other headless tests**

Run: `for t in help_text cards waves run_summary evolutions art; do timeout 60 godot --headless --path . --script tests/test_$t.gd 2>&1 | tail -1; done`
Expected: each ends with `0 failed`.

- [ ] **Step 7: Commit**

```bash
git add scripts/settings.gd tests/test_touch.gd
git commit -m "Add touch mode and key hints to Settings

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: TouchStick joystick logic

**Files:**
- Create: `scripts/ui/touch_stick.gd`
- Modify: `tests/test_touch.gd`

**Interfaces:**
- Produces: `class_name TouchStick extends RefCounted` with `radius: float = 60.0`, `finger: int = -1`, `origin: Vector2`, `is_held() -> bool`, `begin(index: int, at: Vector2)`, `drag(index: int, at: Vector2)`, `end(index: int)`, `reset()`, `vector() -> Vector2` (length ≤ 1, no dead zone), `knob_offset() -> Vector2` (length ≤ radius).

- [ ] **Step 1: Add the failing tests** to `tests/test_touch.gd`. In `_init()`, call `_test_stick()` before `_test_key_hint()`, and add:

```gdscript
func _test_stick() -> void:
	var script: GDScript = load("res://scripts/ui/touch_stick.gd")
	if script == null:
		failed += 1
		print("FAIL scripts/ui/touch_stick.gd missing")
		return
	var stick = script.new()
	check("idle not held", stick.is_held(), false)
	check("idle vector", stick.vector(), Vector2.ZERO)
	stick.begin(2, Vector2(100, 300))
	check("held", stick.is_held(), true)
	check("finger", stick.finger, 2)
	check("origin", stick.origin, Vector2(100, 300))
	check("just pressed", stick.vector(), Vector2.ZERO)
	stick.drag(2, Vector2(130, 300))
	check("half right", stick.vector(), Vector2(0.5, 0))
	stick.drag(2, Vector2(100, 240))
	check("rim up", stick.vector(), Vector2(0, -1))
	stick.drag(2, Vector2(100, 600))
	check("past rim clamped", stick.vector(), Vector2(0, 1))
	check("knob clamped", stick.knob_offset(), Vector2(0, 60))
	stick.begin(5, Vector2(10, 10))
	check("second finger can't take it", stick.finger, 2)
	stick.drag(5, Vector2(500, 500))
	check("other finger's drag ignored", stick.vector(), Vector2(0, 1))
	stick.end(5)
	check("other finger's lift ignored", stick.is_held(), true)
	stick.end(2)
	check("lifted", stick.is_held(), false)
	check("lifted vector", stick.vector(), Vector2.ZERO)
	stick.begin(0, Vector2(50, 50))
	stick.drag(0, Vector2(80, 50))
	stick.reset()
	check("reset", [stick.is_held(), stick.vector()], [false, Vector2.ZERO])
```

- [ ] **Step 2: Run it to see it fail**

Run: `timeout 60 godot --headless --path . --script tests/test_touch.gd`
Expected: `FAIL scripts/ui/touch_stick.gd missing` and `1 failed`.

- [ ] **Step 3: Implement** `scripts/ui/touch_stick.gd`:

```gdscript
class_name TouchStick
extends RefCounted
## A floating joystick's state: where its finger came down and how far it
## has been pushed. Pure logic so it can be tested headless; TouchControls
## draws it and turns vector() into the move actions (whose own 0.2
## deadzone is the stick's dead zone).

## How far the knob can travel from where the finger came down, in pixels.
var radius := 60.0
## The touch index holding the stick, or -1 when nobody is.
var finger := -1
## Where the finger came down (the stick's centre), in viewport pixels.
var origin := Vector2.ZERO

var _offset := Vector2.ZERO


func is_held() -> bool:
	return finger >= 0


## Starts the stick under `at`, unless another finger already holds it.
func begin(index: int, at: Vector2) -> void:
	if is_held():
		return
	finger = index
	origin = at
	_offset = Vector2.ZERO


func drag(index: int, at: Vector2) -> void:
	if index == finger:
		_offset = at - origin


func end(index: int) -> void:
	if index == finger:
		reset()


func reset() -> void:
	finger = -1
	_offset = Vector2.ZERO


## How far the knob is pushed, as a share of the radius (length at most 1).
func vector() -> Vector2:
	return knob_offset() / radius


## The knob's offset from origin, kept inside the radius.
func knob_offset() -> Vector2:
	return _offset.limit_length(radius)
```

- [ ] **Step 4: Import the new class, then run the test**

Run: `godot --headless --editor --path . --import >/dev/null 2>&1; timeout 60 godot --headless --path . --script tests/test_touch.gd`
Expected: `touch: 21 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/touch_stick.gd scripts/ui/touch_stick.gd.uid tests/test_touch.gd
git commit -m "Add the TouchStick joystick logic

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Hero aim, touch auto-aim and camera scale

**Files:**
- Modify: `scripts/heroes/hero.gd`
- Modify: `scripts/towers/tower.gd:247-249`
- Modify: `scripts/towers/mortar_tower.gd:66-68`
- Modify: `scripts/towers/build_slot.gd` (add `can_manage`)
- Modify: `scripts/structures/command_core.gd` (add `can_manage`)

**Interfaces:**
- Consumes: `Settings.touch_mode`, `Settings.TOUCH_UI_SCALE`, `Settings.set_touch_mode()` (Task 1).
- Produces: `Hero.touch_aim: Vector2`; `Hero.aim_position() -> Vector2`; `Hero.nearest_interactable() -> Node` (public, replaces `_nearest_interactable`); `BuildSlot.can_manage(hero: Hero) -> bool`; `CommandCore.can_manage(hero: Hero) -> bool`.

- [ ] **Step 1: Write the in-game check first (expected to fail now).** `run_project`, then this `game_eval` (retry once if "Not connected"):

```gdscript
Settings.set_touch_mode(true)
get_tree().change_scene_to_file("res://scenes/world.tscn")
for i in 4: await get_tree().process_frame
var world = get_tree().current_scene
world.run_cards.ended = true
var hero = world.hero
return [hero.has_method(&"aim_position"), hero.camera.zoom]
```

Expected now: `[false, (1, 1)]` (no `aim_position`, camera not compensated). `stop_project`, `git checkout project.godot`.

- [ ] **Step 2: Implement in `scripts/heroes/hero.gd`**

Update the header comment's controls paragraph: after `E to interact.` add `On touch (Settings.touch_mode) the on-screen controls press the same actions, shots auto-aim at the nearest enemy in range, and operated towers aim at touch_aim.`

Below `var camera_bounds := Rect2()` add:

```gdscript
## Touch mode: where operated towers aim, set by touching the map
## (TouchControls). Unused with a mouse.
var touch_aim := Vector2.ZERO
```

Below `var _facing := 1.0` add:

```gdscript
## Camera zoom with no tower operated: 1, or smaller in touch mode to undo
## the bigger UI scale so the map view matches desktop.
var _base_zoom := 1.0
```

In `_ready()`, after `Settings.changed.connect(_on_settings_changed)`:

```gdscript
	if Settings.touch_mode:
		_base_zoom = 1.0 / Settings.TOUCH_UI_SCALE
	camera.zoom = Vector2.ONE * _base_zoom
```

In `_physics_process`, the operating branch: replace
`_facing_left = get_global_mouse_position().x < global_position.x` with
`_facing_left = aim_position().x < global_position.x`.

Replace the idle-facing lines

```gdscript
	elif input == Vector2.ZERO:
		_facing_left = get_global_mouse_position().x < global_position.x
```

with

```gdscript
	elif input == Vector2.ZERO:
		var look: Variant = _shot_target()
		if look != null:
			_facing_left = look.x < global_position.x
```

and update the comment above them to `# Face where you're walking; when standing still, face where you'd shoot.`

Replace the firing lines

```gdscript
	_cooldown -= delta
	if _cooldown <= 0.0 and (auto_fire or Input.is_action_pressed(&"fire")):
		_fire()
		_cooldown = 1.0 / stats.attacks_per_second
```

with

```gdscript
	_cooldown -= delta
	if _cooldown <= 0.0 and (auto_fire or Input.is_action_pressed(&"fire")):
		var target: Variant = _shot_target()
		if target != null:
			_fire(target)
			_cooldown = 1.0 / stats.attacks_per_second
```

Change `func _fire() -> void:` and its first line to:

```gdscript
func _fire(target: Vector2) -> void:
	var aim := target - muzzle.global_position
```

(`grep -rn "_fire()" scripts tests` — hero is the only caller of the hero's `_fire`; towers have their own `_fire_at`.)

Add after `_fire`:

```gdscript
## Where the hero's shots go: the mouse; in touch mode the body of the
## nearest living enemy in range, or null when there is none (no shot).
func _shot_target() -> Variant:
	if not Settings.touch_mode:
		return get_global_mouse_position()
	var best: Enemy = null
	var best_distance := stats.attack_range
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy.health.is_dead:
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best.hurtbox_shape.global_position if best else null


## Where an operated tower aims: touch_aim in touch mode, else the mouse.
func aim_position() -> Vector2:
	return touch_aim if Settings.touch_mode else get_global_mouse_position()
```

In `start_operating(tower)`, after `global_position = tower.operator_position()` add:

```gdscript
	# Touch: aim just in front of the tower until the player touches the map.
	touch_aim = tower.global_position + (Vector2.LEFT if _facing_left else Vector2.RIGHT) * 120.0
```

Change `_zoom_to` to scale by the base zoom:

```gdscript
func _zoom_to(zoom: float) -> void:
	create_tween().tween_property(camera, "zoom", Vector2.ONE * zoom * _base_zoom, 0.25) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
```

Rename `_nearest_interactable` to `nearest_interactable` (definition and every call: `grep -rn "_nearest_interactable" scripts`).

- [ ] **Step 3: Towers aim at `aim_position()`**

`scripts/towers/tower.gd`:

```gdscript
## Where an operated tower aims: the operator's aim (mouse, or touch aim
## point on phones). Tower types can clamp it.
func _operated_aim_point() -> Vector2:
	return operator.aim_position()
```

`scripts/towers/mortar_tower.gd`: the doc line becomes `## The operator's aim, pulled in or out to lie between min range and range.` and
`var offset := operator.get_global_mouse_position() - global_position` becomes
`var offset := operator.aim_position() - global_position`.

Then `grep -rn "get_global_mouse_position" scripts` must show only `hero.gd` (inside `_shot_target`, `aim_position` and the right-click `_movement_input`).

- [ ] **Step 4: `can_manage` for the touch Manage button**

`scripts/towers/build_slot.gd`, after `manage()`:

```gdscript
## True when Manage would open something (the touch Manage button shows then).
func can_manage(hero: Hero) -> bool:
	return built != null and not built.is_destroyed() and hero.operating != built
```

`scripts/structures/command_core.gd`, after `manage()`:

```gdscript
## True when Manage would open something (the touch Manage button shows then).
func can_manage(hero: Hero) -> bool:
	return not hero.definition.upgrades.is_empty()
```

- [ ] **Step 5: Validate and re-run the check**

`mcp__godot__validate_scripts`, then `run_project` and repeat the Step 1 eval. Expected: `[true, (0.714286, 0.714286)]`.

Then in the same run, a second eval for Review Focus 4 and auto-aim:

```gdscript
var world = get_tree().current_scene
var hero = world.hero
var slot = world.find_child("BuildSlotWest", true, false)
slot.locked = false
var d: Dictionary[StringName, int] = {&"scrap": 200, &"aether": 30}
world.core.stored.add_all(d)
slot.build(load("res://data/towers/rune_mortar.tres"))
await get_tree().physics_frame
hero.start_operating(slot.built)
await get_tree().create_timer(0.4).timeout
var tower = slot.built
var aim: Vector2 = tower._operated_aim_point()
var zoom_operating: Vector2 = hero.camera.zoom
hero.touch_aim = tower.global_position + Vector2(0, -150)
var aim2: Vector2 = tower._operated_aim_point()
hero.stop_operating()
await get_tree().create_timer(0.4).timeout
return [aim.distance_to(tower.global_position), zoom_operating, aim2.distance_to(tower.global_position + Vector2(0, -150)) < 1.0, hero.camera.zoom]
```

Expected: first value between the Mortar's min range and range (≈120 clamped), `zoom_operating ≈ (0.571, 0.571)`, `true`, `(0.714286, 0.714286)`.

Third eval, hero auto-aim:

```gdscript
var world = get_tree().current_scene
var hero = world.hero
var none = hero._shot_target()
var e = world.waves.spawn_at(load("res://data/enemies/goblin.tres"), hero.global_position + Vector2(200, 0))
e.set_physics_process(false)
var t = hero._shot_target()
var far = world.waves.spawn_at(load("res://data/enemies/goblin.tres"), hero.global_position + Vector2(-2000, 0))
far.set_physics_process(false)
var t2 = hero._shot_target()
e.health.take_damage(999999, Health.DamageType.MAGIC)
far.health.take_damage(999999, Health.DamageType.MAGIC)
return [none, t != null and t.x > hero.global_position.x, t2 == t]
```

Expected: `[null, true, true]`. Check `get_debug_output` for new errors. `stop_project`, `git checkout project.godot`.

- [ ] **Step 6: Desktop regression.** `run_project`, eval without `set_touch_mode`: load the world as above, then

```gdscript
var hero = get_tree().current_scene.hero
get_viewport().warp_mouse(get_viewport().get_canvas_transform() * (hero.global_position + Vector2(100, 0)))
await get_tree().process_frame
return [hero.camera.zoom, hero.aim_position().distance_to(hero.global_position + Vector2(100, 0)) < 2.0, hero._shot_target() != null]
```

Expected: `[(1, 1), true, true]`. `stop_project`, `git checkout project.godot`.

- [ ] **Step 7: Headless tests still pass** (same loop as Task 1 Step 6, plus `test_touch`).

- [ ] **Step 8: Commit**

```bash
git add scripts/heroes/hero.gd scripts/towers/tower.gd scripts/towers/mortar_tower.gd scripts/towers/build_slot.gd scripts/structures/command_core.gd
git commit -m "Aim towers and hero shots without a mouse in touch mode

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Key hints from bindings, touch-friendly menu text, build menu Close

**Files:**
- Modify: `scripts/loot/resource_heap.gd:27`, `scripts/towers/build_slot.gd:103-112`, `scripts/towers/tower.gd:178-180`, `scripts/structures/command_core.gd:67-69`, `scripts/heroes/hero.gd:17` (comment)
- Modify: `scripts/ui/hud.gd:51-53,72`
- Modify: `scripts/ui/build_menu.gd`, `scenes/ui/build_menu.tscn`
- Modify: `scripts/ui/tower_menu.gd`, `scripts/ui/hero_upgrade_menu.gd`, `scripts/ui/game_over.gd`, `scripts/ui/power_card.gd`, `scripts/ui/codex_toast.gd`, `scripts/ui/options_menu.gd`
- Modify: `tests/test_touch.gd`

**Interfaces:**
- Consumes: `Settings.key_hint(action)`, `Settings.touch_mode` (Task 1).
- Produces: `BuildMenu.close_button: Button` (`%CloseButton`).

- [ ] **Step 1: Add the failing test** — no script may hard-code a key in brackets. In `tests/test_touch.gd`, call `_test_no_hard_coded_keys()` in `_init()` and add:

```gdscript
## Prompts and hints get their key from Settings.key_hint, so none may
## spell out "[E]", "[F]", "[Q]" or "[Enter]" themselves.
func _test_no_hard_coded_keys() -> void:
	var files := ["res://scripts/loot/resource_heap.gd", "res://scripts/towers/build_slot.gd",
			"res://scripts/towers/tower.gd", "res://scripts/structures/command_core.gd",
			"res://scripts/ui/hud.gd"]
	for file in files:
		var text := FileAccess.get_file_as_string(file)
		for key in ["\"[E]", "\"[F]", "\"[Q]", "[Enter]"]:
			check("%s has no %s" % [file.get_file(), key], text.contains(key), false)
```

Run: `timeout 60 godot --headless --path . --script tests/test_touch.gd`
Expected: several `FAIL ... has no ...` lines.

- [ ] **Step 2: Prompts use `key_hint`**

- `resource_heap.gd`: `return "%s%s (%d %s)" % [Settings.key_hint(&"interact"), action, amount, Loot.display_name(type)]`
- `build_slot.gd`: `return "%sUnlock slot (%s)" % [Settings.key_hint(&"interact"), Loot.describe(unlock_cost)]`; `return Settings.key_hint(&"interact") + "Build"`; `return text + "    %sRepair / Upgrade / Sell" % Settings.key_hint(&"manage")`
- `tower.gd`: `return "%sLeave %s" % [Settings.key_hint(&"interact"), definition.display_name]` and `return "%sOperate %s" % [Settings.key_hint(&"interact"), definition.display_name]`
- `command_core.gd`: `parts.append("%sDeposit %s" % [Settings.key_hint(&"interact"), hero.carried.describe()])` and `parts.append(Settings.key_hint(&"manage") + "Upgrade hero")`
- `hero.gd:17` comment: `## Text for the nearest interactable ("[E] Deposit ...", or "Deposit ..." on touch), or "" for none.`
- `hud.gd`: `ability_text.text = "%s%s recharging: %ds" % [Settings.key_hint(&"tower_ability"), def.ability_name, ceili(tower.ability_cooldown_left())]`, `ability_text.text = "%s%s ready" % [Settings.key_hint(&"tower_ability"), def.ability_name]`, and the break line:

```gdscript
			var start := "tap ▶ to start now" if Settings.touch_mode \
					else Settings.key_hint(&"start_wave") + "start now"
			wave_status.text = "Arrives in %d:%02d  ·  %s" % [left / 60, left % 60, start]
```

Run the test again. Expected: `0 failed`.

- [ ] **Step 3: Build menu Close button.** In `scenes/ui/build_menu.tscn`, after the `Hint` node add:

```
[node name="CloseButton" type="Button" parent="Center/Panel/Margin/Rows"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 4
text = "Close (Esc)"
```

In `build_menu.gd`: header comment's last sentence becomes `Esc, E or Close closes.`; add `@onready var close_button: Button = %CloseButton` and `@onready var hint: Label = $Center/Panel/Margin/Rows/Hint`; in `_ready()`:

```gdscript
	close_button.pressed.connect(close)
	if Settings.touch_mode:
		close_button.text = "Close"
		hint.text = "Game paused  ·  Walls are raised on both sides of every tower"
```

- [ ] **Step 4: Other menus drop key names in touch mode.** Add to each `_ready()` (after the existing setup):

- `tower_menu.gd`:
  ```gdscript
  	if Settings.touch_mode:
  		close_button.text = "Close"
  		back_button.text = "Back"
  ```
- `hero_upgrade_menu.gd`: `if Settings.touch_mode: close_button.text = "Close"` (as two lines).
- `game_over.gd`: `if Settings.touch_mode: play_again_button.text = "Play Again"` (two lines).
- `codex_toast.gd`: add `@onready var hint: Label = %Hint` (and set `unique_name_in_owner = true` on the `Hint` node in `scenes/ui/codex_toast.tscn`), then in `_ready()` `if Settings.touch_mode: hint.text = "⏸ → Help to read it"`.
- `power_card.gd` in `show_card`: `choose_button.text = "Choose" if Settings.touch_mode else "Choose  [%d]" % key`.
- `options_menu.gd` — touch hides key bindings and auto-fire. Add `@onready var controls_header: Label = $Center/Panel/Margin/Rows/ControlsHeader` and `@onready var bindings_scroll: ScrollContainer = $Center/Panel/Margin/Rows/Scroll`; in `_ready()`:
  ```gdscript
  	if Settings.touch_mode:
  		controls_header.visible = false
  		bindings_scroll.visible = false
  		auto_fire_box.visible = false
  ```
  and in `_refresh()` the fullscreen label: `fullscreen_box.text = ("Fullscreen: " if Settings.touch_mode else "Fullscreen (F11): ") + ("On" if Settings.fullscreen else "Off")`.

- [ ] **Step 5: Check in game.** `mcp__godot__validate_scripts`; `run_project`. Desktop eval: load the world, move the hero next to the Core (`world.hero.global_position = world.core.global_position + Vector2(0, 60); world.hero.reset_physics_interpolation()`), await 3 physics frames, return `world.hud.prompt.text` and `world.get_node("UI/BuildMenu").close_button.text`. Expected: the prompt contains `[F] Upgrade hero`, button `Close (Esc)`. `stop_project`, `git checkout project.godot`, `run_project` again; same eval with `Settings.set_touch_mode(true)` first. Expected: `Upgrade hero` with no `[`, button `Close`. Open the build menu on a free slot (`slot.locked = false; slot.interact(world.hero)`), screenshot, tap Close (`close_button.pressed.emit()`), `get_tree().paused == false`. `stop_project`, `git checkout project.godot`.

- [ ] **Step 6: Headless tests** (all, as in Task 1 Step 6 plus `test_touch`). Expected: `0 failed` everywhere.

- [ ] **Step 7: Commit**

```bash
git add scripts/loot/resource_heap.gd scripts/towers/build_slot.gd scripts/towers/tower.gd scripts/structures/command_core.gd scripts/heroes/hero.gd scripts/ui/hud.gd scripts/ui/build_menu.gd scenes/ui/build_menu.tscn scripts/ui/tower_menu.gd scripts/ui/hero_upgrade_menu.gd scripts/ui/game_over.gd scripts/ui/codex_toast.gd scenes/ui/codex_toast.tscn scripts/ui/power_card.gd scripts/ui/options_menu.gd tests/test_touch.gd
git commit -m "Take key hints from the bindings and drop them on touch

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: The touch controls layer

**Files:**
- Create: `tools/make_touch_buttons.py`, `assets/ui/touch/{use,manage,ability,wave,pause,stick_base,stick_knob}.png`
- Create: `scripts/ui/touch_controls.gd`, `scenes/ui/touch_controls.tscn`
- Modify: `scenes/world.tscn` (instance under `UI`), `scripts/world.gd` (bind it)
- Modify: `tests/test_help_text.gd` (layer order check)

**Interfaces:**
- Consumes: `TouchStick` (Task 2); `Settings.touch_mode`; `Hero.operating`, `Hero.health`, `Hero.touch_aim`, `Hero.nearest_interactable()`; `can_manage(hero)` on BuildSlot / CommandCore (Task 3); `WaveDirector.state`, `WaveDirector.State.BREAK`.
- Produces: `class_name TouchControls extends CanvasLayer`; `TouchControls.bind(hero: Hero, director: WaveDirector) -> void`; `TouchControls.stick: TouchStick`; nodes `%Use`, `%Manage`, `%Ability`, `%Wave`, `%Pause` (TouchScreenButton), `%Controls` (Node2D), `%StickView` (Node2D).

- [ ] **Step 1: Placeholder art tool** `tools/make_touch_buttons.py`:

```python
#!/usr/bin/env python3
"""Draws the placeholder on-screen touch buttons into assets/ui/touch/.

Each is a translucent dark disc with a brass rim and a short label, until
real art replaces them. Run: python3 tools/make_touch_buttons.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent.parent / "assets" / "ui" / "touch"
RIM = (184, 143, 72, 230)
FILL = (16, 18, 24, 150)
TEXT = (240, 228, 200, 255)

# name: (size, label)
BUTTONS = {
    "use": (80, "USE"),
    "manage": (80, "MANAGE"),
    "ability": (80, "Q"),
    "wave": (80, "WAVE"),
    "pause": (56, "II"),
    "stick_base": (140, ""),
    "stick_knob": (60, ""),
}


def font(size: int) -> ImageFont.ImageFont:
    for name in ("DejaVuSans-Bold.ttf", "LiberationSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def draw(size: int, label: str, knob: bool) -> Image.Image:
    scale = 4  # draw big, then shrink, for smooth edges
    big = size * scale
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rim = 3 * scale
    fill = (184, 143, 72, 200) if knob else FILL
    d.ellipse((rim, rim, big - rim, big - rim), fill=fill, outline=RIM, width=rim)
    if label:
        f = font(int(big * (0.34 if len(label) <= 2 else 0.18)))
        box = d.textbbox((0, 0), label, font=f)
        d.text(((big - (box[2] - box[0])) / 2 - box[0], (big - (box[3] - box[1])) / 2 - box[1]),
               label, font=f, fill=TEXT)
    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (size, label) in BUTTONS.items():
        draw(size, label, name == "stick_knob").save(OUT / f"{name}.png")
        print(f"wrote {OUT / name}.png")


if __name__ == "__main__":
    main()
```

Run: `python3 tools/make_touch_buttons.py && godot --headless --editor --path . --import >/dev/null 2>&1; ls assets/ui/touch/*.png.import | wc -l`
Expected: 7 `wrote` lines, then `7`. Read one PNG with the Read tool to eyeball it.

- [ ] **Step 2: Layer-order check (failing).** In `tests/test_help_text.gd`, next to the existing toast-layer checks, add:

```gdscript
	# Touch controls sit above the HUD, below the Codex notice and every menu.
	var touch_layer := _layer("res://scenes/ui/touch_controls.tscn")
	check("touch above hud", touch_layer > 1, true)
	check("touch below toast", touch_layer < toast_layer, true)
```

Run: `timeout 60 godot --headless --path . --script tests/test_help_text.gd`
Expected: a script error (the scene doesn't exist yet, so `load()` returns null).

- [ ] **Step 3: The script** `scripts/ui/touch_controls.gd`:

```gdscript
class_name TouchControls
extends CanvasLayer
## On-screen controls for phones and tablets (Settings.touch_mode; with a
## mouse and keyboard it removes itself). A floating joystick on the left of
## the screen presses the move actions; the buttons press interact, manage,
## tower_ability, start_wave and ui_cancel, so the game reads them like
## keys. While the hero operates a tower, touching the map sets its aim
## point instead. Everything hides while a menu has the game paused.

## Share of the screen width, from the left, where a touch starts the stick.
const STICK_ZONE := 0.45
## Gap from the screen edge and between buttons, in pixels.
const MARGIN := 16.0
const GAP := 12.0
const STICK_BASE := preload("res://assets/ui/touch/stick_base.png")
const STICK_KNOB := preload("res://assets/ui/touch/stick_knob.png")
## Move action -> the stick axis and sign that presses it.
const MOVE_ACTIONS := {
	&"move_right": Vector2(1, 0), &"move_left": Vector2(-1, 0),
	&"move_down": Vector2(0, 1), &"move_up": Vector2(0, -1),
}

var stick := TouchStick.new()

var _hero: Hero
var _director: WaveDirector
## The touch index aiming an operated tower, or -1.
var _aim_finger := -1
## Move actions this layer is holding (so it never releases a real key).
var _pressed: Dictionary[StringName, bool] = {}

@onready var controls: Node2D = %Controls
@onready var stick_view: Node2D = %StickView
@onready var use_button: TouchScreenButton = %Use
@onready var manage_button: TouchScreenButton = %Manage
@onready var ability_button: TouchScreenButton = %Ability
@onready var wave_button: TouchScreenButton = %Wave
@onready var pause_button: TouchScreenButton = %Pause
@onready var _buttons: Array[TouchScreenButton] = [
	use_button, manage_button, ability_button, wave_button, pause_button]


func _ready() -> void:
	if not Settings.touch_mode:
		queue_free()
		return
	stick_view.draw.connect(_draw_stick)
	get_viewport().size_changed.connect(_place_buttons)
	_place_buttons()


func bind(hero: Hero, director: WaveDirector) -> void:
	_hero = hero
	_director = director


func _process(_delta: float) -> void:
	var paused := get_tree().paused
	controls.visible = not paused
	var can_walk := not paused and _hero != null and not _hero.health.is_dead \
			and _hero.operating == null
	if not can_walk:
		stick.reset()
	if paused or _hero == null or _hero.operating == null:
		_aim_finger = -1
	_apply_stick()
	_update_buttons()
	stick_view.queue_redraw()


func _input(event: InputEvent) -> void:
	if get_tree().paused or _hero == null or _hero.health.is_dead:
		return
	if event is InputEventScreenTouch:
		if not event.pressed:
			stick.end(event.index)
			if event.index == _aim_finger:
				_aim_finger = -1
		elif _on_button(event.position):
			return
		elif _hero.operating:
			_aim_finger = event.index
			_set_aim(event.position)
		elif event.position.x < get_viewport().get_visible_rect().size.x * STICK_ZONE:
			stick.begin(event.index, event.position)
	elif event is InputEventScreenDrag:
		stick.drag(event.index, event.position)
		if event.index == _aim_finger:
			_set_aim(event.position)


## Presses each move action as far as the stick leans that way; releases
## the ones this layer pressed that the stick no longer leans toward.
func _apply_stick() -> void:
	var v := stick.vector()
	for action: StringName in MOVE_ACTIONS:
		var strength := maxf(v.dot(MOVE_ACTIONS[action]), 0.0)
		if strength > 0.0:
			Input.action_press(action, strength)
			_pressed[action] = true
		elif _pressed.get(action, false):
			Input.action_release(action)
			_pressed.erase(action)


func _update_buttons() -> void:
	if _hero == null:
		return
	var alive := not _hero.health.is_dead
	var target := _hero.nearest_interactable() if alive else null
	use_button.visible = alive and (_hero.operating != null or target != null)
	manage_button.visible = alive and _hero.operating == null and target != null \
			and target.has_method(&"can_manage") and target.can_manage(_hero)
	ability_button.visible = alive and _hero.operating != null
	wave_button.visible = _director != null and _director.state == WaveDirector.State.BREAK


## Bottom-right cluster (Use, Manage to its left, Q above Use); pause and
## Wave down the right edge under the HUD's wave panel.
func _place_buttons() -> void:
	var size := get_viewport().get_visible_rect().size
	var big := 80.0
	use_button.position = Vector2(size.x - MARGIN - big, size.y - MARGIN - big)
	manage_button.position = use_button.position - Vector2(big + GAP, 0)
	ability_button.position = use_button.position - Vector2(0, big + GAP)
	pause_button.position = Vector2(size.x - MARGIN - 56.0, 92.0)
	wave_button.position = Vector2(size.x - MARGIN - big, 92.0 + 56.0 + GAP)


func _on_button(pos: Vector2) -> bool:
	for button in _buttons:
		if button.is_visible_in_tree() and Rect2(button.position,
				button.texture_normal.get_size() * button.scale).has_point(pos):
			return true
	return false


func _set_aim(pos: Vector2) -> void:
	_hero.touch_aim = get_viewport().get_canvas_transform().affine_inverse() * pos


func _draw_stick() -> void:
	if not stick.is_held():
		return
	stick_view.draw_texture(STICK_BASE, stick.origin - STICK_BASE.get_size() / 2.0)
	stick_view.draw_texture(STICK_KNOB,
			stick.origin + stick.knob_offset() - STICK_KNOB.get_size() / 2.0)
```

- [ ] **Step 4: The scene** `scenes/ui/touch_controls.tscn` (create with the Write tool; the editor adds uids on the next import):

```
[gd_scene load_steps=7 format=3]

[ext_resource type="Script" path="res://scripts/ui/touch_controls.gd" id="1_touch"]
[ext_resource type="Texture2D" path="res://assets/ui/touch/use.png" id="2_use"]
[ext_resource type="Texture2D" path="res://assets/ui/touch/manage.png" id="3_manage"]
[ext_resource type="Texture2D" path="res://assets/ui/touch/ability.png" id="4_ability"]
[ext_resource type="Texture2D" path="res://assets/ui/touch/wave.png" id="5_wave"]
[ext_resource type="Texture2D" path="res://assets/ui/touch/pause.png" id="6_pause"]

[node name="TouchControls" type="CanvasLayer"]
process_mode = 3
layer = 3
script = ExtResource("1_touch")

[node name="Controls" type="Node2D" parent="."]
unique_name_in_owner = true

[node name="StickView" type="Node2D" parent="Controls"]
unique_name_in_owner = true

[node name="Use" type="TouchScreenButton" parent="Controls"]
unique_name_in_owner = true
texture_normal = ExtResource("2_use")
action = "interact"

[node name="Manage" type="TouchScreenButton" parent="Controls"]
unique_name_in_owner = true
texture_normal = ExtResource("3_manage")
action = "manage"

[node name="Ability" type="TouchScreenButton" parent="Controls"]
unique_name_in_owner = true
texture_normal = ExtResource("4_ability")
action = "tower_ability"

[node name="Wave" type="TouchScreenButton" parent="Controls"]
unique_name_in_owner = true
texture_normal = ExtResource("5_wave")
action = "start_wave"

[node name="Pause" type="TouchScreenButton" parent="Controls"]
unique_name_in_owner = true
texture_normal = ExtResource("6_pause")
action = "ui_cancel"
```

(`visibility_mode` defaults to Always and `passby_press` to false; leave them.) Pressed look: set `modulate` darker while pressed is optional — skip (YAGNI).

- [ ] **Step 5: Wire it into the world.** In `scenes/world.tscn` add an ext_resource for `res://scenes/ui/touch_controls.tscn` (next free id, e.g. `24_touch`, and bump `load_steps`) and, after the `HUD` node:

```
[node name="TouchControls" parent="UI" instance=ExtResource("24_touch")]
```

In `scripts/world.gd` `_ready()`, after `hud.bind_waves(waves)`:

```gdscript
	var touch := get_node_or_null("UI/TouchControls") as TouchControls
	if touch and not touch.is_queued_for_deletion():
		touch.bind(hero, waves)
```

Import (`godot --headless --editor --path . --import`), then run `tests/test_help_text.gd`: expected `0 failed`.

- [ ] **Step 6: In-game checks (touch).** `validate_scripts`; `run_project`; eval loads the world in touch mode (Global Constraints), sets `run_cards.ended` and Core invulnerable, then with the `touch`/`drag` helpers:

  a. **Stick moves the hero:** `var start = world.hero.global_position`; `touch.call(0, Vector2(150, 350), true)`; `drag.call(0, Vector2(210, 350))`; await 20 physics frames; `var moved = world.hero.global_position.x - start.x`; `touch.call(0, Vector2(210, 350), false)`; await 3 physics frames; return `[moved > 20, Input.is_action_pressed(&"move_right"), world.hero.velocity]`. Expected `[true, false, (0, 0)]`.
  b. **Right half doesn't start the stick:** `touch.call(0, Vector2(600, 300), true)`; await 3 frames; return `layer.stick.is_held()` → `false`; release.
  c. **Two fingers (Review Focus 2):** put the hero beside the Core; hold the stick with index 0 at (150, 350) dragged up to (150, 300); press index 1 on the Manage button's centre (`layer.manage_button.position + Vector2(40, 40)`); await 2 frames; expect `world.get_node("UI/HeroUpgradeMenu").visible == true` and `layer.stick.finger == 0` before the pause reset — then assert after 2 more frames `layer.stick.is_held() == false` and `Input.is_action_pressed(&"move_up") == false` (Review Focus 1); close with `world.get_node("UI/HeroUpgradeMenu").close()`; release both fingers.
  d. **Keyboard not cancelled (Review Focus 3):** `Input.action_press(&"move_up")`; await 5 physics frames; expect `Input.is_action_pressed(&"move_up") == true`; `Input.action_release(&"move_up")`.
  e. **Use → build → operate → touch aim → Q:** unlock `BuildSlotWest`, add resources, walk/teleport the hero beside it, tap Use (index 0 on its centre, press then release), expect the BuildMenu visible; `build_menu._choose(load("res://data/towers/rune_mortar.tres"))`; tap Use again → `world.hero.operating != null`; tap the map at viewport (650, 200) (index 0) and release; expect `hero.touch_aim` equals `get_viewport().get_canvas_transform().affine_inverse() * Vector2(650, 200)` (±1 px); tap Q (Ability centre) → `slot.built.ability_cooldown_left() > 0`.
  f. **Wave and pause:** with `world.waves.state == WaveDirector.State.BREAK`, tap Wave → state becomes `WAVE`; tap Pause → `world.get_node("UI/PauseMenu").visible` and `get_tree().paused`; `PauseMenu.close()`.
  g. **Screenshot** (`mcp__godot__game_screenshot`) in the break with the stick held, and one while operating; check buttons don't overlap the HUD panels. If they do, adjust the y offsets in `_place_buttons()` (keep the cluster in the bottom-right) and re-check.

  Check `get_debug_output` for new errors after each eval. `stop_project`, `git checkout project.godot`.

- [ ] **Step 7: Desktop regression.** `run_project`, load the world without touch mode: `world.get_node_or_null("UI/TouchControls")` after 2 frames is `null`; WASD (`Input.action_press(&"move_right")` for 10 physics frames) still moves the hero. `stop_project`, `git checkout project.godot`.

- [ ] **Step 8: Headless tests** (all). Expected `0 failed`.

- [ ] **Step 9: Commit**

```bash
git add tools/make_touch_buttons.py assets/ui/touch scripts/ui/touch_controls.gd scripts/ui/touch_controls.gd.uid scenes/ui/touch_controls.tscn scenes/world.tscn scripts/world.gd tests/test_help_text.gd
git commit -m "Add the on-screen joystick and buttons for touch play

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Portrait overlay and Android fullscreen

**Files:**
- Create: `scripts/ui/rotate_overlay.gd`, `scenes/ui/rotate_overlay.tscn`
- Modify: `scenes/ui/touch_controls.tscn` (instance the overlay), `scenes/ui/main_menu.tscn` (instance the overlay), `scripts/ui/main_menu.gd`

**Interfaces:**
- Consumes: `Settings.touch_mode`, `Settings.set_fullscreen(on)`.
- Produces: `class_name RotateOverlay extends CanvasLayer` with `@export var pauses := true`; `RotateOverlay.is_portrait() -> bool`.

- [ ] **Step 1: The overlay script** `scripts/ui/rotate_overlay.gd`:

```gdscript
class_name RotateOverlay
extends CanvasLayer
## Touch mode only: covers the screen with "Rotate your device" while it is
## taller than wide. In a run it also pauses the game, and only unpauses if
## it was the one that paused (a menu that had the game paused stays so).

## False on the main menu, where there is nothing to pause.
@export var pauses := true

var _paused_it := false

@onready var cover: Control = $Cover


func _ready() -> void:
	if not Settings.touch_mode:
		queue_free()
		return
	get_viewport().size_changed.connect(_update)
	_update()


func is_portrait() -> bool:
	var size := get_viewport().get_visible_rect().size
	return size.y > size.x


func _update() -> void:
	var portrait := is_portrait()
	cover.visible = portrait
	if not pauses:
		return
	if portrait and not get_tree().paused:
		get_tree().paused = true
		_paused_it = true
	elif not portrait and _paused_it:
		get_tree().paused = false
		_paused_it = false
```

- [ ] **Step 2: The scene** `scenes/ui/rotate_overlay.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/rotate_overlay.gd" id="1_rotate"]

[node name="RotateOverlay" type="CanvasLayer"]
process_mode = 3
layer = 30
script = ExtResource("1_rotate")

[node name="Cover" type="ColorRect" parent="."]
visible = false
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.03, 0.04, 0.06, 0.96)

[node name="Label" type="Label" parent="Cover"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_font_sizes/font_size = 28
text = "Rotate your device to landscape"
horizontal_alignment = 1
vertical_alignment = 1
autowrap_mode = 3
```

- [ ] **Step 3: Use it.** Instance it as a child of the root of `scenes/ui/touch_controls.tscn` (ext_resource + `[node name="RotateOverlay" parent="." instance=...]`). The touch controls freeing themselves on desktop frees it too. In `scenes/ui/main_menu.tscn` instance it at the root with `pauses = false`.

- [ ] **Step 4: Android fullscreen on Play.** In `scripts/ui/main_menu.gd`, at the top of `_play()`:

```gdscript
	# Phones: hide the browser bars. Browsers only allow it from a tap, and
	# iPhone Safari never does, so only Android asks.
	if Settings.touch_mode and OS.has_feature("web_android"):
		Settings.set_fullscreen(true)
```

- [ ] **Step 5: Check in game (Review Focus 5).** Import, `validate_scripts`, `run_project`. Eval in touch mode: load the world; open the build menu on an unlocked slot (`slot.interact(world.hero)`); `DisplayServer.window_set_size(Vector2i(600, 1000))`; await 3 frames; expect overlay `Cover.visible` and `get_tree().paused`; screenshot; `DisplayServer.window_set_size(Vector2i(1152, 648))`; await 3 frames; expect the cover hidden, BuildMenu still visible and `get_tree().paused == true`; close the build menu → not paused. Then without a menu: portrait → paused; landscape → unpaused. Main menu (`change_scene_to_file("res://scenes/ui/main_menu.tscn")`, touch mode on): portrait shows the cover and `get_tree().paused == false`. `stop_project`, `git checkout project.godot`.

- [ ] **Step 6: Headless tests** (all). Expected `0 failed`.

- [ ] **Step 7: Commit**

```bash
git add scripts/ui/rotate_overlay.gd scripts/ui/rotate_overlay.gd.uid scenes/ui/rotate_overlay.tscn scenes/ui/touch_controls.tscn scenes/ui/main_menu.tscn scripts/ui/main_menu.gd
git commit -m "Ask phone players to rotate to landscape, and go fullscreen on Android

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Menus fit at 1.4×, web check, roadmap

**Files:**
- Modify (only if clipped): `scenes/ui/{build_menu,tower_menu,help_menu,options_menu,card_menu,game_over,hero_upgrade_menu,pause_menu,main_menu}.tscn`
- Modify: `ROADMAP.md`
- Modify: `docs/superpowers/specs/2026-10-02-touch-controls-design.md` (only if a fix changes something it states)

- [ ] **Step 1: Screenshot every menu in touch mode** at two window sizes, 1152×648 and 1170×540 (a 19.5:9 phone shape; `mcp__godot__game_window` action `set`). `run_project`, touch mode on, and for each: main menu, Options (from main menu), Help (Towers tab and Codex tab), in-world pause menu, build menu (every buildable tower affordable: give 999 scrap / 99 aether), tower menu on a Lv3 tower and its evolve view, hero upgrade menu, card menu (`world.get_node("UI/CardMenu")` opened by granting XP with `world.run_cards.ended = false; world.run_cards.add_xp(1000)`), game over (`world.core.health.take_damage(999999, Health.DamageType.MAGIC)` with invulnerable off), win screen (`world._on_run_won()`). Take a `game_screenshot` of each.

- [ ] **Step 2: Fix anything clipped or cut off.** A screen fails if any text, button or card goes past the screen edge or can't be reached. Fixes, in order of preference:
  1. A row of cards (build menu `Cards` HBox) that is too wide → change it to an `HFlowContainer` so it wraps, or wrap it in a `ScrollContainer` (`horizontal_scroll_mode = 1`, `vertical_scroll_mode = 0`, `custom_minimum_size.x` = 760) — pick whichever keeps all Build buttons on screen.
  2. A column too tall (help, options, evolve view, game over) → put its body in a `ScrollContainer` with `custom_minimum_size.y` sized to fit inside 463 px minus the title and buttons, and `vertical_scroll_mode = 1`.
  3. Spacing → reduce `separation` / margins only in the clipped container.
  Re-screenshot each fix at both sizes, and once on desktop (touch off) to make sure desktop still looks right.

- [ ] **Step 3: Web check with an Android profile.**
  - Export: `godot --headless --path . --export-release "Web" export/web/index.html`
  - Serve: `python3 -m http.server 8765 -d export/web` in the background; note its PID.
  - In the scratchpad, write `touch_check.mjs` using `playwright-core` and chromium from `~/.cache/ms-playwright` with args `--use-angle=swiftshader --enable-unsafe-swiftshader`, context `{ viewport: {width: 844, height: 390}, deviceScaleFactor: 3, isMobile: true, hasTouch: true, userAgent: "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Mobile Safari/537.36" }`. Load `http://localhost:8765/`, wait for the canvas plus ~6 s, screenshot the main menu, `page.touchscreen.tap()` on Play (find it from the screenshot; the menu is now 1.4× bigger, so it is not at y≈321), wait ~4 s, screenshot the world (the joystick zone is empty and the buttons are visible), then `page.setViewportSize({width: 390, height: 844})`, wait 1 s, screenshot (rotate overlay). Also log `console` messages and fail on any `SCRIPT ERROR`.
  - Look at the three screenshots. Kill the server by its PID (never `pkill -f`).

- [ ] **Step 4: Roadmap.** In `ROADMAP.md` Phase 11, after `- [ ] **[AI]** Controller support` add:

```markdown
- [x] **[AI]** Touch controls for phone/tablet browsers (joystick, on-screen buttons, touch aim, 1.4× UI) — `docs/superpowers/specs/2026-10-02-touch-controls-design.md`
- [ ] **[You]** Play a full run on your phone; is the joystick zone/button size right? Real button art wanted
```

- [ ] **Step 5: Full test pass.** All headless tests (`0 failed` each); `git status` shows only intended files (no `project.godot`, no `export/`).

- [ ] **Step 6: Commit**

```bash
git add ROADMAP.md scenes/ui docs/superpowers/specs/2026-10-02-touch-controls-design.md
git commit -m "Fit the menus to the touch UI scale and tick the roadmap

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
