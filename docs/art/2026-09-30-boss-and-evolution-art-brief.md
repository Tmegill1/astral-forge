ASTRAL FORGE — ART BRIEF + IMAGE PROMPTS
Bosses (Phase 10 run) and tower evolutions (next feature)
Written 2026-09-30. A copy lives in the repo: docs/art/2026-09-30-boss-and-evolution-art-brief.md

=====================================================================
HOW TO USE THIS
=====================================================================
- Make one sprite SHEET per section below with your image generator.
- Every time, ATTACH the reference sheet named in that section (from
  ~/Desktop/Astral forge assests/) so the new art matches the existing style.
- Paste the PROMPT text exactly; it already describes the layout.
- Save the result as a PNG with a transparent background and the file name
  given, into ~/Desktop/Astral forge assests/. Tell Claude when it's there;
  Claude slices it, lines up the frames and swaps out the placeholder.
- If one row comes out wrong, regenerate just that row with the "single row"
  prompt at the end of the section and the same reference attached.

=====================================================================
RULES FOR EVERY SHEET (already inside each prompt)
=====================================================================
- Same art style as the attached reference: painted, chunky, readable
  steampunk-fantasy, warm rim light, thick dark outlines, bright accents.
- Camera: three-quarter top-down view (like the reference), character facing
  RIGHT. Left-facing is mirrored in the game.
- Transparent background. No shadows on the ground, no text, no borders,
  no grid lines, no frame numbers.
- One animation per ROW, frames left to right, with clear empty space
  between frames (frames must not touch or overlap — effects included).
- Every frame of a row shows the same character at the same size, with the
  FEET ON THE SAME BASELINE (the bottom of the feet lines up across frames).
- Poses within a row must be clearly different (big readable motion);
  frames that look identical are wasted.
- Wide sheet, roughly 16:9 or 4:3. Big characters: each frame about
  300–450 px tall.

=====================================================================
1) GOBLIN WARCHIEF — mini-boss (wave 6)
   File: goblin_warchief.png      Reference to attach: image-gen-9.png
   (the Armored Goblin with the cleaver)
=====================================================================
Who: the Armored Goblins' leader. About 1.8× their size: a hulking goblin
in heavy riveted plate and a spiked pauldron, a tattered red war-banner on
his back, a huge two-handed steam-powered cleaver with glowing orange
vents, a horned helmet, glowing amber eyes. Brutal, readable silhouette.

Rows (top to bottom):
  Row 1  idle      4 frames  breathing, cleaver resting on shoulder, steam puffs
  Row 2  walk      8 frames  heavy stomping walk cycle, cleaver held low
  Row 3  attack    6 frames  overhead smash: raise (1-2), peak (3), slam down
                             with a ground crack and sparks (4 = impact),
                             recover (5-6)
  Row 4  war_cry   6 frames  plants feet, throws head back and roars, fists
                             and cleaver raised; a red shockwave ring grows
                             around him (frames 3-5), settles (6)
  Row 5  hurt      4 frames  staggers back from a hit, armour sparks
  Row 6  death     8 frames  drops to one knee, cleaver falls, collapses
                             face down, banner drapes over him (last frame
                             is the corpse at rest)

PROMPT (paste this):
"Using the attached sprite sheet as the exact art style reference, create a
new sprite sheet for a boss enemy: the Goblin Warchief, leader of the
armored goblins, about 1.8 times their size. A hulking goblin in heavy
riveted iron plate with a spiked pauldron, a horned helmet, glowing amber
eyes, a tattered red war-banner on a pole strapped to his back, and a huge
two-handed steam-powered cleaver with glowing orange vents. Three-quarter
top-down view, facing right, painted steampunk-fantasy style matching the
reference, thick dark outlines, warm rim light. Transparent background, no
ground shadow, no text, no borders. Lay out one animation per row with clear
empty space between frames, feet on the same baseline in every frame, same
size in every frame:
Row 1 (4 frames): idle, breathing, cleaver resting on his shoulder, small
steam puffs from the cleaver.
Row 2 (8 frames): heavy stomping walk cycle, cleaver held low.
Row 3 (6 frames): overhead smash attack — raising the cleaver, peak,
slamming it into the ground with a crack and sparks on frame 4, then
recovering.
Row 4 (6 frames): war cry — planting his feet and roaring with fists and
cleaver raised, a red shockwave ring expanding around him in frames 3 to 5.
Row 5 (4 frames): hurt — staggering back from a hit, sparks off the armour.
Row 6 (8 frames): death — dropping to one knee, the cleaver falling,
collapsing face down, the banner draping over him; the last frame is the
body at rest.
Poses in each row must be clearly different and readable at small size."

