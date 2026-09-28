# Astral Forge — Roadmap

> Built from the *Aetherhold* design brief (Aetherhold was the working title).
> Source doc: `~/Downloads/Aetherhold_Game_Design_and_Core_Loop.docx`
> Art: `~/Desktop/Astral forge assests/`

## How to use this

- Work **top to bottom**. Each phase ends with something you can **play**.
- Don't start the next phase until the current one's **Done when** is true.
- Tags: **[AI]** = ask Claude to do it · **[You]** = needs your hands, eyes, or opinion · **[Both]** = Claude builds, you test and give feedback.
- Tick the box `[x]` when finished.
- Placeholder art is fine at any step. Fun first, pretty later.

---

## Phase 0 — Setup ✅ mostly done

- [x] Godot project, terrain tileset (64×64 tiles), world scene, grass painted
- [x] **[AI]** Copy the art from the Desktop folder into `assets/source/` (originals, never edited; Godot ignores this folder)
- [x] **[AI]** Cut each sprite sheet into clean, equal-size frames → `tools/slice_sprites.py` writes `assets/sprites/<name>.png` + `<name>.tres` (Godot SpriteFrames with named animations)
- [x] **[You]** Look over the sprite preview and the "What each art file is" table below; fix anything I guessed wrong (rename = change the name in `SHEETS` in `tools/slice_sprites.py` and re-run it)

Known small glitches (fine for placeholders): Mortar/Spire/Embercaster fire frames that shoot past the frame edge get their shell/bolt/flame clipped. Projectiles will be separate sprites later anyway.

**Done when:** every character/tower has clean animation frames in the project.

---

## Phase 1 — Hero walks around

- [x] **[AI]** Artificer hero: move with WASD, camera follows
- [x] **[AI]** Right-click to walk to a spot; hold right-click to keep following the cursor (WASD cancels it; while operating a tower, right-click is the tower ability)
- [x] **[AI]** Idle / walk / death animations hooked up
- [x] **[AI]** Hero health + a basic attack (auto-fires bolts toward the mouse)
- [x] **[AI]** An "Interact" button (E) — used later for towers, building, depositing
- [x] **[You]** Decide: aim with the **mouse**, shooting is **automatic** for now (`auto_fire` on the Hero can be turned off → hold left click to shoot)
- [x] **[Both]** Play it — does moving feel good? (hero shrunk 30%, faces the way it walks, HUD + health bars added)

- [x] **[Both]** Running in 8 directions: `assets/source/artificer_run.png` (5 directions, left ones mirrored); the hero picks the walk art by direction, leans into turns, and lines frames up by the body so the run doesn't jitter

**How heroes work:** every hero shares `scripts/heroes/hero.gd`. Baseline stats are the defaults in `scripts/heroes/hero_stats.gd`. Each hero is a data file in `data/heroes/` (art, size, and stat multipliers, e.g. Artificer = 0.9× health). `Game.selected_hero` picks who spawns; a hero-select screen will set it later. New hero = new `.tres` file, no code.

**Done when:** you can walk around the map and swing/shoot at nothing.

---

## Phase 2 — The Core and one Goblin

- [x] **[AI]** Command Core in the middle of the map, with health (looks more broken at 66% and 33%)
- [x] **[AI]** Core regenerates 10 health every 5 s (`regen_amount` / `regen_interval` on the CommandCore)
- [x] **[AI]** Goblin walks toward the Core and attacks it (turns on the hero if you get close)
- [x] **[AI]** Hero can kill goblins
- [x] **[AI]** Core reaches 0 → "You Lose" screen (Restart button or R)
- [x] **[AI]** A fallen hero gets back up at the Core (15 seconds since Phase 3)
- [x] **[Both]** Play it — are goblins too fast/slow/tough? Is the Core too weak?
- [x] **[AI]** Enemy hitboxes cover the whole visible sprite +25% (`hurtbox_padding` per enemy), so shots aimed at the body land
- [x] **[You]** Decide: the hero starts at **1 shot per second**; upgrades raise it later (Phase 10)

**How enemies work:** same idea as heroes. Every enemy shares `scripts/enemies/enemy.gd`; each type is a data file in `data/enemies/` with its art and stats (Goblin: 30 HP, speed 70, hits for 5 once a second). Enemies now arrive in waves (the `WaveDirector` node, Phase 7).

