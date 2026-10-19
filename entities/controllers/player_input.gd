class_name PlayerInput
extends Node
## Steers the parent Blob from the keyboard and/or one gamepad. The keys come
## from an InputProfile, not the InputMap, so two players can share a keyboard
## and each use their own controller.

@export var profile: InputProfile = preload("res://entities/controllers/profiles/solo.tres")
## Which connected gamepad to use: 0 = the first, 1 = the second, -1 = none.
@export var pad_slot := 0
## A specific gamepad (its device id, from the lobby). Overrides pad_slot; -1 = not set.
@export var pad_device := -1

var _was_down := {} # button name -> held last frame

@onready var blob: Blob = get_parent()


func _ready() -> void:
	process_physics_priority = -10 # before BlobPhysics moves the blob
	blob.controller = self


func _physics_process(_delta: float) -> void:
	if not blob.alive:
		return
	# Poll every frame, so a press during the countdown doesn't fire after it.
	var pushed := _just_pressed("push", profile.push, profile.pad_push)
	var dashed := _just_pressed("dash", profile.dash, profile.pad_dash)
	var slashed := _just_pressed("slash", profile.slash, profile.pad_slash)
	var spat := _just_pressed("spit", profile.spit, profile.pad_spit)
	var shielded := _just_pressed("shield", profile.shield, profile.pad_shield)
	if not blob.active:
		blob.move_dir = Vector2.ZERO
		return
	blob.move_dir = _move()
	if pushed:
		blob.request_push()
	if dashed:
		blob.request_dash()
	if slashed:
		blob.request_slash()
	if spat:
		blob.request_spit()
	if shielded:
		blob.request_shield()


## For a menu over the game that this player drives (Don't Get Fat!'s upgrade
## cards): where they're steering, keys and gamepad together, length <= 1.
func steer() -> Vector2:
	return _move()


## For such a menu: true on the frame they press their push button (A, or the push key).
func ok_pressed() -> bool:
	return _just_pressed("menu_ok", profile.push, profile.pad_push)


func _pad() -> int:
	var pads := Input.get_connected_joypads()
	if pad_device >= 0:
		return pad_device if pads.has(pad_device) else -1
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


## True only on the frame one of `keys` / `buttons` goes down.
func _just_pressed(action: String, keys: Array[Key], buttons: Array[JoyButton]) -> bool:
	var is_down := _held(keys) > 0.0
	var pad := _pad()
	if pad >= 0:
		for b in buttons:
			is_down = is_down or Input.is_joy_button_pressed(pad, b)
	var pressed: bool = is_down and not _was_down.get(action, false)
	_was_down[action] = is_down
	return pressed


func _held(keys: Array[Key]) -> float:
	for k in keys:
		if Input.is_physical_key_pressed(k):
			return 1.0
	return 0.0


func _button(pad: int, button: JoyButton) -> float:
	return 1.0 if Input.is_joy_button_pressed(pad, button) else 0.0
