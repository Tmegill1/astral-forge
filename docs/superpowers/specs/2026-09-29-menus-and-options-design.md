# Menus, Part 1: Main menu, pause menu and Options

Date: 2026-09-29
Status: design approved in chat

Part 2 (Help: tower guide with upgrade paths, and the enemy Codex) gets its own
spec after this ships. This part leaves a disabled Help button for it.

## Decisions (from the design discussion)

| Question | Decision |
|---|---|
| Order | Menus + Options first; Help + Codex second |
| Rebindable | Every input action, keyboard **and** mouse; two slots (primary, secondary) per action |
| Other options | Fullscreen, Auto-fire, Master / Music / Effects volume, Reset to defaults |
| Pause-menu Quit | Confirm "Abandon this run?", then back to the main menu. The main menu has its own Quit (hidden in the web build) |
| Structure | A separate main-menu scene; one shared Options screen; a `Settings` autoload that saves to `user://settings.cfg` |
| Shared keys | Allowed (right-click is both Move To and Tower Ability today); shown in amber with "also used by …" |
| Saving | Every change saves immediately; no Apply button |

## Design

### Main menu (`scenes/ui/main_menu.tscn`, `scripts/ui/main_menu.gd`)
- Becomes `application/run/main_scene`.
- Title "Astral Forge" above a centred vertical stack: **Play**, **Options**,
  **Quit**. Background: the map's grass with the Command Core art, dimmed.
- Play: `get_tree().change_scene_to_file("res://scenes/world.tscn")`.
- Options: opens the Options screen on top; the menu is hidden behind it and
  shown again when Options closes.
- Quit: `get_tree().quit()`. Hidden when `OS.has_feature("web")`.
- Keyboard/controller friendly: Play has focus on open; Up/Down move between
  buttons (Godot's built-in focus neighbours).

### Pause menu (`scenes/ui/pause_menu.tscn`, `scripts/ui/pause_menu.gd`)
- A `CanvasLayer` instanced in `world.tscn` next to the other menus,
  `process_mode = ALWAYS`, hidden by default.
- **Opens** on `ui_cancel` (Escape) only when the game is **not** already
  paused. Every other menu (build, tower, hero upgrade, game over) pauses the
  game, so this means Escape still just closes those menus as it does now,
  and the pause menu never opens over the Win / Lose screen.
- **Look**: the screen dims (black at 50%); a centred vertical panel about as
  tall as the Core on screen (≈190 px tall, ≈220 px wide) holds **Resume**,
  **Options**, **Help**, **Quit**, top to bottom.
- Resume, or Escape again: close and unpause.
- Options: opens the Options screen on top (panel hidden until it closes).
  Escape inside Options closes Options, not the pause menu.
- Help: disabled, with the tooltip "Coming soon" (part 2).
- Quit: shows "Abandon this run?" with **Abandon** / **Cancel**. Abandon
  unpauses and changes to the main menu; Cancel returns to the panel.
- Opening sets `get_tree().paused = true`; closing sets it back to false.

### Options (`scenes/ui/options_menu.tscn`, `scripts/ui/options_menu.gd`)
- A full-screen overlay (`process_mode = ALWAYS`) the main menu and pause
  menu both instance. `open()` shows it; it emits `closed` on **Back** or
  Escape (when not waiting for a key).
- Two sections, one above the other, the Controls list scrolling:
  - **Controls**: one `BindingRow` per action (below): label, **Primary**
    button, **Secondary** button.
  - **General**: Fullscreen (checkbox), Auto-fire (checkbox), Master /
    Music / Effects (sliders 0–100%).
- **Reset to defaults** button: restores every binding and setting.
- Every change goes straight to `Settings`, which applies and saves it.

### Binding row (`scenes/ui/binding_row.tscn`, `scripts/ui/binding_row.gd`)
- Shows the action's label and its two slots, each a button labelled with
  the bound input ("W", "Up Arrow", "Right Mouse", "Enter") or "—" when
  empty.
- Click a slot: it reads "Press a key or mouse button…" and the next key
  press or mouse-button press becomes that slot's binding. **Escape**
  cancels (Escape itself can't be bound: it's the pause key). **Delete** or
  **Backspace** clears the slot. Only one slot listens at a time.
- A slot whose input is also bound to another action is tinted amber with
  the tooltip "Also used by: Move To" (names of the other actions).
- Rows refresh on `Settings.changed`.

Actions, in this order, with their labels:
| Action | Label |
|---|---|
| move_up | Move Up |
| move_down | Move Down |
| move_left | Move Left |
| move_right | Move Right |
| move_to | Walk to Spot |
| fire | Fire |
| interact | Interact |
| manage | Manage / Upgrade |
| tower_ability | Tower Ability |
| start_wave | Start Wave |
| toggle_fullscreen | Fullscreen |

### Settings autoload (`scripts/settings.gd`, autoloaded as `Settings` after `Game`)
- `process_mode = ALWAYS`.
- State: `fullscreen: bool` (default false), `auto_fire: bool` (default true),
  `volumes: Dictionary` `{&"Master": 1.0, &"Music": 1.0, &"Effects": 1.0}`.
- `ACTIONS: Array[StringName]`, the list above, and a label for each.
- **Defaults**: on `_ready`, before loading, it copies every action's events
  from `InputMap` (the project's shipped bindings) as the defaults (first
  two events per action; a third or later is dropped).
- **Load** `user://settings.cfg` (`ConfigFile`):
  - `[input]` one key per action: an array of up to two events, each stored
    as a small dictionary (`{"type": "key", "physical_keycode": 87}` or
    `{"type": "mouse", "button_index": 2}`, `null` for an empty slot).
  - `[general]` `fullscreen`, `auto_fire`; `[audio]` one float per bus.
  - A missing file, a file that fails to parse, a missing action, or an
    unreadable event all fall back to the defaults for that part; loading
    never errors. Actions not in the file (added in a later version) keep
    their defaults.
- **Apply**: replaces each action's events in `InputMap` (empty slots
  skipped); sets the window mode; sets each bus's volume
  (`linear_to_db`, and `set_bus_mute` at 0).
