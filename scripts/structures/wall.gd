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
## World area where this piece's art isn't drawn (its tower's pad); empty = none.
var art_hidden_area := Rect2()

@onready var sprite: Sprite2D = $Sprite
@onready var health_bar: Node2D = $HealthBar
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


## Keeps the art off `area` (the tower's pad, in world space) so walls look
## like they come out of the pad's edge instead of cutting across the tower.
## A piece standing on the pad is hidden; one reaching onto it from the side
## is cropped at the edge. Only the art changes: the piece still blocks.
func hide_art_within(area: Rect2) -> void:
	art_hidden_area = area
	_apply_art_crop()


## The part of `art` (left, right x) left over once `area` (left, right x)
## is cut away from the side it overlaps; zero length when nothing is left.
static func kept_span(art: Vector2, area: Vector2) -> Vector2:
	if art.y <= area.x or art.x >= area.y:
		return art
	if art.x < area.x:
		return Vector2(art.x, area.x)
	if art.y > area.y:
		return Vector2(area.y, art.y)
	return Vector2(art.x, art.x)


func _apply_art_crop() -> void:
	var area := art_hidden_area
	if not area.has_area():
		return
	var base := global_position
	var size := sprite.texture.get_size() * sprite_scale
	var art := Vector2(base.x - size.x / 2.0, base.x + size.x / 2.0)
	var top := base.y - size.y
	var kept := art
	var kept_top := top
	if base.y >= area.position.y and base.y <= area.end.y:
		# Level with the pad: cut off the side that reaches across it.
		kept = kept_span(art, Vector2(area.position.x, area.end.x))
	elif base.y > area.end.y and top < area.end.y and art.x < area.end.x and art.y > area.position.x:
		# Just in front of the pad: the art stands up over its edge.
		kept_top = area.end.y
	var visible_art := kept.y - kept.x > 1.0 and base.y - kept_top > 1.0
	sprite.visible = visible_art
	health_bar.visible = visible_art
	sprite.region_enabled = kept != art or kept_top != top
	var region_height := (base.y - kept_top) / sprite_scale
	if sprite.region_enabled:
		sprite.region_rect = Rect2((kept.x - art.x) / sprite_scale, (kept_top - top) / sprite_scale,
				(kept.y - kept.x) / sprite_scale, region_height)
	# Keep the (cropped) art standing on the piece's base.
	sprite.offset.y = -region_height / 2.0
	sprite.position.x = (kept.x + kept.y) / 2.0 - base.x


func nav_footprint() -> Rect2:
	return Rect2(global_position + Vector2(-footprint.x / 2.0, -footprint.y), footprint)


func _on_health_changed(current: float, maximum: float) -> void:
	sprite.texture = intact_texture if current > maximum * 0.5 else damaged_texture
	_apply_art_crop()


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
