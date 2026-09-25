class_name TurretHead
extends Resource
## One level's rotating-head art, made by tools/split_turret.py: a static
## base plus a head that turns to face any direction.

@export var base_texture: Texture2D
@export var head_texture: Texture2D
## Where the head turns, relative to the tower's base point, in texture pixels.
@export var pivot := Vector2.ZERO
## Direction the barrel points in head_texture (degrees, 0 = right, -90 = up).
@export var drawn_angle := 0.0
## Pivot to barrel tip, in texture pixels.
@export var barrel_length := 0.0
