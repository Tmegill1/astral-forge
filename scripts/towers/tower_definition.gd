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

@export_group("Operated")
## Multipliers while the hero operates the tower (the design's starting
## point: clearly better than automatic, not just a hidden bonus).
@export var operated_damage_multiplier := 1.35
@export var operated_fire_rate_multiplier := 1.5
@export var operated_range_multiplier := 1.15

@export_group("Ability")
## Active ability while operated. For now every ability is a timed fire-rate
## burst; towers with other kinds of abilities will extend this.
@export var ability_name := "Rapid Fire"
@export var ability_duration := 3.0
@export var ability_cooldown := 12.0
@export var ability_fire_rate_multiplier := 3.0

@export_group("Rotating head")
## Optional: a static base plus a head that turns to face any direction
## (made by tools/split_turret.py). When set, these replace the idle/fire
## frames and aim_angles below.
@export var base_texture: Texture2D
@export var head_texture: Texture2D
## Where the head turns, relative to the tower's base point, in texture pixels.
@export var head_pivot := Vector2.ZERO
## Direction the barrel points in head_texture (degrees, 0 = right, -90 = up).
@export var head_drawn_angle := 0.0
## Pivot to barrel tip, in texture pixels.
@export var head_barrel_length := 0.0
## Degrees per second the head can turn.
@export var head_turn_speed := 720.0

@export_group("Aiming")
## Barrel direction (degrees, 0 = right, -90 = up) drawn in each idle/fire
## frame. The tower shows the frame, or its mirror image, closest to its
## target. Leave empty for towers that don't turn. Ignored with a rotating head.
@export var aim_angles: PackedFloat32Array = []
## Where shots start: this far above the tower's base...
@export var muzzle_height := 40.0
## ...then this far along the aim direction, in on-screen pixels.
@export var barrel_length := 22.0
