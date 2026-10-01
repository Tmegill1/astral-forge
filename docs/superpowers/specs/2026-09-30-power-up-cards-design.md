# Phase 10: XP, level-ups and power-up cards

Date: 2026-09-30
Status: design approved in chat

Covers two roadmap items: "Player XP earned during a run" and "Power-up
cards: pick 1 of 3 cards that make you stronger for the run".

## Decisions (from the design discussion)

| Question | Decision |
|---|---|
| When a pick happens | On an XP level-up |
| How XP is earned | **XP orbs** dropped by enemies, picked up by the hero |
| Level-up mid-fight | The game **pauses immediately** and shows the cards |
| XP per level | Grows ×1.5 per level, starting at 8 (8, 12, 18, 27, 41, 61, …) |
| Pull-everything magnet | A rare **Lodestone** drop that pulls every XP orb on the map to the hero |
| Card structure | Data files (`data/cards/*.tres`): stat bonuses applied generically, plus an optional `mod` id that hero code acts on |
| Lifetime | Cards, XP and level last one run (no meta-progression) |

## Design

### XP orbs (`scenes/loot/xp_orb.tscn`, `scripts/loot/xp_orb.gd`)
- `EnemyDefinition` gains `xp_value: int` (Loot group). Goblin 1, Goblin
  Shaman 3, Armored Goblin 3.
- When an enemy is killed, the world drops one orb worth `xp_value` where it
  died (same moment Scrap drops, same "pop" hop).
- Look: drawn in code (no art): a glowing teal orb ≈7 px radius with a soft
  halo and a gentle pulse.
- Pull: drifts to the hero once within the **orb pull radius** (140 px,
  ×(1 + Wide Pull bonus)), speed 320 px/s; on touching the hero it adds its
  XP to `RunCards` and frees itself. A dead hero doesn't attract orbs.
- Orbs never despawn. They are not "carried" — XP is never lost on death.
- Pickup collision: an `Area2D` on the pickups layer that the hero's body
  touches, like Scrap pickups.

### Lodestone (`scenes/loot/lodestone.tscn`, `scripts/loot/lodestone.gd`)
- Each kill has a **3%** chance to drop a Lodestone, unless one is already on
  the map.
- Look: drawn in code: a slowly spinning gold diamond with a blue core and a
  pulsing ring, ≈10 px.
- Pull: same as an orb (140 px radius) so it's easy to collect.
- Touching it: every XP orb on the map flies to the hero at 900 px/s
  (ignoring the pull radius) and is collected on arrival, all within ~0.6 s
  for a typical map; the Lodestone frees itself.

### RunCards (`scripts/cards/run_cards.gd`, a node in `world.tscn`)
- Holds this run's state: `xp: int`, `level: int` (starts 1),
  `ranks: Dictionary[StringName, int]` (card id → rank owned).
- `const FIRST_LEVEL_XP := 8`, `const LEVEL_GROWTH := 1.5`.
  `xp_for_level(level) -> int` = round(8 × 1.5^(level − 1)): 8, 12, 18, 27,
  41, 61, 91. XP resets to the remainder after each level (overflow kept).
- `add_xp(amount)`: adds XP; for each level gained emits
  `leveled_up(new_level)` (several in one call if a big Lodestone haul
  crosses several levels).
- `offer(count := 3) -> Array[CardDefinition]`: `count` different random
  cards from the pool that aren't at their max rank (fewer if fewer remain).
- `take(card)`: rank + 1; emits `changed`.
- `bonus(stat: StringName) -> float`: sum over owned cards of
  `stat_bonuses[stat] × rank` (0 if none) — e.g. two ranks of Sharpened Bolts
  → `bonus(&"hero_damage") == 0.4`.
- `mod_rank(mod: StringName) -> int`: the rank of the card with that `mod`
  (0 if not owned).
- Reachable as the `run_cards` group (one per run).

### CardDefinition (`scripts/cards/card_definition.gd`, `data/cards/*.tres`)
- `id`, `title`, `description` (one line, says what one rank does),
  `category` ("Hero", "Towers", "Fortress"), `max_rank`,
  `stat_bonuses: Dictionary[StringName, float]` (per-rank), `mod: StringName`
  (empty for stat cards).
- `RunCards` loads every `.tres` in `res://data/cards/` with
  `ResourceLoader.list_directory`.

### The card pool (14 cards)

| id | Title | Category | Per rank | Max | Data |
|---|---|---|---|---|---|
| sharpened_bolts | Sharpened Bolts | Hero | +20% hero damage | 5 | `hero_damage: 0.2` |
| quick_trigger | Quick Trigger | Hero | +15% hero fire rate | 5 | `hero_fire_rate: 0.15` |
| fleet_foot | Fleet Foot | Hero | +10% move speed | 3 | `hero_move_speed: 0.1` |
| thick_hide | Thick Hide | Hero | +20% max health (heals that much) | 3 | `hero_max_health: 0.2` |
| arc_bolts | Arc Bolts | Hero | Bolts chain lightning to +1 nearby enemy at 50% damage (magic) | 3 | `mod = arc_bolts` |
| split_shot | Split Shot | Hero | +1 extra bolt on each side (±12° steps) | 2 | `mod = split_shot` |
| ember_rounds | Ember Rounds | Hero | Bolts add +1 burn stack | 3 | `mod = ember_rounds` |
| calibrated_barrels | Calibrated Barrels | Towers | All towers +15% damage | 5 | `tower_damage: 0.15` |
| oiled_gears | Oiled Gears | Towers | All towers +10% fire rate | 3 | `tower_fire_rate: 0.1` |
| long_sight | Long Sight | Towers | All towers +10% range | 3 | `tower_range: 0.1` |
| reinforced_plating | Reinforced Plating | Towers | Towers and walls +25% max health | 3 | `structure_health: 0.25` |
| core_plating | Core Plating | Fortress | Core +20% max health (heals that much) | 3 | `core_max_health: 0.2` |
| salvager | Salvager | Fortress | +25% Scrap from enemy drops | 3 | `scrap_drops: 0.25` |
| wide_pull | Wide Pull | Fortress | XP orbs and Scrap drift to you from 50% further | 2 | `pull_radius: 0.5` |

