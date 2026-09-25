class_name MortarDefinition
extends TowerDefinition
## A Rune Mortar's extra settings: lobbed splash shells that can't hit up
## close, and the Rune Shell ability.

@export_group("Mortar")
## Damage reaches every enemy within this of the impact point, in pixels.
@export var splash_radius := 70.0
## Targets closer than this can't be shelled, in pixels.
@export var min_range := 110.0
## Seconds a shell is in the air.
@export var shell_flight_time := 0.9
## How high the shell's arc peaks, in pixels.
@export var shell_arc_height := 90.0
## Splash radius multiplier while operated.
@export var operated_splash_multiplier := 1.25
## Where shells leave from, relative to the base point, facing right.
@export var muzzle_offset := Vector2(8, -88)

@export_group("Rune Shell")
@export var rune_damage_multiplier := 2.0
@export var rune_radius_multiplier := 2.0
## Share of speed taken away inside the rune circle (0.4 = 40% slower).
@export var rune_slow := 0.4
## Seconds the rune circle lasts.
@export var rune_duration := 4.0
