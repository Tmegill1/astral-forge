class_name UpgradeRow
extends HBoxContainer
## One hero upgrade in the Core's upgrade menu: what it does now and next,
## and its buy button. The layout lives in scenes/ui/upgrade_row.tscn; the
## menu fills it in with show_upgrade().

signal bought

@onready var info: Label = %Info
@onready var buy_button: Button = %BuyButton


func _ready() -> void:
	buy_button.pressed.connect(func() -> void: bought.emit())


func show_upgrade(text: String, button_text: String, can_buy: bool) -> void:
	info.text = text
	buy_button.text = button_text
	buy_button.disabled = not can_buy
