extends Control
## Pick a treadmill mode. The choice goes into Session, then the treadmill
## scene reads it in its _ready().
##
## A button's position under Modes is its mode number:
## 0 = 1P vs computer, 1 = 2P versus, 2 = 2P + computer, 3 = watch.

@export_file("*.tscn") var treadmill_path: String
@export_file("*.tscn") var main_menu_path: String

@onready var modes: VBoxContainer = %Modes
@onready var info: Label = %Info

var _focused_mode := 0


func _ready() -> void:
	for i in modes.get_child_count():
		var button := modes.get_child(i) as Button
		button.pressed.connect(_on_mode_pressed.bind(i))
		button.focus_entered.connect(_on_mode_focused.bind(i))
	# Start on the mode you played last, so Esc + Enter is a quick restart.
	var start: int = Session.treadmill_mode if Session.treadmill_mode >= 0 else 0
	(modes.get_child(start) as Button).grab_focus()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()


func _on_mode_pressed(mode: int) -> void:
	Session.treadmill_mode = mode
	get_tree().change_scene_to_file(treadmill_path)


func _on_mode_focused(mode: int) -> void:
	_focused_mode = mode
	_show_info(mode)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(main_menu_path)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_show_info(_focused_mode)


## Controllers found, and who plays with what in this mode.
func _show_info(mode: int) -> void:
	var pads := Input.get_connected_joypads().size()
	var text := "Controllers detected: %d\n" % pads
	match mode:
		3:  # watch
			text += "Four bots, no humans. Esc goes back to this menu."
		0:  # 1P vs computer
			text += "You: WASD or arrows, Space or Enter to push"
			if pads > 0:
				text += "  ·  or the controller"
		_:  # two players
			text += "P1: WASD + Space"
			if pads >= 2:
				text += "  ·  or controller 1"
			text += "\nP2: Arrows + Enter"
			if pads >= 1:
				text += "  ·  or controller %d" % (2 if pads >= 2 else 1)
			else:
				text += "\n(no controller found, so share the keyboard)"
	info.text = text
