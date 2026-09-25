# Hero Upgrades at the Core + Core Regeneration

Date: 2026-09-25
Status: approved in chat ("yes build it, then commit and push")

## Goal

Let the player spend stored resources on their own hero at the Command Core,
competing with tower builds and upgrades for the same pool. Also give the
Core slow, tunable health regeneration.

## Decisions (from the design discussion)

| Question | Decision |
|---|---|
| Upgrades offered | Damage, Fire rate, Max health, Move speed |
| Ranks and costs | 5 ranks; 12, 20, 30 + 1 Aether, 40 + 2 Aether, 55 + 3 Aether |
| Core regen | Always on: 10 health every 5 seconds, both tunable |

## Design

### Hero upgrades
- **Station:** F at the Core opens a paused Hero Upgrades menu. Core prompt:
  `[F] Upgrade hero`, or `[E] Deposit 12 Scrap    [F] Upgrade hero` while
  carrying. The F part only appears if the hero has upgrades.
- **Menu:** title `Upgrade Artificer`, a line showing stored resources, then
  one row per upgrade: `Damage — Rank 2/5 · 12 → 14`, plus a button:
  - `Upgrade — 30 Scrap, 1 Aether`
  - `Need 5 Scrap more`, disabled, when short
  - `Maxed`, disabled, at rank 5
  - `Close (Esc)`; Esc or F also closes
- **Effect:** each rank adds `bonus_per_rank` × the hero's starting value
  (additive, not compounding):
  - Damage +20% (`attack_damage`)
  - Fire rate +20% (`attacks_per_second`)
  - Max health +20% (`max_health`); the added health is healed at once
    (`Health.grow_max`)
  - Move speed +8% (`move_speed`)
- **Costs** are paid from `CommandCore.stored`, the same pool as towers.
- **Ranks last the whole run**, including through death and respawn.
- The HUD hero stats line updates whenever stats change.
- **Data:**
  - `HeroUpgrade` resource: `id`, `display_name`, `stat`, `bonus_per_rank`,
    `scrap_costs`, `aether_costs`. One `.tres` each in `data/hero_upgrades/`.
  - `HeroDefinition.upgrades` lists which upgrades a hero offers.
- **Later (roadmap only):** specialized roguelite upgrades such as
  chain-lightning shots and a flamethrower, picked during a run (Phase 10).

### Core regeneration
- `CommandCore.regen_amount = 10.0` and `regen_interval = 5.0` (exports).
- Every `regen_interval` seconds, heal `regen_amount` if the Core is alive
  and not at full health. Pauses with the game.

## Testing (running game via MCP)
- Buying ranks: exact costs, Aether ranks, a shortfall spends nothing,
  maxed at 5.
- Stats after ranks match the base × (1 + bonus × rank); the HUD line updates.
- Max health upgrade adds its health on top; ranks survive death and respawn.
- The Core heals exactly 10 after 5 s when damaged, never above max, and
  never when destroyed.
- Core prompt text; menu screenshot; no new script errors.