=====================================================================
2) GOBLIN SHAMAN-KING — final boss (wave 10)
   File: goblin_shaman_king.png   Reference to attach: image-gen-10.png
   (the Goblin Shaman)
=====================================================================
Who: the Shamans' master. About 2.2× a Shaman. An old, gaunt goblin in
layered crimson and purple robes covered in glowing runes, a crown of
floating violet crystals over his hood, a tall twisted staff topped with a
huge purple Aether crystal, two smaller crystals orbiting him. He FLOATS a
little above the ground (draw a faint rune circle under him in every frame
as his "feet" line).

Rows (top to bottom):
  Row 1  idle         4 frames  hovering, robes sway, crystals orbit
  Row 2  walk         8 frames  drifting forward while floating, robe trailing
  Row 3  cast         6 frames  sweeps the staff forward and releases a FAN of
                                purple orbs (release on frame 4), recover (5-6)
  Row 3b projectile   2 frames  at the END of row 3, after a gap: the purple
                                orb he throws, flying right, with a short
                                sparkling trail (2 frames of shimmer)
  Row 4  summon       6 frames  slams the staff down; a glowing green rune
                                portal opens in front of him (frames 3-5)
  Row 5  buff         4 frames  raises the staff overhead; a purple pulse ring
                                bursts outward (his frenzy pulse)
  Row 6  phase_shift  6 frames  enraged: crystals flare, a translucent purple
                                shield bubble forms around him (3-6)
  Row 7  death        8 frames  the crown crystals shatter, he sinks to the
                                ground, robes collapse, staff crystal goes dark

PROMPT (paste this):
"Using the attached sprite sheet as the exact art style reference, create a
new sprite sheet for the final boss: the Goblin Shaman-King, master of the
goblin shamans, about 2.2 times their size. An old, gaunt goblin in layered
crimson and purple robes covered in glowing runes, a crown of floating violet
crystals above his hood, a tall twisted staff topped with a large glowing
purple crystal, and two small crystals orbiting him. He floats slightly above
the ground with a faint glowing rune circle beneath him in every frame.
Three-quarter top-down view, facing right, painted steampunk-fantasy style
matching the reference, thick dark outlines, glowing purple and blue magic.
Transparent background, no ground shadow, no text, no borders. One animation
per row with clear empty space between frames, the rune circle at the same
baseline in every frame, same size in every frame:
Row 1 (4 frames): idle, hovering, robes swaying, crystals orbiting.
Row 2 (8 frames): drifting forward while floating, robe trailing behind.
Row 3 (6 frames): casting — sweeping the staff forward and releasing a fan of
five purple magic orbs on frame 4, then recovering. After a gap at the end of
this row, add 2 frames of just the purple orb projectile flying right with a
short sparkling trail.
Row 4 (6 frames): summoning — slamming the staff down while a glowing green
rune portal opens in front of him.
Row 5 (4 frames): raising the staff overhead as a purple pulse ring bursts
outward.
Row 6 (6 frames): enraged phase change — the crystals flare and a
translucent purple shield bubble forms around him.
Row 7 (8 frames): death — the crown crystals shatter, he sinks to the ground,
the robes collapse and the staff crystal goes dark; the last frame is the
body at rest.
Poses in each row must be clearly different and readable at small size."

=====================================================================
3) (OPTIONAL) BOSS PORTRAITS for the boss health bar
   File: boss_portraits.png       Reference to attach: image-gen-9.png and
   image-gen-10.png
