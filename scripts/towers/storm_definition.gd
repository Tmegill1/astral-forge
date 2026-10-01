class_name StormDefinition
extends SpireDefinition
## A Storm Array's extra settings (an evolved Aether Spire): stunning bolts,
## and the Thunderstorm ability. Its jump_count and jump_falloff are set in
## its data file (8 jumps, no falloff).

@export_group("Storm")
## Every this-many-th bolt stuns everything it hits...
@export var stun_every := 5
## ...for this many seconds.
@export var stun_time := 0.5

@export_group("Thunderstorm")
## Seconds between strikes while the storm lasts (ability_duration).
@export var storm_interval := 0.25
## Jumps from each strike's target.
@export var storm_jumps := 2
@export var storm_stun := 0.5
