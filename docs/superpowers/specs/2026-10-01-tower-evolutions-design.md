# Phase 10: tower evolutions

Date: 2026-10-01
Status: design approved in chat (from `docs/proposals/2026-09-30-phase-10-proposal.md`,
section 3 — unlock A, 6 Aether, all 8 branches, placeholder look)

Each tower can evolve once, at Lv3, into one of two branches that change
**how it plays**, not just its numbers. Real evolution art doesn't exist yet;
the placeholder look is described under "Look". The art brief is
`docs/art/2026-09-30-boss-and-evolution-art-brief.md`.

## Decisions

| Question | Decision |
|---|---|
| Unlock | Tower at **Lv3** → F menu → **Evolve — 6 Aether** → choose 1 of 2 branches |
| How many | One evolution per tower; it can't be undone (sell to start over) |
| Power | **Lv3 stats + the branch change** (no extra flat boost) |
| Abilities | Each branch gets its **own Q ability** (Inferno keeps Overpressure) |
| Selling | 50% of everything spent, the 6 Aether included |
| Bosses | Freezes and stuns hit bosses at full strength (as Resonance Burst does today) |
| Build order | One branch: evolve system + menu, then Gearshot → Mortar → Embercaster → Spire pairs, testing each pair in the game |

## The evolve system

### Data
- **Each evolution is its own tower data file** in `data/towers/`
  (`gatling_engine.tres`, `rune_cannon.tres`, `siege_battery.tres`,
  `frost_mortar.tres`, `inferno.tres`, `oil_sprayer.tres`, `storm_array.tres`,
  `focus_lens.tres`), using the same definition class as its base tower or a
  subclass of it, plus its own scene/script where its behaviour differs.
