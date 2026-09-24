class_name WaveDefinition
extends Resource
## One wave: a scavenging/building break, then groups of enemies. The wave
## is cleared once every enemy in it has been spawned and killed.

## Seconds of calm before this wave starts (shown as a countdown).
@export var prep_time := 30.0
@export var groups: Array[WaveGroup] = []


func sectors() -> Array[StringName]:
	var result: Array[StringName] = []
	for group in groups:
		if not StringName(group.sector) in result:
			result.append(StringName(group.sector))
	return result


func enemy_count() -> int:
	var total := 0
	for group in groups:
		total += group.count
	return total
