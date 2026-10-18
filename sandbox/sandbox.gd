extends Node2D
## Test bench: a walled room with the player and two bots, and nothing else.
## Drop any component scene in here to try it out. R = reset, Esc = menu.
## Tab opens the lab (LabMenu): the game settings plus the sandbox's own
## (props), changed live.

@export_file("*.tscn") var menu_path := "res://ui/menus/main_menu.tscn"
@export var lab: LabMenu
@export var props_parent: Node2D # the lab's props go here (before the blobs, so blobs draw on top)
@export var props_scene: PackedScene
@export var hint: Label


func _ready() -> void:
	lab.changed.connect(_apply_lab)
	_apply_lab()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("quit"):
		get_tree().change_scene_to_file(menu_path)


## The sandbox-only settings. Everything else (rules, bars) reads GameSettings itself.
func _apply_lab() -> void:
	var want_props := GameSettings.choice("props") != "none"
	if want_props and props_parent.get_child_count() == 0:
		props_parent.add_child(props_scene.instantiate())
	elif not want_props:
		for c in props_parent.get_children():
			c.queue_free()

	hint.text = "WASD / arrows: move     SPACE: push     SHIFT: dash     J: slash     K: spit     L: shield\n" \
		+ "TAB: lab     R: reset     Esc: menu     dash: %s     energy: %s" % [GameSettings.choice_label("dash"), GameSettings.choice_label("energy")]
