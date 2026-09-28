class_name BuildCard
extends PanelContainer
## One tower in the build menu: picture, name, description, stats and a
## Build button. The layout lives in scenes/ui/build_card.tscn; show_tower()
## fills it in.

signal chosen(tower: TowerDefinition)

var _tower: TowerDefinition

@onready var icon: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var description: Label = %Description
@onready var stats: Label = %Stats
@onready var build_button: Button = %BuildButton


func _ready() -> void:
	build_button.pressed.connect(func() -> void: chosen.emit(_tower))


## Fills the card in for `tower`, numbered for its hotkey. Greyed out when it
## isn't available yet or `stored` can't pay for it.
func show_tower(number: int, tower: TowerDefinition, stored: ResourceBag) -> void:
	_tower = tower
	icon.texture = tower.icon()
	name_label.text = "%d. %s" % [number, tower.display_name]
	description.text = tower.description
	stats.visible = tower.available
	stats.text = "Damage %.0f · %.1f/s · Range %.0f" % [
			tower.attack_damage, tower.attacks_per_second, tower.attack_range]
	var missing := stored.shortfall(tower.cost)
	if not tower.available:
		build_button.text = "Coming soon"
		build_button.disabled = true
	elif not missing.is_empty():
		build_button.text = "Need %s more" % Loot.describe(missing)
		build_button.disabled = true
	else:
		build_button.text = "Build — %s" % Loot.describe(tower.cost)
		build_button.disabled = false
	modulate = Color.WHITE if not build_button.disabled else Color(1, 1, 1, 0.55)
