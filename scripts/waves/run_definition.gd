class_name RunDefinition
extends Resource
## A whole run: the waves in order. Clearing the last one wins.

@export var waves: Array[WaveDefinition] = []
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
