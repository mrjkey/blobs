class_name GameTabs
extends Control
## The lobby's game picker: every game's name on a tile, in a row that never
## moves, the picked one lit. It's the first stop of the GAME list:
## left/right (or a click on a tile) picks another. Drawn with the menu
## theme's GameTabs items: styles `tab`, `tab_selected` and `focus`, colours
## `font_color` and `font_selected_color`, font size `font_size`.

signal picked(index: int)

const GAP := 14.0

var titles := PackedStringArray():
	set(value):
		titles = value
		queue_redraw()
var index := 0:
	set(value):
		index = value
		queue_redraw()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT, NOTIFICATION_THEME_CHANGED, NOTIFICATION_RESIZED:
			queue_redraw()


func _tile(i: int) -> Rect2:
	var w := (size.x - GAP * (titles.size() - 1)) / titles.size()
	return Rect2(i * (w + GAP), 0.0, w, size.y)


func _draw() -> void:
	if titles.is_empty():
		return
	var font := get_theme_font("font", "Button")
	var fs := get_theme_font_size("font_size", "GameTabs")
	if has_focus():
		get_theme_stylebox("focus", "GameTabs").draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	for i in titles.size():
		var r := _tile(i)
		var on := i == index
		get_theme_stylebox("tab_selected" if on else "tab", "GameTabs").draw(get_canvas_item(), r)
		var col := get_theme_color("font_selected_color" if on else "font_color", "GameTabs")
		var tw := font.get_string_size(titles[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var y := r.get_center().y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string(font, Vector2(r.get_center().x - tw * 0.5, y), titles[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if has_focus():
		var arrow := get_theme_color("font_selected_color", "GameTabs")
		var mid := size.y * 0.5
		for side: float in [-1.0, 1.0]:
			var tip := Vector2(-34.0 if side < 0.0 else size.x + 34.0, mid)
			var back := Vector2(-side * 14.0, 0.0)
			draw_colored_polygon(PackedVector2Array([tip, tip + back + Vector2(0, -11), tip + back + Vector2(0, 11)]), arrow)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in titles.size():
			if _tile(i).has_point(event.position):
				grab_focus()
				picked.emit(i)
				accept_event()
				return
