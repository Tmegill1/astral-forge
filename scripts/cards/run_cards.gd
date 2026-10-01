class_name RunCards
extends Node
## This run's XP, level and power-up cards (a node in the world scene, so a
## new run starts fresh). Other scripts fold card bonuses into their stats
## with RunCards.multiplier(self, &"stat").

## Emitted once per level gained; the card menu offers a pick for each.
signal leveled_up(new_level: int)
signal xp_changed
## A card was taken.
signal changed

const FIRST_LEVEL_XP := 8
## Each level costs this many times the one before.
const LEVEL_GROWTH := 1.5
const CARD_DIR := "res://data/cards/"

var xp := 0
var level := 1
## Card id -> rank owned.
var ranks: Dictionary[StringName, int] = {}
## Set when the run is over: no more XP or level-ups.
var ended := false
var pool: Array[CardDefinition] = []


func _ready() -> void:
	add_to_group(&"run_cards")
	if pool.is_empty():
		pool = load_pool()


## Every card in data/cards/.
static func load_pool() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for file in ResourceLoader.list_directory(CARD_DIR):
		if not file.ends_with(".tres"):
			continue
		var card := load(CARD_DIR + file) as CardDefinition
		if card:
			cards.append(card)
	return cards


## XP needed to go from `for_level` to the next: 8, 12, 18, 27, 41, ...
static func xp_for_level(for_level: int) -> int:
	return roundi(FIRST_LEVEL_XP * pow(LEVEL_GROWTH, for_level - 1))


## 1 + this run's card bonus for `stat`, or 1 outside a run.
static func multiplier(node: Node, stat: StringName) -> float:
	if node == null or not node.is_inside_tree():
		return 1.0
	var cards := node.get_tree().get_first_node_in_group(&"run_cards") as RunCards
	return 1.0 + cards.bonus(stat) if cards else 1.0


func add_xp(amount: int) -> void:
	if ended or amount <= 0:
		return
	xp += amount
	while xp >= xp_for_level(level):
		xp -= xp_for_level(level)
		level += 1
		leveled_up.emit(level)
	xp_changed.emit()


## Up to `count` different cards that still have ranks to give.
func offer(count := 3) -> Array[CardDefinition]:
	var open: Array[CardDefinition] = []
	for card in pool:
		if rank_of(card) < card.max_rank:
			open.append(card)
	open.shuffle()
	return open.slice(0, count)


func rank_of(card: CardDefinition) -> int:
	return ranks.get(card.id, 0)


func take(card: CardDefinition) -> void:
	ranks[card.id] = rank_of(card) + 1
	changed.emit()


## Total bonus for `stat` from every card owned (0.4 = +40%).
func bonus(stat: StringName) -> float:
	var total := 0.0
	for card in pool:
		var rank := rank_of(card)
		if rank > 0 and card.stat_bonuses.has(stat):
			total += card.stat_bonuses[stat] * rank
	return total


## Rank of the card with this mod (0 if not owned).
func mod_rank(mod: StringName) -> int:
	for card in pool:
		if card.mod == mod:
			return rank_of(card)
	return 0


func end_run() -> void:
	ended = true
