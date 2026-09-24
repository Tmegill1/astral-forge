class_name HealthBar
extends Node2D
## Small bar floating above a unit. Follows the sibling "Health" node unless
## one is assigned. Reusable for enemies, towers and the Core.

@export var health: Health
@export var width := 44.0
@export var height := 5.0
## Enemies can hide the bar until they take damage.
@export var hide_when_full := false


func _ready() -> void:
	if health == null:
		health = get_parent().get_node_or_null("Health")
	if health:
		health.changed.connect(func(_current: float, _maximum: float) -> void: queue_redraw())
		health.died.connect(queue_redraw)


func _draw() -> void:
	if health == null or health.is_dead:
		return
	var ratio := clampf(health.current / health.max_health, 0.0, 1.0)
	if hide_when_full and ratio >= 1.0:
		return
	var box := Rect2(-width / 2.0, -height, width, height)
	draw_rect(box.grow(1.0), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(box.position, Vector2(width * ratio, height)), health_color(ratio))


## Green when healthy, through yellow, to red when low.
static func health_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.95, 0.85, 0.2).lerp(Color(0.3, 0.85, 0.3), (ratio - 0.5) * 2.0)
	return Color(0.9, 0.2, 0.15).lerp(Color(0.95, 0.85, 0.2), ratio * 2.0)
