# Touch controls for mobile players

Date: 2026-10-02
Status: design approved in chat

Phone and tablet players of the web build (GitHub Pages now, itch.io later)
can play a whole 10-wave run with touch: move, salvage, build, operate and
aim towers, use Q abilities, evolve, buy hero upgrades, pick power-up
cards, pause. Desktop play doesn't change.

## Decisions

| Question | Decision |
|---|---|
| Scope | **Fully playable** on a phone in landscape, start to finish |
| Detection | `OS.has_feature("web_android") or OS.has_feature("web_ios")`, or `web_macos` with `DisplayServer.is_touchscreen_available()` (iPadOS Safari sends a Mac user agent) (also native `"mobile"`); `--touch` user arg forces it on desktop |
| Movement | **Floating joystick**: touch anywhere on the left 45% of the screen |
| Tower aim | **Touch to aim**: while operating, any map touch (not on a button) sets the aim point; dragging moves it |
| UI size | **Zoom UI only**: `content_scale_factor = 1.4`, hero camera zoom × 1/1.4 so the map view is unchanged |
| How input reaches the game | **Inject the existing actions** (`move_*`, `interact`, `manage`, `tower_ability`, `start_wave`, `ui_cancel`); towers read a new `Hero.aim_position()` instead of the mouse |
| Auto-fire | Always on in touch mode; its Options toggle is hidden |
| Hero shots on touch | Auto-aim at the nearest living enemy within the hero's range; no enemy in range → no shot (desktop still shoots at the mouse) |
| Portrait | "Rotate your device" overlay, game paused while shown |
| Button art | Placeholder (circle + glyph) for now |

## Detection — `Settings`

- `var touch_mode: bool`, set once in `_ready()` (before anything reads it):
  true when `OS.has_feature("web_android")`, `OS.has_feature("web_ios")`,
  `OS.has_feature("mobile")`, `OS.has_feature("web_macos")` with
  `DisplayServer.is_touchscreen_available()` (iPadOS), or when `OS.get_cmdline_user_args()` contains
  `--touch`.
