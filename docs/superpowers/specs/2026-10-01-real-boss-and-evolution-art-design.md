# Real art for the bosses and the tower evolutions

Date: 2026-10-01
Status: design approved in chat

The new sheets in `~/Desktop/Astral forge assests/` (made from
`docs/art/2026-09-30-boss-and-evolution-art-brief.md`) replace the
placeholder looks: the tinted Armored Goblin / Shaman stand-ins for the two
bosses, and the tint + glow + 10% bigger looks (or the borrowed
blaster_turret / aether_harvester sheets) for the evolved towers.

## Decisions

| Question | Decision |
|---|---|
| Focus Lens | Its rows on `aether_spire_evolutions.png` came out jumbled (6 idle frames in two sizes, 3 fire, no wreck). It **keeps its placeholder look** for now; a fix-up prompt for a new `focus_lens.png` (idle 4, fire 4, destroyed 2) is on the Desktop (`astral_forge_focus_lens_prompt.txt`). When that sheet arrives it's sliced like the others (a small follow-up). |
| Gearshot pair | **Rotating heads**, cut from the idle frame with `tools/split_turret.py`, like the plain Gearshot. The Gatling Engine stops mirroring. |
| Effects painted pointing right | Inferno / Oil Sprayer flames and Storm Array lightning only point right in the art, but the towers fire every way: they show **idle art while firing**, and the game keeps drawing the real flame cone / lightning. The Mortar pair use their fire frames (the shell arcs up either way, and they mirror). |
| Boss tints / auras | Tints go. The Shaman-King's drawn aura goes (the art has its own rune circle); the Warchief keeps his red ground ring. |
| Old stand-ins | `tools/alias_frames.py` and the generated `assets/sprites/gatling_engine.tres` / `storm_array.tres` aliases are replaced by the real sheets (the tool is deleted). |

## Source files

Copy the new sheets into `assets/source/` (originals, never edited):
`goblin_warchief.png`, `goblin_shaman_king.png`, `boss_portraits.png`,
`gearshot_evolutions.png`, `rune_mortar_evolutions.png`,
`embercaster_evolutions.png`, `aether_spire_evolutions.png`.

## Slicing (`tools/slice_sprites.py`)

New `SHEETS` entries (rows top to bottom, frame counts as drawn):

| Output | Source | Rows |
|---|---|---|
| `goblin_warchief` | goblin_warchief.png | idle 4 · walk 9 · attack 6 · war_cry 6 · hurt 4 · death 8 |
| `goblin_shaman_king` | goblin_shaman_king.png | idle 4 · walk 8 · cast 6 (+ the loose orb fan, discarded) + projectile 2 · summon 6 · buff 4 · phase_shift 7 · death 9 |

The four evolution sheets each hold two towers (rows: A idle 4, A fire 4,
A destroyed 2, B idle 4, B fire 4, B destroyed 2). Each tower gets its own
SpriteFrames with animations `lv3_idle`, `lv3_fire`, `destroyed` (an
evolution always runs at Lv3), written as `assets/sprites/<evolution id>.png/.tres`:

| Sheet | Rows 1–3 | Rows 4–6 |
|---|---|---|
| gearshot_evolutions | `gatling_engine` | `rune_cannon` |
| rune_mortar_evolutions | `siege_battery` | `frost_mortar` |
| embercaster_evolutions | `inferno` | `oil_sprayer` |
| aether_spire_evolutions | `storm_array` (rows 1–2, wreck = the 2 frames at the left of row 4) | — (Focus Lens skipped; see Decisions) |

The slicer gains the small support this needs: `--only name,name` to build
just the named outputs (a full re-run rewrites the other `.tres` files in a
different but equivalent format, so existing sprite files are left alone),
animation names starting with `_` are discarded (for rows that belong to the
other output, or the loose orb fan), and a name used twice in a row is joined
into one animation. `war_cry`, `summon` and `phase_shift` don't loop (channels
wait for them to finish).

Boss portraits: `boss_portraits.png` → two static images,
`assets/sprites/portraits/goblin_warchief.png` and
`goblin_shaman_king.png` (trimmed).

## Bosses

- `data/enemies/goblin_warchief.tres`: new `sprite_frames`, `tint` white,
  `pulse_animation = &"war_cry"`, keeps `attack_hit_frame = 3` (the slam is
  frame 4), keeps its aura; `sprite_scale` tuned so he stands about 1.8× a
  goblin's height.
- `data/enemies/goblin_shaman_king.tres`: new `sprite_frames`, `tint` white,
  aura removed, `summon_animation = &"summon"`, `phase_shift_animation =
  &"phase_shift"`, `pulse_animation = &"buff"`, `attack_animation = &"cast"`
  with the release on frame 4 (`attack_hit_frame = 3`); `sprite_scale` tuned
  to about 2.2× a goblin; `projectile_scene` = a new
  `scenes/projectiles/king_orb.tscn` (like `enemy_orb.tscn`, drawn from the
  King's own `projectile` frame).
- Every animation a boss's abilities name must exist in its frames (headless
  test).
- `hurt` is used by the Warchief only through data (no new hurt behaviour).

## Boss portraits

- `EnemyDefinition` gains `portrait: Texture2D` (null = none).
- The boss bar shows it as a 56×56 picture left of the name and bar, hidden
  when null. Both bosses set it.

## Evolutions

For the seven with new art, each data file: `sprite_frames` → its new
SpriteFrames, `tint` white, `glow` transparent, `sprite_scale` back to the
base tower's (0.55) unless tuning needs otherwise, muzzle / bolt positions
re-measured.

- **Gatling Engine / Rune Cannon:** a `TurretHead` for Lv3 cut from the idle
  frame (`split_turret.py` entries `gatling_engine`, `rune_cannon` →
  `assets/sprites/towers/<id>_base.png` / `_head.png`); `heads` = three
  entries with the Lv3 one set (evolutions only use Lv3). `GatlingTower`
  drops its mirroring and `muzzle_offset` and aims like the Gearshot; the
  muzzle flash and recoil show shots. Wreck = `destroyed`.
- **Siege Battery / Frost Rune Mortar:** mirror like the Mortar, fire frames
  shown as now; `muzzle_offset` re-measured.
- **Inferno / Oil Sprayer:** mirror like the Embercaster; while spraying they
  show `lv3_idle` (the drawn cone is the flame). Implemented as a per-tower
  data flag (e.g. `fire_frame_while_spraying := true` on EmberDefinition,
  false for these two). `muzzle_offset` re-measured.
- **Storm Array:** shows `lv3_idle` when it fires (a data flag on
  SpireDefinition, e.g. `show_fire_frame := true`, false here); `bolt_heights`
  re-measured to the top crystal.
- **Focus Lens:** unchanged (placeholder) until `focus_lens.png` arrives.

## Testing

- Headless (`tests/test_evolutions.gd`, plus a boss check): every evolution's
  frames have `lv3_idle`, `lv3_fire` and `destroyed` (or a per-level wreck);
  each boss's frames have `idle`, `walk`, `death`, its attack animation and
  every channel animation its data names; both bosses have a portrait.
- In the game (Godot MCP): screenshots of each boss walking, attacking and
  using each ability (war cry, cast, summon, phase shift) and its death; the
  boss bar with portrait; each of the seven towers idle, firing (in two
  directions for the mirrored and rotating ones) and wrecked; sizes and
  muzzle points tuned from the screenshots.
- Existing tests keep passing; the web build loads without errors.

## Out of scope
- The Focus Lens art (follow-up when its sheet arrives).
- New boss behaviour (e.g. a hurt reaction) — art only.
