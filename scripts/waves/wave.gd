class_name Wave
extends Node
## One wave in a WaveRun scene: a break of prep_time seconds, then its
## SpawnGroup children arrive. Groups parked under any other kind of node
## are ignored.

## Seconds of calm before this wave starts (shown as a countdown).
@export var prep_time := 30.0


func to_definition() -> WaveDefinition:
	var wave := WaveDefinition.new()
	wave.prep_time = prep_time
	for child in get_children():
		if child is SpawnGroup:
			var group := (child as SpawnGroup).to_definition()
			if group:
				wave.groups.append(group)
	return wave