**Done when:** goblins spawn, you fight them, and you can lose.

---

## Phase 3 — Pick up Scrap, bring it home

- [x] **[AI]** Goblins drop Scrap (1–2, gear pickups that drift toward you when close)
- [x] **[AI]** Scrap you're holding = **carried**; press E at the Core = **stored** (only stored can be spent)
- [x] **[AI]** Simple HUD: Core health, hero health, carried vs. stored Scrap, "[E] Deposit" prompt
- [x] **[You]** Decide: if the hero goes down, **half the carried Scrap is lost and the other half drops where they fell** (never despawns). The hero respawns at the Core after **15 seconds** (countdown on screen) and can go back for it
- [ ] **[Both]** Play it — is 15s the right respawn time? Do goblins drop enough?

Tuning knobs: respawn time and loss share are on the `World` node (`hero_respawn_time`, `fall_loss`); drops per enemy are in its data file (`drops`).

**Done when:** you can kill, collect, walk home, and see your bank go up.

---

## Phase 4 — Build a tower

- [x] **[AI]** Build slots around the Core (2 for now: left and right; they glow when you stand on one)
- [x] **[AI]** Stand on a slot + press E → spend 10 stored Scrap → Gearshot Turret appears (prompt says how much you're short)
- [x] **[AI]** Gearshot automatically aims at and shoots the nearest goblin within ~4 tiles (8 dmg, 1.5 shots/sec)
- [ ] **[Both]** Play it — is the turret too strong or too weak? Is 10 Scrap the right price?
- [x] **[AI]** Turret head rotates smoothly in any direction: `tools/split_turret.py` cuts the art into a fixed base + turning head (muzzle flash and recoil instead of swapping frames)

**How towers work:** same idea as heroes and enemies. Every tower shares `scripts/towers/tower.gd`; each type is a data file in `data/towers/` (art, cost, damage, fire rate, range, and which way each frame's barrel points). Each `BuildSlot` in the world scene has a `tower` it offers.

**Done when:** you can buy a turret and watch it defend on its own.

---

## Phase 5 — Operate the tower ⭐ the signature mechanic

- [x] **[AI]** Press E at a tower → hero takes control; press E again → leave (instant)
- [x] **[AI]** While controlled: aim with the mouse, **+35% damage, +50% fire rate, +15% range**
- [x] **[AI]** Camera zooms out **20%** while operating (`operating_zoom` on the Hero)
- [x] **[AI]** One tower active ability: **Rapid Fire** — Q or right-click, 3× fire rate for 3s, 12s cooldown
- [x] ~~**[AI]** Tower earns Mastery XP (1 XP per damage dealt while you operate it)~~ (removed 2026-09-27: replaced by player XP)
- [x] **[AI]** Clear "you are controlling this" visuals (range ring + operating panel)
- [ ] **[You]** The big question: **is operating a tower fun?** Would you choose to do it?
- [ ] **[You]** Balance: range bonus (10–20%?), zoom amount, ability numbers

All operated bonuses and the ability live in each tower's data file (`operated_*_multiplier`, `ability_*`).

**Done when:** jumping into the turret feels noticeably better than leaving it on auto.

---

## Phase 6 — Walls, build menu, repair & sell

- [x] **[AI]** E on an empty pad pauses the game and opens a **build menu** of the towers for that pad (Mortar, Embercaster, Spire show as "Coming soon" until Phase 8)
- [x] **[AI]** Every tower comes with **walls**: out from both sides of the tower, then turning back toward the middle — enemies must go around (`wall_length`, `wall_return` on each BuildSlot)
- [x] **[AI]** Enemies **path around walls** (grid pathfinding); if completely walled off they smash the nearest wall
- [x] **[AI]** While you **operate a tower you can't be hurt** — enemies attack the tower instead; if it's destroyed you're thrown out and the wreckage clears after 4s (walls stay up)
- [x] **[AI]** F at a tower: **Repair** tower + walls (1 Scrap per 25 missing health, rebuilds destroyed pieces) or **Sell** for **50%** back (removes its walls)
- [x] **[You]** Decide: sell for 50% of the cost
- [ ] **[Both]** Play it — do the walls funnel enemies well? Is repair too cheap/expensive?
- [ ] **[You]** Art wish: a proper wall piece for walls running up/down the screen (currently a row of pillars cut from the across-the-screen wall)

**Done when:** building a tower shapes where enemies can walk, and keeping walls repaired matters.

---

## Phase 7 — Waves

- [x] **[AI]** Wave system: countdown → wave → break → next wave (5 waves; clear them all to win)
- [x] **[AI]** 4 sectors (North/East/South/West); waves pick which sides attack (W → W+N → E+S → 3 sides → all 4)
- [x] **[AI]** Warning arrows at the screen edge: amber = where the next wave comes from, red = attacking now
- [x] **[AI]** Scrap heaps out in the world each break (E to salvage; farther from the Core = more Scrap; max 8 on the map)
- [x] **[AI]** A few waves that get harder (6 → 10 → 14 → 18 → 28 goblins, arriving faster)
- [x] **[AI]** Bigger map: 40×26 tiles with the Core in the middle
- [x] **[AI]** [Enter] starts the next wave early

The waves live in `scenes/waves/first_run.tscn`: edit them in Godot's scene tree (Wave nodes → SpawnGroup nodes: break length, and per group: enemy, count, side, spacing, delay).

### 🎯 FIRST PLAYTEST MILESTONE

You can: leave the Core → kill goblins → carry Scrap home → build a Gearshot (with its walls) → operate the turret → survive 5 escalating waves → win, or lose when the Core dies.

- [ ] **[You]** Play 5+ runs. Write down what's fun, boring, confusing.
- [ ] **[Both]** Tune numbers (damage, costs, wave size) until it feels good

**Don't move on until this is fun.** Everything after this is adding content.

---

## Phase 8 — More stuff to build

Order: 1) slots + Aether ✅ 2) levels ✅ 3) Mortar ✅ 4) Embercaster ✅ 5) Spire ✅. Each step: design → build → playtest.

