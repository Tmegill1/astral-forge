class_name HeroDefinition
extends Resource
## Everything that makes one hero different from another. To add a hero,
## create a new .tres in data/heroes/ — no code changes needed.

@export var id: StringName
@export var display_name: String
@export var sprite_frames: SpriteFrames
## Sprite sheets are drawn large; this shrinks them to fit the 64px tile grid.
@export var sprite_scale: float = 0.5
## Where shots leave from, in unscaled sprite pixels relative to the feet,
## for a hero facing right.
@export var muzzle_offset := Vector2(50, -88)
## Stat name -> multiplier on top of the HeroStats baseline, e.g.
## {"max_health": 0.9} gives this hero 90% of the baseline health.
## Stats not listed stay at 1x.
@export var stat_multipliers: Dictionary[StringName, float] = {}


## Returns this hero's final stats: the baseline with multipliers applied.
func build_stats(base: HeroStats = HeroStats.new()) -> HeroStats:
	var stats: HeroStats = base.duplicate()
	for stat: StringName in stat_multipliers:
		if not stat in stats:
			push_error("Hero '%s' has a multiplier for unknown stat '%s'" % [id, stat])
			continue
		stats.set(stat, stats.get(stat) * stat_multipliers[stat])
	return stats
