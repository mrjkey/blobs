class_name PauseMenu
extends CanvasLayer
## A game's pause menu: GameMode opens it on START or ESC and the game stops
## while it's up. RESUME (also START, ESC or B), RESTART (PLAY AGAIN once the
## round is over, and then it's the one picked) and QUIT, back to the lobby or
## the main menu. It only tells the mode what was picked.

signal resumed
signal restart_requested
signal quit_requested

@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var quit_button: Button = %QuitButton


## `round_over`: the round is decided. `quit_text`: where QUIT goes.
func open(round_over: bool, quit_text: String) -> void:
	get_tree().paused = true
	%Title.text = "ROUND OVER" if round_over else "PAUSED"
	restart_button.text = "PLAY AGAIN" if round_over else "RESTART"
	quit_button.text = quit_text
	(restart_button if round_over else resume_button).grab_focus()
	Sfx.play("pop", 0.8)


func _exit_tree() -> void:
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	var start: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START
	if start or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_resume_button_pressed()


func _on_resume_button_pressed() -> void:
	get_tree().paused = false
	resumed.emit()
	queue_free()


func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	restart_requested.emit()


func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	quit_requested.emit()
