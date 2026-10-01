class_name Pickup
extends Area2D
## A pile of Scrap or Aether on the ground. Drifts toward a nearby living
## hero and goes into their carried resources on touch. Never despawns.

@export var type := Loot.SCRAP
@export var amount := 1
## A living hero this close pulls the pickup in, in pixels.
@export var magnet_radius := 70.0
@export var magnet_speed := 260.0

var _popping := false

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	var icons: Array = Loot.ICONS[type]
	sprite.texture = icons.pick_random()
	body_entered.connect(_on_body_entered)


## Little hop from where it dropped to where it lands.
func pop_to(landing: Vector2) -> void:
	_popping = true
	# Physics ticks, so physics interpolation smooths the hop.
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position", landing, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "position:y", sprite.position.y - 14.0, 0.17).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(sprite, "position:y", sprite.position.y, 0.18).set_ease(Tween.EASE_IN)
	tween.tween_callback(_land)


func _land() -> void:
	_popping = false
	# A hero already standing here won't trigger body_entered again.
	for body in get_overlapping_bodies():
		_on_body_entered(body)


func _physics_process(delta: float) -> void:
	if _popping:
		return
	var hero := get_tree().get_first_node_in_group(&"hero") as Hero
	if hero == null or hero.health.is_dead:
		return
	if global_position.distance_to(hero.global_position) <= magnet_radius * RunCards.multiplier(self, &"pull_radius"):
		global_position = global_position.move_toward(hero.global_position, magnet_speed * delta)


func _on_body_entered(body: Node2D) -> void:
	var hero := body as Hero
	if hero == null or hero.health.is_dead or _popping:
		return
	hero.carried.add(type, amount)
	queue_free()
