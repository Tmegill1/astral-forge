class_name CommandCore
extends StaticBody2D
## The heart of the fortress. Enemies march on it; when its health hits
## zero the run is lost. Its look changes as it takes damage.

signal destroyed

@export var max_health := 500.0
## How far from the centre enemies can hit it from, in pixels.
@export var hit_radius := 95.0
@export var intact_texture: Texture2D
@export var damaged_texture: Texture2D
@export var ruined_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite
@onready var health: Health = $Health


func _ready() -> void:
	health.changed.connect(_on_health_changed)
	health.died.connect(destroyed.emit)
	health.reset(max_health)


func _on_health_changed(current: float, maximum: float) -> void:
	var ratio := current / maximum
	if ratio > 0.66:
		sprite.texture = intact_texture
	elif ratio > 0.33:
		sprite.texture = damaged_texture
	else:
		sprite.texture = ruined_texture
