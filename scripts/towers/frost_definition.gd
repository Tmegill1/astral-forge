class_name FrostDefinition
extends MortarDefinition
## A Frost Rune Mortar's extra settings (an evolved Rune Mortar): every shell
## leaves a frost circle and freezes what it lands on; Glacial Shell ability.

@export_group("Frost")
## Share of the Mortar's damage each shell deals.
@export var damage_multiplier := 0.8
## Share of speed taken away inside a frost circle (0.6 = 60% slower).
@export var frost_slow := 0.6
## Seconds a frost circle lasts.
@export var frost_duration := 6.0
## Enemies this close to the impact are frozen, in pixels...
@export var freeze_radius := 30.0
## ...for this many seconds.
@export var freeze_time := 0.6
@export var frost_color := Color(0.65, 0.9, 1.0)

@export_group("Glacial Shell")
@export var glacial_radius_multiplier := 2.0
## Seconds everything in a Glacial Shell's blast is frozen.
@export var glacial_freeze := 2.0
