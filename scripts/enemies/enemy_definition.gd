class_name EnemyDefinition
extends Resource
## Everything that makes one enemy type different. To add an enemy, create a
## new .tres in data/enemies/ — no code changes needed. Sprites must face
## right and have idle, walk and death animations, plus the attack animation
## (`attack` unless set below).

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
## Animation played for each attack; the hit (or shot) comes on attack_hit_frame.
@export var attack_animation: StringName = &"attack"
## When set, each attack throws this projectile (magic damage) at the target
## instead of hitting it directly. Empty = melee.
@export var projectile_scene: PackedScene
## Pixels per second.
@export var projectile_speed := 260.0

@export_group("Armour")
## Share of each kind of damage that gets through (1 = all, 0.3 = 30%).
@export var physical_taken := 1.0
@export var fire_taken := 1.0
@export var magic_taken := 1.0

@export_group("Loot")
## Resource type -> (min, max) dropped on death, e.g. {"scrap": (1, 2)}.
@export var drops: Dictionary[StringName, Vector2i] = {}
## Resource type -> chance (0 to 1) of also dropping exactly one on death,
## e.g. {"aether": 0.05}.
@export var rare_drops: Dictionary[StringName, float] = {}

@export_group("Frenzy pulse")
## Seconds between pulses that frenzy nearby enemies. 0 = never pulses.
@export var pulse_interval := 0.0
## How far a pulse reaches, in pixels.
@export var pulse_radius := 160.0
## Seconds each pulse's frenzy lasts.
@export var pulse_duration := 4.0
## Extra move speed while frenzied (0.3 = +30%).
@export var pulse_speed_bonus := 0.3
## Extra attack damage while frenzied (0.3 = +30%).
@export var pulse_damage_bonus := 0.3
## Played while casting a pulse (must not loop); the frenzy lands when it ends.
@export var pulse_animation: StringName = &"buff"
