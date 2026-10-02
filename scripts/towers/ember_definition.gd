class_name EmberDefinition
extends TowerDefinition
## An Embercaster's extra settings: a short flame cone that sets enemies
## burning, fed by a fuel tank, and the Overpressure ability.

@export_group("Flame")
## Full width of the flame cone, in degrees.
@export var cone_angle := 50.0
## Where the flame leaves from, relative to the base point, facing right.
@export var muzzle_offset := Vector2(44, -50)
## Multiplies how far the flame reaches (the Inferno's longer cone).
@export var cone_length_multiplier := 1.0
## Show the first fire frame while spraying. Off for art whose painted flame
## only points one way: the drawn cone is the flame.
@export var fire_frame_while_spraying := true

@export_group("Fuel")
## Seconds of spraying a full tank holds.
@export var fuel_seconds := 4.0
## Seconds to refill from empty while not spraying.
@export var refill_seconds := 3.0
## After running dry it can't spray until the tank is back to this share.
@export var restart_fraction := 0.4

@export_group("Burn")
## Damage per second of each burn stack at Lv1 (scales like the flame).
@export var burn_dps_per_stack := 2.0
@export var burn_max_stacks := 5
## All stacks drop off this many seconds after the last one was added.
@export var burn_duration := 3.0

@export_group("Overpressure")
@export var overpressure_angle_multiplier := 1.5
@export var overpressure_range_multiplier := 1.3
