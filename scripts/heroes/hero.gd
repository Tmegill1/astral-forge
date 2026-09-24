class_name Hero
extends CharacterBody2D
## The player's hero. Every hero uses this script; what differs (art, stats)
## comes from the HeroDefinition passed to setup() before the hero spawns.
##
## Controls: WASD to move (the hero faces the way it walks), mouse to aim,
## E to interact. Shooting is automatic toward the mouse unless auto_fire is
## off, then hold left mouse to shoot. Picked-up resources go into `carried`
## until deposited at the Core.

signal died
## Text for the nearest interactable ("[E] Deposit ..."), or "" for none.
signal interact_prompt_changed(text: String)

const BOLT_SCENE := preload("res://scenes/projectiles/hero_bolt.tscn")

## When false, the hero only shoots while the "fire" action is held.
@export var auto_fire := true
## How far from the hero's feet enemies can hit it from, in pixels.
@export var hit_radius := 12.0

var definition: HeroDefinition
## Final stats for this run: baseline x this hero's multipliers.
var stats: HeroStats
## World-space area the hero can't leave. Empty means no limit.
var bounds := Rect2()
## Resources picked up but not yet deposited; at risk if the hero falls.
var carried := ResourceBag.new()

var _cooldown := 0.0
var _prompt := ""

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle
@onready var health: Health = $Health
@onready var interact_area: Area2D = $InteractArea
@onready var health_bar: HealthBar = $HealthBar
@onready var camera: Camera2D = $Camera


## Call before adding the hero to the scene tree.
func setup(hero_definition: HeroDefinition) -> void:
	definition = hero_definition
	stats = definition.build_stats()


func _ready() -> void:
	assert(definition != null, "Call Hero.setup() before adding the hero to the tree")
	sprite.sprite_frames = definition.sprite_frames
	sprite.scale = Vector2.ONE * definition.sprite_scale
	sprite.offset = -definition.sprite_frames.get_meta("foot_offset", Vector2.ZERO)
	sprite.play(&"idle")
	muzzle.position = definition.muzzle_offset * definition.sprite_scale
	health_bar.place_above(sprite)
	health.reset(stats.max_health)
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if health.is_dead:
		return
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = input * stats.move_speed
	move_and_slide()
	if bounds.has_area():
		global_position = global_position.clamp(bounds.position, bounds.end)

	# Face where you're walking; when standing still, face the mouse.
	# Walking straight up/down keeps the current facing.
	var facing_left := sprite.flip_h
	if input.x != 0.0:
		facing_left = input.x < 0.0
	elif input == Vector2.ZERO:
		facing_left = get_global_mouse_position().x < global_position.x
	sprite.flip_h = facing_left
	muzzle.position.x = -absf(muzzle.position.x) if facing_left else absf(muzzle.position.x)
	sprite.play(&"walk" if input else &"idle")
	_update_prompt()

	_cooldown -= delta
	if _cooldown <= 0.0 and (auto_fire or Input.is_action_pressed(&"fire")):
		_fire()
		_cooldown = 1.0 / stats.attacks_per_second


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and not health.is_dead:
		interact()


## Uses the nearest interactable in reach (towers, build slots, the Core...).
func interact() -> void:
	var target := _nearest_interactable()
	if target:
		target.interact(self)
		_update_prompt()


## Anything in reach with an interact(hero) method counts. It may also have
## get_interact_prompt(hero) -> String to show a hint on screen.
func _nearest_interactable() -> Node:
	var nearest: Node = null
	var nearest_distance := INF
	for area in interact_area.get_overlapping_areas():
		var target: Node = area if area.has_method(&"interact") else area.get_parent()
		if not target.has_method(&"interact"):
			continue
		var distance := global_position.distance_squared_to(area.global_position)
		if distance < nearest_distance:
			nearest = target
			nearest_distance = distance
	return nearest


func _update_prompt() -> void:
	var text := ""
	var target := _nearest_interactable()
	if target and not health.is_dead and target.has_method(&"get_interact_prompt"):
		text = target.get_interact_prompt(self)
	if text != _prompt:
		_prompt = text
		interact_prompt_changed.emit(text)


## Brings a dead hero back at full health.
func revive(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	_cooldown = 0.0
	health.reset(stats.max_health)
	sprite.play(&"idle")


func _fire() -> void:
	var aim := get_global_mouse_position() - muzzle.global_position
	if aim.is_zero_approx():
		aim = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	var bolt: Projectile = BOLT_SCENE.instantiate()
	bolt.global_position = muzzle.global_position
	bolt.direction = aim.normalized()
	bolt.speed = stats.projectile_speed
	bolt.damage = stats.attack_damage
	bolt.max_distance = stats.attack_range
	get_parent().add_child(bolt)


func _on_died() -> void:
	velocity = Vector2.ZERO
	sprite.play(&"death")
	_update_prompt()
	died.emit()
