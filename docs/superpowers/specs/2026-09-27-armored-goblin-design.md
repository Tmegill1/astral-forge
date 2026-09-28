# Phase 9, Step 1: Armored Goblin (damage types, editable waves, and removing Mastery XP)

Date: 2026-09-27
Status: design approved in chat

## Decisions (from the design discussion)

| Question | Decision |
|---|---|
| Art | The existing `goblin_brute` sheet (padded leather, helmet, cleaver); swappable later in its data file |
| How armour works | % of damage taken, by damage type |
| Damage types | Physical: Gearshot bullets, hero bolts. Fire: Embercaster flame and burn. Magic: Rune Mortar shells, Aether Spire lightning |
| Where resistance lives | On `Health`, filled in from the enemy's data |
| Mastery XP | Removed entirely. Player XP and power-up cards come later (Phase 10), not in this step |
| Editing waves | A node tree scene (WaveRun → Wave → SpawnGroup) edited in Godot, replacing the nested `.tres` |

## Design

### Damage types
- `Health` gains `enum DamageType { PHYSICAL, FIRE, MAGIC }`, used as
  `Health.DamageType.MAGIC`.
- `Health.damage_taken`: one multiplier per type, all 1.0 by default, so the
  Core, towers, walls and the hero are unaffected.
- `Health.take_damage(amount, type := PHYSICAL) -> float` scales `amount` by
  that type's multiplier, applies it as before (ignored when dead,
  invulnerable or ≤ 0), and returns the damage actually dealt (0 when
  ignored; never more than the health that was left).
- New signal `Health.damaged(dealt: float, type: int, blocked: float)`,
  emitted whenever damage is applied. `blocked` = the part removed by the
  multiplier.
- Enemy attacks on towers, walls, the hero and the Core stay physical (the
  default argument), so they are unchanged.

### Which attack is which type
- Physical: `Projectile` (Gearshot bullets and hero bolts) — gains
  `damage_type` (default physical) and passes it on.
- Fire: Embercaster flame ticks; `Enemy._tick_burn`.
- Magic: `Shell` (Rune Mortar blast and Rune Shell); `SpireTower._strike`
  (normal bolts and Resonance Burst).
- `RuneCircle` only slows and is unchanged.

### Enemy data
- `EnemyDefinition` gains `physical_taken`, `fire_taken`, `magic_taken`
  (each default 1.0). `Enemy._ready()` copies them into its Health's
  `damage_taken`. The basic goblin needs no change.

### Armored Goblin (`data/enemies/armored_goblin.tres`)
- Sprites: `assets/sprites/goblin_brute.tres`, sprite_scale 0.32 (basic
  goblin 0.3), hit on the cleaver-swing frame (calibrated by screenshot).
- Damage taken: physical 30%, fire 60%, magic 100%.
- 60 health; move speed 55; attack 8 at 0.8/s; attack range 20; aggro
  range 140.
- Drops: 3–4 Scrap; 10% Aether.
- Effective damage per hit on it: Gearshot 2.4, hero bolt 3, Embercaster
  tick 1.8 (burn deals 60%), Mortar shell 14, Spire bolt 10.

### Armour spark (`scripts/effects/armor_spark.gd`)
- A small self-freeing Node2D: a few short grey-white lines bursting outward
  from a point, fading over 0.15 s. Drawn above units (`z_index = 1`).
- `Enemy` listens to its Health's `damaged` signal and spawns one at its body
  point when a physical hit had `blocked > 0`. It's added to the enemy's
  parent, so it outlives the enemy.
- It never touches the enemy's tint, so it can't clash with burn or stun.

### Editing waves: a node tree
Waves move out of `data/waves/first_playtest.tres` (nested sub-resources)
into a scene you edit in Godot's scene tree and inspector:

```
FirstRun            (WaveRun: heaps_per_break, max_heaps, aether_* settings)
├─ Wave1            (Wave: prep_time 45)
│   └─ GoblinsWest  (SpawnGroup: enemy goblin.tres, count 6, sector west,
│                    interval 2.0, delay 0)
├─ Wave2 …
```
- `WaveRun extends Node` (`scripts/waves/wave_run.gd`): the scene root. It
  holds the run-wide settings that `RunDefinition` has today, and its `Wave`
  children, top to bottom, are the waves in order.
- `Wave extends Node` (`scripts/waves/wave.gd`): `prep_time`; its
  `SpawnGroup` children are the wave's groups.
- `SpawnGroup extends Node` (`scripts/waves/spawn_group.gd`): `enemy`
  (EnemyDefinition file picker), `count`, `sector` (dropdown: north / east /
  south / west), `interval`, `delay` — the same fields `WaveGroup` has.
- Each converts itself to the existing data (`to_definition()` →
  `RunDefinition` / `WaveDefinition` / `WaveGroup`), so nothing downstream
  changes (sector warnings, the wave counter, spawning, winning, heaps).
