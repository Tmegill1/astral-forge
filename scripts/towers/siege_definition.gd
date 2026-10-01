class_name SiegeDefinition
extends MortarDefinition
## A Siege Battery's extra settings (an evolved Rune Mortar): salvos of
## shells, and the Bombardment ability.

@export_group("Salvo")
@export var salvo_shells := 3
## The extra shells land within this of the target, in pixels.
@export var salvo_scatter := 40.0
## Seconds between the shells of a salvo.
@export var salvo_gap := 0.1
## Share of the Mortar's damage each shell deals.
@export var shell_damage_multiplier := 0.7
## Blast radius multiplier.
@export var blast_multiplier := 1.3
@export var fire_rate_multiplier := 0.6

@export_group("Bombardment")
@export var bombard_shells := 6
## Bombardment shells land within this of the mouse, in pixels.
@export var bombard_scatter := 120.0