- **API** (each setter applies, saves, and emits `changed`):
  - `bind(action: StringName, slot: int, event: InputEvent)`: stores a clean
    copy (key by physical keycode, or mouse button index; modifiers ignored)
  - `clear(action: StringName, slot: int)`
  - `reset_to_defaults()`
  - `set_fullscreen(on: bool)`, `set_auto_fire(on: bool)`,
    `set_volume(bus: StringName, value: float)` (value 0–1)
  - `events_for(action) -> Array` (two entries, `null` for empty)
  - `actions_sharing(action, event) -> Array[StringName]`: the **other**
    actions with an equal input
  - `event_label(event) -> String`
- **Audio buses**: a new `default_bus_layout.tres` (Godot loads it
  automatically) with **Master**, plus **Music** and **Effects** buses that
  send to Master.

### Hooking into existing code
- `Game._input` F11: calls `Settings.set_fullscreen(not Settings.fullscreen)`
  instead of setting the window mode itself, so the checkbox and the saved
  value stay in step.
- `Hero`: in `_ready()`, `auto_fire = Settings.auto_fire`, and it follows
  `Settings.changed` so toggling it mid-run applies at once.
- The Game Over screen's Restart keeps using `reload_current_scene()`;
  settings live in the autoload, so they survive.

## Out of scope
- Help and the Codex (part 2).
- Gamepad bindings, key modifiers (Shift+E), more than two bindings per
  action.
- A hero-select screen, save games / continue.
- Graphics options beyond fullscreen.

## Testing (in the running game, via the Godot MCP tools)
1. The game starts at the main menu; Play loads the map with a fresh run.
2. Rebind Move Up's primary to I: holding I moves the hero up; W no longer
   does; the arrow key (secondary) still does.
3. The binding survives restarting the game (new process); deleting
   `user://settings.cfg` brings back the defaults.
4. Binding Q to Interact shows the amber "Also used by: Tower Ability"
   warning on both; both actions respond to Q.
5. Clearing a slot with Delete leaves it "—" and the action no longer
   responds to that input; Escape while listening cancels without changes.
6. Escape in a run pauses (enemies stop moving) and shows the panel; Escape
   again resumes. With the build menu open, Escape closes only the build menu.
   Escape on the Lose screen doesn't open the pause menu.
7. Pause → Options → Back returns to the pause panel; Escape in Options
   closes only Options.
8. Pause → Quit → Abandon returns to the main menu; Play starts a new run
   (wave 1, full Core, no towers).
9. Fullscreen checkbox and F11 change the window and stay in step; Auto-fire
   off stops the hero shooting until Fire is held, mid-run; volume sliders
   change the buses' volume (and mute at 0).
10. Reset to defaults restores bindings and settings.
11. A `settings.cfg` full of garbage loads without errors, with defaults.
12. A local web export: the main menu has no Quit button; settings persist
    across a page reload.
