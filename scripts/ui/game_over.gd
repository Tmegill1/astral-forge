class_name GameOverScreen
extends CanvasLayer
## The end of a run, won or lost: a summary (time, waves, kills by type,
## level and cards, towers standing, resources gathered), Play Again (or R)
## and Main Menu. A win first plays a short slow-motion banner.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const VICTORY_COLOR := Color(0.55, 0.95, 0.6)
const DEFEAT_COLOR := Color(1, 0.45, 0.35)
## The victory banner shows for this long (real seconds) with the game at
## SLOW_MOTION speed.
const BANNER_TIME := 2.0
const SLOW_MOTION := 0.3
const CHIP_COLOR := Color(0.2, 0.22, 0.28)

@onready var dim: ColorRect = $Dim
@onready var center: CenterContainer = $Center
@onready var banner: Label = %Banner
@onready var title: Label = %Title
@onready var run_line: Label = %RunLine
@onready var kills_row: HFlowContainer = %Kills
@onready var kills_total: Label = %KillsTotal
@onready var level_line: Label = %LevelLine
@onready var cards_row: HFlowContainer = %Cards
@onready var towers_row: HFlowContainer = %Towers
@onready var gathered_label: Label = %Gathered
@onready var play_again_button: Button = %PlayAgain
@onready var main_menu_button: Button = %MainMenu


func _ready() -> void:
	visible = false
	banner.visible = false
	play_again_button.pressed.connect(restart)
	main_menu_button.pressed.connect(to_main_menu)


## Shows `summary` (from World.run_summary()). A victory plays the banner first.
func show_summary(summary: Dictionary) -> void:
	_fill(summary)
	if summary.victory:
		await _play_banner()
	_show()


## "12:05".
static func time_text(seconds: float) -> String:
	var whole := int(seconds)
	return "%d:%02d" % [floori(whole / 60.0), whole % 60]


## "Arc Bolts" at rank 1, "Arc Bolts ×2" above.
static func card_chip(card_title: String, rank: int) -> String:
	return card_title if rank <= 1 else "%s ×%d" % [card_title, rank]


## "140 Scrap · 12 Aether" (Scrap first), or "Nothing".
static func gathered_text(amounts: Dictionary) -> String:
	var types: Array = amounts.keys()
	types.sort_custom(func(a: StringName, b: StringName) -> bool:
		return (0 if a == Loot.SCRAP else 1) < (0 if b == Loot.SCRAP else 1))
	var parts: PackedStringArray = []
	for type in types:
		if amounts[type] > 0:
			parts.append("%d %s" % [amounts[type], Loot.display_name(type)])
	return " · ".join(parts) if not parts.is_empty() else "Nothing"


static func waves_text(cleared: int, total: int) -> String:
	return "%d / %d" % [cleared, total]


func restart() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()


func to_main_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)


func _fill(summary: Dictionary) -> void:
	var won: bool = summary.victory
	title.text = "Victory — The Core holds!" if won else "Defeat — The Core has fallen"
	title.add_theme_color_override(&"font_color", VICTORY_COLOR if won else DEFEAT_COLOR)
	var run: PackedStringArray = [
		"Time %s" % time_text(summary.seconds),
		"Waves %s" % waves_text(summary.waves_cleared, summary.wave_count)]
	if won:
		run.append("Core %d / %d" % [roundi(summary.core_health), roundi(summary.core_max)])
	run_line.text = "   ·   ".join(run)

	_clear(kills_row)
	for row in summary.kills:
		var enemy: EnemyDefinition = row[0]
		kills_row.add_child(_icon_entry(enemy.sprite_frames.get_frame_texture(&"idle", 0),
				"%s %d" % [enemy.display_name, row[1]]))
	kills_total.text = "Total: %d" % summary.kills_total if summary.kills_total > 0 else "None"

	level_line.text = "Level %d" % summary.level
	_clear(cards_row)
	if summary.cards.is_empty():
		cards_row.add_child(_note("No cards"))
	for card in summary.cards:
		cards_row.add_child(_chip(card_chip(card[0], card[1])))

	_clear(towers_row)
	if summary.towers.is_empty():
		towers_row.add_child(_note("No towers standing"))
	for tower in summary.towers:
		var definition: TowerDefinition = tower[0]
		towers_row.add_child(_icon_entry(definition.icon(),
				"Evolved" if definition.evolved else "Lv%d" % tower[1], definition.tint))
	gathered_label.text = "Gathered: " + gathered_text(summary.gathered)


## "The Core holds!" over the field while the game runs in slow motion.
func _play_banner() -> void:
	visible = true
	dim.visible = false
	center.visible = false
	banner.visible = true
	Engine.time_scale = SLOW_MOTION
	await get_tree().create_timer(BANNER_TIME, true, false, true).timeout
	Engine.time_scale = 1.0
	banner.visible = false


func _show() -> void:
	visible = true
	dim.visible = true
	center.visible = true
	# Esc during the banner could have opened the pause menu; the run is over.
	# (Closing it unpauses, so do it before pausing.)
	get_tree().call_group(&"pause_menu", &"close")
	get_tree().paused = true
	play_again_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		restart()


static func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


## A small picture (cropped to its visible pixels) with a caption.
func _icon_entry(texture: Texture2D, caption: String, tint := Color.WHITE) -> HBoxContainer:
	var entry := HBoxContainer.new()
	entry.add_theme_constant_override(&"separation", 4)
	var icon := TextureRect.new()
	icon.texture = HelpMenu._trimmed(texture)
	icon.custom_minimum_size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = tint
	entry.add_child(icon)
	entry.add_child(_note(caption))
	return entry


func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 15)
	return label


func _chip(text: String) -> Label:
	var label := _note(text)
	var style := StyleBoxFlat.new()
	style.bg_color = CHIP_COLOR
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	label.add_theme_stylebox_override(&"normal", style)
	return label
