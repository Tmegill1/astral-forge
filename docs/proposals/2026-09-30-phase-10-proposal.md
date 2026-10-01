# Phase 10 proposal: tower evolutions, a 10-wave run, and the Win screen

Date: 2026-09-30
Status: **proposal — for your review.** Nothing here is built yet. Each of the
three parts would go through the usual flow (short design chat → spec → plan →
build) once you've marked this up. Every "**Decide:**" line is a question for
you; my recommendation is listed first.

Also in this change: **hero abilities are dropped from the roadmap.** Instead,
each hero will later get its own ability cards that only show up in that
hero's card offers (prototype later).

What the design brief says, for reference:
- Evolutions: "a meaningful evolution choice rather than another percentage
  increase. A run should produce a few highly specialized towers, not a
  fortress where every structure is equally maxed." Named branches: Gearshot →
  Gatling Engine / Rune Cannon, Rune Mortar → Siege Battery, Aether Spire →
  Storm Array. Aether pays for "evolutions, hero upgrades, magical structures".
- Run: "a 12–15 minute run with 10 waves, short scavenging windows, one elite
  or mini-boss escalation, and a final boss." Mini-boss ≈ 8:30 "tests
  specialized tower damage"; final boss 12:00+ "validates the build and
  demands personal intervention".

Suggested build order: **Win screen → 10-wave run with bosses → evolutions.**
The Win screen is small and makes testing full runs nicer; the longer run is
where evolutions get to matter.

---

## 1. Win screen (and a better defeat screen)

**Today:** "The Core holds!" / "The Core has fallen", one summary line and a
Restart button.

**Proposal:** one end-of-run screen used for both, with a run summary:

| Section | Shows |
|---|---|
| Title | **Victory — The Core holds!** (green) / **Defeat — The Core has fallen** (red) |
| Run | Time · waves cleared (x / 10) · Core health left (victory) |
| Combat | Goblins defeated, broken down by type (icon + count): Goblin 48 · Armored 9 · Shaman 6 · Warchief 1… |
| You | Level reached · the cards you took, as small chips with ranks ("Arc Bolts ×2") |
| Fortress | Towers standing (icons with level / evolution), Scrap and Aether gathered |
| Buttons | **Play Again** · **Main Menu** (R still restarts) |

