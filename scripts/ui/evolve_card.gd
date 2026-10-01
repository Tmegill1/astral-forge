class_name EvolveCard
extends PanelContainer
## One evolution branch in the tower menu's evolve view: picture, name, what
## changes, its Q ability and a Choose button. Layout in
## scenes/ui/evolve_card.tscn; show_branch() fills it in.

signal chosen(branch: TowerDefinition)

var _branch: TowerDefinition

@onready var icon: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var description: Label = %Description
@onready var ability: Label = %Ability
@onready var choose_button: Button = %ChooseButton


func _ready() -> void:
	choose_button.pressed.connect(func() -> void: chosen.emit(_branch))


## Fills the card in for `branch`; greyed out when `stored` can't pay.
func show_branch(branch: TowerDefinition, stored: ResourceBag) -> void:
	_branch = branch
	icon.texture = branch.icon()
	icon.modulate = branch.tint
	name_label.text = branch.display_name
	description.text = branch.help_line
	ability.text = "Q: %s — %s" % [branch.ability_name, branch.ability_text]
	var missing := stored.shortfall(branch.evolve_cost)
	choose_button.disabled = not missing.is_empty()
	if missing.is_empty():
		choose_button.text = "Choose — %s" % Loot.describe(branch.evolve_cost)
	else:
		choose_button.text = "Need %s more" % Loot.describe(missing)
	modulate = Color.WHITE if missing.is_empty() else Color(1, 1, 1, 0.55)
