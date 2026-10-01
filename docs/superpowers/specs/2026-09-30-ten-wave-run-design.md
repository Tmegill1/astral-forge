# Phase 10: a full 10-wave run with a mini-boss and a final boss

Date: 2026-09-30
Status: design approved in chat (from `docs/proposals/2026-09-30-phase-10-proposal.md`, section 2 — all recommendations accepted)

Art for the bosses doesn't exist yet. This builds the run with **placeholder
bosses** made from existing sprites; the art brief and image prompts for the
real sheets are in `docs/art/2026-09-30-boss-and-evolution-art-brief.md`
(copy on the Desktop: `~/Desktop/astral_forge_boss_and_evolution_art_prompts.txt`).
Swapping the real art in later is a data change (see "Art hand-off").

## Decisions

| Question | Decision |
|---|---|
| Length | 10 waves, ≈ 13–15 min |
| Mini-boss | **Goblin Warchief**, wave 6 (placeholder now) |
| Final boss | **Goblin Shaman-King**, wave 10 (placeholder now) |
| Ending | Killing the Shaman-King wins the run at once; every other enemy flees |
| Banners | Big centre banner at the start of waves 6 and 10 (and "Wave N" for the rest) |
| Boss bar | Wide health bar across the top while a boss is alive |
| Shaman-King's shield | Phase 2 (below 50%): takes only 10% damage **unless the hero is operating a tower that has the boss in range** — then the shield drops |

## Waves (`scenes/waves/first_run.tscn`)

Waves 1–5 stay as they are. New waves (prep time = break before the wave):

| Wave | Prep | Groups (enemy × count, side, interval s, delay s) | Banner |
|---|---|---|---|
| 6 | 35 | Goblin ×10 W 1.2 0 · Goblin ×6 E 1.2 2 · Shaman ×1 W 2 4 · Shaman ×1 E 2 6 · **Warchief ×1 E, delay 10** | "Wave 6 — The Warchief approaches" |
| 7 | 30 | Goblin ×10 N 1.0 0 · Goblin ×10 E 1.0 2 · Goblin ×10 S 1.0 4 · Armored ×3 N 2.5 3 · Armored ×3 S 2.5 6 · Shaman ×1 N/E/S, delay 8 | "Wave 7" |
| 8 | 30 | Goblin ×9/9/8/8 N/E/S/W 1.0, delays 0/2/4/6 · Armored ×3 E 2.5 3 · Armored ×3 W 2.5 5 · Shaman ×1 each side, delay 8 | "Wave 8" |
| 9 | 25 | **Burst 1** (delay 0): Goblin ×10 each side 0.8 · Armored ×2 each side 2.0 · Shaman ×1 N and S, delay 6. **Burst 2** (delay 22): Goblin ×5 each side 0.8 · Armored ×1 each side 2.0 · Shaman ×1 E, W and N, delay 26 | "Wave 9 — They're everywhere" |
| 10 | 45 | **Shaman-King ×1 N, delay 4** · escorts over time: Goblin ×5 per side 1.5 (W delay 8, E 16, S 24, N 32) · Armored ×2 E and ×2 W 3.0, delay 20 · Armored ×1 N and ×1 S, delay 30 · Shaman ×1 each side, delay 14 | "Final wave — The Shaman-King" |

A full run: Goblin 236, Armored 39, Shaman 24, the two bosses, plus the
Shaman-King's summons — about 510 XP before summons (≈ level 9).

Every wave's banner is set on its `Wave` node (`banner: String`; empty =
"Wave N").

## Bosses

### Shared boss support
- `EnemyDefinition` gains:
  - `is_boss: bool` — shows the boss bar, joins group `bosses`.
  - `ends_run: bool` — its death wins the run.
  - `tint: Color` (default white) and `aura: Color` (default transparent) —
    placeholder look: the sprite is tinted, and an aura ring is drawn under
    the feet if `aura.a > 0`.
  - `projectile_count: int` (default 1) and `projectile_spread_deg: float`
    (default 0) — a ranged attack fires that many projectiles in a fan.
  - `ignores_walls: bool` — pathing goes straight through walls/towers; the
    first wall/tower it bumps into (within attack reach on its way) becomes its
    target until destroyed.
  - `structure_damage_multiplier: float` (default 1) — damage × this against
    walls and towers.
  - `guaranteed_drops: Dictionary[StringName, int]` and
    `drops_lodestone: bool`.
- Boss **health bar** (`scenes/ui/boss_bar.tscn` in the HUD): 520×16 bar,
  top centre under the wave/Core panels, boss name above it, shows while any
  `bosses` member is alive; with two bosses it tracks the first.
- When a boss with `ends_run` dies: every other living enemy "flees" (fades
  out over 0.6 s and is freed without loot), the spawn queue is cleared, and
  the run is won (Win screen with its slow-motion banner).

