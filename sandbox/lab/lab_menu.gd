class_name LabMenu
extends CanvasLayer
## The sandbox's lab: every GameSettings option, plus the sandbox-only ones
## (props), as a pause menu. Tab (or pad Y) opens and closes it. Changes are
## saved and apply at once; `changed` tells the sandbox to redo its own part.

signal changed

@onready var options: OptionList = %Options


func _ready() -> void:
	visible = false
	options.changed.connect(changed.emit)


func _exit_tree() -> void:
	if visible:
		get_tree().paused = false


func _input(event: InputEvent) -> void:
	var toggle_key: bool = event is InputEventKey and event.pressed and not event.echo \
		and event.physical_keycode == KEY_TAB
	var toggle_pad: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y
	if toggle_key or toggle_pad:
		open(not visible)
		get_viewport().set_input_as_handled()
	elif visible and (event.is_action_pressed("quit") or event.is_action_pressed("ui_cancel")):
		open(false)
		get_viewport().set_input_as_handled()


func open(on: bool) -> void:
	visible = on
	get_tree().paused = on
	if on:
		options.focus_first()
