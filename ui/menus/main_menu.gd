extends Control
## The first scene. Each button swaps the whole scene for another one. A mode
## goes through the lobby first, where players join and the lineup is made.
##
## Scene links are file paths (@export_file), not PackedScene slots: the
## menus link back here, and two scenes holding PackedScenes of each other is
## a cyclic load that Godot refuses. Paths also load only on click. A mode is
## its ModeInfo, which holds its scene as a path too.

@export var treadmill: ModeInfo
@export var ring: ModeInfo
@export_file("*.tscn") var lobby_path: String
@export_file("*.tscn") var sandbox_path: String
@export_file("*.tscn") var settings_path: String

@onready var treadmill_button: Button = $Center/Column/Buttons/TreadmillButton


func _ready() -> void:
	treadmill_button.grab_focus()


func _on_treadmill_button_pressed() -> void:
	_play(treadmill)


func _on_ring_button_pressed() -> void:
	_play(ring)


func _play(mode: ModeInfo) -> void:
	Session.next_mode = mode
	get_tree().change_scene_to_file(lobby_path)


func _on_sandbox_button_pressed() -> void:
	get_tree().change_scene_to_file(sandbox_path)


func _on_settings_button_pressed() -> void:
	get_tree().change_scene_to_file(settings_path)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