- `set_touch_mode(on)` (called from `_ready()` when detected; tests call it
  from an eval because the MCP runner can't pass `--touch`) sets
  `get_tree().root.content_scale_factor = TOUCH_UI_SCALE` (`1.4`) and forces
  `auto_fire = true` (not saved over the player's desktop choice).
- `const TOUCH_UI_SCALE := 1.4` is public so the hero camera can undo it.

## Prompts — `Settings.key_hint(action)`

- `func key_hint(action: StringName) -> String`: in touch mode `""`; otherwise
  `"[%s] " % event_label(<first event bound to action>)`, or `""` when the
  action has nothing bound.
- Replaces the hard-coded `"[E] "` / `"[F] "` in:
  `resource_heap.gd`, `build_slot.gd` (unlock, build), `tower.gd`
  (operate, leave), `command_core.gd` (deposit, upgrade hero), and any other
  prompt string found with `grep -rn '\[[A-Z]\]' scripts`.
- Side effect on desktop: a rebound key now shows its real label.

## The touch layer — `scenes/ui/touch_controls.tscn`

A `CanvasLayer` (layer 3: above the HUD at 1, below the toast at 4 and the
menus at 5+) added under `UI` in `world.tscn`, script
`scripts/ui/touch_controls.gd`. In `_ready()`, if `not Settings.touch_mode`,
it calls `queue_free()` and does nothing else.

It finds the hero the same way the HUD does and reads its state each frame
to show/hide buttons.

```
┌────────────────────────────────────────────┐
│ [HUD panels .........................] [⏸] │
│                                  [▶ Wave]  │  ← only during the break
│                                            │
│     ╭───╮                                  │
│     │ ◯ │  ← appears under the thumb       │
│     ╰───╯     (left 45% of the screen)     │
│                              [Manage] [Use]│
│                                    [Q]     │  ← only while operating
└────────────────────────────────────────────┘
```

### Joystick

- Pure logic lives in `scripts/ui/touch_stick.gd` (`class_name TouchStick`,
  `RefCounted`) so it can be tested headless:
  - `radius := 60.0`. No dead zone of its own: the move actions' existing
    `0.2` deadzone, applied by `Input.get_vector`, is the stick's dead zone.
  - `begin(index: int, at: Vector2)`, `drag(index, at)`, `end(index)`;
    ignores events from any other finger index while one is held.
  - `vector() -> Vector2`: offset / radius, length clamped to 1.
  - `knob_offset() -> Vector2`: offset clamped to `radius` (for drawing).
- `touch_controls.gd` handles `InputEventScreenTouch` /
  `InputEventScreenDrag` in `_input()`:
  - A press in the left 45% of the visible rect that isn't on a button,
    while the hero isn't operating and no menu has the tree paused, begins
    the stick there.
  - Each frame, `vector()` is applied with `Input.action_press(action,
    strength)` on `move_right` / `move_left` / `move_down` / `move_up`
    (positive x → `move_right` at `x`, `move_left` released, and so on);
    released actions get `Input.action_release`. On end, all four release.
  - The stick draws a base ring and knob (`_draw` on a child `Control` or
    `Node2D`) only while held.
- If the hero starts operating, dies, or the tree pauses while the stick is
  held, the stick ends and the actions are released (no stuck movement).

### Buttons

`TouchScreenButton` nodes (they read `InputEventScreenTouch` per finger, so
they work while the other thumb holds the stick; `Button` controls only get
the single emulated mouse). Each has its `action` property set, so presses
arrive as normal action events and the existing `_unhandled_input` handlers
run unchanged. `visibility_mode = ALWAYS`; `passby_press = false`.

| Button | Action | Shown when |
|---|---|---|
| Use | `interact` | the hero has an interactable in reach that returns a non-empty prompt, or is operating (to leave) |
| Manage | `manage` | the nearest interactable has a `manage` method |
| Q | `tower_ability` | the hero is operating a tower |
| ▶ Wave | `start_wave` | the run is in a break (wave not running) |
| ⏸ | `ui_cancel` | always (pause menu ignores it when another menu has paused) |

- Anchored to screen corners by placing them relative to
  `get_viewport().get_visible_rect()` on `size_changed`.
- The Manage button asks the target: `BuildSlot.can_manage(hero)` and
  `CommandCore.can_manage(hero)` (true when Manage would open a menu).
- Textures: `assets/ui/touch/{use,manage,ability,wave,pause,stick_base,stick_knob}.png`,
  simple placeholder circles with a glyph, ~96 px. Real art later.
- Hero needs a small public read so the layer can decide visibility:
  `func nearest_interactable() -> Node` (rename/expose the existing
  `_nearest_interactable`, keeping callers working).

### Aim while operating

- `Hero` gains `var touch_aim: Vector2` and
  `func aim_position() -> Vector2`: `touch_aim` in touch mode, else
  `get_global_mouse_position()`.
- In touch mode, while the hero is operating, a press or drag that isn't on
  a button sets `hero.touch_aim` to the touch position converted to world
  space (`get_viewport().get_canvas_transform().affine_inverse() * pos`).
- `start_operating()` sets `touch_aim` to the tower position plus 120 px in
  the hero's facing direction, so the first Q never fires at an old point.
- Every `get_global_mouse_position()` read in gameplay switches to
  `aim_position()` (via `operator.aim_position()` in towers): `hero.gd`
  (facing), `tower.gd`, `mortar_tower.gd`, `siege_tower.gd`,
  `rune_cannon_tower.gd`, `spire_tower.gd`, `lens_tower.gd`,
  `ember_tower.gd`, and any other hit from
  `grep -rn get_global_mouse_position scripts`.

### Portrait overlay

- Part of `touch_controls.tscn`: a full-rect dark `ColorRect` with
  "Rotate your device to landscape", on its own CanvasLayer at 30 so it
  covers menus, `process_mode = ALWAYS`.
- Shown when the visible rect is taller than wide; while shown it pauses the
  tree (remembering whether it was already paused, and only unpausing if it
  did the pausing).
- The main menu gets the same overlay (instanced there too), without the
  pause logic.

## UI scale and camera

- `content_scale_factor = 1.4` makes every Control and the world 1.4× bigger
  in `canvas_items` stretch mode; anchors lay out against the smaller
  virtual size (≈823×463), so full-rect menus still fit the screen.
- `hero.gd`: `var _base_zoom := 1.0 / Settings.TOUCH_UI_SCALE if
  Settings.touch_mode else 1.0`; the camera starts at `_base_zoom`, and
  `_zoom_to(z)` tweens to `z * _base_zoom` (so 1.0 and `operating_zoom` 0.8
  both keep the desktop framing). The camera-bounds math that uses
  `camera.zoom` keeps working as is.

## Menu fixes

- **Build menu**: add a Close button (all modes) that calls `close()`.
- **Options**: in touch mode hide the key-binding rows and the auto-fire
  toggle.
- **Key names in menus** (Help has no controls page, so this replaces the
  planned touch Help text): in touch mode "Close (Esc)" / "Back (Esc)" /
  "Play Again (R)" drop the key, power cards say "Choose" without "[1]",
  the build menu hint drops "[1–4] build · [Esc] close", the Codex toast
  says "⏸ → Help", and the HUD's "[Q]" / "[Enter]" come from `key_hint`
  ("tap ▶ to start now" on touch).
- **Fit check at 1.4×**: every menu (main, pause, options, help, build,
  tower + evolve view, hero upgrade, card, game over, win) is screenshotted
  in touch mode at 1152×648 and at a phone-shaped window (e.g. 2340×1080).
  Anything clipped gets a `ScrollContainer` or tighter spacing. Result:
  Help's 900×560 panel shrinks to the screen minus a 12 px margin when it
  doesn't fit (its list and text already scroll); the game-over/win summary
  sits in a `ScrollContainer` capped at the room left beside the title and
  buttons (desktop never needs to scroll); the evolve view's spacing is
  tighter (view 10→6, card rows 6→4). Build, options, pause, tower, hero
  upgrade, card and main menus fit as they are.
- **Fullscreen**: on `web_android`, pressing Play on the main menu calls
  `DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)` (it
  runs inside the tap's user gesture). Skipped on iOS, where Safari doesn't
  allow it.

## Things that already work and stay as they are

- Menu buttons, cards, build/evolve/upgrade rows respond to taps through
  Godot's default mouse emulation from touch.
- A tap also emulates a left click, which presses `fire`; with auto-fire
  forced on this has no effect.
- Touch doesn't press `move_to` (right click), so tap-to-move never triggers.

## Testing

- **Headless** `tests/test_touch.gd` (run as
  `timeout 60 godot --headless --path . --script tests/test_touch.gd`):
  `TouchStick` (dead zone gives zero, rim gives length 1, beyond the rim is
  clamped, a second finger index is ignored, end resets) and
  `Settings.key_hint` in both modes.
- **In game with `--touch`** via the Godot MCP tools (`game_touch`):
  joystick moves the hero in all directions and releases cleanly; stick +
  Use with two fingers; build a tower with Use and the build menu; operate,
  touch-aim and fire Q on a Mortar (shells land at the touched point);
  Manage opens the tower menu and Core upgrades; ▶ Wave starts a wave; ⏸
  pauses; card pick by tap; prompts have no `[E]`; every menu at 1.4× fits.
- **Web**: export, then Playwright with an Android device profile
  (`hasTouch`, `isMobile`, Android user agent): touch mode turns on by
  itself, landscape screenshot shows the controls, portrait shows the
  rotate overlay.
- **Desktop regression** without the flag: no touch layer, prompts show the
  bound keys, mouse aim on operated towers unchanged, camera framing
  unchanged.

## Files touched

- New: `scripts/ui/touch_controls.gd`, `scenes/ui/touch_controls.tscn`,
  `scripts/ui/touch_stick.gd`, `assets/ui/touch/*.png`,
  `tests/test_touch.gd`.
- Changed: `scripts/settings.gd`, `scripts/heroes/hero.gd`,
  `scripts/towers/{tower,mortar_tower,siege_tower,rune_cannon_tower,spire_tower,lens_tower,ember_tower}.gd`,
  `scripts/towers/build_slot.gd`, `scripts/loot/resource_heap.gd`,
  `scripts/structures/command_core.gd`, `scripts/ui/{build_menu,options_menu,help_text,main_menu,help_menu,game_over}.gd`
  and their scenes, `scenes/world.tscn`, `scenes/ui/{main_menu,tower_menu,evolve_card}.tscn`,
  `ROADMAP.md`.
