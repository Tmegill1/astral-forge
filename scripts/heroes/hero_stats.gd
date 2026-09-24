class_name HeroStats
extends Resource
## Baseline stats shared by every hero. The defaults below ARE the baseline;
## each HeroDefinition scales them with its multipliers when a run starts.
## Add a new stat here and every hero gets it at 1x automatically.

@export var max_health: float = 100.0
## Pixels per second.
@export var move_speed: float = 220.0
@export var attack_damage: float = 10.0
@export var attacks_per_second: float = 1.0
## How far a shot travels, in pixels.
@export var attack_range: float = 500.0
## Pixels per second.
@export var projectile_speed: float = 700.0
