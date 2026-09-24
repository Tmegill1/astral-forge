class_name RunDefinition
extends Resource
## A whole run: the waves in order. Clearing the last one wins.

@export var waves: Array[WaveDefinition] = []
## Scrap heaps scattered around the map at the start of each break.
@export var heaps_per_break := 4
## Never more than this many heaps on the map at once.
@export var max_heaps := 8