- `TowerDefinition` gains:
  - `evolutions: Array[TowerDefinition]` — the two branches (base towers only).
  - `evolve_cost: Dictionary[StringName, int]` — `{aether: 6}` (set on each
    evolution; read from the chosen branch).
  - `evolved: bool` — true on evolution files (they never show in the build
    menu and can't evolve again).
  - `tint: Color` (default white) and `glow: Color` (default transparent) —
    placeholder look.
  - `help_line: String` — one line for the evolve choice and the Help screen.
- An evolution file **copies its base tower's base stats and level
  multipliers** and always runs at **level 3**, so it starts from exactly the
  Lv3 numbers. Its branch changes live in **separate, named fields** (e.g.
  `shot_damage_multiplier = 0.65`), never by editing the copied stats. A
  headless test checks that every evolution's copied stats match its base
  tower's, so the two can't drift apart.

### Evolving (`BuildSlot.evolve(branch)`)
- Allowed when: a tower is built, not wrecked, at Lv3, not already evolved,
  `branch` is one of its `evolutions`, and the Core can pay `branch.evolve_cost`
  (nothing is spent otherwise; returns false).
- Pays the cost and adds it to `invested` (so selling refunds 50% of it).
- Replaces the tower node: the new tower is set up with the branch, placed at
  the same spot at level 3, keeps the **same damage taken** (missing health
  carries over), and is connected like a newly built one. **Walls are not
  touched.**
- If the hero was operating the old tower, they are moved straight onto the
  new one (still operating, ability cooldown fresh).
- The nav grid is marked dirty (the footprint is the same, but this keeps it
  safe).

### F menu (`TowerMenu`)
- Lv1–2: the Upgrade button works as it does today.
- **Lv3, not evolved:** the button reads **"Evolve — 6 Aether"** (or
  "Evolve — need N more Aether", still clickable to see the choices but the
  branch buttons are disabled). Pressing it switches the panel to an
  **evolve view**: two branch cards side by side (icon, name, `help_line`,
  "Q: ability name — ability text") with a **Choose** button each, and a
  **Back** button. Choosing evolves and returns to the normal view.
- **Evolved:** title "Gatling Engine (Evolved)"; button "Fully evolved",
  disabled.
- Esc / F in the evolve view goes back to the normal view first; again
  closes.

### Look (placeholder)
- **Gatling Engine:** the `blaster_turret` sheet. It faces right and is
  mirrored for left (like the Mortar); idle = its first idle frame, fire =
  fire frames 1–5, wreck = last destroy frame. `tools/slice_sprites.py` writes
  an evolution-ready `assets/sprites/gatling_engine.tres` with animations
  named `lv3_idle`, `lv3_fire`, `destroyed`.
- **Storm Array:** the `aether_harvester` sheet's Lv3 row; its `pulse` plays
  as the firing animation. The slicer writes `assets/sprites/storm_array.tres`
  (`lv3_idle`, `lv3_fire` = pulse, `destroyed`).
- **The other six** use their base tower's Lv3 art with the branch `tint`, a
  soft `glow` ring drawn under the tower, and 10% larger scale:
  Rune Cannon violet, Siege Battery orange, Frost Rune Mortar icy blue,
  Inferno deep red, Oil Sprayer dark amber, Focus Lens white-gold.
- Swapping in real art later is a data change (new SpriteFrames, tint white,
  glow transparent).
- `TowerDefinition.icon()` uses `lv3_idle` for evolutions (their sheets have
  no `lv1_` animations). The end screen's "towers standing" row shows an
  evolved tower's icon with its tint and the label "Evolved" instead of
  "Lv3"; the F menu's evolve cards use the same tinted icon.

### Help screen
Each base tower's entry gets an **Evolutions (Lv3, 6 Aether)** section: each
branch's name, `help_line` and "Q: ability — text (cooldown)". Evolutions
don't get entries of their own.

## The branches

All numbers start from the base tower's Lv3 stats and are a starting point
for tuning. "Damage" includes operating and card bonuses as usual.

### Gearshot → Gatling Engine (physical)
- **Spin:** `spin` goes 0 → 1 over **2 s** of continuous firing and back to 0
  over **1 s** when not firing. Fire rate × (1 + 3 × spin): 1× → **4×**.
- Each shot deals **65%** damage.
- Shoots normal bullets (like the Gearshot); no rotating head.
- **Q — Overspin:** spin jumps to 1 and doesn't drop for **4 s**. Cooldown 12 s.

### Gearshot → Rune Cannon (**magic**)
- Fire rate × **0.3** (≈ 0.6 shots/s at Lv3), damage × **3.5**.
- Rounds **pierce**: each passes through up to **3** enemies (hitting each
  once), and every hit **splashes 40%** of its damage to other enemies within
  **50 px**.
- **Q — Overcharge Round:** one 4× round that pierces **every** enemy in its
  line and flies 1.5× as far. Cooldown 12 s.

### Rune Mortar → Siege Battery (magic)
- Each shot is a **salvo of 3 shells**: one on the target, two scattered
  within **40 px** of it, landing 0.1 s apart. Each shell deals **70%** damage
  with a **30% larger** blast.
- Fire rate × **0.6**.
- **Q — Bombardment:** 6 full-damage shells scattered within **120 px** of
  the mouse (replaces Rune Shell). Cooldown 14 s.

### Rune Mortar → Frost Rune Mortar (magic)
- Damage × **0.8**.
- Every shell leaves a **frost circle** (the rune circle, icy blue, the size
  of the blast): enemies inside are **60% slower**; it lasts **6 s**.
- Enemies within **30 px** of the impact are **frozen** (stunned) for **0.6 s**.
- **Q — Glacial Shell:** a shell with **2×** blast radius that freezes
  everything in it for **2 s** (and leaves a frost circle). Cooldown 14 s.

### Embercaster → Inferno (fire)
- Cone length × **1.4**.
- Burn stacks up to **10** (from 5).
- **Q — Overpressure** (unchanged, using the longer cone and 10 stacks).

### Embercaster → Oil Sprayer (fire)
- Flame damage × **0.5** (burn too).
- Everything the flame hits is **oiled** for **4 s** (refreshed on each hit):
  **30% slower** and takes **+50% fire damage** from any source — other
  Embercasters, burn, the Ember Rounds card. (Implemented as the enemy's fire
  `damage_taken` × 1.5 while oiled; an Armored Goblin's 60% becomes 90%.)
  Oiled enemies get a dark sheen.
- **Q — Ignite:** every oiled enemy within its range takes a **fire burst of
  3×** the flame's damage, is set to **max burn**, and loses its oil.
  Cooldown 10 s.

### Aether Spire → Storm Array (magic)
- **8 jumps**, **no falloff**.
- Every **5th** bolt stuns everything it hits for **0.5 s**.
- **Q — Thunderstorm:** for **4 s**, every **0.25 s** a strike hits a random
  enemy in range, chaining **2** jumps and stunning each for **0.5 s**.
  Cooldown 14 s.

### Aether Spire → Focus Lens (magic)
- **No chaining.** A continuous **beam** on one target that ticks **10× a
  second**; its total damage per second at 1× equals the Spire's Lv3 single
  -target damage per second (damage × fire rate).
- **Ramp:** × 1 → **× 5** over **3 s** on the same target; switching target
  resets it.
- Target: on its own, the enemy with the **most health** in range; operated,
  the enemy in range nearest the mouse.
- Drawn as a beam whose width and brightness grow with the ramp.
- **Q — Overload:** ramp jumps to max and the beam deals **1.5×** on top for
  **4 s**. Cooldown 12 s.

## Testing
- **Headless** (`tests/test_evolutions.gd`): every base tower lists 2
  evolutions; every evolution is `evolved`, costs 6 Aether, and its copied
  stats and level multipliers match its base tower's; `sell_value` after
  evolving includes 3 Aether; the Help text lists both branches.
- **In the game (Godot MCP)**, after the system and after each pair: evolve
  through the F menu (cost taken, walls untouched, damage taken kept, the
  operator stays on); each branch's behaviour and its Q ability; screenshots
  of each look.

## Out of scope
- Real evolution art (data swap later).
- Evolutions for towers that don't exist yet.
