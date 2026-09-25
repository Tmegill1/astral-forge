# Phase 8, Step 3: Rune Mortar

Date: 2026-09-25
Status: approved in chat ("yes build it")

## Decisions (from the design discussion)

| Question | Decision |
|---|---|
| Operating | Click-to-target: shells land at the mouse point (clamped to min–max range) |
| Q ability | Rune Shell: 2× damage, 2× splash, leaves a 4 s rune circle slowing goblins 40% |
| Automatic aim | Biggest clump, leading the target; can't fire inside min range |

## Design

### Stats (Lv1, all tunable in `data/towers/rune_mortar.tres`)
- Costs: build 15 Scrap; Lv2 20 Scrap; Lv3 30 Scrap + 3 Aether.
- 14 damage to every goblin within 70 px of the impact point.
- 0.5 shots/s; range 420; min range 110.
- Shell flight 0.9 s on an arc. A faint circle marks the landing spot during flight.
- Health 150. Level multipliers as the Gearshot (×1.3 damage, ×1.15 rate,
  ×1.1 range, ×1.4 health). Splash radius doesn't change with level.
- Operated: ×1.35 damage, ×1.25 splash radius, ×1.15 range, ×1.0 fire rate.

### Automatic
- Target = the living goblin within [min range, range] with the most other
  living goblins within splash radius of it; ties go to the nearest.
- Aim = the target's position + its velocity × flight time (leading).
- The sprite faces the target's side (mirrored when it's to the left). The
  idle frames show reload progress (frame 0 just fired … frame 3 ready).
  The fire animation plays on each shot.

### Operated
- Aim point = mouse position, clamped along the line from the tower to
  between min range and range.
- The range drawing shows the outer ring, the inner no-fire ring and a
  reticle at the aim point.
- Q = Rune Shell: fires at once at the aim point (if the ability is off
  cooldown; 15 s cooldown): 2× damage, 2× radius, and a rune circle of the
  blast radius for 4 s that slows goblins inside by 40%.
- Mastery XP = damage dealt by shells fired while operated.

### Architecture
- `TowerDefinition.scene: PackedScene`. When set, `BuildSlot` builds that
  scene instead of the default `tower.tscn`.
- `MortarDefinition extends TowerDefinition` adds the mortar settings:
  `splash_radius`, `min_range`, `shell_flight_time`, `shell_arc_height`,
  `operated_splash_multiplier`, `rune_damage_multiplier`,
  `rune_radius_multiplier`, `rune_slow`, `rune_duration`.
- `MortarTower extends Tower` (`scenes/towers/mortar_tower.tscn` inherits
  `tower.tscn`). It overrides targeting, aiming, firing, `use_ability`,
  `_draw`, and the idle charge display.
- Base `Tower` gains one hook, `_operated_aim_point()` (default: the mouse
  position), which the mortar overrides to clamp. Gearshot behaviour is
  unchanged.
- `Shell` (`scripts/projectiles/shell.gd`, a Node2D) travels from muzzle to
  target over the flight time, with a height arc and a ground shadow. On
  landing it damages every living enemy within radius, emits
  `hit(damage, killed)` per enemy, shows a 0.25 s blast, and optionally
  spawns a `RuneCircle`.
- `RuneCircle` (`scripts/projectiles/rune_circle.gd`) slows enemies inside it
  every physics frame for its duration, drawn as a fading glowing ring.
- `Enemy.slow(factor, seconds)`: the strongest active slow applies to move
  speed until it expires.
- The Mortar becomes `available = true`, so the build menu offers it.

## Testing (running game via MCP)
- Gearshot baseline unchanged (stats, firing, ability).
- Clump beats nearest; leading a moving goblin lands within ~20 px of it;
  targets inside min range are ignored.
- Splash damages goblins inside the radius and none outside.
- Operated shots land at the mouse, clamped to min/max range; reticle and
  rings drawn.
- Rune Shell: doubled damage and radius; circle slows goblins to 60% speed,
  and speed returns after it ends; cooldown shows in the HUD.
- Build / upgrade / sell costs; Mastery XP only while operated.
- Screenshots: shell mid-flight, blast, rune circle, operated rings.
- No new script errors.
