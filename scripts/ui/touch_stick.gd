class_name TouchStick
extends RefCounted
## A floating joystick's state: where its finger came down and how far it
## has been pushed. Pure logic so it can be tested headless; TouchControls
## draws it and turns vector() into the move actions (whose own 0.2
## deadzone is the stick's dead zone).

## How far the knob can travel from where the finger came down, in pixels.
var radius := 60.0
## The touch index holding the stick, or -1 when nobody is.
var finger := -1
## Where the finger came down (the stick's centre), in viewport pixels.
var origin := Vector2.ZERO

var _offset := Vector2.ZERO


func is_held() -> bool:
	return finger >= 0


## Starts the stick under `at`, unless another finger already holds it.
func begin(index: int, at: Vector2) -> void:
	if is_held():
		return
	finger = index
	origin = at
	_offset = Vector2.ZERO


func drag(index: int, at: Vector2) -> void:
	if index == finger:
		_offset = at - origin


func end(index: int) -> void:
	if index == finger:
		reset()


func reset() -> void:
	finger = -1
	_offset = Vector2.ZERO


## How far the knob is pushed, as a share of the radius (length at most 1).
func vector() -> Vector2:
	return knob_offset() / radius


## The knob's offset from origin, kept inside the radius.
func knob_offset() -> Vector2:
	return _offset.limit_length(radius)
