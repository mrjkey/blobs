class_name PauseMenu
extends CanvasLayer
## A game's pause menu: GameMode opens it on START or ESC and the game stops
## while it's up. RESUME (also START, ESC or B), RESTART (PLAY AGAIN once the
## round is over, and then it's the one picked) and QUIT, back to the lobby or
## the main menu, and HOW TO PLAY (a HowToPlay page over the menu, when the
## mode gave it the game with how_to(); any of START, ESC, B or A closes it).
## It only tells the mode what was picked. Online the game
## goes on behind it (players on this computer let go while it's open), and
## on a joined computer there's no restart: the host decides.

signal resumed
signal restart_requested
signal quit_requested

@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var quit_button: Button = %QuitButton
@onready var how_to_button: Button = %HowToButton
@onready var how_to_page: HowToPlay = %HowTo


func _enter_tree() -> void:
	add_to_group("pause_menu")


## `round_over`: the round is decided. `quit_text`: where QUIT goes. `stop`:
## the game stops while it's open. `can_restart`: RESTART / PLAY AGAIN shows.
func open(round_over: bool, quit_text: String, stop := true, can_restart := true) -> void:
	get_tree().paused = stop
	%Title.text = "ROUND OVER" if round_over else ("PAUSED" if stop else "MENU")
	restart_button.text = "PLAY AGAIN" if round_over else "RESTART"
	restart_button.visible = can_restart
	quit_button.text = quit_text
	(restart_button if round_over and can_restart else resume_button).grab_focus()
	Sfx.play_here("pop", 0.8)


## HOW TO PLAY shows `game` with `rules` and this computer's players' keys (`keys`).
func how_to(game: ModeInfo, rules: MoveRules, keys: Array[InputProfile]) -> void:
	how_to_page.show_game(game, rules, keys)
	how_to_page.prompts = [[["b", "key:ESC", "pill:START"], "Back"]]
	how_to_page.pause_hint = false
	how_to_button.visible = true


func _exit_tree() -> void:
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	var start: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START
	if how_to_page.visible:
		if start or event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			how_to_page.hide()
			how_to_button.grab_focus()
			Sfx.play_here("pop", 0.9)
		return
	if start or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_resume_button_pressed()


func _on_resume_button_pressed() -> void:
	get_tree().paused = false
	resumed.emit()
	queue_free()


func _on_how_to_button_pressed() -> void:
	how_to_page.show()
	get_viewport().gui_release_focus() # so A / SPACE come here to close it, not to a button
	Sfx.play_here("pop", 1.1)


func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	restart_requested.emit()


func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	quit_requested.emit()
