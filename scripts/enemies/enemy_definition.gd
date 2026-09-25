class_name EnemyDefinition
extends Resource
## Everything that makes one enemy type different. To add an enemy, create a
## new .tres in data/enemies/ — no code changes needed. Sprites must face
## right and have idle, walk, attack and death animations.

@export var id: StringName
@export var display_name: String
@export var sprite_frames: SpriteFrames
## Sprite sheets are drawn large; this shrinks them to fit the 64px tile grid.
@export var sprite_scale: float = 0.35
## Size of the area shots can hit, relative to the visible sprite.
## Above 1 is more forgiving, so shots aimed at the body don't slip past.
@export var hurtbox_padding: float = 1.25

@export_group("Stats")
@export var max_health := 30.0
## Pixels per second.
@export var move_speed := 70.0
@export var attack_damage := 5.0
@export var attacks_per_second := 1.0
## Gap between the enemy and its target's edge when it stops to attack, in pixels.
@export var attack_range := 20.0
## A living hero closer than this becomes the target instead of the Core.
@export var aggro_range := 140.0
## Frame of the attack animation where the hit lands.
@export var attack_hit_frame := 3

@export_group("Loot")
## Resource type -> (min, max) dropped on death, e.g. {"scrap": (1, 2)}.
@export var drops: Dictionary[StringName, Vector2i] = {}
## Resource type -> chance (0 to 1) of also dropping exactly one on death,
## e.g. {"aether": 0.05}.
@export var rare_drops: Dictionary[StringName, float] = {}
