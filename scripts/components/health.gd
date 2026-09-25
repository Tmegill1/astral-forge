class_name Health
extends Node
## Hit points for anything that can be damaged: heroes, enemies, the Core,
## towers. Attach as a child named "Health" so attacks can find it.

signal changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0
## While true, damage is ignored (e.g. a hero safely operating a tower).
var invulnerable := false

var current: float
var is_dead: bool:
	get:
		return current <= 0.0


func _ready() -> void:
	current = max_health


## Sets a new maximum and refills to full.
func reset(new_max: float = max_health) -> void:
	max_health = new_max
	current = max_health
	changed.emit(current, max_health)


## Changes the maximum but keeps the same amount of missing health
## (an upgrade adds the new health on top). Does nothing when dead.
func grow_max(new_max: float) -> void:
	if is_dead:
		return
	current = maxf(current + new_max - max_health, 1.0)
	max_health = new_max
	changed.emit(current, max_health)


func take_damage(amount: float) -> void:
	if is_dead or invulnerable or amount <= 0.0:
		return
	current = maxf(current - amount, 0.0)
	changed.emit(current, max_health)
	if is_dead:
		died.emit()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current = minf(current + amount, max_health)
	changed.emit(current, max_health)
