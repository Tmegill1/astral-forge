class_name Wall
extends StaticBody2D
## One piece of wall: blocks movement and enemy paths, can be attacked,
## looks broken below half health, and is removed when destroyed.
## A BuildSlot lays these out around its tower.

signal destroyed(wall: Wall)

const DEFAULT_MAX_HEALTH := 120.0

@export var max_health := DEFAULT_MAX_HEALTH
## How far from its base enemies can hit it from, in pixels.
@export var hit_radius := 14.0

var intact_texture: Texture2D
var damaged_texture: Texture2D
## Size of the solid base, in pixels (width across, depth front-to-back).
var footprint := Vector2(20, 14)
var sprite_scale := 0.4

@onready var sprite: Sprite2D = $Sprite
@onready var body: CollisionShape2D = $Body
@onready var health: Health = $Health


## Call before adding the wall to the scene tree.
func setup(intact: Texture2D, damaged: Texture2D, base_size: Vector2, art_scale: float) -> void:
	intact_texture = intact
	damaged_texture = damaged
	footprint = base_size
	sprite_scale = art_scale


func _ready() -> void:
	sprite.texture = intact_texture
	sprite.scale = Vector2.ONE * sprite_scale
	# Stand the art on the wall's origin so y-sorting uses its base.
	sprite.offset = Vector2(0, -intact_texture.get_height() / 2.0)
	var shape := RectangleShape2D.new()
	shape.size = footprint
	body.shape = shape
	body.position = Vector2(0, -footprint.y / 2.0)
	health.changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	health.reset(max_health * RunCards.multiplier(self, &"structure_health"))


## Switches to another level's art and maximum health, keeping the damage
## taken (for a tower upgrade).
func restyle(intact: Texture2D, damaged: Texture2D, new_max: float) -> void:
	intact_texture = intact
	damaged_texture = damaged
	max_health = new_max
	sprite.offset = Vector2(0, -intact_texture.get_height() / 2.0)
	health.grow_max(new_max * RunCards.multiplier(self, &"structure_health"))
	_on_health_changed(health.current, health.max_health)


func nav_footprint() -> Rect2:
	return Rect2(global_position + Vector2(-footprint.x / 2.0, -footprint.y), footprint)


func _on_health_changed(current: float, maximum: float) -> void:
	sprite.texture = intact_texture if current > maximum * 0.5 else damaged_texture


func _on_died() -> void:
	remove_from_group(&"nav_blockers")
	destroyed.emit(self)
	get_tree().call_group(&"nav_grid", &"mark_dirty")
	queue_free()


## Re-applies card bonuses to max health (adds the difference to current).
func refresh_max_health() -> void:
	var target := max_health * RunCards.multiplier(self, &"structure_health")
	if not health.is_dead and not is_equal_approx(health.max_health, target):
		health.grow_max(target)