=====================================================================
Two square head-and-shoulders portraits side by side, ~256×256 each, same
style, transparent background: the Goblin Warchief (horned helmet, red
banner behind) and the Goblin Shaman-King (crystal crown, purple glow).
The bar works without these (name text only).

PROMPT:
"Using the attached sprite sheets as the art style reference, draw two square
head-and-shoulders portraits side by side on a transparent background, with
space between them: left, the Goblin Warchief — a scarred armored goblin in a
horned iron helmet with glowing amber eyes and a tattered red banner behind
him; right, the Goblin Shaman-King — an old goblin with a crown of floating
violet crystals and a purple magical glow. Painted steampunk-fantasy style,
thick dark outlines, no text, no borders."

=====================================================================
4) TOWER EVOLUTIONS — for the next feature (8 towers, 4 sheets)
=====================================================================
Each evolution is a single-level tower. One sheet per base tower, holding
its TWO evolutions:
  Row 1  <branch A> idle       4 frames
  Row 2  <branch A> fire       4 frames  (the shot / effect leaving the muzzle)
  Row 3  <branch A> destroyed  2 frames  (wrecked, smoking)
  Row 4  <branch B> idle       4 frames
  Row 5  <branch B> fire       4 frames
  Row 6  <branch B> destroyed  2 frames
Draw each tower on the SAME stone-and-brass base as its Level 3 version in
the reference, facing right, a bit grander than Level 3 (it's the top tier).
For the Gearshot pair, keep the gun barrel pointing straight right in idle
frames (the game rotates the turret head).
Gatling Engine and Storm Array can also fall back on the existing
blaster_turret / aether_harvester art if these don't come out well.

4a) GEARSHOT EVOLUTIONS — File: gearshot_evolutions.png — Reference: image-gen-4.png
    Branch A: GATLING ENGINE — six-barrel rotary brass gatling on the turret
      base, ammo belt, steam vents; fire = barrels spinning with a stream of
      muzzle flashes.
    Branch B: RUNE CANNON — a single heavy bronze cannon etched with glowing
      blue runes; fire = a large glowing blue rune shell leaving the muzzle
      with a ring of magic.
PROMPT:
"Using the attached sprite sheet as the exact art style reference, create a
sprite sheet with two top-tier upgrades of this turret, on the same stone and
brass base as its level 3 version, three-quarter top-down view, facing
right, transparent background, no text, no borders, clear space between
frames, base on the same baseline in every frame. Rows 1–3: the Gatling
Engine — a six-barrel rotary brass gatling gun with an ammo belt and steam
vents; row 1 idle (4 frames, gun pointing straight right), row 2 firing (4
frames, barrels spinning, stream of muzzle flashes), row 3 destroyed (2
frames, wrecked and smoking). Rows 4–6: the Rune Cannon — one heavy bronze
cannon etched with glowing blue runes; row 4 idle (4 frames, pointing
straight right), row 5 firing (4 frames, a glowing blue rune shell leaving
the muzzle with a magic ring), row 6 destroyed (2 frames). Painted
steampunk-fantasy style, readable at small size."

4b) RUNE MORTAR EVOLUTIONS — File: rune_mortar_evolutions.png — Reference: image-gen-5.png
    Branch A: SIEGE BATTERY — three mortar tubes on a rotating carriage;
      fire = the three tubes firing in sequence.
    Branch B: FROST RUNE MORTAR — mortar wrapped in frosted blue runes and
      ice crystals; fire = a pale blue glowing shell with frost mist.
PROMPT:
"Using the attached sprite sheet as the exact art style reference, create a
sprite sheet with two top-tier upgrades of this mortar tower, on the same
stone base as its level 3 version, three-quarter top-down view, facing right,
transparent background, no text, no borders, clear space between frames, base
on the same baseline in every frame. Rows 1–3: the Siege Battery — three
mortar tubes on a rotating iron carriage; row 1 idle (4 frames), row 2
firing (4 frames, the three tubes firing in sequence with smoke), row 3
destroyed (2 frames). Rows 4–6: the Frost Rune Mortar — a mortar wrapped in
frosted blue runes and ice crystals; row 4 idle (4 frames), row 5 firing (4
frames, a pale blue glowing shell with frost mist), row 6 destroyed (2
frames). Painted steampunk-fantasy style, readable at small size."

