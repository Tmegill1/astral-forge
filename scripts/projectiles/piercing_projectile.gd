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
## Splashes from this frame's hits, [centre, damage], dealt at the start of
## the next physics frame so enemies hit in the same frame (stacked on one
## spot) are left out of each other's splash.
var _pending_splash: Array = []


func _physics_process(delta: float) -> void:
	_flush_splash()
	super(delta)


func _on_hit(target: Node) -> void:
	if _spent:
		return
	var health := _health_of(target)
	if health == null or health.is_dead or health.invulnerable:
		return
	var victim := health.get_parent() as Node2D
	if _hit_ids.has(victim.get_instance_id()):
		return
	_hit_ids[victim.get_instance_id()] = true
	var dealt := health.take_damage(damage, damage_type)
	struck.emit(victim)
	hit.emit(dealt, health.is_dead)
	_pending_splash.append([victim.global_position, damage * splash_share])
	if pierce > 0 and _hit_ids.size() >= pierce:
		_spent = true
		# Nothing else can be hit now, so splash at once before freeing.
		_flush_splash()
		queue_free()


## Deals the queued splashes: each to every living enemy within
## splash_radius of its centre that the round hasn't hit itself.
func _flush_splash() -> void:
	for splash in _pending_splash:
		for node in get_tree().get_nodes_in_group(&"enemies"):
			var enemy := node as Enemy
			if _hit_ids.has(enemy.get_instance_id()) or enemy.health.is_dead:
				continue
			if enemy.global_position.distance_to(splash[0]) <= splash_radius:
				var dealt := enemy.health.take_damage(splash[1], damage_type)
				hit.emit(dealt, enemy.health.is_dead)
	_pending_splash.clear()
