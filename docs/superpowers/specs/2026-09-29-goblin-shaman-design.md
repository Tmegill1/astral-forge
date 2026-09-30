# Phase 9, Step 2: Goblin Shaman (frenzy pulse and a ranged orb)

Date: 2026-09-29
Status: design approved in chat

## Decisions (from the design discussion)

| Question | Decision |
|---|---|
| Role | Support caster: pulses a buff on nearby goblins and otherwise throws a weak, slow orb from range |
| Buff | **Frenzy**: +30% move speed and +30% attack damage |
| Timing | A pulse every few seconds with a visible cast (not a constant aura), so it has a tell and can be interrupted |
| Where the code lives | Frenzy and the ranged attack are data options any enemy can use; the pulse is its own small component. A new enemy is still just a `.tres` |
| Art | The existing `goblin_shaman` sheet: `cast` = attack, `projectile` = orb, `buff` = pulse |

## Design

### Frenzy (any enemy can receive it)
- `Enemy.frenzy(speed_bonus: float, damage_bonus: float, seconds: float)`,
  e.g. `frenzy(0.3, 0.3, 4.0)`. A new frenzy **refreshes** the timer and
  keeps the stronger bonuses; it never stacks.
- While frenzied: move speed ×(1 + speed_bonus) (combined with any slow),
  attack damage ×(1 + damage_bonus) for both melee hits and orbs.
- `Enemy.is_frenzied() -> bool`.
- Ignored when dead; ends on death.
- Tint: frenzied goblins pulse red (`Color(1.0, 0.4, 0.35)`). Priority:
  stun (pale blue) > frenzy (red) > burn (orange).

### Ranged attack (data option)
`EnemyDefinition` gains an **Attack** setup that the basic and Armored
Goblins leave at their defaults:
- `attack_animation: StringName = &"attack"`: the Shaman uses `&"cast"`.
- `projectile_scene: PackedScene = null`: null = melee as today. When set,
  on `attack_hit_frame` the enemy spawns this projectile at itself aimed at
  its target's current position instead of hitting directly. It still
  checks the target is alive and in reach, as melee does.
- `projectile_speed := 260.0`.
- Ranged damage uses `attack_damage` (×frenzy) and is **magic**.
- `attack_range` already controls how far away it stops; the Shaman uses 220.
- Targeting, pathing and breaking through walls are unchanged, so a
  walled-off Shaman shoots the nearest wall.

### Enemy orb (`scenes/projectiles/enemy_orb.tscn`)
- A `Projectile` whose sprite is the Shaman sheet's one-frame `projectile`
  art, scaled to about 24 px long, pointing along its flight.
- Hits the first hero, tower, wall or Core it touches (collision mask =
  hero + structures), so walls block it. An operating hero is
  invulnerable, so an orb that touches them does nothing, just like melee.
- Flies up to its target distance + 60 px, then disappears.

### Frenzy pulse (`scripts/enemies/frenzy_pulse.gd`)
A child node the enemy adds to itself in `_ready()` when its definition
has `pulse_interval > 0`. `EnemyDefinition` gains a **Pulse** group:
- `pulse_interval := 0.0` (0 = no pulse; Shaman 6.0). The first pulse
  comes 2 s after spawning, then every `pulse_interval` seconds.
- `pulse_radius := 160.0`, `pulse_duration := 4.0`,
  `pulse_speed_bonus := 0.3`, `pulse_damage_bonus := 0.3`,
  `pulse_animation: StringName = &"buff"`.

Behaviour:
- When a pulse is due and the enemy is alive, not stunned and not mid-attack,
  it stops moving and plays `pulse_animation` (3 frames at 8 fps ≈ 0.4 s).
- When that animation finishes, every **other** living enemy within
  `pulse_radius` gets `frenzy(...)`. Then the timer restarts and the enemy
  goes back to walking or attacking.
- A stun or death during the cast **cancels** it: no frenzy, and the timer
  restarts.
- A brief expanding ring (drawn, about 0.3 s) at the moment it lands shows
  the radius.

### Goblin Shaman (`data/enemies/goblin_shaman.tres`)
- Sprites: `assets/sprites/goblin_shaman.tres`, sprite_scale about 0.3 (set by
  screenshot next to a goblin); `attack_animation = cast`,
  `attack_hit_frame = 3` (the last cast frame, orb leaving the staff).
- 40 health; move speed 60; orb 6 damage every 2 s (`attacks_per_second` 0.5);
  attack range 220; aggro range 220.
- Damage taken: physical 100%, fire 100%, magic 70%.
- Pulse: every 6 s, 160 px, +30% speed and damage for 4 s.
- Drops: 2–3 Scrap; 15% Aether.

### Waves (`scenes/waves/first_run.tscn`)
One or two Shamans per wave from wave 2, arriving after their side's pack:

| Wave | Group | Count | Side | Delay |
|---|---|---|---|---|
| 2 | ShamanWest | 1 | west | 5 s |
| 3 | ShamanEast | 1 | east | 4 s |
| 4 | ShamanNorth, ShamanWest | 1 each | north, west | 4 s, 6 s |
| 5 | ShamanEast, ShamanWest | 1 each | east, west | 5 s, 9 s |

### Roadmap
- Tick **Goblin Shaman** in Phase 9 with a one-line summary.
- Phase 1 run-art line: the hero has its own run art for right, down-right
  and down (left ones mirrored); running up and up-diagonal uses the
  side-on run (with a lean) until that art is redone.

## Out of scope
- Shamans healing or shielding goblins (other buff kinds).
- Buffing the Shaman itself or stacking frenzy from several Shamans.
- Orbs that home or lead their target.
- Towers preferring Shamans as targets.

## Testing (in the running game, via the Godot MCP tools)
1. A spawned Shaman walks in, stops at about 220 px from the Core or hero and
   throws orbs every 2 s; each orb deals 6 magic damage.
2. A wall between a Shaman and its target stops the orb (the wall loses health,
   the target doesn't).
3. A pulse frenzies goblins within 160 px and not those farther out; frenzied
   goblins move 30% faster and hit 30% harder, and it wears off after 4 s.
4. Stunning a Shaman mid-pulse (Spire Resonance) or killing it cancels the
   frenzy.
5. Frenzy doesn't stack from two Shamans; the tint order is stun > frenzy > burn.
6. The basic and Armored Goblins behave exactly as before (melee, same damage).
7. Shaman loot drops; a full wave 2 run completes with no errors.