- `WaveDirector` gets `@export var waves_scene: PackedScene` (set to
  `scenes/waves/first_run.tscn` in `world.tscn`). In `_ready()` it
  instantiates the scene, builds `run` from it, and frees the tree. `run`
  stops being an export. A `SpawnGroup` with no enemy is skipped with a
  warning in the Output panel; nodes of other types are ignored (so you can
  park a group under a plain Node to switch it off).
- `data/waves/first_playtest.tres` is deleted once the scene holds the same
  waves.
- Editing: duplicate a wave or group with Ctrl+D, reorder by dragging, pick
  the enemy file and side in the inspector. Node names are just labels.

### Waves in `scenes/waves/first_run.tscn`
The existing five waves, exactly as they are now, plus new Armored Goblin
groups (interval 2.5 s):
- Wave 1 (prep 45): goblin ×6 west (every 2.0).
- Wave 2 (prep 30): goblin ×5 west (1.8); goblin ×5 north (1.8, delay 4).
- Wave 3 (prep 30): goblin ×7 east (1.5); goblin ×7 south (1.5, delay 3);
  **armored goblin ×2 east (delay 0)**.
- Wave 4 (prep 30): goblin ×6 north (1.4); goblin ×6 west (1.4, delay 2);
  goblin ×6 south (1.4, delay 4); **armored goblin ×3 north (delay 0)**.
- Wave 5 (prep 35): goblin ×7 north (1.2); ×7 east (1.2, delay 2); ×7 south
  (1.2, delay 4); ×7 west (1.2, delay 6); **armored goblin ×4 south
  (delay 4)**.
- Run settings keep today's values (4 heaps per break, max 8; 1–2 Aether
  crystals per break, max 3, 2–4 Aether each).

### Removing Mastery XP
- Delete `Tower.mastery_xp` and every place it's added (Gearshot bolts,
  Mortar shells, Embercaster flame, Spire strikes), plus the "earns Mastery
  XP" line in `tower.gd`'s class comment.
- Delete the operate panel's Mastery label (`hud.tscn` `MasteryText`, and
  `hud.gd`'s `mastery_text`).
- The F menu's info line drops its Mastery part:
  "Tower X / Y health\nWalls: …".
- Towers keep counting nothing; `take_damage`'s return value is there for
  player XP later.

### Descriptions and roadmap
- Tower descriptions mention magic where it matters: Rune Mortar
  "Long-range lobbed rune shells that hit an area. Magic: great against
  armour and clusters." Aether Spire "Lightning that jumps between enemies.
  Magic: great against armour and spread-out groups."
- `ROADMAP.md`:
  - Tick "Armored Goblin (resists bullets → need magic)" with a one-line
    summary.
  - The art table's `goblin_brute` row becomes "**Armored Goblin**".
  - Line 100 (ticked "Tower earns Mastery XP") is struck through and marked
    "removed 2026-09-27: replaced by player XP".
  - Line 159 ("Decide: is Mastery per-tower or per-tower-type?") is removed.
  - Phase 10 gains "Player XP earned during a run ([You] decide how it's
    earned)". The existing "Specialized roguelite hero upgrades" and
    "Upgrade choices after waves (pick 1 of 3)" become one item: "Power-up
    cards: after waves, pick 1 of 3 cards that make you stronger for the
    run (chain-lightning shots, flamethrower, …)".
  - "One evolution per tower" notes "needs a new unlock (Mastery was
    removed): e.g. a card or Aether".

## Testing (running game via MCP)
- Normal goblins take exactly what they did before: Gearshot 8, hero bolt
  10, Mortar 14 splash, Embercaster 3 per tick + burn, Spire 10 / 8 / 6.4…
- Armored Goblin takes: Gearshot 2.4, hero bolt 3, Embercaster tick 1.8 and
  burn at 60%, Mortar shell 14, Spire bolt 10.
- `take_damage` returns the dealt amount (capped at remaining health; 0 when
  dead or invulnerable).
- Sparks appear only for physical hits on armour — not on basic goblins,
  not for magic or fire hits.
- Goblin attacks on the Core, a tower and the hero deal the same as before.
- The Armored Goblin walks, attacks (8 per swing on the swing frame), dies,
  and drops 3–4 Scrap; its animations show at the right size.
- The waves built from `first_run.tscn` match today's `first_playtest.tres`
  group for group, plus the new Armored Goblin groups; run settings match.
- Wave 3 contains 2 Armored Goblins; the wave ends when all are dead.
- Editing check: duplicating a SpawnGroup (count changed) in the scene adds
  that group to the wave; a SpawnGroup with no enemy is skipped with a
  warning, not a crash.
- No `mastery` references remain in `scripts/` or `scenes/`; the operate
  panel and the F menu show no Mastery text; operating each tower type and
  firing causes no errors.
- Screenshots: Armored Goblin beside a basic goblin; a spark on a Gearshot
  hit; a Spire chain through armour; the operate panel without Mastery.
- No new script errors.
