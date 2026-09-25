# Phase 8, Step 1: Slot Ring and Aether

Date: 2026-09-24
Status: approved in chat, awaiting written-spec review

## Context

Phase 8 ("More stuff to build") is split into six steps, each designed,
built and playtested on its own:

1. **Slot ring + Aether** ← this spec
2. Tower levels 1 → 3
3. Rune Mortar
4. Embercaster
5. Aether Spire
6. Aether Harvester

This step lays the foundation for the others: room to build (12 slots) and the
second resource (Aether) that later towers and levels will cost.

## Goals

- Grow the base from 2 build slots to 12, arranged so walls form one line per
  side of the Core with open corners as the enemy entrances.
- Let the base grow over a run: most slots start locked and cost Scrap to open.
- Add Aether as a rare resource that rewards going far from the Core.

## Non-goals

- Anything to spend Aether on (step 2 onwards).
- New towers, tower levels, the Harvester.
- Standalone wall building (walls still come free with towers).
- Balance beyond sensible starting numbers; all numbers below are tunable.

## Decisions (from the design discussion)

| Question | Decision |
|---|---|
| Phase 8 order | Foundation first (the six steps above) |
| Slot layout | Ring of 12, 3 per side; walls join neighbours; corners open |
| Aether source | Crystals far from the Core, plus a rare goblin drop |
| Slot unlocks | 4 open, 8 locked, unlocked with Scrap |

## Design

### 1. The slot ring

- 12 `BuildSlot` instances in `scenes/world.tscn`, 3 per side of the Core
  (Core at `(640, 384)`):
  - **West / East sides:** about 330 px left/right of the Core; slots at
    y offsets −150, 0, +150.
  - **North / South sides:** about 270 px above/below the Core; slots at
    x offsets −170, 0, +170.
  - The existing `BuildSlotWest` / `BuildSlotEast` become the West and East
    middle slots.
  - Exact positions are tuned in-game so the Core sprite, towers and walls
    don't overlap and the corners stay passable.
- The 4 **middle** slots start open. The 8 **flank** slots start `locked`.
- Naming: `BuildSlot<Side><Position>`, e.g. `BuildSlotNorthWest`,
  `BuildSlotNorth`, `BuildSlotNorthEast`, `BuildSlotWestNorth`, `BuildSlotWest`,
  `BuildSlotWestSouth`, and so on.

### 2. Unlocking slots

- New `BuildSlot` export: `unlock_cost: Dictionary[StringName, int]`, default
  `{&"scrap": 6}`.
- Interact (E) on a locked slot pays `unlock_cost` from the Core's stored
  resources and sets `locked = false`; the pad switches to its empty texture.
  There's no menu or confirmation, matching how quick building feels.
- Prompt on a locked slot: `[E] Unlock slot (6 Scrap)`, or when short,
  `Unlock slot: need 4 more Scrap`. Reuse the same shortfall wording the
  build prompt uses.
- A locked slot never opens the build menu and never glows.

### 3. Walls join up

- Ring slots use `wall_return = 0` (no turn back toward the Core) and a
  `wall_length` of half the spacing to the neighbouring slot on that side
  (about 75 px on West/East, 85 px on North/South), so two built neighbours'
  walls meet in the middle.
- A flank slot's outer wall runs the same length toward its corner, leaving a
  gap of about 80 px (5 nav cells at 16 px) between sides. These 4 gaps are
  the entrances enemies path through and the hero walks out of.
- A side with gaps (unbuilt slots) leaves gaps in the wall too. That's
  intended: building a full side is what closes it.
- Wall direction logic (`_plan_walls`: walls run at right angles to the
  Core direction) already fits the ring. The walls need no code change beyond
  checking that the configured lengths behave.
- Repair and sell are unchanged: each slot owns and rebuilds or removes only
  its own wall pieces.
- Enemies that find every route blocked still smash the nearest wall (existing
  behaviour).

### 4. Aether crystals

- `ScrapHeap` becomes a general **`ResourceHeap`**
  (`scripts/loot/resource_heap.gd`, `scenes/loot/resource_heap.tscn`, group
  `resource_heaps`) with a new export `type: StringName` (default
  `Loot.SCRAP`). Its pieces use `Loot.ICONS[type]`, and the prompt reads
  `[E] Salvage heap (5 Scrap)` or `[E] Break crystal (3 Aether)`.
- `World._scatter_heaps` places Scrap heaps as now, then places Aether
  crystals:
  - count per break: random within `RunDefinition.aether_per_break`
    (new, `Vector2i(1, 2)`)
  - never closer than `AETHER_MIN_DISTANCE` (new const, 800 px) to the Core
  - never more than `RunDefinition.max_aether` (new, 3) crystals on the map
  - amount: random 2–4 (`RunDefinition.aether_amount`, new,
    `Vector2i(2, 4)`)
  - same open-ground and spacing checks as Scrap heaps
- The Scrap heap cap (`max_heaps`) counts only Scrap heaps.

### 5. Rare drops

- New `EnemyDefinition` export in the Loot group:
  `rare_drops: Dictionary[StringName, float]`, the chance (0–1) of dropping
  **one** of that resource on death.
- Goblin: `rare_drops = {&"aether": 0.05}`.
- `World._on_enemy_killed` rolls each rare drop after the regular drops.

### 6. HUD

- The hero panel's `Carrying` line and the Core panel's `Stored` line show
  Aether next to Scrap, each with its icon (e.g. `Carrying 4 ⚙  1 ◆`).
  Aether is shown even at 0, so players learn it exists.
- Nothing else changes: pickups, carrying, depositing and the half-loss on
  death already handle any resource type.

## Files touched

| File | Change |
|---|---|
| `scenes/world.tscn` | 12 slots with positions, lock state and wall lengths |
| `scripts/towers/build_slot.gd` | `unlock_cost`, unlocking in `interact`, locked prompt |
| `scripts/loot/scrap_heap.gd` → `resource_heap.gd` | rename + `type` |
| `scenes/loot/scrap_heap.tscn` → `resource_heap.tscn` | rename, group `resource_heaps` |
| `scripts/world.gd` | crystal placement, rare-drop rolls |
| `scripts/waves/run_definition.gd` | `aether_per_break`, `max_aether`, `aether_amount` |
| `scripts/enemies/enemy_definition.gd` | `rare_drops` |
| `data/enemies/goblin.tres` | `rare_drops` |
| `scripts/ui/hud.gd` + `scenes/ui/hud.tscn` | Aether in Carrying / Stored |
| `ROADMAP.md` | tick "Expand to 12–16 build slots" and "Aether" |

## Testing

There's no automated test suite in this project; verification is done by
driving the running game through the Godot MCP tools:

- 12 slots exist; exactly 8 are locked at start.
- Unlocking with enough Scrap spends 6 and makes the slot buildable; with too
  little it spends nothing and the prompt shows the shortfall.
- Building two neighbouring slots produces walls that meet (no gap between).
- Goblins from each sector reach the Core through the corner gaps when a
  whole side is built; with every side sealed they smash a wall.
- Each break adds 1–2 crystals, all at least 800 px from the Core, never more
  than 3 on the map.
- Breaking a crystal drops Aether pickups; carrying and depositing Aether
  updates both HUD lines.
- Forcing the rare-drop roll (setting the chance to 1.0) drops 1 Aether per kill.
- No new script errors or warnings in the debug output.
