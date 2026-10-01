class_name TowerMenu
extends CanvasLayer
## Pop-up for a built tower: repair it and its walls, upgrade it (walls
## too), or sell it (and its walls) for part of what was spent. Pauses the
## game while open. Esc or F closes.

@onready var title: Label = %Title
@onready var info: Label = %Info
@onready var repair_button: Button = %RepairButton
@onready var upgrade_button: Button = %UpgradeButton
@onready var sell_button: Button = %SellButton
@onready var close_button: Button = %CloseButton

var _slot: BuildSlot
var _opened_frame := -1


func _ready() -> void:
	add_to_group(&"tower_menu")
	visible = false
	repair_button.pressed.connect(_on_repair)
	upgrade_button.pressed.connect(_on_upgrade)
	sell_button.pressed.connect(_on_sell)
	close_button.pressed.connect(close)


func open(slot: BuildSlot) -> void:
	_slot = slot
	_opened_frame = Engine.get_process_frames()
	_refresh()
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	_slot = null
	get_tree().paused = false


func _refresh() -> void:
	var tower := _slot.built
	title.text = "%s — Lv%d" % [tower.definition.display_name, tower.level]
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
	if tower.level >= TowerDefinition.MAX_LEVEL:
		upgrade_button.disabled = true
		upgrade_button.text = "Max level"
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
	_slot.upgrade()
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
		close()
		get_viewport().set_input_as_handled()
