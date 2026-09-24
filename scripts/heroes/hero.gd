class_name Hero
extends CharacterBody2D
## The player's hero. Every hero uses this script; what differs (art, stats)
## comes from the HeroDefinition passed to setup() before the hero spawns.
##
## Controls: WASD to move (the hero faces the way it walks), or right-click
## to walk to a spot (hold it to keep following the cursor); mouse to aim;
## E to interact. Shooting is automatic toward the mouse unless auto_fire is
## off, then hold left mouse to shoot. Picked-up resources go into `carried`
## until deposited at the Core.
##
## Pressing E at a tower operates it: the hero is anchored beside it, the
## tower aims at the mouse with boosted stats, Q / right-click uses its
## ability, and the camera zooms out. E again leaves instantly.

signal died
## Text for the nearest interactable ("[E] Deposit ..."), or "" for none.
signal interact_prompt_changed(text: String)
## The tower now being operated, or null after leaving one.
signal operating_changed(tower: Tower)

const BOLT_SCENE := preload("res://scenes/projectiles/hero_bolt.tscn")

## When false, the hero only shoots while the "fire" action is held.
@export var auto_fire := true
## How far from the hero's feet enemies can hit it from, in pixels.
@export var hit_radius := 12.0
## Camera zoom while operating a tower; 0.8 = zoomed out 20%.
@export var operating_zoom := 0.8
## Right-click movement stops this close to the target, in pixels.
@export var arrive_distance := 6.0

var definition: HeroDefinition
## Final stats for this run: baseline x this hero's multipliers.
var stats: HeroStats
## World-space area the hero can't leave. Empty means no limit.
var bounds := Rect2()
## Resources picked up but not yet deposited; at risk if the hero falls.
var carried := ResourceBag.new()
## The tower being operated, or null.
var operating: Tower
## The area the camera may show (the map). When the zoomed-out view is
## bigger than this, the map is centred instead.
var camera_bounds := Rect2()

var _cooldown := 0.0
var _prompt := ""
## Where right-click movement is heading; null when not click-moving.
var _move_target: Variant = null

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


func _process(_delta: float) -> void:
	_update_camera_limits()


func _physics_process(delta: float) -> void:
	if health.is_dead:
		return
	if operating:
		sprite.flip_h = get_global_mouse_position().x < global_position.x
		sprite.play(&"idle")
		_update_prompt()
		return
	var input := _movement_input()
	velocity = input * stats.move_speed
	move_and_slide()
	if bounds.has_area():
		global_position = global_position.clamp(bounds.position, bounds.end)
	# Walked into something (the Core, a tower) on the way: give up.
	if _move_target != null and input != Vector2.ZERO \
			and get_real_velocity().length() < stats.move_speed * 0.1:
		_move_target = null
	queue_redraw()

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


## WASD wins; otherwise head for the right-click target. Holding right-click
## keeps moving the target to the cursor.
func _movement_input() -> Vector2:
	var keys := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if keys != Vector2.ZERO:
		_move_target = null
		return keys
	if Input.is_action_pressed(&"move_to"):
		var target := get_global_mouse_position()
		_move_target = target.clamp(bounds.position, bounds.end) if bounds.has_area() else target
	if _move_target == null:
		return Vector2.ZERO
	var to_target: Vector2 = _move_target - global_position
	if to_target.length() <= arrive_distance:
		_move_target = null
		return Vector2.ZERO
	# Slow down on the last step so the hero lands on the spot, not past it.
	return to_target.normalized() * minf(1.0, to_target.length() / (stats.move_speed / 60.0))


## Small ring on the ground where a right-click is heading.
func _draw() -> void:
	if _move_target == null:
		return
	var at: Vector2 = _move_target - global_position
	draw_arc(at, 7.0, 0.0, TAU, 24, Color(1.0, 0.92, 0.6, 0.8), 1.5)
	draw_circle(at, 2.0, Color(1.0, 0.92, 0.6, 0.8))


func _unhandled_input(event: InputEvent) -> void:
	if health.is_dead:
		return
	if event.is_action_pressed(&"interact"):
		interact()
	elif event.is_action_pressed(&"tower_ability") and operating:
		operating.use_ability()


func start_operating(tower: Tower) -> void:
	if operating:
		stop_operating()
	operating = tower
	_move_target = null
	queue_redraw()
	tower.set_operator(self)
	global_position = tower.operator_position()
	velocity = Vector2.ZERO
	_zoom_to(operating_zoom)
	operating_changed.emit(tower)


func stop_operating() -> void:
	if operating == null:
		return
	operating.set_operator(null)
	global_position = operating.exit_position()
	operating = null
	_zoom_to(1.0)
	operating_changed.emit(null)


func _zoom_to(zoom: float) -> void:
	create_tween().tween_property(camera, "zoom", Vector2.ONE * zoom, 0.25) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Keeps the camera inside camera_bounds; if the view is bigger than the
## bounds on an axis, centres the bounds on that axis instead.
func _update_camera_limits() -> void:
	if not camera_bounds.has_area():
		return
	var view := get_viewport_rect().size / camera.zoom
	var area := camera_bounds
	for axis in 2:
		if area.size[axis] < view[axis]:
			area.position[axis] -= (view[axis] - area.size[axis]) / 2.0
			area.size[axis] = view[axis]
	camera.limit_left = floori(area.position.x)
	camera.limit_top = floori(area.position.y)
	camera.limit_right = ceili(area.end.x)
	camera.limit_bottom = ceili(area.end.y)


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
	stop_operating()
	_move_target = null
	queue_redraw()
	velocity = Vector2.ZERO
	sprite.play(&"death")
	_update_prompt()
	died.emit()
