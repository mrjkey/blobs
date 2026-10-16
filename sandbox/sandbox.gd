extends Node2D
## Test bench: a walled room with the player and two bots, and nothing else.
## Drop any component scene in here to try it out. R = reset, Esc = menu.

@export_file("*.tscn") var menu_path := "res://ui/menus/main_menu.tscn"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("quit"):
		get_tree().change_scene_to_file(menu_path)
