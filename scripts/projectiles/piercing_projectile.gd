class_name PiercingProjectile
extends Projectile
## A round that passes through enemies: it hits each one once, splashes
## part of every hit onto other enemies near it, and is spent after `pierce`
## different enemies (0 = never; it flies its whole distance).

var pierce := 3
## Share of each hit's damage dealt to other enemies within splash_radius.
var splash_share := 0.4
var splash_radius := 50.0

## Instance ids of the enemies already hit, so overlapping shapes on the same
## enemy never count twice.
var _hit_ids := {}


func _on_hit(target: Node) -> void:
	if _spent:
		return
	var health := _health_of(target)
	if health == null or health.is_dead or health.invulnerable:
		return
	var victim := health.get_parent()
	if _hit_ids.has(victim.get_instance_id()):
		return
	_hit_ids[victim.get_instance_id()] = true
	var dealt := health.take_damage(damage, damage_type)
	struck.emit(victim)
	hit.emit(dealt, health.is_dead)
	_splash(victim as Node2D)
	if pierce > 0 and _hit_ids.size() >= pierce:
		_spent = true
		queue_free()


## Damages every other living enemy within splash_radius of `centre`.
func _splash(centre: Node2D) -> void:
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == centre or enemy.health.is_dead:
			continue
		if enemy.global_position.distance_to(centre.global_position) <= splash_radius:
			var dealt := enemy.health.take_damage(damage * splash_share, damage_type)
			hit.emit(dealt, enemy.health.is_dead)
