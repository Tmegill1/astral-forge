class_name HelpMenu
extends CanvasLayer
## Tower guide and enemy Codex, opened from the main menu and the pause menu.
## Each tab is a list on the left and the chosen entry's details on the right.
## Back or Esc closes it.

signal closed

const TOWERS: Array[String] = [
	"res://data/towers/gearshot.tres", "res://data/towers/rune_mortar.tres",
	"res://data/towers/embercaster.tres", "res://data/towers/aether_spire.tres"]
## Enemy ratings are words relative to this one.
const BASE_ENEMY := "res://data/enemies/goblin.tres"
const SELECTED := Color(1.0, 0.85, 0.5)
## The panel's size when the screen has room (desktop); smaller screens
## (a phone's bigger UI) get a panel this far inside the screen edges.
const PANEL_SIZE := Vector2(900, 560)
const SCREEN_MARGIN := 12.0

var _entries: Array[Button] = []
var _preview: AnimatedSprite2D

@onready var towers_tab: Button = %TowersTab
@onready var codex_tab: Button = %CodexTab
@onready var entry_list: VBoxContainer = %List
@onready var sprite_holder: Control = %SpriteHolder
@onready var picture: TextureRect = %Picture
@onready var entry_name: Label = %EntryName
@onready var body: RichTextLabel = %Body
@onready var back_button: Button = %Back
@onready var panel: PanelContainer = $Center/Panel


func _ready() -> void:
	visible = false
	towers_tab.pressed.connect(show_tab.bind(&"towers"))
	codex_tab.pressed.connect(show_tab.bind(&"codex"))
	back_button.pressed.connect(close)


## Opens on the Towers tab; the lists are rebuilt each time, so new Codex
## entries appear.
func open() -> void:
	var room := get_viewport().get_visible_rect().size - Vector2.ONE * 2.0 * SCREEN_MARGIN
	panel.custom_minimum_size = PANEL_SIZE.min(room)
	visible = true
	show_tab(&"towers")
	back_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	_clear_preview()
	closed.emit()


func show_tab(tab: StringName) -> void:
	towers_tab.set_pressed_no_signal(tab == &"towers")
	codex_tab.set_pressed_no_signal(tab == &"codex")
	for child in entry_list.get_children():
		entry_list.remove_child(child)
		child.queue_free()
	_entries.clear()
	if tab == &"towers":
		for path in TOWERS:
			var tower: TowerDefinition = load(path)
			_add_entry(tower.display_name, tower.icon(), false, _show_tower.bind(tower))
	else:
		for enemy in Codex.all_enemies():
			var seen := Codex.is_seen(enemy.id)
			_add_entry(enemy.display_name if seen else "???", _enemy_icon(enemy),
					not seen, _show_enemy.bind(enemy))
	if not _entries.is_empty():
		_entries[0].pressed.emit()


func _add_entry(text: String, icon: Texture2D, silhouette: bool, on_pick: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.icon = _trimmed(icon)
	button.expand_icon = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 46)
	button.add_theme_constant_override(&"icon_max_width", 40)
	if silhouette:
		for state in [&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color",
				&"icon_focus_color", &"icon_hover_pressed_color"]:
			button.add_theme_color_override(state, Color.BLACK)
	button.pressed.connect(_select.bind(button, on_pick))
	entry_list.add_child(button)
	_entries.append(button)


func _select(button: Button, on_pick: Callable) -> void:
	for entry in _entries:
		entry.remove_theme_color_override(&"font_color")
	button.add_theme_color_override(&"font_color", SELECTED)
	on_pick.call()


func _show_tower(tower: TowerDefinition) -> void:
	_set_picture(tower.icon(), false)
	entry_name.text = tower.display_name + ("" if tower.available else "  (Coming soon)")
	body.text = HelpText.tower_bbcode(tower)


func _show_enemy(enemy: EnemyDefinition) -> void:
	if Codex.is_seen(enemy.id):
		_set_sprite(enemy)
		entry_name.text = enemy.display_name
		body.text = HelpText.enemy_bbcode(enemy, load(BASE_ENEMY))
	else:
		_set_picture(_enemy_icon(enemy), true)
		entry_name.text = "???"
		body.text = "Not yet encountered."


static func _enemy_icon(enemy: EnemyDefinition) -> Texture2D:
	return enemy.sprite_frames.get_frame_texture(&"idle", 0)


## `texture` cropped to its visible pixels: sprite frames are mostly empty
## space, which would shrink a small icon to a speck.
static func _trimmed(texture: Texture2D) -> Texture2D:
	var image := texture.get_image()
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return texture
	return ImageTexture.create_from_image(image.get_region(used))


func _set_picture(texture: Texture2D, silhouette: bool) -> void:
	_clear_preview()
	picture.visible = true
	picture.texture = _trimmed(texture)
	picture.modulate = Color.BLACK if silhouette else Color.WHITE


## The seen enemy's idle animation, fitted to the picture box.
func _set_sprite(enemy: EnemyDefinition) -> void:
	_clear_preview()
	picture.visible = false
	var box := sprite_holder.custom_minimum_size
	var frame := _enemy_icon(enemy).get_size()
	_preview = AnimatedSprite2D.new()
	_preview.sprite_frames = enemy.sprite_frames
	_preview.scale = Vector2.ONE * minf(box.x / frame.x, box.y / frame.y)
	_preview.position = box / 2.0
	sprite_holder.add_child(_preview)
	_preview.play(&"idle")


func _clear_preview() -> void:
	if _preview:
		_preview.queue_free()
		_preview = null


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
