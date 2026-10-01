class_name OilTower
extends EmberTower
## The Oil Sprayer (an evolved Embercaster): a weaker flame that oils
## everything it hits for 4 s (30% slower, +50% fire damage from any
## source). Q = Ignite: every oiled enemy in range takes a fire burst, goes
## to max burn and loses its oil.

var oil: OilDefinition


func _ready() -> void:
	oil = definition as OilDefinition
	assert(oil != null, "An OilTower needs an OilDefinition")
	super()


func damage() -> float:
	return super() * oil.flame_damage_multiplier


## Oils everything in the cone first, so the tick itself gets the bonus.
func _fire_at(point: Vector2) -> void:
	for enemy in _enemies_in_cone(point):
		enemy.oil(oil.oil_seconds, oil.oil_slow, oil.oil_fire_bonus)
	super(point)


## Ignites every oiled enemy in range, if it's recharged.
func use_ability() -> void:
	if operator == null or _ability_cooldown_left > 0.0:
		return
	_ability_cooldown_left = definition.ability_cooldown
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy.health.is_dead or not enemy.is_oiled() \
				or global_position.distance_to(enemy.global_position) > attack_range():
			continue
		enemy.health.take_damage(damage() * oil.ignite_damage_multiplier, Health.DamageType.FIRE)
		enemy.add_burn(burn_dps(), ember.burn_max_stacks, ember.burn_duration, ember.burn_max_stacks)
		enemy.clear_oil()
