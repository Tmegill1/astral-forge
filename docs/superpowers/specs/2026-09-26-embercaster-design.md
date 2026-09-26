# Phase 8, Step 4: Embercaster

Date: 2026-09-26
Status: design approved in chat

## Decisions (from the design discussion)

| Question | Decision |
|---|---|
| Flame style | Fuel tank: a continuous stream that drains a tank |
| Refill | Refills whenever not spraying; once dry, can't restart until 40% |
| Burn | Stacks (max 5); all stacks expire 3 s after the last one was added |
| Q ability | Overpressure: 3 s of free fuel, bigger cone, instant max burn |
| Automatic aim | The cone direction that hits the most goblins |

## Design

### Stats (Lv1, all tunable in `data/towers/embercaster.tres`)
- Costs: build 12 Scrap; Lv2 18 Scrap; Lv3 28 Scrap + 3 Aether.
- Flame cone: 50° total, 150 px reach.
- 5 ticks/s (`attacks_per_second`). Each tick deals 3 damage to every living
  goblin in the cone and adds 1 burn stack.
- Burn: 2 damage/s per stack, max 5 stacks, 3 s after the last stack was
  added.
- Fuel: 4 s of spraying when full; refills from empty in 3 s while not
  spraying. If the tank runs dry it can't spray until it's back to 40%.
- Health 180. Level multipliers as the other towers (×1.3 damage, ×1.15 fire
  rate, ×1.1 range, ×1.4 health). The damage multiplier applies to both the
  flame tick and burn per stack; the fire-rate multiplier speeds up the ticks.
  Cone angle and fuel don't change with level.
- Operated: ×1.35 damage, ×1.15 range, ×1.0 fire rate.

### Automatic
- Target = the living goblin in range whose cone (from the tower, pointed at
  it) contains the most living goblins; ties go to the nearest.
- Aim = the target's position (no leading; the flame is instant).
- The sprite faces the aim side (mirrored when it's to the left; the art
  faces right). While spraying it holds the first fire frame (the glowing
  barrel), because the later frames' flames are clipped and the drawn cone is the
  flame. Otherwise it shows idle.

### Operated
- The cone points at the mouse. It sprays while fire is held (or auto-fire is
  on); letting go refills the tank.
- The range drawing shows the reach arc and the cone outline.
- Q = Overpressure (15 s cooldown, 3 s): no fuel used, cone angle ×1.5,
  reach ×1.3, and every tick sets goblins in the cone straight to max stacks.
- Mastery XP = direct flame-tick damage dealt while operated (not burn).

### Visuals
- While spraying: a flickering orange gradient cone drawn in code, plus a
  `CPUParticles2D` ember spray aimed along the cone.
- A small fuel bar under the tower whenever the tank isn't full (turns red
  while dry and locked out).
- Burning goblins flicker with an orange tint.

### Architecture
- `EmberDefinition extends TowerDefinition`
  (`scripts/towers/ember_definition.gd`) adds `cone_angle`, `muzzle_offset`
  (where the flame starts, facing right), `fuel_seconds`,
  `refill_seconds`, `restart_fraction`, `burn_dps_per_stack`,
  `burn_max_stacks`, `burn_duration`, `overpressure_angle_multiplier`,
  `overpressure_range_multiplier`. It reuses `attacks_per_second` as the tick
  rate and the `ability_*` fields for Overpressure's name, duration and
  cooldown.
- `EmberTower extends Tower` (`scripts/towers/ember_tower.gd`;
  `scenes/towers/ember_tower.tscn` inherits `tower.tscn`) overrides
  `_find_target`, `_aim_at`, `_fire_at`, `use_ability`, `_draw`, and extends
  `_physics_process` to refill fuel when it didn't fire this frame, switch
  idle/fire animation, and redraw.
- Base `Tower`: when a sheet has no `lvN_destroyed` (the Embercaster's has
  one `destroyed`), the wreck falls back to `destroyed`.
- Base `Tower` gains one hook, `_can_fire() -> bool` (default `true`), checked
  before firing. The Embercaster returns false while locked out for fuel. The
  Gearshot and Mortar are unchanged.
- Overpressure uses the base ability timer (`_ability_left`). The cone angle
  and reach getters check it, and `_fire_at` skips the fuel drain and applies
  max stacks while it's active.
- `Enemy.add_burn(dps_per_stack, max_stacks, seconds, stacks := 1)`: stacks
  are capped, and each call resets the timer. Burn damage goes through `health`
  every physics frame. When two sources differ, the higher per-stack damage
  wins. The tint is on while stacks > 0.
- `embercaster.tres` switches to `EmberDefinition`, sets `available = true`
  and `scene` = `ember_tower.tscn`.

## Testing (running game via MCP)
- Gearshot and Mortar baselines unchanged.
- Cone hits goblins inside its angle and range and none outside.
- Burn: stacks to 5, correct damage per second, expires 3 s after the last
  stack.
- Fuel: empties after ~4 s of spraying; won't restart below 40%; refills in
  ~3 s.
- Operated: cone follows the mouse; sprays only while fire is held.
- Overpressure: no fuel used, bigger cone, 5 stacks per tick; cooldown shows
  in the HUD.
- Build / upgrade / sell costs; Mastery XP only while operated.
- Screenshots: spraying cone, burning goblin, fuel bar, Overpressure.
- No new script errors.
