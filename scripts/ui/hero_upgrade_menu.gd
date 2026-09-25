class_name HeroUpgradeMenu
extends CanvasLayer
## Pop-up at the Command Core for buying hero stat ranks with stored
## resources. Pauses the game while open. Esc or F closes.

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
		list.add_child(_row(upgrade))


## One upgrade: "Damage — Rank 2/5 · 12 → 14" and its buy button.
func _row(upgrade: HeroUpgrade) -> Control:
	var rank := _hero.rank_of(upgrade)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override(&"font_size", 14)
	var now := _value(upgrade, rank)
	var button := Button.new()
	button.custom_minimum_size = Vector2(210, 32)
	if rank >= upgrade.max_rank():
		label.text = "%s — Rank %d/%d · %s" % [upgrade.display_name, rank, upgrade.max_rank(), now]
		button.text = "Maxed"
		button.disabled = true
	else:
		label.text = "%s — Rank %d/%d · %s → %s" % [
			upgrade.display_name, rank, upgrade.max_rank(), now, _value(upgrade, rank + 1)]
		var cost := upgrade.cost_for(rank + 1)
		var missing := _core.stored.shortfall(cost)
		button.disabled = not missing.is_empty()
		if missing.is_empty():
			button.text = "Upgrade — %s" % Loot.describe(cost)
		else:
			button.text = "Need %s more" % Loot.describe(missing)
		button.pressed.connect(func() -> void:
			_core.buy_upgrade(_hero, upgrade)
			_refresh())
	row.add_child(label)
	row.add_child(button)
	return row


## The stat's value at `rank`, e.g. "14" or "1.4/s".
func _value(upgrade: HeroUpgrade, rank: int) -> String:
	var value: float = _hero.base_stats.get(upgrade.stat) * upgrade.multiplier(rank)
	if upgrade.stat == &"attacks_per_second":
		return "%.1f/s" % value
	return "%.0f" % value


func _unhandled_input(event: InputEvent) -> void:
	if not visible or Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"manage"):
		close()
		get_viewport().set_input_as_handled()
