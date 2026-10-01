class_name RuneCannonTower
extends Tower
## The Rune Cannon (an evolved Gearshot): slow, heavy magic rounds that pass
## through up to 3 enemies and splash each hit. Q = Overcharge Round: one 4×
## round at the mouse that pierces everything and flies farther.

const ROUND_SCENE := preload("res://scenes/projectiles/rune_round.tscn")

var cannon: CannonDefinition


func _ready() -> void:
	cannon = definition as CannonDefinition
	assert(cannon != null, "A RuneCannonTower needs a CannonDefinition")
	super()


func damage() -> float:
	return super() * cannon.damage_multiplier


func fire_rate() -> float:
	return super() * cannon.fire_rate_multiplier


func _fire_at(point: Vector2) -> void:
	_launch_bolt(_make_round(cannon.pierce_count), point)


## Fires an Overcharge Round at the mouse if it's recharged.
func use_ability() -> void:
	if operator == null or _ability_cooldown_left > 0.0:
		return
	_ability_cooldown_left = definition.ability_cooldown
	var shot := _make_round(0)
	_launch_bolt(shot, _operated_aim_point())
	shot.damage *= cannon.overcharge_damage_multiplier
	shot.max_distance = attack_range() * cannon.overcharge_range_multiplier
	shot.radius *= 1.6


func _make_round(pierce: int) -> PiercingProjectile:
	var shot: PiercingProjectile = ROUND_SCENE.instantiate()
	shot.pierce = pierce
	shot.splash_share = cannon.splash_share
	shot.splash_radius = cannon.splash_radius
	shot.damage_type = Health.DamageType.MAGIC
	return shot
