# Menus, Part 2: Help (tower guide) and the enemy Codex

Date: 2026-09-30
Status: design approved in chat

Builds on part 1 (`2026-09-29-menus-and-options-design.md`): the pause menu's
disabled Help button becomes a real Help screen, also reachable from the main
menu.

## Decisions (from the design discussion)

| Question | Decision |
|---|---|
| When an enemy joins the Codex | The first time one **comes on screen** (not when it spawns off-camera) |
| Towers tab detail | Descriptions + costs + upgrade bonuses (numbers where you need them to plan) |
| Enemy detail | No exact numbers: words only |
| Unseen enemies | Listed as dark silhouettes named "???"; a "New Codex entry" notice pops up when one unlocks |
| Where Help opens | Pause menu **and** main menu |
| Where the words come from | Hand-written text in each tower/enemy data file, plus lines generated from the data (numbers for towers, word ratings for enemies) |
| Saving | A separate `Codex` autoload saving to `user://codex.cfg`, so Options' Reset never clears it |

## Design

### Help screen (`scenes/ui/help_menu.tscn`, `scripts/ui/help_menu.gd`)
- A `CanvasLayer` overlay (`process_mode = ALWAYS`, layer 20) with the same
  look as Options: black 60% dim, a centred solid dark panel with a gold
  border (≈900×560), title "Help", **Towers** / **Codex** tabs, **Back**.
- `open()` shows it on the Towers tab with the first entry selected;
  `signal closed` on Back or Escape.
- Each tab is split: a scrolling **list** on the left (≈220 px wide, one
  button per entry with a small icon and name) and a **detail** panel on the
  right (scrolls if long). Clicking an entry shows its details; the selected
  entry is highlighted.

