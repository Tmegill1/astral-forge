class_name FrostTower
extends MortarTower
## The Frost Rune Mortar (an evolved Rune Mortar): weaker shells that leave
## an icy circle slowing enemies 60% for 6 s and freeze anything within 30 px
## of the impact. Q = Glacial Shell: a double-size blast that freezes
## everything in it for 2 s.

var frost: FrostDefinition


func _ready() -> void:
	frost = definition as FrostDefinition
	assert(frost != null, "A FrostTower needs a FrostDefinition")
	super()


func damage() -> float:
	return super() * frost.damage_multiplier


func _fire_at(point: Vector2) -> void:
	var shell := _frost_shell(point, splash_radius())
	shell.freeze_radius = frost.freeze_radius
	shell.freeze_time = frost.freeze_time
	projectile_parent.add_child(shell)
	_show(&"fire")
	_fire_frame_left = 0.35


## Fires a Glacial Shell at the aim point if it's recharged.
func use_ability() -> void:
	if operator == null or _ability_cooldown_left > 0.0:
		return
	_ability_cooldown_left = definition.ability_cooldown
	var point := _operated_aim_point()
	_aim_at(point)
	var radius := splash_radius() * frost.glacial_radius_multiplier
	var shell := _frost_shell(point, radius)
	shell.freeze_radius = radius
	shell.freeze_time = frost.glacial_freeze
	projectile_parent.add_child(shell)
	_show(&"fire")
	_fire_frame_left = 0.35


## An icy shell that leaves a frost circle the size of its blast.
func _frost_shell(point: Vector2, radius: float) -> Shell:
	var shell := _make_shell(point, damage(), radius, frost.frost_duration)
	shell.rune_slow = frost.frost_slow
	shell.color = frost.frost_color
	return shell
