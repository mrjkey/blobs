extends Control
## The first scene. Each button swaps the whole scene for another one. PLAY
## opens the lobby, where the game is picked, players join and the lineup is
## made.
##
## Scene links are file paths (@export_file), not PackedScene slots: the
## menus link back here, and two scenes holding PackedScenes of each other is
## a cyclic load that Godot refuses. Paths also load only on click.

@export_file("*.tscn") var lobby_path: String
@export_file("*.tscn") var sandbox_path: String
@export_file("*.tscn") var settings_path: String

@onready var play_button: Button = %PlayButton


func _ready() -> void:
	play_button.grab_focus()


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file(lobby_path)


func _on_sandbox_button_pressed() -> void:
	get_tree().change_scene_to_file(sandbox_path)


func _on_settings_button_pressed() -> void:
	get_tree().change_scene_to_file(settings_path)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
