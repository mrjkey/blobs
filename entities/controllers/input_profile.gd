class_name InputProfile
extends Resource
## One player's keys. PlayerInput reads these directly (not the InputMap), so
## two players can share a keyboard and each have their own gamepad.

@export var left: Array[Key] = []
@export var right: Array[Key] = []
@export var up: Array[Key] = []
@export var down: Array[Key] = []
@export var push: Array[Key] = []
@export var pad_push: Array[JoyButton] = [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER]
@export var dash: Array[Key] = []
@export var pad_dash: Array[JoyButton] = [JOY_BUTTON_B, JOY_BUTTON_LEFT_SHOULDER]
@export_range(0.0, 1.0) var pad_deadzone := 0.25