### Goblin Warchief (wave 6) — `data/enemies/goblin_warchief.tres`
- Placeholder: `goblin_brute` sprites, `sprite_scale` 0.58 (1.8× the Armored
  Goblin), `tint` Color(1, 0.62, 0.55), `aura` red Color(1, 0.3, 0.2, 0.35).
- 600 health; speed 45; physical 0.3 / fire 0.6 / magic 1.0.
- Melee: 20 damage at 0.6/s, `structure_damage_multiplier` 3 (60 per hit on
  walls/towers); `ignores_walls` true (smashes straight through toward the
  Core).
- **War cry**: frenzy pulse every 8 s, radius 250, +30% speed and damage for 5 s
  (reuses `FrenzyPulse`); placeholder animation `hurt` (non-looping) until the
  real `war_cry` row exists.
- XP 25; drops 20–25 Scrap, guaranteed 5 Aether, guaranteed Lodestone.
- `is_boss` true, `ends_run` false.

### Goblin Shaman-King (wave 10) — `data/enemies/goblin_shaman_king.tres`
- Placeholder: `goblin_shaman` sprites, `sprite_scale` 0.66 (2.2×), `tint`
  Color(0.8, 0.6, 1.0), `aura` purple Color(0.6, 0.3, 1.0, 0.4).
- 2,500 health; speed 40; physical 1.0 / fire 1.0 / magic 0.6.
- **Orb volley**: ranged, 8 magic per orb, `projectile_count` 5,
  `projectile_spread_deg` 40, every 3 s (`attacks_per_second` 0.333), attack
  range 300.
- **Frenzy pulse**: every 6 s, radius 300, +30%/+30% for 4 s.
- **Summon** (new `Summoner` component, like `FrenzyPulse`): every 12 s stops,
  plays its summon animation, and spawns 4 Goblins in a ring 60 px around
  itself (they count toward the wave). Placeholder animation: `buff`.
- **Phase 2** at ≤ 50% health (once): speed × 1.3, summon interval halves,
  and a **shield**: a translucent purple bubble (drawn in code). While shielded
  it takes 10% of all damage — **except** while the hero is operating a tower
  whose attack range reaches the boss, when the bubble fades and damage is
  normal. A 1.5 s "phase shift" pause (placeholder animation `buff`) and a
  screen-wide purple flash mark the change.
- XP 60; `is_boss` true, `ends_run` true.

## Banners (`scenes/ui/wave_banner.tscn` in the HUD)
- At each wave start: the wave's banner text, 40 px, centred in the upper
  third, fades in 0.3 s, holds 2 s, fades out 0.5 s. Boss waves use gold text
  with a red (wave 6) / purple (wave 10) outline; others white.
- Doesn't block input; plays while not paused.

## Art hand-off (when real sheets arrive)
- Warchief sheet → `assets/source/goblin_warchief.png`; slicer entry with
  rows idle 4, walk 8, attack 6, war_cry 6, hurt 4, death 8; then in
  `goblin_warchief.tres` set `sprite_frames` to the new sheet, `tint` to white,
  `pulse_animation = &"war_cry"`, and recalibrate `sprite_scale` and
  `attack_hit_frame` by screenshot.
- Shaman-King sheet → `assets/source/goblin_shaman_king.png`; rows idle 4,
  walk 8, cast 6 (+ projectile 2), summon 6, buff 4, phase_shift 6, death 8;
  set `pulse_animation = &"buff"`, summon animation `summon`, phase-shift
  animation `phase_shift`, `tint` white; the orb scene can use its projectile
  frames.

## Out of scope
- Tower evolutions (next feature; their art is in the same art brief).
- New regular enemies (Ogre, Bat), difficulty settings, endless mode.
- Rebalancing waves 1–5.

## Testing
Headless (`tests/test_waves.gd`): the run has 10 waves; waves 1–5 unchanged
(enemy, count, sector, delay per group); wave 6 contains one Warchief, wave
10 one Shaman-King; every wave has a banner or the default "Wave N"; total
enemies per type (Goblin 236, Armored 39, Shaman 24, plus the two bosses) and
expected XP (≈ 510 before summoned goblins) match the table.

In the running game (Godot MCP):
1. Banner shows at wave start with the right text/colour and fades.
2. Warchief: walks straight through a wall line, destroys the wall (60 per
   hit), war-cries every 8 s (nearby goblins frenzied), boss bar shows and
   drains; on death drops 5 Aether, a Lodestone and 20–25 Scrap; bar hides.
3. Shaman-King: fires 5-orb fans every 3 s; summons 4 goblins every 12 s;
   frenzy pulse; at 50% shifts phase (pause, flash), speeds up, summons every
   6 s, shield takes 10% damage; operating a tower in range of it drops the
   shield (full damage).
4. Killing the Shaman-King: all other enemies flee (no loot), run won, Win
   screen shows "Waves 10 / 10".
5. A sped-up full run from wave 1 to the win completes without errors.
6. Web export: banner and boss bar render; no console errors.
