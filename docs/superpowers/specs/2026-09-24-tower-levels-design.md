# Phase 8, Step 2: Tower Levels 1 → 3

Date: 2026-09-24
Status: approved in chat; the user asked to go straight to building

## Context

Step 2 of Phase 8 (order: 1 slots + Aether ✅, **2 levels**, 3 Mortar,
4 Embercaster, 5 Spire, 6 Harvester). Towers already carry a `level` number
and level 1–3 art. This step makes levels buyable and meaningful, and gives
Aether its first use.

## Decisions (from the design discussion)

| Question | Decision |
|---|---|
| Upgrade cost | Lv2 costs Scrap; Lv3 costs Scrap + Aether |
| What a level changes | Stat boosts only (playstyle changes are for Phase 10 evolutions) |
| Walls | A tower's walls level up with it (art + health) |

## Design

### 1. Upgrading

- The tower menu (F at a built tower) gets an **Upgrade** button between
  Repair and Sell:
  - `Upgrade to Lv2 — 15 Scrap`
  - when short: `Upgrade to Lv2 — need 4 Scrap more` (same wording as
    the build menu and slot unlock), button disabled
  - at Lv3: `Max level`, disabled
- Gearshot costs: **Lv2 = 15 Scrap**, **Lv3 = 25 Scrap + 3 Aether**.
- Upgrading is instant. Max health rises and the tower heals by the amount
  added, so the missing health stays the same.
- **Selling refunds 50% of everything spent on that tower**, the build cost
  plus upgrades, rounded down per resource.
- The menu title shows the level (`Gearshot Turret — Lv2`). Below the
  health line, a preview of the next level reads, e.g.
  `Next: damage 10 → 14 · 1.7 → 2.0 shots/s · range 286 → 315 · health 210 → 294`.
- The operating panel title reads `Operating Gearshot Turret Lv2`.

### 2. What a level does

- Per tower definition, compounding per level above 1:
  - `level_damage_multiplier = 1.3`
  - `level_fire_rate_multiplier = 1.15`
  - `level_range_multiplier = 1.1`
  - `level_health_multiplier = 1.4`
- Operated bonuses and the ability multiply on top, as now. Mastery is
  unchanged.
- Art follows the level: `lv<N>_idle` / `lv<N>_fire` frames, or the
  level's rotating head. Wreckage uses `lv<N>_destroyed`.
- Upgrade costs live in the definition: `lv2_cost` and `lv3_cost`
  (`Dictionary[StringName, int]`). `MAX_LEVEL = 3`.

### 3. Walls level up with the tower

- A slot tracks `wall_level` (1–3). Upgrading a tower raises `wall_level` to
  the tower's level if it's lower. Every standing wall piece then switches to
  that level's art and raises its max health, keeping its missing health.
- Wall health by level: **120 / 180 / 260**.
- Wall art by level: `wall_lv1..3.png` and `wall_lv1..3_damaged.png`. Posts
  (walls running up/down the screen) are cut from each picture's left pillar,
  with widths **52 / 52 / 48 px**.
- Repair rebuilds destroyed pieces at `wall_level`. Their repair cost uses
  that level's wall health (1 Scrap per 25 missing, as now).
- A destroyed tower's walls keep their level. A new tower built on that slot
  (Lv1) never lowers `wall_level`.
- Selling removes the walls, as now, and resets `wall_level` to 1.

### 4. Gearshot Lv2/Lv3 rotating heads

- `tools/split_turret.py` gains `gearshot_lv2` and `gearshot_lv3` entries:
  the twin-barrel and four-barrel frames cut into base + head. That needs
  the pivot, radius, tip, barrel width and base extent measured for each.
- The five single head fields on `TowerDefinition` (`base_texture`,
  `head_texture`, `head_pivot`, `head_drawn_angle`, `head_barrel_length`)
  become `heads: Array[TurretHead]`, one per level. `TurretHead` is a small
  new Resource holding those five values. `head_turn_speed` stays on the
  definition.
- `head_pivot` = cell pivot − the sheet's foot point. For the Gearshot sheet
  the foot point is (96, 282) in its 192×288 cell, so Lv1's (93, 205) gives
  (−3, −77), which matches today's value.
- A level without a head entry falls back to the frame-based art.

## Files touched

| File | Change |
|---|---|
| `scripts/towers/turret_head.gd` (new) | `TurretHead` resource |
| `scripts/towers/tower_definition.gd` | `heads`, level multipliers, `lv2_cost`/`lv3_cost`, stat-at-level helpers |
| `scripts/towers/tower.gd` | stats by level, `set_level`, head per level |
| `scripts/components/health.gd` | `grow_max(new_max)` keeps the missing health |
| `scripts/structures/wall.gd` | `restyle(intact, damaged, new_max)` |
| `scripts/towers/build_slot.gd` | `upgrade()`, invested-cost tracking, `wall_level`, per-level wall art |
| `scenes/towers/build_slot.tscn` | per-level wall texture arrays |
| `scripts/ui/tower_menu.gd` + `scenes/ui/tower_menu.tscn` | Upgrade button, level title, next-level preview |
| `scripts/ui/hud.gd` | level in the operating title |
| `tools/split_turret.py`, `assets/sprites/towers/gearshot_lv2/3_*.png` | new head art |
| `data/towers/gearshot.tres` | `heads` (3), costs |
| `ROADMAP.md` | tick "Tower levels 1 → 3" |

## Testing

Driven in the running game through the Godot MCP tools:

- Upgrade with enough stored resources: spends exactly the cost, and the
  level rises. When short: nothing is spent and the level is unchanged. At
  Lv3: no further upgrade.
- The stats after each level match the compounding multipliers (Gearshot Lv3
  damage = 8 × 1.3² = 13.52).
- A damaged tower keeps the same missing health after upgrading.
- Walls switch art and max health (120 → 180 → 260) and keep their damage.
  Repair rebuilds destroyed pieces at the current wall level.
- Sell after upgrading refunds 50% of build + upgrades.
- Destroy a Lv3 tower and build a new one: the walls stay Lv3.
- The Lv2/Lv3 heads aim at several directions without visible seams, bolts
  leave from the barrel tips, and the muzzle flash sits on the tips
  (screenshots).
- The menu shows the level, the preview and the button states. The
  operating title shows the level.
- No new script errors or warnings.
