class_name TowerMenu
extends CanvasLayer
## Pop-up for a built tower: repair it and its walls, or sell it (and its
## walls) for part of the cost. Pauses the game while open. Esc or F closes.

@onready var title: Label = %Title
@onready var info: Label = %Info
@onready var repair_button: Button = %RepairButton
@onready var sell_button: Button = %SellButton
@onready var close_button: Button = %CloseButton

var _slot: BuildSlot
var _opened_frame := -1


func _ready() -> void:
	add_to_group(&"tower_menu")
	visible = false
	repair_button.pressed.connect(_on_repair)
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
	title.text = tower.definition.display_name
	var standing := 0
	var damaged := 0
	for wall in _slot.walls:
		if is_instance_valid(wall):
			standing += 1
			if wall.health.current < wall.health.max_health:
				damaged += 1
	var lost := _slot.walls.size() - standing
	info.text = "Tower %d / %d health   ·   Mastery %d XP\nWalls: %d standing (%d damaged), %d destroyed" % [
		ceili(tower.health.current), ceili(tower.health.max_health), floori(tower.mastery_xp),
		standing, damaged, lost]
	var cost := _slot.repair_cost()
	if cost <= 0:
		repair_button.text = "Nothing to repair"
		repair_button.disabled = true
	else:
		var short := cost - _slot.core().stored.get_amount(Loot.SCRAP)
		repair_button.disabled = short > 0
		repair_button.text = "Repair all — %d Scrap" % cost if short <= 0 else "Repair all — need %d more Scrap" % short
	sell_button.text = "Sell — get %s back" % Loot.describe(_slot.sell_value())


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
