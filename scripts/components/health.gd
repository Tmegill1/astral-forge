class_name Health
extends Node
## Hit points for anything that can be damaged: heroes, enemies, the Core,
## towers. Attach as a child named "Health" so attacks can find it.

signal changed(current: float, maximum: float)
signal died
## Emitted whenever damage is applied: what got through, its type, and the
## part the target's resistance blocked.
signal damaged(dealt: float, type: int, blocked: float)

## What kind of harm a hit does. Enemies can resist some kinds.
enum DamageType { PHYSICAL, FIRE, MAGIC }

@export var max_health: float = 100.0
## While true, damage is ignored (e.g. a hero safely operating a tower).
var invulnerable := false
## Share of each DamageType's damage that gets through (1 = all of it),
## indexed by DamageType.
var damage_taken := PackedFloat32Array([1.0, 1.0, 1.0])

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


## Applies damage of `type`, reduced by damage_taken, and returns how much
## health it actually took (0 if it was ignored).
func take_damage(amount: float, type := DamageType.PHYSICAL) -> float:
	if is_dead or invulnerable or amount <= 0.0:
		return 0.0
	var scaled := amount * damage_taken[type]
	var dealt := minf(scaled, current)
	current = maxf(current - scaled, 0.0)
	changed.emit(current, max_health)
	damaged.emit(dealt, type, amount - scaled)
	if is_dead:
		died.emit()
	return dealt


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current = minf(current + amount, max_health)
	changed.emit(current, max_health)
