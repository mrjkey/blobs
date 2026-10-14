extends Control
## The first scene. Each button swaps the whole scene for another one.
##
## Scene links are file paths (@export_file), not PackedScene slots: the
## treadmill menu links back here, and two scenes holding PackedScenes of each
## other is a cyclic load that Godot refuses. Paths also load only on click.

@export_file("*.tscn") var treadmill_menu_path: String
@export_file("*.tscn") var classic_path: String
@export_file("*.tscn") var neon_path: String

@onready var treadmill_button: Button = $Center/Column/Buttons/TreadmillButton

func _ready() -> void:
	treadmill_button.grab_focus()


func _on_treadmill_button_pressed() -> void:
	get_tree().change_scene_to_file(treadmill_menu_path)


func _on_classic_button_pressed() -> void:
	get_tree().change_scene_to_file(classic_path)


func _on_neon_button_pressed() -> void:
	get_tree().change_scene_to_file(neon_path)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
