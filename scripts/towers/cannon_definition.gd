class_name CannonDefinition
extends TowerDefinition
## A Rune Cannon's extra settings (an evolved Gearshot): slow, heavy magic
## rounds that pierce and splash, and the Overcharge Round ability.

@export_group("Rune rounds")
@export var fire_rate_multiplier := 0.3
@export var damage_multiplier := 3.5
## Different enemies one round hits before it's spent.
@export var pierce_count := 3
## Share of each hit's damage splashed onto other enemies within splash_radius.
@export var splash_share := 0.4
@export var splash_radius := 50.0

@export_group("Overcharge Round")
@export var overcharge_damage_multiplier := 4.0
## How much farther than its range the round flies.
@export var overcharge_range_multiplier := 1.5
