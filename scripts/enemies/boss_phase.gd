class_name BossPhase
extends Node2D
## Added by an Enemy with phase2_at > 0 (the Shaman-King). Once its health
## falls to phase2_at, it channels a phase shift (1.5 s), flashes the screen,
## speeds up, summons twice as often and raises a shield: the boss takes
## SHIELD_TAKEN of all damage unless the hero is operating a tower whose
## range reaches it.

const SHIFT_TIME := 1.5
const SPEED := 1.3
const SHIELD_TAKEN := 0.1
const FLASH := Color(0.6, 0.3, 1.0, 0.45)

var shifted := false
var shield_open := false
var _waiting := false
var _cleared := false
var _base_taken := PackedFloat32Array()

@onready var enemy: Enemy = get_parent()


func _ready() -> void:
	_base_taken = enemy.health.damage_taken.duplicate()
	enemy.channel_finished.connect(_on_channel_finished)


func _physics_process(_delta: float) -> void:
	if enemy.health.is_dead or enemy.fled:
		if not _cleared:
			_cleared = true
			queue_redraw()
		return
	if not shifted:
		var ratio := enemy.health.current / enemy.health.max_health
		if ratio <= enemy.definition.phase2_at and not _waiting and enemy.can_channel():
			_waiting = true
			enemy.start_channel(enemy.definition.phase_shift_animation, self, SHIFT_TIME)
		return
	var open := _hero_operating_in_range()
	if open != shield_open:
		shield_open = open
		_apply_shield()
		queue_redraw()


func _on_channel_finished(by: Node, landed: bool) -> void:
	if by != self:
		return
	_waiting = false
	if not landed:
		return  # try again when it can channel
	shifted = true
	enemy.phase_speed = SPEED
	for child in enemy.get_children():
		if child is Summoner:
			child.interval *= 0.5
	_apply_shield()
	_flash()
	queue_redraw()


func _hero_operating_in_range() -> bool:
	var hero := get_tree().get_first_node_in_group(&"hero") as Hero
	if hero == null or hero.health.is_dead or hero.operating == null:
		return false
	var tower := hero.operating
	return tower.global_position.distance_to(enemy.global_position) <= tower.attack_range()


func _apply_shield() -> void:
	var taken := _base_taken.duplicate()
	if not shield_open:
		for i in taken.size():
			taken[i] *= SHIELD_TAKEN
	enemy.health.damage_taken = taken


func _flash() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	var rect := ColorRect.new()
	rect.color = FLASH
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	get_tree().current_scene.add_child(layer)
	var tween := layer.create_tween()
	tween.tween_property(rect, "color:a", 0.0, 0.6)
	tween.tween_callback(layer.queue_free)


func _draw() -> void:
	if not shifted or enemy.health.is_dead or enemy.fled:
		return
	var radius := 70.0
	var alpha := 0.12 if shield_open else 0.35
	draw_circle(Vector2(0, -50), radius, Color(0.6, 0.3, 1.0, alpha))
	draw_arc(Vector2(0, -50), radius, 0.0, TAU, 48, Color(0.75, 0.5, 1.0, alpha + 0.3), 3.0)
