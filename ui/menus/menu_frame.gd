class_name MenuFrame
extends Control
## Makes the Control it sits in a menu in the current theme's look. Put it
## first in a menu scene, full rect. It:
## - gives its parent the theme's menu style (GameTheme.menu, a UI Theme with
##   the buttons, labels, the lobby's panels, prompts and game tiles),
## - paints the background (`background` colour of type MenuFrame, plus
##   diagonal `stripes` if that colour isn't clear) and the theme's backdrop
##   scene (the neon grid, brightened by `backdrop_tint`), which ripples where
##   the focus goes,
## - turns gamepad stick pushes into single ui_up / ui_down / ui_left /
##   ui_right steps (StickRepeat), so a held stick doesn't race through the menu.
## It follows the THEME setting live (Session.theme_changed).

const STRIPE_GAP := 56.0
const STRIPE_WIDTH := 20.0

@export var background := true # false: the style only (a pause menu over a game)
@export var stick_steps := true # false: the menu reads the stick itself (the lobby)
@export var ripple_strength := 260.0
@export var ripple_radius := 200.0

var _stick := StickRepeat.new()
var _backdrop: Node2D


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	Session.theme_changed.connect(_apply)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	_apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
		queue_redraw()


func _apply() -> void:
	var theme := GameTheme.current()
	var target := get_parent() as Control
	if target != null and theme.menu != null:
		target.theme = theme.menu
	if _backdrop != null:
		_backdrop.queue_free()
		_backdrop = null
	if background and theme.backdrop != null:
		var view := get_viewport_rect().size
		_backdrop = theme.backdrop.instantiate()
		if "half_size" in _backdrop:
			_backdrop.half_size = view * 0.5 + Vector2(80, 80)
		_backdrop.position = view * 0.5
		_backdrop.z_index = 0 # in front of the colour this node paints, behind the menu
		_backdrop.modulate = get_theme_color("backdrop_tint", "MenuFrame") if has_theme_color("backdrop_tint", "MenuFrame") else Color.WHITE
		add_child(_backdrop)
	queue_redraw()


func _draw() -> void:
	if not background:
		return
	draw_rect(Rect2(Vector2.ZERO, size), get_theme_color("background", "MenuFrame"))
	var stripes := get_theme_color("stripes", "MenuFrame")
	if stripes.a <= 0.0:
		return
	var x := -size.y
	while x < size.x:
		draw_line(Vector2(x, size.y), Vector2(x + size.y, 0), stripes, STRIPE_WIDTH)
		x += STRIPE_GAP


func _on_focus_changed(control: Control) -> void:
	if _backdrop != null and is_visible_in_tree() and control != null:
		ripple(control.get_global_rect().get_center())


## A ripple in the backdrop (if it ripples: the neon grid) at canvas position `at`.
func ripple(at: Vector2, scale := 1.0) -> void:
	if _backdrop != null:
		get_tree().call_group("grid", "impulse", at, ripple_strength * scale, ripple_radius)


func _input(event: InputEvent) -> void:
	if not stick_steps or not event is InputEventJoypadMotion or event.axis > JOY_AXIS_LEFT_Y:
		return
	var layer := get_canvas_layer_node()
	if not is_visible_in_tree() or (layer != null and not layer.visible):
		return
	get_viewport().set_input_as_handled()
	var step := _stick.motion(event)
	if step != "":
		_send(step)


func _process(delta: float) -> void:
	if stick_steps:
		for r: Array in _stick.repeats(delta):
			_send(r[1])


## A ui_<step> press and release, as if the d-pad gave it.
func _send(step: String) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventAction.new()
		e.action = "ui_" + step
		e.pressed = pressed
		Input.parse_input_event(e)
