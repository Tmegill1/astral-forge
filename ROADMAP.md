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
- [ ] **[You]** Look over the sprite preview and the "What each art file is" table below; fix anything I guessed wrong (rename = change the name in `SHEETS` in `tools/slice_sprites.py` and re-run it)

Known small glitches (fine for placeholders): Mortar/Spire/Embercaster fire frames that shoot past the frame edge get their shell/bolt/flame clipped. Projectiles will be separate sprites later anyway.

**Done when:** every character/tower has clean animation frames in the project.

---

## Phase 1 — Hero walks around

- [x] **[AI]** Artificer hero: move with WASD, camera follows
- [x] **[AI]** Idle / walk / death animations hooked up
- [x] **[AI]** Hero health + a basic attack (auto-fires bolts toward the mouse)
- [x] **[AI]** An "Interact" button (E) — used later for towers, building, depositing
- [x] **[You]** Decide: aim with the **mouse**, shooting is **automatic** for now (`auto_fire` on the Hero can be turned off → hold left click to shoot)
- [x] **[Both]** Play it — does moving feel good? (hero shrunk 30%, faces the way it walks, HUD + health bars added)

**How heroes work:** every hero shares `scripts/heroes/hero.gd`. Baseline stats are the defaults in `scripts/heroes/hero_stats.gd`. Each hero is a data file in `data/heroes/` (art, size, and stat multipliers, e.g. Artificer = 0.9× health). `Game.selected_hero` picks who spawns; a hero-select screen will set it later. New hero = new `.tres` file, no code.

**Done when:** you can walk around the map and swing/shoot at nothing.

---

## Phase 2 — The Core and one Goblin

- [x] **[AI]** Command Core in the middle of the map, with health (looks more broken at 66% and 33%)
- [x] **[AI]** Goblin walks toward the Core and attacks it (turns on the hero if you get close)
- [x] **[AI]** Hero can kill goblins
- [x] **[AI]** Core reaches 0 → "You Lose" screen (Restart button or R)
- [x] **[AI]** Placeholder: a fallen hero gets back up at the Core after 5 seconds
- [ ] **[Both]** Play it — are goblins too fast/slow/tough? Is the Core too weak?
- [x] **[AI]** Enemy hitboxes cover the whole visible sprite +25% (`hurtbox_padding` per enemy), so shots aimed at the body land
- [x] **[You]** Decide: the hero starts at **1 shot per second**; upgrades raise it later (Phase 10)

**How enemies work:** same idea as heroes. Every enemy shares `scripts/enemies/enemy.gd`; each type is a data file in `data/enemies/` with its art and stats (Goblin: 30 HP, speed 70, hits for 5 once a second). For now a test spawner (the `EnemySpawner` node in the world scene) drops goblins at the map edge, a bit faster each time; Phase 7 replaces it with real waves.

**Done when:** goblins spawn, you fight them, and you can lose.

---

## Phase 3 — Pick up Scrap, bring it home

- [ ] **[AI]** Goblins drop Scrap (gear pickups)
- [ ] **[AI]** Scrap you're holding = **carried**; drop it at the Core = **stored** (only stored can be spent)
- [ ] **[AI]** Simple HUD: Core health, hero health, carried vs. stored Scrap
- [ ] **[You]** Decide: what happens to carried Scrap if the hero goes down? (lose all / lose half / keep)

**Done when:** you can kill, collect, walk home, and see your bank go up.

---

## Phase 4 — Build a tower

- [ ] **[AI]** Build slots around the Core (start with 1–2, not 16)
- [ ] **[AI]** Stand on a slot + press E → spend Scrap → Gearshot Turret appears
- [ ] **[AI]** Gearshot automatically aims and shoots at goblins
- [ ] **[Both]** Play it — is the turret too strong or too weak?

**Done when:** you can buy a turret and watch it defend on its own.

---

## Phase 5 — Operate the tower ⭐ the signature mechanic

- [ ] **[AI]** Press E at a tower → hero takes control; press E again → leave (instant)
- [ ] **[AI]** While controlled: aim with the mouse, **+35% damage, +50% fire rate**
- [ ] **[AI]** One tower active ability (e.g. burst fire)
- [ ] **[AI]** Tower earns Mastery XP while you operate it
- [ ] **[AI]** Clear "you are controlling this" visuals
- [ ] **[You]** The big question: **is operating a tower fun?** Would you choose to do it?

**Done when:** jumping into the turret feels noticeably better than leaving it on auto.

---

## Phase 6 — Walls vs. towers

- [ ] **[AI]** Same slot can be a **wall** instead of a tower
- [ ] **[AI]** Goblins attack walls that block them
- [ ] **[AI]** Repair damaged walls/towers with Scrap
- [ ] **[You]** Decide: can you sell/replace a structure? For how much back?

**Done when:** "wall or turret here?" is a real choice.

---

## Phase 7 — Waves

- [ ] **[AI]** Wave system: countdown → wave → break → next wave
- [ ] **[AI]** 4 sectors (North/East/South/West); waves pick which sides attack
- [ ] **[AI]** Warning arrows showing where the next attack comes from
- [ ] **[AI]** Scrap piles out in the world to scavenge between waves
- [ ] **[AI]** A few waves that get harder

### 🎯 FIRST PLAYTEST MILESTONE

You can: leave the Core → kill goblins → carry Scrap home → choose wall or Gearshot → operate the turret → survive a few waves → lose when the Core dies.

- [ ] **[You]** Play 5+ runs. Write down what's fun, boring, confusing.
- [ ] **[Both]** Tune numbers (damage, costs, wave size) until it feels good

**Don't move on until this is fun.** Everything after this is adding content.

---

## Phase 8 — More stuff to build

- [ ] **[AI]** Aether (2nd resource: rare, found far from base)
- [ ] **[AI]** Tower levels 1 → 2 → 3 (the art already has 3 levels per tower)
- [ ] **[AI]** Rune Mortar (long-range splash)
- [ ] **[AI]** Embercaster (short-range flamethrower + burn)
- [ ] **[AI]** Aether Spire (chain lightning)
- [ ] **[AI]** Aether Harvester (pulls Scrap toward it; Lv3 auto-deposits)
- [ ] **[AI]** Expand to 12–16 build slots
- [ ] **[You]** Decide: is Mastery per-tower or per-tower-type?
- [ ] **[Both]** Playtest after each new tower

---

## Phase 9 — More enemies

- [ ] **[AI]** Armored Goblin (resists bullets → need magic)
- [ ] **[AI]** Goblin Shaman (buffs nearby goblins)
- [ ] **[AI]** Ogre (smashes walls) — *needs art*
- [ ] **[AI]** Bat (flies over walls) — *needs art*
- [ ] **[You]** Decide: how do flying enemies look/work in top-down?
- [ ] **[You]** Pick the elite enemy and what the final boss tests
- [ ] **[You]** Make art for the elite and boss

---

## Phase 10 — A full run

- [ ] **[AI]** Artificer abilities: passive, **Overclock** (boost your tower), **Full Steam** ultimate (share it with all towers)
- [ ] **[AI]** Upgrade choices after waves (pick 1 of 3) — include fire-rate upgrades (hero starts at 1 shot/sec)
- [ ] **[AI]** One evolution per tower (e.g. Gearshot → Gatling Engine or Rune Cannon)
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
| `image-gen-9.png` | `goblin_brute` (placeholder) — brown goblin with blade: Armored Goblin? Saboteur? | idle, walk, attack, hurt, death | 9 |
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
