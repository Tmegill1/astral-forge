class_name HeroUpgradeMenu
extends CanvasLayer
## Pop-up at the Command Core for buying hero stat ranks with stored
## resources. Pauses the game while open. Esc or F closes.

const ROW_SCENE := preload("res://scenes/ui/upgrade_row.tscn")

@onready var title: Label = %Title
@onready var stored_text: Label = %StoredText
@onready var list: VBoxContainer = %List
@onready var close_button: Button = %CloseButton

var _core: CommandCore
var _hero: Hero
var _opened_frame := -1


func _ready() -> void:
	add_to_group(&"hero_upgrade_menu")
	visible = false
	close_button.pressed.connect(close)


func open(core: CommandCore, hero: Hero) -> void:
	_core = core
	_hero = hero
	_opened_frame = Engine.get_process_frames()
	_refresh()
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


func _refresh() -> void:
	title.text = "Upgrade %s" % _hero.definition.display_name
	var have := _core.stored.describe()
	stored_text.text = "Stored: %s" % (have if have != "" else "nothing")
	for child in list.get_children():
		child.queue_free()
	for upgrade in _hero.definition.upgrades:
		var row: UpgradeRow = ROW_SCENE.instantiate()
		list.add_child(row)
		_show_row(row, upgrade)


## One upgrade: "Damage — Rank 2/5 · 12 → 14" and its buy button.
func _show_row(row: UpgradeRow, upgrade: HeroUpgrade) -> void:
	var rank := _hero.rank_of(upgrade)
	var now := _value(upgrade, rank)
	if rank >= upgrade.max_rank():
		row.show_upgrade("%s — Rank %d/%d · %s" % [upgrade.display_name, rank, upgrade.max_rank(), now],
				"Maxed", false)
		return
	var cost := upgrade.cost_for(rank + 1)
	var missing := _core.stored.shortfall(cost)
	row.show_upgrade("%s — Rank %d/%d · %s → %s" % [
			upgrade.display_name, rank, upgrade.max_rank(), now, _value(upgrade, rank + 1)],
			"Upgrade — %s" % Loot.describe(cost) if missing.is_empty() else "Need %s more" % Loot.describe(missing),
			missing.is_empty())
	row.bought.connect(func() -> void:
		_core.buy_upgrade(_hero, upgrade)
		_refresh())


## Hero stat -> the power-up card bonus that also scales it.
const CARD_STATS := {&"attack_damage": &"hero_damage", &"attacks_per_second": &"hero_fire_rate",
		&"move_speed": &"hero_move_speed", &"max_health": &"hero_max_health"}


## The stat's value at `rank` with any card bonus, e.g. "14" or "1.4/s".
func _value(upgrade: HeroUpgrade, rank: int) -> String:
	var value: float = _hero.base_stats.get(upgrade.stat) * upgrade.multiplier(rank)
	if CARD_STATS.has(upgrade.stat):
		value *= RunCards.multiplier(self, CARD_STATS[upgrade.stat])
	if upgrade.stat == &"attacks_per_second":
		return "%.1f/s" % value
	return "%.0f" % value


func _unhandled_input(event: InputEvent) -> void:
	if not visible or Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"manage"):
		close()
		get_viewport().set_input_as_handled()
