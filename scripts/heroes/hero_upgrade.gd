class_name HeroUpgrade
extends Resource
## One stat the hero can buy ranks in at the Command Core. Each rank adds
## bonus_per_rank of the hero's starting value (not compounding). To add
## one, create a .tres in data/hero_upgrades/ and list it on the hero.

@export var id: StringName
@export var display_name: String
## The HeroStats property it raises, e.g. &"attack_damage".
@export var stat: StringName
## Share of the starting value added per rank (0.2 = +20%).
@export var bonus_per_rank := 0.2
## Price of each rank in order (index 0 = rank 1); one entry per rank.
@export var scrap_costs: PackedInt32Array = [12, 20, 30, 40, 55]
@export var aether_costs: PackedInt32Array = [0, 0, 1, 2, 3]


func max_rank() -> int:
	return scrap_costs.size()


## What buying `rank` (1 = the first) costs.
func cost_for(rank: int) -> Dictionary[StringName, int]:
	var cost: Dictionary[StringName, int] = {Loot.SCRAP: scrap_costs[rank - 1]}
	if aether_costs[rank - 1] > 0:
		cost[Loot.AETHER] = aether_costs[rank - 1]
	return cost


## Multiplier on the starting value at `rank`.
func multiplier(rank: int) -> float:
	return 1.0 + bonus_per_rank * rank
