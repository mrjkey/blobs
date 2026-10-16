extends RefCounted
## One player's controls, read straight from the keyboard and/or one gamepad.
## Each player gets their own keys and device, so two people can share a
## keyboard or each use a controller (the shared InputMap can't split those).

const TT = preload("res://scripts/treadmill/treadmill_tuning.gd")

var left: Array
var right: Array
var up: Array
var down: Array
var push: Array
var joy := -1                  # gamepad device id, or -1 for keyboard only
var _push_was_down := false


func _init(keys: Dictionary, joy_device: int) -> void:
	left = keys["left"]
	right = keys["right"]
	up = keys["up"]
	down = keys["down"]
	push = keys["push"]
	joy = joy_device


func move() -> Vector2:
	var v := Vector2(_held(right) - _held(left), _held(down) - _held(up))
	if joy >= 0:
		var stick := Vector2(Input.get_joy_axis(joy, JOY_AXIS_LEFT_X), Input.get_joy_axis(joy, JOY_AXIS_LEFT_Y))
		var amount := stick.length()
		if amount > TT.JOY_DEADZONE:
			v += stick / amount * inverse_lerp(TT.JOY_DEADZONE, 1.0, minf(amount, 1.0))
		v.x += _button(JOY_BUTTON_DPAD_RIGHT) - _button(JOY_BUTTON_DPAD_LEFT)
		v.y += _button(JOY_BUTTON_DPAD_DOWN) - _button(JOY_BUTTON_DPAD_UP)
	return v.limit_length(1.0)


## True only on the frame the push button goes down. Call once per frame.
func push_pressed() -> bool:
	var is_down := _held(push) > 0.0
	if joy >= 0:
		is_down = is_down or _button(JOY_BUTTON_A) > 0.0 or _button(JOY_BUTTON_X) > 0.0 \
			or _button(JOY_BUTTON_RIGHT_SHOULDER) > 0.0
	var pressed := is_down and not _push_was_down
	_push_was_down = is_down
	return pressed


func _held(keys: Array) -> float:
	for k in keys:
		if Input.is_physical_key_pressed(k):
			return 1.0
	return 0.0


func _button(button: JoyButton) -> float:
	return 1.0 if Input.is_joy_button_pressed(joy, button) else 0.0