### Where the bonuses apply
- **Hero stats**: when stats are rebuilt (upgrade bought or card taken),
  `damage`, `attacks_per_second`, `move_speed`, `max_health` are multiplied
  by (1 + the matching `hero_*` bonus), on top of Core upgrades. A max-health
  increase is added to current health (like the Core upgrade does now).
- **Hero mods** (in `Hero._fire` and the bolt's hit):
  - Split Shot: rank r fires r extra bolts on each side at ±12°, ±24°.
  - Arc Bolts: when a hero bolt hits an enemy, lightning jumps to up to
    `rank` other enemies within 120 px (nearest first, no repeats), each
    taking 50% of the bolt's damage as magic, with the Spire's lightning arc
    visual.
  - Ember Rounds: a hit enemy gets `rank` burn stacks (2 damage/s per stack,
    3 s, max 5 stacks — the Embercaster's burn).
- **Towers**: `Tower.damage()`, `fire_rate()`, `attack_range()` multiply by
  (1 + `tower_damage` / `tower_fire_rate` / `tower_range`). Every tower type
  goes through these (the Embercaster's own `attack_range()` too).
- **Structure health**: towers' and walls' max health × (1 +
  `structure_health`), applied to existing ones when the card is taken
  (`grow_max`, adding the difference) and to new ones when built.
- **Core**: max health × (1 + `core_max_health`), the increase added to
  current health.
- **Scrap**: enemy Scrap drop amounts × (1 + `scrap_drops`), rounded, at
  least the original amount (rare Aether drops unchanged).
- **Pull radius**: Scrap pickups' magnet radius and XP orbs'/Lodestone pull
  radius × (1 + `pull_radius`).

### HUD
- An **XP bar** directly under the hero panel (same width), thin (8 px),
  teal fill, with "Lv 3" on its left and "12 / 18 XP" on its right.

### Card pick screen (`scenes/ui/card_menu.tscn`, `scripts/ui/card_menu.gd`)
- A `CanvasLayer` (layer 5, like the other gameplay menus; `process_mode =
  ALWAYS`) that opens on `RunCards.leveled_up`: pauses the game, dims the
  screen, title "Level 3 — choose a card".
- Three cards side by side (`scenes/ui/power_card.tscn`), each with: a
  category tag coloured by category (Hero gold, Towers blue, Fortress
  green), the title, the description, "Rank 2 / 5" (the rank you'd reach)
  and the number key "1"/"2"/"3".
- Pick by clicking a card or pressing 1/2/3. No skipping. Esc does nothing
  while it's open (the pick is required), and the pause menu can't open over
  it (the game is paused).
- After a pick: `RunCards.take(card)`, then if more level-ups are pending,
  the next offer appears immediately (title updates); otherwise the screen
  closes and the game unpauses.
- If no card is left to offer (all maxed), the level-up is skipped silently.
- Opens even if the hero is dead (XP can't be collected while dead, so in
  practice it won't).

### Interaction with other systems
- Game Over / win: a pending pick never opens over the end screen (the
  card menu checks the game isn't already paused by another screen; pending
  level-ups are dropped at run end).
- Restart / quit to menu: `RunCards` belongs to the world scene, so
  everything resets.

## Out of scope
- Tower evolutions, Artificer abilities, rerolls, banishing, rarity tiers.
- Card art (category colours only).
- Meta-progression between runs.

## Testing
Headless (`tests/test_cards.gd`, run like `tests/test_help_text.gd`):
1. `xp_for_level` gives 8, 12, 18, 27, 41, 61.
2. `add_xp` across several levels emits `leveled_up` once per level and keeps
   the overflow.
3. `offer(3)` returns 3 different cards; a card at max rank is never
   offered; with 2 cards left it returns 2.
4. `bonus()` sums per-rank values across cards; `mod_rank()` returns ranks.
5. All 14 card files load with a non-empty title/description/category and
   `max_rank` ≥ 1.

In the running game (Godot MCP):
6. Killing a goblin drops an orb worth 1; walking near collects it; the HUD
   bar and text update; an orb outside 140 px doesn't move.
7. Reaching 8 XP pauses the game and shows 3 different cards; pressing 2
   takes the middle one and resumes; a big XP gain shows several picks in a
   row.
8. Each stat card changes its number (hero damage on a bolt, tower damage on
   a Gearshot shot, Core and wall max health, Scrap per kill, pull radius).
9. Arc Bolts: a bolt hitting one goblin also damages a second goblin within
   120 px (50%, magic). Split Shot fires 3 bolts. Ember Rounds burns.
10. Lodestone: with orbs scattered across the map, touching it brings them all
    in and adds their XP; only one Lodestone exists at a time.
11. Game Over during a pending level-up shows Game Over, not the cards.
12. Web export: level-up screen works; no console errors.