### Towers tab
One entry per tower data file in `data/towers/`, in this order: Gearshot
Turret, Rune Mortar, Embercaster, Aether Spire. Detail panel, top to bottom:
- Picture (the build menu's icon) and name.
- `description` (existing field).
- **Damage:** `damage_type_label` (Physical / Fire / Magic).
- **Good against:** `good_against`. **Weak against:** `weak_against`.
- **Ability (while operated):** `ability_name` — `ability_text`
  (Cooldown: `ability_cooldown` s).
- **Operated:** "+35% damage, +50% fire rate, +15% range" from the
  `operated_*_multiplier` fields (percent = (multiplier − 1) × 100, rounded;
  a multiplier of 1 is left out).
- **Upgrade path:**
  - "Lv1 — Build: 10 Scrap"
  - "Lv2 — 15 Scrap: +30% damage, +15% fire rate, +10% range, +40% health"
  - "Lv3 — 25 Scrap + 3 Aether: +30% damage, +15% fire rate, +10% range,
    +40% health (again)"
  Costs from `cost`, `lv2_cost`, `lv3_cost` (formatted like the build menu:
  "10 Scrap", "25 Scrap + 3 Aether"); bonuses from the `level_*_multiplier`
  fields.
- A tower with `available = false` shows "Coming soon" under its name (none
  today).

`TowerDefinition` gains a **Help** export group:
- `damage_type_label: String` (display only; the damage type itself stays in
  each tower's code).
- `good_against: String`, `weak_against: String` (one short line each).
- `ability_text: String` (what the ability does, in words).

Text for the four towers:
| Tower | Damage | Good against | Weak against | Ability text |
|---|---|---|---|---|
| Gearshot | Physical | Swarms of basic goblins | Armour (bullets glance off) | Triples the fire rate for 3 s. |
| Rune Mortar | Magic | Tight groups and armour, far away | Anything right next to it (can't fire that close) | Fires a double-strength shell that leaves a slowing rune circle for 4 s. |
| Embercaster | Fire | Crowds at close range; burning finishes them off | Long range; it has to refuel | 3 s of free fuel, a wider cone and maximum burn. |
| Aether Spire | Magic | Spread-out groups and armour | Lone tough enemies (the chain has nothing to jump to) | Double-strength lightning that jumps 8 times without weakening and stuns for 1 s. |

### Codex tab
One entry per enemy data file in `data/enemies/`, sorted by `display_name`.
- **Seen**: icon (first idle frame) + name.
- **Not seen**: the same icon drawn as a black silhouette (`modulate` black)
  and the name "???"; its detail panel shows the silhouette and "Not yet
  encountered."
- Seen detail panel, top to bottom:
  - Animated idle sprite (an `AnimatedSprite2D` playing `idle`) and name.
  - `codex_summary`.
  - **At a glance:** "Health: High · Speed: Low · Hits: Average".
  - **Strengths:** the generated resistance lines, then `codex_strengths`.
  - **Weaknesses:** the generated weakness line, then `codex_weaknesses`.
  - **Tip:** `codex_tip`.

Word ratings (relative to the basic Goblin, `data/enemies/goblin.tres`):
- ratio = this enemy's value ÷ the Goblin's: **Low** below 0.8, **Average**
  0.8 to 1.5, **High** above 1.5 up to 2.5, **Very high** above 2.5.
- Health: `max_health`. Speed: `move_speed`. Hits: damage per second =
  `attack_damage × attacks_per_second`.

Generated resistance lines, per damage type (Physical, Fire, Magic):
- `*_taken` ≤ 0.5 → Strength "Shrugs off {Type} damage".
- 0.5 < `*_taken` < 1.0 → Strength "Resists {Type} damage".
- If any type is resisted, the type(s) with the highest `*_taken` →
  Weakness "Weak to {Type}" (two tied types: "Weak to Physical and Fire").

`EnemyDefinition` gains a **Codex** export group:
- `codex_summary: String`
- `codex_strengths: PackedStringArray`, `codex_weaknesses: PackedStringArray`
- `codex_tip: String`

Text for the three enemies:
| Enemy | Summary | Strengths | Weaknesses | Tip |
|---|---|---|---|---|
| Goblin | The basic raider: comes in numbers and goes for the Core. | Arrives in large groups | Fragile on its own | Gearshots and the hero's bolts handle them well. |
| Armored Goblin | A heavy brute in padded armour with a cleaver. | Hits hard up close; takes a beating | Slow on its feet | Bring magic: a Rune Mortar or Aether Spire cuts right through. |
| Goblin Shaman | A caster that hangs back, throws magic orbs and drives nearby goblins into a frenzy. | Makes nearby goblins faster and deadlier; attacks from range; walls don't stop it casting | Frail; stuns and kills interrupt its frenzy | Kill it first — frenzied packs break walls quickly. |

(With the current data the generated lines give: Goblin none; Armored Goblin
"Shrugs off Physical damage", "Resists Fire damage", "Weak to Magic";
Goblin Shaman "Resists Magic damage", "Weak to Physical and Fire".)

### Codex autoload (`scripts/codex.gd`, autoloaded as `Codex` after `Settings`)
- `process_mode = ALWAYS`. Loads `user://codex.cfg` (`ConfigFile`, section
  `[seen]`, key = enemy id, value `true`) at startup. A missing or broken
  file (or a non-bool value) means that enemy isn't seen; loading never
  errors (check `has_section_key` before reading).
- `signal discovered(definition: EnemyDefinition)`.
- `is_seen(id: StringName) -> bool`.
- `mark_seen(definition: EnemyDefinition)`: if not seen, records it, saves at
  once and emits `discovered`. Already seen: nothing.
- `all_enemies() -> Array[EnemyDefinition]`: every `.tres` in
  `res://data/enemies/`, found with `ResourceLoader.list_directory()` (which
  also works in exported builds, where the files are remapped), sorted by
  `display_name`.

### Discovery on screen
- `enemy.tscn` gains a `VisibleOnScreenNotifier2D` named `OnScreen`; `Enemy`
  sizes its `rect` to the hurtbox in `_fit_hurtbox()` and, on
  `screen_entered`, calls `Codex.mark_seen(definition)` (once per enemy,
  disconnecting after).
- **Notice** (`scenes/ui/codex_toast.tscn`, `scripts/ui/codex_toast.gd`): a
  `CanvasLayer` in `world.tscn` (layer 5, above the HUD, below menus) that
  listens to `Codex.discovered` and shows a small panel near the top centre:
  "New Codex entry: Goblin Shaman" and, smaller, "Esc → Help to read it". It
  fades in, stays ~3 s, fades out; several discoveries queue and show one
  after another. It keeps running while paused (`process_mode = ALWAYS`) so
  a queued notice isn't stuck, but new sightings can't happen while paused.

### Menu changes
- **Pause menu**: Help is enabled (no tooltip) and opens the Help screen
  (panel hidden until Help closes, like Options).
- **Main menu**: buttons become **Play / Options / Help / Quit**; Help opens
  the same Help screen (buttons hidden until it closes).
- Escape inside Help closes Help only.

## Out of scope
- A button to reset the Codex.
- Hero and Artificer upgrades, controls help, or a how-to-play tab.
- Tower evolutions (they don't exist yet; the upgrade path shows Lv1–3).
- Localisation.

## Testing (in the running game, via the Godot MCP tools)
1. With no `codex.cfg`: an enemy spawned far off camera is not marked seen;
   moving the camera onto it marks it seen, shows the notice once, and saves
   (`user://codex.cfg` has it). Seeing a second of the same type shows no
   new notice.
2. The seen state survives a restart; a garbage `codex.cfg` loads as
   nothing seen, with no errors.
3. Help opens from the main menu and from the pause menu; Back and Escape
   close it (Escape from the pause menu's Help returns to the pause panel,
   still paused).
4. Towers tab: four entries in order; the Gearshot's upgrade path and
   operated line match its data (costs and percentages).
5. Codex tab: seen enemies show name, ratings and lines; unseen ones show a
   silhouette and "???". The Armored Goblin shows "Health: High · Speed:
   Low · Hits: Average", "Shrugs off Physical damage", "Resists Fire damage"
   and "Weak to Magic".
6. Two new enemy types seen at once: two notices, one after the other.
7. Web export: Help is on the main menu; a Codex entry survives a page
   reload; no console errors.
