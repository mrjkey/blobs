extends Control
## The first scene. Each button swaps the whole scene for a game.

@export var treadmill_scene: PackedScene  # drag treadmill.tscn here
@export var classic_scene: PackedScene    # drag main.tscn here
@export var neon_scene: PackedScene       # drag neon.tscn here

@onready var treadmill_button: Button = $Center/Column/Buttons/TreadmillButton

func _ready() -> void:
	treadmill_button.grab_focus()


func _on_treadmill_button_pressed() -> void:
	get_tree().change_scene_to_packed(treadmill_scene)


func _on_classic_button_pressed() -> void:
	get_tree().change_scene_to_packed(classic_scene)


func _on_neon_button_pressed() -> void:
	get_tree().change_scene_to_packed(neon_scene)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
