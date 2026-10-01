class_name OilDefinition
extends EmberDefinition
## An Oil Sprayer's extra settings (an evolved Embercaster): a weaker flame
## that oils enemies, and the Ignite ability.

@export_group("Oil")
## Share of the Embercaster's flame (and burn) damage it deals.
@export var flame_damage_multiplier := 0.5
## Seconds oil lasts after the last hit.
@export var oil_seconds := 4.0
## Share of speed taken away while oiled.
@export var oil_slow := 0.3
## Extra fire damage an oiled enemy takes (0.5 = +50%).
@export var oil_fire_bonus := 0.5

@export_group("Ignite")
## Ignite's fire burst, as a multiple of the flame's damage.
@export var ignite_damage_multiplier := 3.0
