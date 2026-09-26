class_name SpireTower
extends Tower
## The Aether Spire: lightning that jumps between enemies. Each bolt hits a
## first target, then jumps to the nearest enemy it hasn't hit within
## jump_range, each jump dealing less. On its own the first target is the
## nearest enemy; operated, the enemy in range nearest the mouse. Q =
## Resonance Burst: a double-damage bolt with more jumps and no falloff that
## stuns everything it hits.

## How long the charge frame shows after a bolt, in seconds.
const CHARGE_FRAME_TIME := 0.2

var spire: SpireDefinition


func _ready() -> void:
	spire = definition as SpireDefinition
	assert(spire != null, "A SpireTower needs a SpireDefinition")
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	if operator:
		queue_redraw()


## Where bolts leave from: this level's crystal tip.
func _muzzle_base() -> Vector2:
	return global_position + Vector2(0.0, -spire.bolt_heights[level - 1])


## The living enemy in range nearest `point`, or null.
func _first_target(point: Vector2) -> Enemy:
	var best: Enemy = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy.health.is_dead or global_position.distance_to(enemy.global_position) > attack_range():
			continue
		var distance := point.distance_to(_aim_point(enemy))
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best


## `first` and up to `jumps` more living enemies: each the nearest one not
## yet in the chain within jump_range of the last.
func chain_from(first: Enemy, jumps: int) -> Array[Enemy]:
	var chain: Array[Enemy] = [first]
	var others: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy != first and not enemy.health.is_dead:
			others.append(enemy)
	while chain.size() <= jumps and not others.is_empty():
		var from := _aim_point(chain[-1])
		var best := -1
		var best_distance := spire.jump_range
		for i in others.size():
			var distance := from.distance_to(_aim_point(others[i]))
			if distance <= best_distance:
				best = i
				best_distance = distance
		if best < 0:
			break
		chain.append(others[best])
		others.remove_at(best)
	return chain


## Operated, only fire when a bolt would hit something, so holding fire
## before enemies arrive doesn't waste the recharge.
func _can_fire() -> bool:
	return operator == null or _first_target(_operated_aim_point()) != null


func _fire_at(point: Vector2) -> void:
	var first := _first_target(point)
	if first:
		_strike(chain_from(first, spire.jump_count), damage(), spire.jump_falloff, 0.0)


## Fires a Resonance Burst at the enemy nearest the mouse, if it's recharged
## and an enemy is in range.
func use_ability() -> void:
	if operator == null or _ability_cooldown_left > 0.0:
		return
	var first := _first_target(_operated_aim_point())
	if first == null:
		return
	_ability_cooldown_left = definition.ability_cooldown
	_strike(chain_from(first, spire.burst_jump_count),
			damage() * spire.burst_damage_multiplier, 0.0, spire.burst_stun)


## Deals `bolt_damage` down the chain (each jump `falloff` less than the one
## before), stuns each enemy hit for `stun` seconds if above 0, and draws the
## bolt.
func _strike(chain: Array[Enemy], bolt_damage: float, falloff: float, stun: float) -> void:
	var points := PackedVector2Array([_muzzle_base()])
	var hit_damage := bolt_damage
	for enemy in chain:
		points.append(_aim_point(enemy))
		var before := enemy.health.current
		enemy.health.take_damage(hit_damage)
		if operator:
			mastery_xp += before - enemy.health.current
		if stun > 0.0:
			enemy.stun(stun)
		hit_damage *= 1.0 - falloff
	var arc := LightningArc.new()
	arc.points = points
	arc.burst = stun > 0.0
	projectile_parent.add_child(arc)
	# The first fire frame is the swirling charge; the later ones' beams are
	# clipped at the frame edge.
	sprite.animation = StringName("lv%d_fire" % level)
	sprite.stop()
	sprite.frame = 0
	_fire_frame_left = CHARGE_FRAME_TIME


## While operated: the range ring, and a ring on the enemy the next bolt
## would hit first.
func _draw() -> void:
	if operator == null:
		return
	var reach := Color(0.45, 0.85, 1.0)
	draw_circle(Vector2.ZERO, attack_range(), Color(reach, 0.04))
	draw_arc(Vector2.ZERO, attack_range(), 0.0, TAU, 96, Color(reach, 0.35), 2.0)
	var first := _first_target(_operated_aim_point())
	if first:
		draw_arc(to_local(_aim_point(first)), 16.0, 0.0, TAU, 24, Color(reach, 0.9), 2.0)
