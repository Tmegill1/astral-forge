class_name SiegeTower
extends MortarTower
## The Siege Battery (an evolved Rune Mortar): each shot is a salvo of 3
## weaker shells with bigger blasts, the first on the target and the rest
## scattered around it. Q = Bombardment: 6 full-strength shells scattered
## around the mouse.

var siege: SiegeDefinition
## Shells still to launch this salvo: [seconds left, point, damage].
var _queued: Array = []


func _ready() -> void:
	siege = definition as SiegeDefinition
	assert(siege != null, "A SiegeTower needs a SiegeDefinition")
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	for i in range(_queued.size() - 1, -1, -1):
		_queued[i][0] -= delta
		if _queued[i][0] <= 0.0:
			var shot: Array = _queued[i]
			_queued.remove_at(i)
			_launch(shot[1], shot[2], splash_radius(), 0.0)


func fire_rate() -> float:
	return super() * siege.fire_rate_multiplier


func splash_radius() -> float:
	return super() * siege.blast_multiplier


func _fire_at(point: Vector2) -> void:
	_salvo(point, siege.salvo_shells, siege.salvo_scatter, damage() * siege.shell_damage_multiplier)
	_show(&"fire")
	_fire_frame_left = 0.35


## Fires a Bombardment around the mouse if it's recharged.
func use_ability() -> void:
	if operator == null or _ability_cooldown_left > 0.0:
		return
	_ability_cooldown_left = definition.ability_cooldown
	var point := _operated_aim_point()
	_aim_at(point)
	_salvo(point, siege.bombard_shells, siege.bombard_scatter, damage())
	_show(&"fire")
	_fire_frame_left = 0.35


## Launches one shell at `point` now and queues `count - 1` more, salvo_gap
## apart, at random spots within `scatter` of it.
func _salvo(point: Vector2, count: int, scatter: float, shell_damage: float) -> void:
	_launch(point, shell_damage, splash_radius(), 0.0)
	for i in range(1, count):
		var spot := point + Vector2.from_angle(randf() * TAU) * scatter * sqrt(randf())
		_queued.append([siege.salvo_gap * i, spot, shell_damage])
