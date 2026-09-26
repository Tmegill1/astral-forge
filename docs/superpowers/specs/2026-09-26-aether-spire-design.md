# Phase 8, Step 5: Aether Spire

Date: 2026-09-26
Status: design approved in chat

## Decisions (from the design discussion)

| Question | Decision |
|---|---|
| Chain style | Chain with falloff: up to 4 jumps, each 20% weaker |
| Armour | Left out (no enemy has armour yet); description changed to talk about chaining |
| Q ability | Resonance Burst: instant 2× bolt, 8 jumps with no falloff, 1 s stun on every goblin hit |
| Automatic aim | Nearest goblin in range (same as the Gearshot); the chain spreads from there |
| Operated aim | First bolt goes to the goblin in range nearest the mouse |

## Design

### Stats (Lv1, all tunable in `data/towers/aether_spire.tres`)
- Costs: build 14 Scrap; Lv2 20 Scrap; Lv3 30 Scrap + 3 Aether.
- 0.8 bolts/s; range 280 (measured from the tower's base point).
- 10 damage to the first goblin. Then up to 4 jumps, each to the nearest
  living goblin within 120 px of the previous one that hasn't been hit by
  this bolt. Each jump deals 20% less than the one before (10, 8, 6.4, 5.12,
  4.1; about 34 in total across 5 goblins).
- Health 150. Level multipliers as the other towers (×1.3 damage, ×1.15 fire
  rate, ×1.1 range, ×1.4 health). The damage multiplier applies to the whole
  chain. Jump count, jump range and falloff don't change with level.
- Operated: ×1.35 damage, ×1.15 range, ×1.0 fire rate.
- Description: "Lightning that jumps between enemies. Best against
  spread-out groups."

### Automatic
- Target = the nearest living goblin in range (the base Tower rule).
- The chain starts at it and jumps as above.

### Operated
- The first bolt goes to the living goblin in range nearest the mouse (the
  mouse may be outside range). With no goblin in range it doesn't fire.
- Fires while fire is held (or auto-fire is on).
- The range drawing shows the range ring and a small ring on the goblin that
  would be hit first.
- Mastery XP = damage dealt by bolts fired while operated.
- Q = Resonance Burst (15 s cooldown): fires at once (if recharged and a
  goblin is in range), starting at the goblin nearest the mouse. 2× damage,
  up to 8 jumps with no falloff, and every goblin hit is stunned for 1 s.

### Stun
- A stunned goblin can't move (velocity 0) or attack, and holds its idle
  animation. Burn and slows keep ticking. The longer stun wins; a new stun
  never shortens the current one. Dying clears it.

### Visuals
- Each bolt draws a jagged blue-white line from the crystal tip through each
  goblin in the chain, re-jittered every frame, fading over 0.15 s. Resonance
  Burst draws a thicker, brighter bolt that fades over 0.25 s.
- After each bolt the Spire holds its first fire frame (the swirling charge)
  for 0.2 s. The later fire frames' beams are clipped at the frame edge, so
  they aren't used.
- Enemy tint lives in one place: stun = pale blue flicker, burn = orange
  flicker, and stun wins when both apply.

### Architecture
- `SpireDefinition extends TowerDefinition`
  (`scripts/towers/spire_definition.gd`) adds `jump_count` (4), `jump_range`
  (120), `jump_falloff` (0.2), `burst_damage_multiplier` (2),
  `burst_jump_count` (8), `burst_stun` (1.0), `bolt_origin` (the crystal tip
  relative to the base point, calibrated by screenshot). It reuses
  `attack_damage`, `attacks_per_second`, `attack_range` and the `ability_*`
  fields (`ability_name` "Resonance Burst", `ability_cooldown` 15).
- `SpireTower extends Tower` (`scripts/towers/spire_tower.gd`;
  `scenes/towers/spire_tower.tscn` inherits `tower.tscn`):
  - keeps the base `_find_target()` and `_operated_aim_point()`;
  - `_first_target(point) -> Enemy`: the living goblin in range nearest
    `point`;
  - `chain_from(first, jumps) -> Array[Enemy]`: gets the living goblins once,
    then repeatedly takes the nearest one not yet in the chain within
    `jump_range` of the last;
  - `_fire_at(point)`: chains, deals damage with falloff, adds Mastery XP
    while operated, spawns a `LightningArc`, and holds the first fire frame
    for 0.2 s;
  - `use_ability()`: Resonance Burst as above, then starts the cooldown
    (same shape as the Mortar's Rune Shell);
  - `_draw()`: while operated, the range ring and the first-target ring.
- `LightningArc` (`scripts/projectiles/lightning_arc.gd`, a Node2D added to
  `projectile_parent`) takes a copy of its points (the crystal tip, then each
  goblin's body), draws the jagged bolt, fades out, then frees itself. It
  doesn't depend on the tower or the goblins still existing.
- `Enemy.stun(seconds)` and `Enemy.is_stunned()`; `Enemy._update_tint()`
  called every physics frame replaces the tint code inside `_tick_burn`.
- `aether_spire.tres` switches to `SpireDefinition`, sets `available = true`,
  `scene` = `spire_tower.tscn`, and the new description. The sheet's single
  `destroyed` wreck already works through the base Tower fallback.

## Testing (running game via MCP)
- Gearshot, Mortar and Embercaster baselines unchanged.
- Chain: a line of goblins 100 px apart takes 10 / 8 / 6.4 / 5.12 / 4.1; a
  goblin 150 px from the chain isn't reached; no goblin is hit twice; the
  chain stops early when nothing is in jump range; goblins killed mid-chain
  cause no errors.
- Automatic: 0.8 bolts/s at the nearest goblin.
- Operated: the first target is the goblin nearest the mouse (mouse inside
  and outside range); fires only while fire is held; Mastery XP matches
  damage dealt.
- Resonance Burst: 2× damage, 8 jumps with no falloff; stunned goblins don't
  move or attack for 1 s, then carry on; Q again during cooldown does nothing;
  the HUD shows the cooldown.
- Tint: stun shows over burn; both clear afterward.
- Build / Lv2 / Lv3 costs and art; destroyed wreck; selling while an arc is
  still fading.
- Screenshots: normal chain, Resonance Burst, stunned goblin, operated
  highlight.
- No new script errors.