4c) EMBERCASTER EVOLUTIONS — File: embercaster_evolutions.png — Reference: image-gen-6.png
    Branch A: INFERNO — larger brass flame projector with twin fuel tanks
      and a red-hot nozzle; fire = a long roaring cone of flame.
    Branch B: OIL SPRAYER — pump-driven sprayer with a black oil drum;
      fire = a dark oil spray with a few sparks igniting at the tip.
PROMPT:
"Using the attached sprite sheet as the exact art style reference, create a
sprite sheet with two top-tier upgrades of this flamethrower tower, on the
same base as its level 3 version, three-quarter top-down view, facing right,
transparent background, no text, no borders, clear space between frames, base
on the same baseline in every frame. Rows 1–3: the Inferno — a larger brass
flame projector with twin fuel tanks and a red-hot nozzle; row 1 idle (4
frames), row 2 firing (4 frames, a long roaring cone of flame to the right),
row 3 destroyed (2 frames). Rows 4–6: the Oil Sprayer — a pump-driven sprayer
with a black oil drum; row 4 idle (4 frames), row 5 firing (4 frames, a dark
glossy oil spray to the right with sparks igniting at the tip), row 6
destroyed (2 frames). Painted steampunk-fantasy style, readable at small
size."

4d) AETHER SPIRE EVOLUTIONS — File: aether_spire_evolutions.png — Reference: image-gen-7.png
    Branch A: STORM ARRAY — three crystal prongs crackling with arcs between
      them; fire = forked lightning bursting outward.
    Branch B: FOCUS LENS — a single huge crystal held in brass rings with a
      lens in front; fire = a thick steady beam to the right.
PROMPT:
"Using the attached sprite sheet as the exact art style reference, create a
sprite sheet with two top-tier upgrades of this crystal lightning tower, on
the same base as its level 3 version, three-quarter top-down view, facing
right, transparent background, no text, no borders, clear space between
frames, base on the same baseline in every frame. Rows 1–3: the Storm Array —
three tall crystal prongs with lightning arcing between them; row 1 idle (4
frames), row 2 firing (4 frames, forked lightning bursting outward), row 3
destroyed (2 frames). Rows 4–6: the Focus Lens — one huge crystal held in
brass rings with a glass lens in front; row 4 idle (4 frames), row 5 firing
(4 frames, a thick steady blue-white beam to the right), row 6 destroyed (2
frames). Painted steampunk-fantasy style, readable at small size."

=====================================================================
SINGLE-ROW FIX PROMPT (any sheet)
=====================================================================
"Using the attached sprite sheet as the exact style and character
reference, redraw only the <ANIMATION NAME> animation as one horizontal row
of <N> frames: <describe the motion>. Same character, same size, same
three-quarter top-down view facing right, feet (or base) on the same baseline
in every frame, transparent background, clear space between frames, no
text, no borders. Poses clearly different from frame to frame."

=====================================================================
CHECKLIST — everything the new content needs
=====================================================================
Needed for the 10-wave run (placeholders work until these exist):
  [ ] goblin_warchief.png      idle 4, walk 8, attack 6, war_cry 6, hurt 4, death 8
  [ ] goblin_shaman_king.png   idle 4, walk 8, cast 6 + projectile 2, summon 6,
                               buff 4, phase_shift 6, death 8
  [ ] boss_portraits.png       (optional) 2 portraits
Not needed as art (drawn in code): wave banners, boss health bar, the
Shaman-King's shield bubble, auras, the war-cry and pulse rings.

Needed for tower evolutions (next feature):
  [ ] gearshot_evolutions.png      Gatling Engine + Rune Cannon
  [ ] rune_mortar_evolutions.png   Siege Battery + Frost Rune Mortar
  [ ] embercaster_evolutions.png   Inferno + Oil Sprayer
  [ ] aether_spire_evolutions.png  Storm Array + Focus Lens
  (each: idle 4, fire 4, destroyed 2, per branch)