- [x] **[AI]** Aether (2nd resource: rare, found far from base): crystals 800+ px from the Core each break (1–2, max 3, 2–4 Aether each) + 5% goblin drop
- [x] **[AI]** Tower levels 1 → 2 → 3: upgrade in the F menu (Gearshot Lv2 15 Scrap, Lv3 25 Scrap + 3 Aether); ×1.3 damage, ×1.15 fire rate, ×1.1 range, ×1.4 health per level; walls level up too (120/180/260)
- [x] **[AI]** Rune Mortar (long-range splash): 15 Scrap (Lv2 20, Lv3 30 + 3 Aether); shells the biggest clump and leads it, can't hit inside 110 px; operated = shells land on the mouse; Q = Rune Shell (2× blast + 4 s slowing circle)
- [x] **[AI]** Embercaster (short-range flamethrower + burn): 12 Scrap (Lv2 18, Lv3 28 + 3 Aether); 50° cone, 150 px; fuel tank 4 s / 3 s refill, locks out until 40% when dry; burn stacks to 5 × 2/s for 3 s; aims where it hits the most goblins; operated = cone at the mouse; Q = Overpressure (3 s free fuel, bigger cone, max burn)
- [x] **[AI]** Aether Spire (chain lightning): 14 Scrap (Lv2 20, Lv3 30 + 3 Aether); 10 damage, 0.8/s, 280 range; up to 4 jumps within 120 px, 20% less each jump; nearest goblin first; operated = goblin nearest the mouse; Q = Resonance Burst (2×, 8 jumps, no falloff, 1 s stun)
- [x] **[AI]** Expand to 12–16 build slots: a ring of 12 (3 per side); 4 open, 8 unlock for 6 Scrap; walls join into one line per side, corners stay open
- [ ] **[Both]** Playtest after each new tower

---

## Phase 9 — More enemies

- [x] **[AI]** Armored Goblin (resists bullets → need magic) (`goblin_brute` art): takes 30% physical / 60% fire / 100% magic; 60 health, speed 55, 8 per swing; 3–4 Scrap + 10% Aether; waves 3–5. Damage types: Gearshot + hero = physical, Embercaster = fire, Mortar + Spire = magic. Waves are now edited as a node tree in `scenes/waves/first_run.tscn`.
- [ ] **[AI]** Goblin Shaman (buffs nearby goblins)
- [ ] **[AI]** Ogre (smashes walls) — *needs art*
- [ ] **[AI]** Bat (flies over walls) — *needs art*
- [ ] **[You]** Decide: how do flying enemies look/work in top-down?
- [ ] **[You]** Pick the elite enemy and what the final boss tests
- [ ] **[You]** Make art for the elite and boss

