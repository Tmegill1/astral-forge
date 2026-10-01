class_name TowerMenu
extends CanvasLayer
## Pop-up for a built tower: repair it and its walls, upgrade it (walls
## too), evolve it at Lv3, or sell it (and its walls) for part of what was spent. Pauses the
## game while open. Esc or F closes.

const EVOLVE_CARD_SCENE := preload("res://scenes/ui/evolve_card.tscn")

@onready var title: Label = %Title
@onready var info: Label = %Info
@onready var repair_button: Button = %RepairButton
@onready var upgrade_button: Button = %UpgradeButton
@onready var sell_button: Button = %SellButton
@onready var close_button: Button = %CloseButton
@onready var evolve_view: VBoxContainer = %EvolveView
@onready var branches: HBoxContainer = %Branches
@onready var back_button: Button = %BackButton
## Everything hidden while the evolve view shows.
@onready var _main_rows: Array[Control] = [info, repair_button, upgrade_button, sell_button, close_button]

var _slot: BuildSlot
var _opened_frame := -1


func _ready() -> void:
	add_to_group(&"tower_menu")
	visible = false
	repair_button.pressed.connect(_on_repair)
	upgrade_button.pressed.connect(_on_upgrade)
	sell_button.pressed.connect(_on_sell)
	close_button.pressed.connect(close)
	back_button.pressed.connect(_show_evolve.bind(false))


func open(slot: BuildSlot) -> void:
	_slot = slot
	_opened_frame = Engine.get_process_frames()
	_show_evolve(false)
	_refresh()
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	_slot = null
	get_tree().paused = false


func _refresh() -> void:
	var tower := _slot.built
	var def := tower.definition
	title.text = ("%s (Evolved)" % def.display_name) if def.evolved \
			else "%s — Lv%d" % [def.display_name, tower.level]
	var standing := 0
	var damaged := 0
	for wall in _slot.walls:
		if is_instance_valid(wall):
			standing += 1
			if wall.health.current < wall.health.max_health:
				damaged += 1
	var lost := _slot.walls.size() - standing
	info.text = "Tower %d / %d health\nWalls: %d standing (%d damaged), %d destroyed" % [
		ceili(tower.health.current), ceili(tower.health.max_health),
		standing, damaged, lost]
	_refresh_upgrade(tower)
	var cost := _slot.repair_cost()
	if cost <= 0:
		repair_button.text = "Nothing to repair"
		repair_button.disabled = true
	else:
		var short := cost - _slot.core().stored.get_amount(Loot.SCRAP)
		repair_button.disabled = short > 0
		repair_button.text = "Repair all — %d Scrap" % cost if short <= 0 else "Repair all — need %d more Scrap" % short
	sell_button.text = "Sell — get %s back" % Loot.describe(_slot.sell_value())


## Next-level preview under the info text, and the Upgrade button's state.
func _refresh_upgrade(tower: Tower) -> void:
	if tower.definition.evolved:
		upgrade_button.disabled = true
		upgrade_button.text = "Fully evolved"
		return
	if tower.level >= TowerDefinition.MAX_LEVEL:
		if not _slot.can_evolve():
			upgrade_button.disabled = true
			upgrade_button.text = "Max level"
			return
		# Every branch costs the same; the evolve view greys out what can't be paid.
		var evolve_cost := tower.definition.evolutions[0].evolve_cost
		var short := _slot.core().stored.shortfall(evolve_cost)
		upgrade_button.disabled = false
		upgrade_button.text = "Evolve — %s" % Loot.describe(evolve_cost) if short.is_empty() \
				else "Evolve — need %s more" % Loot.describe(short)
		return
	var def := tower.definition
	var next := tower.level + 1
	# Power-up card bonuses apply to every level.
	var damage := RunCards.multiplier(self, &"tower_damage")
	var rate := RunCards.multiplier(self, &"tower_fire_rate")
	var reach := RunCards.multiplier(self, &"tower_range")
	var toughness := RunCards.multiplier(self, &"structure_health")
	info.text += "\nNext: damage %.0f → %.0f · %.1f → %.1f shots/s · range %.0f → %.0f · health %.0f → %.0f" % [
		def.damage_at(tower.level) * damage, def.damage_at(next) * damage,
		def.fire_rate_at(tower.level) * rate, def.fire_rate_at(next) * rate,
		def.range_at(tower.level) * reach, def.range_at(next) * reach,
		def.max_health_at(tower.level) * toughness, def.max_health_at(next) * toughness]
	var cost := def.upgrade_cost(next)
	var missing := _slot.core().stored.shortfall(cost)
	upgrade_button.disabled = not missing.is_empty()
	if missing.is_empty():
		upgrade_button.text = "Upgrade to Lv%d — %s" % [next, Loot.describe(cost)]
	else:
		upgrade_button.text = "Upgrade to Lv%d — need %s more" % [next, Loot.describe(missing)]


func _on_upgrade() -> void:
	if _slot.can_evolve():
		_show_evolve(true)
		return
	_slot.upgrade()
	_refresh()


## Switches between the normal view and the two evolution cards.
func _show_evolve(on: bool) -> void:
	for control in _main_rows:
		control.visible = not on
	evolve_view.visible = on
	for child in branches.get_children():
		branches.remove_child(child)
		child.queue_free()
	if not on:
		return
	for branch in _slot.built.definition.evolutions:
		var card: EvolveCard = EVOLVE_CARD_SCENE.instantiate()
		branches.add_child(card)
		card.show_branch(branch, _slot.core().stored)
		card.chosen.connect(_on_evolve)
	back_button.grab_focus()


func _on_evolve(branch: TowerDefinition) -> void:
	if _slot.evolve(branch):
		_show_evolve(false)
		_refresh()


func _on_repair() -> void:
	_slot.repair()
	_refresh()


func _on_sell() -> void:
	var slot := _slot
	close()
	slot.sell()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"manage"):
		if evolve_view.visible:
			_show_evolve(false)
		else:
			close()
		get_viewport().set_input_as_handled()
