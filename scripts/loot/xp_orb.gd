class_name XpOrb
extends Area2D
## XP dropped by an enemy: a glowing teal orb (drawn, no art). Drifts to a
## nearby living hero and adds its XP to RunCards on touch. A Lodestone sets
## `rushing`, sending it to the hero from anywhere. Never despawns.

const SCENE_PATH := "res://scenes/loot/xp_orb.tscn"
const PULL_RADIUS := 140.0
const PULL_SPEED := 320.0
const RUSH_SPEED := 900.0
## The hero's body centre, from its feet.
const HERO_CENTRE := Vector2(0, -8)

var amount := 1
var rushing := false
var _popping := false
var _time := 0.0


## Drops an orb worth `value` XP at `at` (deferred: kills happen mid-physics).
static func drop(parent: Node, at: Vector2, value: int) -> void:
	if value > 0:
		_drop_now.call_deferred(parent, at, value)


static func _drop_now(parent: Node, at: Vector2, value: int) -> void:
	if not is_instance_valid(parent):
		return
	var orb: XpOrb = load(SCENE_PATH).instantiate()
	orb.amount = value
	orb.position = at
	parent.add_child(orb)
	orb.pop_to(at + Vector2.from_angle(randf() * TAU) * randf_range(8.0, 24.0))


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func pop_to(landing: Vector2) -> void:
	_popping = true
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position", landing, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_land)


func _land() -> void:
	_popping = false
	for body in get_overlapping_bodies():
		_on_body_entered(body)


func _physics_process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _popping:
		return
	var hero := get_tree().get_first_node_in_group(&"hero") as Hero
	if hero == null or hero.health.is_dead:
		return
	var target := hero.global_position + HERO_CENTRE
	if rushing:
		global_position = global_position.move_toward(target, RUSH_SPEED * delta)
	elif global_position.distance_to(target) <= PULL_RADIUS * RunCards.multiplier(self, &"pull_radius"):
		global_position = global_position.move_toward(target, PULL_SPEED * delta)


func _on_body_entered(body: Node2D) -> void:
	var hero := body as Hero
	if hero == null or hero.health.is_dead or _popping:
		return
	var cards := get_tree().get_first_node_in_group(&"run_cards") as RunCards
	if cards:
		cards.add_xp(amount)
	queue_free()


func _draw() -> void:
	var pulse := 1.0 + 0.15 * sin(_time * 6.0)
	draw_circle(Vector2(0, -6), 12.0 * pulse, Color(0.3, 1.0, 0.85, 0.18))
	draw_circle(Vector2(0, -6), 7.0 * pulse, Color(0.35, 0.95, 0.85, 0.9))
	draw_circle(Vector2(0, -7), 3.0, Color(0.9, 1.0, 1.0, 0.95))
