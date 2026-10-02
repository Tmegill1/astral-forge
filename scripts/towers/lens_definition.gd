class_name LensDefinition
extends SpireDefinition
## A Focus Lens's extra settings (an evolved Aether Spire): a ramping beam on
## one target instead of chain lightning, and the Overload ability.

@export_group("Beam")
## Beam damage ticks per second.
@export var tick_rate := 10.0
## Seconds on the same target to reach full ramp.
@export var ramp_time := 3.0
## Damage multiplier at full ramp (1 at the start).
@export var max_ramp := 5.0
@export var beam_color := Color(1.0, 0.95, 0.75)
## Where the beam leaves from (the lens), relative to the base point, facing
## right; the tower mirrors to face left.
@export var lens_offset := Vector2(55, -110)

@export_group("Overload")
## Extra multiplier on top of full ramp while Overload lasts (ability_duration).
@export var overload_multiplier := 1.5


## Damage multiplier at `ramp` (0..1).
func ramp_multiplier(ramp: float) -> float:
	return 1.0 + (max_ramp - 1.0) * clampf(ramp, 0.0, 1.0)
