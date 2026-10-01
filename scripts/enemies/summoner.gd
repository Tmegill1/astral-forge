class_name Summoner
extends Node
## Added by an Enemy whose definition summons (the Shaman-King): every
## `interval` seconds it channels, then raises summon_count summon_enemy in a
## ring around itself. A stun or death cancels the cast.

const RING := 60.0
## First summon this long after spawning.
const FIRST_SUMMON := 4.0

var interval := 12.0
var _left := FIRST_SUMMON
var _casting := false

@onready var enemy: Enemy = get_parent()


func _ready() -> void:
	interval = enemy.definition.summon_interval
	enemy.channel_finished.connect(_on_channel_finished)


func _physics_process(delta: float) -> void:
	if _casting or enemy.health.is_dead or enemy.fled:
		return
	_left -= delta
	if _left <= 0.0 and enemy.can_channel():
		_casting = true
		enemy.start_channel(enemy.definition.summon_animation, self)


func _on_channel_finished(by: Node, landed: bool) -> void:
	if by != self:
		return
	_casting = false
	_left = interval
	if not landed:
		return
	var director := get_tree().get_first_node_in_group(&"wave_director") as WaveDirector
	if director == null:
		return
	var count: int = enemy.definition.summon_count
	for i in count:
		var at := enemy.global_position + Vector2.from_angle(TAU * i / count) * RING
		director.summon(enemy.definition.summon_enemy, at)
