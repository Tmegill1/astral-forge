class_name Projectile
extends Area2D
## Flies in a straight line, damages the first thing it touches that has a
## Health child (on the hit body/area or its parent), and disappears after max_distance. Which things it can hit is set
## by the scene's collision mask.

## Emitted when the bolt damages something; `killed` if that finished it.
signal hit(damage: float, killed: bool)

@export var color := Color(0.45, 0.85, 1.0)
@export var radius := 5.0

var direction := Vector2.RIGHT
var speed := 700.0
var damage := 10.0
var max_distance := 500.0

var _travelled := 0.0
var _spent := false


func _ready() -> void:
	rotation = direction.angle()
	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	position += direction * step
	_travelled += step
	if _travelled >= max_distance:
		queue_free()


func _on_hit(target: Node) -> void:
	if _spent:
		return
	var health := target.get_node_or_null(^"Health") as Health
	if health == null:
		health = target.get_parent().get_node_or_null(^"Health") as Health
	if health == null or health.is_dead:
		return
	# Two overlaps can report in the same frame; only the first one counts.
	_spent = true
	health.take_damage(damage)
	hit.emit(damage, health.is_dead)
	queue_free()


func _draw() -> void:
	# Placeholder look until projectile art exists: a glowing streak.
	draw_circle(Vector2.ZERO, radius * 2.2, Color(color, 0.25))
	draw_line(Vector2(-radius * 3.0, 0), Vector2.ZERO, Color(color, 0.6), radius)
	draw_circle(Vector2.ZERO, radius, Color.WHITE.lerp(color, 0.4))