- Same dark-panel, gold-border look as Help/Options.
- The defeat screen gets the same layout (it's useful to see what you had).

**Decide:**
1. Is that summary the right amount? (Recommended: yes — it's all data the
   game already tracks, apart from kills by type and Scrap gathered, which are
   two counters.)
2. Add a **run grade** (S/A/B/C from time, Core health, level)? Recommended:
   **not yet** — wait until runs are tuned.
3. Victory moment: **a 2-second slow-motion beat** ("The Core holds!" banner
   over the field) before the screen appears? Recommended: yes, cheap and feels
   good.

---

## 2. A full run: 10 waves, a mini-boss, a final boss

### Wave plan (≈ 13–15 minutes)
Breaks shrink as the run goes on; sectors build up; Shamans and Armored
Goblins arrive gradually. Counts are a starting point for tuning.

| Wave | Break before | Enemies | Sides | Notes |
|---|---|---|---|---|
| 1 | 45 s | 6 Goblins | W | as today |
| 2 | 30 s | 10 Goblins, 1 Shaman | W, N | as today |
| 3 | 30 s | 14 Goblins, 2 Armored, 1 Shaman | E, S | as today |
| 4 | 30 s | 18 Goblins, 3 Armored, 2 Shaman | N, W, S | as today |
| 5 | 30 s | 28 Goblins, 4 Armored, 2 Shaman | all 4 | as today's finale |
| 6 | 35 s | 16 Goblins, 2 Shaman + **mini-boss** | E (boss) + W | mini-boss arrives after the pack |
| 7 | 30 s | 30 Goblins, 6 Armored, 3 Shaman | N, E, S | |
| 8 | 30 s | 34 Goblins, 6 Armored, 4 Shaman | all 4 | |
| 9 | 25 s | 40 Goblins, 10 Armored, 5 Shaman | all 4, two bursts | "major wave" — forces triage |
| 10 | 45 s | **final boss** + escorts (20 Goblins, 6 Armored, 4 Shaman over time) | boss from N, escorts all sides | |

With these numbers a full run drops ~470 XP (216 Goblins, 37 Armored, 24
Shamans, plus the bosses) → about **level 9** (8 card picks).

### Bosses
No boss art exists yet. Until you make it, I'd use **placeholder bosses built
from existing sprites** (scaled up, tinted, with a crown/aura drawn in code) so
the run is playable end to end; swapping in real art later is a data change.

**Mini-boss — Goblin Warchief** (wave 6), placeholder: the Armored Goblin art
at 1.8× size with a red tint.
- ~600 health, slow, takes 30% physical / 60% fire / 100% magic (a
  "specialized damage check", as the brief says).
- **Wall-breaker:** goes straight at the nearest wall/tower in its path and
  hits it for heavy damage, instead of pathing around.
- **War cry** every 8 s: frenzies all goblins within 250 px (reuses the
  Shaman's frenzy).
- Drops a big Scrap pile, 5 Aether and a **Lodestone**.

**Final boss — Goblin Shaman-King** (wave 10), placeholder: the Shaman art at
2.2× size, purple tint, floating rune ring.
- ~2,500 health, slow, resists magic (60%).
- **Orb volley:** fires 5 orbs in a fan every 3 s at the hero or Core.
- **Summon:** every 12 s, raises 4 Goblins around itself.
- **Frenzy pulse** like a Shaman, but 300 px.
- **Phase 2 at 50% health:** faster, summons twice as often, and a shield
  that only breaks while the hero is personally operating a tower in range
  ("demands personal intervention").
- Killing it wins the run immediately (remaining enemies flee/vanish).

**Boss health bar:** a wide bar across the top of the screen with the boss's
name while a boss is alive.

**Decide:**
4. Placeholder bosses now (recommended) or wait for boss art first?
5. Boss names and mechanics — keep, change, or swap any out? (The Shaman-King's
   "shield only breaks while you operate a tower" is the brief's "personal
   intervention" idea — keep it?)
6. Should killing the final boss end the run instantly (recommended), or must
   every enemy in wave 10 die too?
7. Do you want a short **"Wave 6 — The Warchief approaches"** / **"Final
   wave"** banner with a sector warning?

---

## 3. Tower evolutions

### How you unlock one
Mastery XP is gone, so evolutions need a new gate. Options:

| Option | How it works | Trade-off |
|---|---|---|
| **A. Lv3 + Aether (recommended)** | At Level 3, the F menu shows **Evolve — 6 Aether**, then a choice of 2 branches. One evolution per tower. | Uses Aether exactly as the brief intends; easy to understand; Aether becomes the late-game currency worth hunting. |
| B. Lv3 + Aether + operated time | Same, but the tower must also have been **operated for 60 s** in total this run. | Strongest tie to the "personal attention" pillar, but adds a hidden-ish requirement. |
| C. Evolution card | A rare card ("Evolution Schematic") that lets you evolve one Lv3 tower for free. | Fun jackpot, but evolutions become random. |

### The branches (two per tower)
Every evolution changes **how the tower plays**, not just its numbers.

| Tower | Branch | What changes |
|---|---|---|
| Gearshot | **Gatling Engine** | Spins up: fire rate ramps from 1× to 4× over 2 s of continuous firing; −35% damage per shot. Shreds swarms. |
| Gearshot | **Rune Cannon** | Slow magic rounds (0.6/s) that **pierce** up to 3 enemies and burst for small splash. Answers armour. |
| Rune Mortar | **Siege Battery** | Fires a 3-shell salvo every 4 s; each shell 70% damage; big area. Crushes clusters. |
| Rune Mortar | **Frost Rune Mortar** | Shells leave larger slowing circles (60% speed, 6 s) and a brief freeze on direct hits. Controls lanes. |
| Embercaster | **Inferno** | Longer cone (+40% range), burn stacks up to 10. Melts crowds that reach it. |
| Embercaster | **Oil Sprayer** | Sprays oil that slows (70%) and makes enemies take +50% fire damage; ignited oil bursts. Combos with any fire. |
| Aether Spire | **Storm Array** | 8 jumps, no damage falloff, and every 5th bolt stuns 0.5 s. Crowd control. |
| Aether Spire | **Focus Lens** | No chaining: a continuous beam on one target that ramps up to 5× damage. Boss/armour killer. |

### Art
There's no evolution art yet. Placeholder: the tower's **Lv3 art with a
coloured glow, a small emblem and slightly larger scale**, so evolved towers
are recognizable. Two unused sheets could also stand in:
`blaster_turret` (idle/fire/damaged/destroy) for **Gatling Engine** and
`aether_harvester` (crystal with a pulse) for **Storm Array**.

### Also
- The Help screen's tower guide shows each tower's two branches and costs.
- Selling an evolved tower refunds 50% of everything spent, Aether included.
- An evolved tower keeps its walls and operated bonuses; its ability may
  change to match (e.g. Gatling's Rapid Fire becomes "Overspin: instant max
  spin for 4 s").

**Decide:**
8. Unlock: A, B or C? (Recommended A.)
9. Cost: 6 Aether? (One Aether crystal gives 2–4, so roughly two trips far
   from the Core.)
10. The 8 branches — keep, change or cut any? If you want a smaller first
    build: **Gatling Engine, Rune Cannon, Siege Battery, Storm Array** (the
    brief's four) first, the other four later.
11. Placeholder look (Lv3 + glow + emblem), or should I use the `blaster_turret`
    and `aether_harvester` sheets where they fit?

---

## Roadmap changes in this branch
- Removed: "Artificer abilities: passive, Overclock, Full Steam ultimate".
- Added under Phase 10: "Hero-specific ability cards (each hero gets its own
  cards that only appear in its offers) — prototype later".
