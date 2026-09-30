class_name FrenzyPulse
extends Node2D
## Added by an Enemy whose definition has a pulse (the Goblin Shaman). Every
## pulse_interval seconds the enemy stops and casts; when the cast finishes,
## every other living enemy within pulse_radius is frenzied. A stun or death
## during the cast cancels it.

## Seconds after spawning before the first pulse.
const FIRST_PULSE := 2.0
## How long the ring showing the pulse's reach stays on screen.
const RING_TIME := 0.3

var _left := FIRST_PULSE
var _casting := false
var _ring_left := 0.0

@onready var enemy: Enemy = get_parent()


func _ready() -> void:
	enemy.pulse_finished.connect(_on_pulse_finished)


func _physics_process(delta: float) -> void:
	if _ring_left > 0.0:
		_ring_left -= delta
		queue_redraw()
	if _casting or enemy.health.is_dead:
		return
	_left -= delta
	if _left <= 0.0 and enemy.can_pulse():
		_casting = true
		enemy.start_pulse()


func _on_pulse_finished(landed: bool) -> void:
	_casting = false
	var def := enemy.definition
	_left = def.pulse_interval
	if not landed:
		return
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy
		if other == enemy or other.health.is_dead:
			continue
		if other.global_position.distance_to(enemy.global_position) <= def.pulse_radius:
			other.frenzy(def.pulse_speed_bonus, def.pulse_damage_bonus, def.pulse_duration)
	_ring_left = RING_TIME
	queue_redraw()


func _draw() -> void:
	if _ring_left <= 0.0:
		return
	var t := 1.0 - _ring_left / RING_TIME
	draw_arc(Vector2.ZERO, enemy.definition.pulse_radius * t, 0.0, TAU, 48,
			Color(1.0, 0.45, 0.35, 0.7 * (1.0 - t)), 3.0)
