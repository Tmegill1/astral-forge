class_name SpawnGroup
extends Node
## One batch of enemies in a Wave (see WaveRun): what, how many, from which
## side, and how quickly they arrive.

@export var enemy: EnemyDefinition
@export var count := 5
## Which map edge they come from.
@export_enum("north", "east", "south", "west") var sector := "west"
## Seconds between spawns in this group.
@export var interval := 1.5
## Seconds after the wave starts before this group begins.
@export var delay := 0.0


## This group as wave data, or null (with a warning) if no enemy is set.
func to_definition() -> WaveGroup:
	if enemy == null:
		push_warning("Waves: %s/%s has no enemy set, so it's skipped" % [get_parent().name, name])
		return null
	var group := WaveGroup.new()
	group.enemy = enemy
	group.count = count
	group.sector = sector
	group.interval = interval
	group.delay = delay
	return group
