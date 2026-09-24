class_name TowerDefinition
extends Resource
## Everything that makes one tower type different. To add a tower, create a
## new .tres in data/towers/. Sprites need lv1_idle and lv1_fire animations
## (lv2_/lv3_ once levels exist) and must face right.

@export var id: StringName
@export var display_name: String
@export var sprite_frames: SpriteFrames
## Sprite sheets are drawn large; this shrinks them to fit the 64px tile grid.
@export var sprite_scale: float = 0.55
## Stored resources spent to build it, e.g. {"scrap": 10}.
@export var cost: Dictionary[StringName, int] = {}

@export_group("Stats")
@export var max_health := 150.0
@export var attack_damage := 8.0
@export var attacks_per_second := 1.5
## Targets within this distance of the tower are shot at, in pixels.
@export var attack_range := 260.0
## Pixels per second.
@export var projectile_speed := 650.0

@export_group("Aiming")
## Barrel direction (degrees, 0 = right, -90 = up) drawn in each idle/fire
## frame. The tower shows the frame, or its mirror image, closest to its
## target. Leave empty for towers that don't turn.
@export var aim_angles: PackedFloat32Array = []
## Where shots start: this far above the tower's base...
@export var muzzle_height := 40.0
## ...then this far along the aim direction, in on-screen pixels.
@export var barrel_length := 22.0
