class_name PlayerInput
extends Node
## Steers the parent Blob from the keyboard and/or one gamepad. The keys come
## from an InputProfile, not the InputMap, so two players can share a keyboard
## and each use their own controller.

@export var profile: InputProfile = preload("res://blob/control/profiles/solo.tres")
## Which connected gamepad to use: 0 = the first, 1 = the second, -1 = none.
@export var pad_slot := 0

var _push_was_down := false

@onready var blob: Blob = get_parent()


func _ready() -> void:
	process_physics_priority = -10 # before BlobPhysics moves the blob
	blob.controller = self


func _physics_process(_delta: float) -> void:
	if not blob.alive:
		return
	var pushed := _push_pressed() # poll every frame, so a press during the countdown doesn't fire after it
	if not blob.active:
		blob.move_dir = Vector2.ZERO
		return
	blob.move_dir = _move()
	if pushed:
		blob.request_push()


func _pad() -> int:
	var pads := Input.get_connected_joypads()
	return pads[pad_slot] if pad_slot >= 0 and pad_slot < pads.size() else -1


func _move() -> Vector2:
	var v := Vector2(_held(profile.right) - _held(profile.left), _held(profile.down) - _held(profile.up))
	var pad := _pad()
	if pad >= 0:
		var stick := Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
		var amount := stick.length()
		if amount > profile.pad_deadzone:
			v += stick / amount * inverse_lerp(profile.pad_deadzone, 1.0, minf(amount, 1.0))
		v.x += _button(pad, JOY_BUTTON_DPAD_RIGHT) - _button(pad, JOY_BUTTON_DPAD_LEFT)
		v.y += _button(pad, JOY_BUTTON_DPAD_DOWN) - _button(pad, JOY_BUTTON_DPAD_UP)
	return v.limit_length(1.0)


## True only on the frame the push button goes down.
func _push_pressed() -> bool:
	var is_down := _held(profile.push) > 0.0
	var pad := _pad()
	if pad >= 0:
		for b in profile.pad_push:
			is_down = is_down or Input.is_joy_button_pressed(pad, b)
	var pressed := is_down and not _push_was_down
	_push_was_down = is_down
	return pressed


func _held(keys: Array[Key]) -> float:
	for k in keys:
		if Input.is_physical_key_pressed(k):
			return 1.0
	return 0.0


func _button(pad: int, button: JoyButton) -> float:
	return 1.0 if Input.is_joy_button_pressed(pad, button) else 0.0