---

## Phase 10 — A full run

- [ ] **[AI]** Artificer abilities: passive, **Overclock** (boost your tower), **Full Steam** ultimate (share it with all towers)
- [x] **[AI]** Hero upgrades at the Core (F): Damage, Fire rate, Max health (+20%/rank), Move speed (+8%/rank); 5 ranks costing 12 / 20 / 30 + 1 Aether / 40 + 2 / 55 + 3, from the same stored pool as towers (data in `data/hero_upgrades/`)
- [ ] **[AI]** Player XP earned during a run — **[You]** decide how it's earned (kills, damage, waves survived)
- [ ] **[AI]** Power-up cards: after waves, pick 1 of 3 cards that make you stronger for the run (chain-lightning shots, flamethrower, and similar)
- [ ] **[AI]** One evolution per tower (e.g. Gearshot → Gatling Engine or Rune Cannon) — needs a new unlock now Mastery is gone (e.g. a card or Aether)
- [ ] **[AI]** 10 waves, a mini-boss around wave 6, final boss
- [ ] **[AI]** Win screen
- [ ] **[You]** Is a run 12–15 minutes? Do different runs feel different?

**Done when:** a complete run from start to boss is playable. **This is the MVP.** 🎉

---

## Phase 11 — Polish (after the MVP works)

- [ ] **[You]** Sound effects + music (put them in `sound/`)
- [ ] **[AI]** Hook up sounds
- [ ] **[AI]** Main menu, hero select screen, pause menu, settings
- [ ] **[AI]** Controller support
- [ ] **[Both]** Juice: screen shake, hit flashes, particles

---

## What each art file is

My best guess from looking at them. Names marked **(placeholder)** are the ones I wasn't sure about. **[You]** please correct.

| Source file | Sliced as | Animations | Phase |
|---|---|---|---|
| `Fantasy RPG Terrain Tileset Atlas.png` | `assets/tilesets/` (already in project) | — | 0 |
| `image-gen-2.png` | `artificer` — **Artificer hero** | idle, walk, attack, build, death | 1 |
| `image-gen-1(1).png` | `engineer` (placeholder) — white-haired engineer, second hero? | idle, walk, attack, death | later |
| `image-gen-2(1).png` | `goblin` — **Goblin** (red hood) | idle, walk, attack, death | 2 |
| `image-gen-3.png` | `fortress/*.png` — Core ×3, slots ×3, walls ×6, Scrap ×4, Aether ×4 | single images | 2–4 |
| `image-gen-4.png` | `gearshot` — **Gearshot Turret** | lv1–3: idle, fire, destroyed | 4 |
| `image-gen-3(1).png` | `blaster_turret` (placeholder) — small blue blaster | idle, fire, damaged, destroy | ? |
| `image-gen-5.png` | `rune_mortar` — **Rune Mortar** | lv1–3: idle, fire, destroyed | 8 |
| `image-gen-6.png` | `embercaster` — **Embercaster** | lv1–3: idle, fire; destroyed | 8 |
| `image-gen-7.png` | `aether_spire` — **Aether Spire** | lv1–3: idle, fire; destroyed | 8 |
| `image-gen-8.png` | `aether_harvester` (placeholder) — swirling crystal tower | lv1–3: idle, pulse; destroyed | 8 |
| `image-gen-9.png` | `goblin_brute` — **Armored Goblin** (brown goblin with cleaver) | idle, walk, attack, hurt, death | 9 |
| `image-gen-10.png` | `goblin_shaman` — **Goblin Shaman** | idle, walk, cast, projectile, recover, buff, death | 9 |

### Art still needed ([You])

- Ogre, Bat, Siege Troll, Burrower, Saboteur (if `image-gen-9` isn't it)
- Elite enemy, final boss
- Bullets / projectiles / hit effects (Claude can do simple placeholders)
- HUD icons (Scrap, Aether, health, sector warnings)

**Art rule:** every sprite sheet should use the **same frame size on an even grid** (e.g. 256×256 per frame, frames in straight rows). That makes the slicing step automatic.

---

## NOT doing (for now)

Multiple maps · multiplayer · procedural worlds · big meta-progression · more than one hero · isometric view · fancy pathfinding. Only after the MVP is fun.
