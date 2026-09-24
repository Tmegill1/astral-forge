class_name ResourceBag
extends RefCounted
## A pile of resources by type (&"scrap", &"aether"). The hero carries one;
## the Command Core stores another, which is what building spends.

signal changed

var _amounts: Dictionary[StringName, int] = {}


func get_amount(type: StringName) -> int:
	return _amounts.get(type, 0)


func add(type: StringName, amount: int) -> void:
	if amount <= 0:
		return
	_amounts[type] = get_amount(type) + amount
	changed.emit()


func add_all(amounts: Dictionary[StringName, int]) -> void:
	for type in amounts:
		_amounts[type] = get_amount(type) + amounts[type]
	if not amounts.is_empty():
		changed.emit()


## Removes the amount if there's enough and returns true; otherwise false.
func spend(type: StringName, amount: int) -> bool:
	if get_amount(type) < amount:
		return false
	_amounts[type] = get_amount(type) - amount
	changed.emit()
	return true


func can_afford(cost: Dictionary[StringName, int]) -> bool:
	for type in cost:
		if get_amount(type) < cost[type]:
			return false
	return true


## Pays a multi-resource cost if every part is affordable; otherwise pays
## nothing and returns false.
func spend_all(cost: Dictionary[StringName, int]) -> bool:
	if not can_afford(cost):
		return false
	for type in cost:
		_amounts[type] = get_amount(type) - cost[type]
	changed.emit()
	return true


## What's still needed to afford a cost, e.g. {"scrap": 4}; empty if affordable.
func shortfall(cost: Dictionary[StringName, int]) -> Dictionary[StringName, int]:
	var missing: Dictionary[StringName, int] = {}
	for type in cost:
		if get_amount(type) < cost[type]:
			missing[type] = cost[type] - get_amount(type)
	return missing


## Empties the bag and returns what was in it.
func take_all() -> Dictionary[StringName, int]:
	var taken: Dictionary[StringName, int] = {}
	for type in _amounts:
		if _amounts[type] > 0:
			taken[type] = _amounts[type]
	_amounts.clear()
	if not taken.is_empty():
		changed.emit()
	return taken


func is_empty() -> bool:
	return _amounts.values().all(func(n: int) -> bool: return n <= 0)


## e.g. "12 Scrap, 3 Aether"; empty string when there's nothing.
func describe() -> String:
	var parts: PackedStringArray = []
	for type in _amounts:
		if _amounts[type] > 0:
			parts.append("%d %s" % [_amounts[type], Loot.display_name(type)])
	return ", ".join(parts)
