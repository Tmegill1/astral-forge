class_name CardDefinition
extends Resource
## One power-up card. Each rank adds `stat_bonuses` again (e.g. 0.2 =
## +20% per rank); a `mod` id turns on special behaviour the hero code checks
## with RunCards.mod_rank(). New card = new .tres in data/cards/.

@export var id: StringName
@export var title := ""
## One line saying what one rank does.
@export var description := ""
## "Hero", "Towers" or "Fortress".
@export var category := "Hero"
@export var max_rank := 3
## Stat id -> bonus per rank. Stat ids: hero_damage, hero_fire_rate,
## hero_move_speed, hero_max_health, tower_damage, tower_fire_rate,
## tower_range, structure_health, core_max_health, scrap_drops, pull_radius.
@export var stat_bonuses: Dictionary[StringName, float] = {}
## Special behaviour: arc_bolts, split_shot or ember_rounds. Empty = none.
@export var mod: StringName
