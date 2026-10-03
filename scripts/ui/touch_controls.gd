class_name TouchControls
extends CanvasLayer
## On-screen controls for phones and tablets (Settings.touch_mode; with a
## mouse and keyboard it removes itself). A floating joystick on the left of
## the screen presses the move actions; the buttons press interact, manage,
## tower_ability, start_wave and ui_cancel, so the game reads them like
## keys. While the hero operates a tower, touching the map sets its aim
## point instead. Everything hides while a menu has the game paused.

## Share of the screen width, from the left, where a touch starts the stick.
const STICK_ZONE := 0.45
## Gap from the screen edge and between buttons, in pixels.
const MARGIN := 16.0
const GAP := 12.0
const STICK_BASE := preload("res://assets/ui/touch/stick_base.png")
const STICK_KNOB := preload("res://assets/ui/touch/stick_knob.png")
## Move action -> the stick axis and sign that presses it.
const MOVE_ACTIONS := {
	&"move_right": Vector2(1, 0), &"move_left": Vector2(-1, 0),
	&"move_down": Vector2(0, 1), &"move_up": Vector2(0, -1),
}

var stick := TouchStick.new()

var _hero: Hero
var _director: WaveDirector
## The touch index aiming an operated tower, or -1.
var _aim_finger := -1
## Move actions this layer is holding (so it never releases a real key).
var _pressed: Dictionary[StringName, bool] = {}

@onready var controls: Node2D = %Controls
@onready var stick_view: Node2D = %StickView
@onready var use_button: TouchScreenButton = %Use
@onready var manage_button: TouchScreenButton = %Manage
@onready var ability_button: TouchScreenButton = %Ability
@onready var wave_button: TouchScreenButton = %Wave
@onready var pause_button: TouchScreenButton = %Pause
@onready var _buttons: Array[TouchScreenButton] = [
	use_button, manage_button, ability_button, wave_button, pause_button]


func _ready() -> void:
	if not Settings.touch_mode:
		queue_free()
		return
	stick_view.draw.connect(_draw_stick)
	get_viewport().size_changed.connect(_place_buttons)
	_place_buttons()


func bind(hero: Hero, director: WaveDirector) -> void:
	_hero = hero
	_director = director


func _process(_delta: float) -> void:
	var paused := get_tree().paused
	controls.visible = not paused
	var can_walk := not paused and _hero != null and not _hero.health.is_dead \
			and _hero.operating == null
	if not can_walk:
		stick.reset()
	if paused or _hero == null or _hero.operating == null:
		_aim_finger = -1
	_apply_stick()
	_update_buttons()
	stick_view.queue_redraw()


func _input(event: InputEvent) -> void:
	if get_tree().paused or _hero == null or _hero.health.is_dead:
		return
	if event is InputEventScreenTouch:
		if not event.pressed:
			stick.end(event.index)
			if event.index == _aim_finger:
				_aim_finger = -1
		elif _on_button(event.position):
			return
		elif _hero.operating:
			_aim_finger = event.index
			_set_aim(event.position)
		elif event.position.x < get_viewport().get_visible_rect().size.x * STICK_ZONE:
			stick.begin(event.index, event.position)
	elif event is InputEventScreenDrag:
		stick.drag(event.index, event.position)
		if event.index == _aim_finger:
			_set_aim(event.position)


## Presses each move action as far as the stick leans that way; releases
## the ones this layer pressed that the stick no longer leans toward.
func _apply_stick() -> void:
	var v := stick.vector()
	for action: StringName in MOVE_ACTIONS:
		var strength := maxf(v.dot(MOVE_ACTIONS[action]), 0.0)
		if strength > 0.0:
			Input.action_press(action, strength)
			_pressed[action] = true
		elif _pressed.get(action, false):
			Input.action_release(action)
			_pressed.erase(action)


func _update_buttons() -> void:
	if _hero == null:
		return
	var alive := not _hero.health.is_dead
	var target := _hero.nearest_interactable() if alive else null
	use_button.visible = alive and (_hero.operating != null or target != null)
	manage_button.visible = alive and _hero.operating == null and target != null \
			and target.has_method(&"can_manage") and target.can_manage(_hero)
	ability_button.visible = alive and _hero.operating != null
	wave_button.visible = _director != null and _director.state == WaveDirector.State.BREAK


## Bottom-right cluster (Use, Manage to its left, Q above Use); pause and
## Wave down the right edge under the HUD's wave panel.
func _place_buttons() -> void:
	var size := get_viewport().get_visible_rect().size
	var big := 80.0
	use_button.position = Vector2(size.x - MARGIN - big, size.y - MARGIN - big)
	manage_button.position = use_button.position - Vector2(big + GAP, 0)
	ability_button.position = use_button.position - Vector2(0, big + GAP)
	pause_button.position = Vector2(size.x - MARGIN - 56.0, 92.0)
	wave_button.position = Vector2(size.x - MARGIN - big, 92.0 + 56.0 + GAP)


func _on_button(pos: Vector2) -> bool:
	for button in _buttons:
		if button.is_visible_in_tree() and Rect2(button.position,
				button.texture_normal.get_size() * button.scale).has_point(pos):
			return true
	return false


func _set_aim(pos: Vector2) -> void:
	_hero.touch_aim = get_viewport().get_canvas_transform().affine_inverse() * pos


func _draw_stick() -> void:
	if not stick.is_held():
		return
	stick_view.draw_texture(STICK_BASE, stick.origin - STICK_BASE.get_size() / 2.0)
	stick_view.draw_texture(STICK_KNOB,
			stick.origin + stick.knob_offset() - STICK_KNOB.get_size() / 2.0)
