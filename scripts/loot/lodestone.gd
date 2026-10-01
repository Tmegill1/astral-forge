class_name Lodestone
extends Area2D
## Rare drop: a spinning gold-and-blue crystal (drawn). When the hero touches
## it, every XP orb on the map rushes to them.

const SCENE_PATH := "res://scenes/loot/lodestone.tscn"

## True between drop() and the Lodestone actually appearing, so several
## kills in one frame can't each drop one.
static var _dropping := false

var _time := 0.0


## Drops one at `at` (deferred: kills happen mid-physics).
static func drop(parent: Node, at: Vector2) -> void:
	if _dropping:
		return
	_dropping = true
	_drop_now.call_deferred(parent, at)


## True if one is on the way (dropped this frame, not added yet).
static func is_dropping() -> bool:
	return _dropping


static func _drop_now(parent: Node, at: Vector2) -> void:
	_dropping = false
	if not is_instance_valid(parent):
		return
	var stone: Lodestone = load(SCENE_PATH).instantiate()
	stone.position = at + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
	parent.add_child(stone)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_time += delta
	queue_redraw()
	var hero := get_tree().get_first_node_in_group(&"hero") as Hero
	if hero == null or hero.health.is_dead:
		return
	var target := hero.global_position + XpOrb.HERO_CENTRE
	if global_position.distance_to(target) <= XpOrb.PULL_RADIUS * RunCards.multiplier(self, &"pull_radius"):
		global_position = global_position.move_toward(target, XpOrb.PULL_SPEED * delta)


func _on_body_entered(body: Node2D) -> void:
	var hero := body as Hero
	if hero == null or hero.health.is_dead:
		return
	for orb in get_tree().get_nodes_in_group(&"xp_orbs"):
		(orb as XpOrb).rushing = true
	queue_free()


func _draw() -> void:
	var spin := _time * 2.0
	var ring := 14.0 + 3.0 * sin(_time * 4.0)
	draw_arc(Vector2(0, -8), ring, 0.0, TAU, 32, Color(1.0, 0.85, 0.4, 0.5), 2.0)
	var points := PackedVector2Array()
	for i in 4:
		var radius := 11.0 if i % 2 == 0 else 7.0
		points.append(Vector2(0, -8) + Vector2.from_angle(spin + i * TAU / 4.0) * radius)
	draw_colored_polygon(points, Color(1.0, 0.8, 0.3))
	draw_circle(Vector2(0, -8), 3.5, Color(0.45, 0.8, 1.0))
