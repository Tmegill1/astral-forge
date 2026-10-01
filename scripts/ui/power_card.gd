class_name PowerCard
extends PanelContainer
## One choice on the level-up screen: category, title, what it does, the
## rank it would reach, and its number key.

signal chosen

const CATEGORY_COLORS := {
	"Hero": Color(1.0, 0.82, 0.45), "Towers": Color(0.55, 0.75, 1.0),
	"Fortress": Color(0.55, 0.9, 0.6)}

var card: CardDefinition

@onready var category_label: Label = %Category
@onready var title_label: Label = %Title
@onready var description_label: Label = %Description
@onready var rank_label: Label = %Rank
@onready var choose_button: Button = %Choose


func _ready() -> void:
	choose_button.pressed.connect(chosen.emit)


func show_card(card_definition: CardDefinition, next_rank: int, key: int) -> void:
	card = card_definition
	category_label.text = card.category.to_upper()
	category_label.add_theme_color_override(&"font_color",
			CATEGORY_COLORS.get(card.category, Color.WHITE))
	title_label.text = card.title
	description_label.text = card.description
	rank_label.text = "Rank %d / %d" % [next_rank, card.max_rank]
	choose_button.text = "Choose  [%d]" % key


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit()
		accept_event()
