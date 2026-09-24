class_name WaveGroup
extends Resource
## One batch of enemies in a wave: what, how many, from which side, and how
## quickly they arrive.

const SECTORS: Array[StringName] = [&"north", &"east", &"south", &"west"]

@export var enemy: EnemyDefinition
@export var count := 5
## north / east / south / west.
@export_enum("north", "east", "south", "west") var sector := "west"
## Seconds between spawns in this group.
@export var interval := 1.5
## Seconds after the wave starts before this group begins.
@export var delay := 0.0
