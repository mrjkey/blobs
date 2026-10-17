extends Control
## The SETTINGS screen, from the main menu: the look (theme, glow) and every
## gameplay option of GameSettings. Changes are saved as soon as they're made.

@export_file("*.tscn") var main_menu_path: String

@onready var options: OptionList = %Options


func _ready() -> void:
	options.focus_first()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(main_menu_path)
