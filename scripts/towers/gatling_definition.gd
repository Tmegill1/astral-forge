class_name GatlingDefinition
extends TowerDefinition
## A Gatling Engine's extra settings (an evolved Gearshot): it spins up while
## it keeps firing, each shot weaker than a Gearshot's.

@export_group("Spin")
## Seconds of continuous firing to reach full spin.
@export var spin_up_time := 2.0
## Seconds to wind down from full spin once it stops firing.
@export var spin_down_time := 1.0
## Fire rate multiplier at full spin (1 when still).
@export var max_spin_multiplier := 4.0
## Share of the Gearshot's damage each shot deals.
@export var shot_damage_multiplier := 0.65
## Where shots leave from, relative to the base point, facing right.
@export var muzzle_offset := Vector2(50, -55)


## Spin (0..1) after `delta` more seconds of firing or not firing.
func spin_after(spin: float, delta: float, firing: bool) -> float:
	if firing:
		return minf(spin + delta / spin_up_time, 1.0)
	return maxf(spin - delta / spin_down_time, 0.0)


## Fire rate multiplier at `spin`.
func spin_multiplier(spin: float) -> float:
	return 1.0 + (max_spin_multiplier - 1.0) * spin
