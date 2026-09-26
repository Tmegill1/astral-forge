class_name SpireDefinition
extends TowerDefinition
## An Aether Spire's extra settings: lightning that jumps between enemies,
## and the Resonance Burst ability.

@export_group("Chain")
## Jumps after the first target.
@export var jump_count := 4
## A jump reaches the nearest enemy not yet hit within this of the last one,
## in pixels.
@export var jump_range := 120.0
## Each jump deals this share less than the one before (0.2 = 20% less).
@export var jump_falloff := 0.2
## How high above the base point bolts leave from (the crystal tip), per
## level (index 0 = Lv1), in on-screen pixels.
@export var bolt_heights: PackedFloat32Array = [90.0, 100.0, 125.0]

@export_group("Resonance Burst")
@export var burst_damage_multiplier := 2.0
@export var burst_jump_count := 8
## Seconds each enemy hit is stunned.
@export var burst_stun := 1.0
