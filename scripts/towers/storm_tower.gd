class_name StormTower
extends SpireTower
## The Storm Array (an evolved Aether Spire): lightning that jumps 8 times
## with no falloff, and every 5th bolt stuns everything it hits. Q =
## Thunderstorm: for 4 s, a stunning strike on a random enemy in range every
## 0.25 s.

var storm: StormDefinition
## Bolts fired so far; every stun_every-th one stuns.
var bolts_fired := 0
var _storm_tick := 0.0


func _ready() -> void:
	storm = definition as StormDefinition
	assert(storm != null, "A StormTower needs a StormDefinition")
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	if _ability_left > 0.0:
		_storm_tick -= delta
		if _storm_tick <= 0.0:
			_storm_tick += storm.storm_interval
			_storm_strike()


func _fire_at(point: Vector2) -> void:
	var first := _first_target(point)
	if first == null:
		return
	bolts_fired += 1
	var stun := storm.stun_time if bolts_fired % storm.stun_every == 0 else 0.0
	_strike(chain_from(first, spire.jump_count), damage(), spire.jump_falloff, stun)


## Starts a Thunderstorm if it's recharged.
func use_ability() -> void:
	if operator == null or _ability_cooldown_left > 0.0:
		return
	_ability_left = definition.ability_duration
	_ability_cooldown_left = definition.ability_cooldown
	_storm_tick = 0.0


## One storm strike on a random living enemy in range, if there is one.
func _storm_strike() -> void:
	var targets: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if not enemy.health.is_dead and global_position.distance_to(enemy.global_position) <= attack_range():
			targets.append(enemy)
	if targets.is_empty():
		return
	_strike(chain_from(targets.pick_random(), storm.storm_jumps), damage(), 0.0, storm.storm_stun)
