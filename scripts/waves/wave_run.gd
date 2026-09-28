class_name WaveRun
extends Node
## The root of a waves scene (scenes/waves/): its Wave children, top to
## bottom, are the run's waves. Edit them in the scene tree: duplicate a
## wave or group with Ctrl+D, drag to reorder, pick enemies and sides in the
## inspector. The WaveDirector reads this when the game starts.

## Scrap heaps scattered around the map at the start of each break.
@export var heaps_per_break := 4
## Never more than this many Scrap heaps on the map at once.
@export var max_heaps := 8
## Aether crystals added each break: a random count from x to y.
@export var aether_per_break := Vector2i(1, 2)
## Never more than this many Aether crystals on the map at once.
@export var max_aether := 3
## Aether in each crystal: a random amount from x to y.
@export var aether_amount := Vector2i(2, 4)


func to_definition() -> RunDefinition:
	var run := RunDefinition.new()
	run.heaps_per_break = heaps_per_break
	run.max_heaps = max_heaps
	run.aether_per_break = aether_per_break
	run.max_aether = max_aether
	run.aether_amount = aether_amount
	for child in get_children():
		if child is Wave:
			run.waves.append((child as Wave).to_definition())
	return run
