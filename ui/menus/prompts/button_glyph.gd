class_name ButtonGlyph
extends RefCounted
## Button prompts drawn by hand, so a menu shows the button a player actually
## presses. A glyph is a short code:
##   "a", "b", "x", "y"    gamepad face buttons, as coloured circles
##   "key:SPACE"           a keyboard key, as a keycap
##   "pill:START"          a named gamepad button (START, LB...), as a pill
##   "lr", "ud"            left/right or up/down (d-pad, stick or arrows), as triangles
##   "stick"               a gamepad's left stick, as a ring with the stick's top in it
## draw() paints one with its left edge at `at` (vertically centred) and
## returns its width; width() only measures. Keycaps, pills and arrows take
## the menu theme's ButtonGlyph colours (key_fill, key_edge, key_text,
## pill_fill, pill_text, arrow); the face buttons keep their own.

const PAD_COLORS := {
	"a": Color(0.33, 0.86, 0.46),
	"b": Color(0.92, 0.32, 0.38),
	"x": Color(0.3, 0.56, 1.0),
	"y": Color(1.0, 0.82, 0.28),
}
const INK := Color(0.03, 0.03, 0.1)
const DEFAULTS := {
	"key_fill": Color(0.11, 0.11, 0.26), "key_edge": Color(0.66, 0.7, 0.94), "key_text": Color(0.9, 0.92, 1.0),
	"pill_fill": Color(0.62, 0.66, 0.9), "pill_text": INK, "arrow": Color(0.85, 0.88, 1.0),
}

static var _cap: StyleBoxFlat
static var _pill: StyleBoxFlat


static func width(font: Font, glyph: String, h: float) -> float:
	if PAD_COLORS.has(glyph):
		return h
	if glyph == "lr" or glyph == "ud":
		return h * 1.25
	if glyph == "stick":
		return h
	var text := glyph.get_slice(":", 1)
	return maxf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size(h)).x + h * 0.6, h)


static func draw(ci: CanvasItem, font: Font, at: Vector2, glyph: String, h: float) -> float:
	var w := width(font, glyph, h)
	var c := at + Vector2(w * 0.5, 0.0)
	if PAD_COLORS.has(glyph):
		ci.draw_circle(c, h * 0.5, PAD_COLORS[glyph])
		_centred(ci, font, c, glyph.to_upper(), _font_size(h) + 2, INK)
	elif glyph == "lr" or glyph == "ud":
		var s := h * 0.24
		for side: float in [-1.0, 1.0]:
			var tip := c + (Vector2(side * w * 0.46, 0.0) if glyph == "lr" else Vector2(0.0, side * h * 0.46))
			var back := (Vector2(-side, 0.0) if glyph == "lr" else Vector2(0.0, -side)) * s * 1.6
			var across := Vector2(0.0, s) if glyph == "lr" else Vector2(s, 0.0)
			ci.draw_colored_polygon(PackedVector2Array([tip, tip + back - across, tip + back + across]), _color(ci, "arrow"))
	elif glyph == "stick":
		ci.draw_circle(c, h * 0.5, _color(ci, "pill_fill"))
		ci.draw_circle(c, h * 0.3, _color(ci, "key_fill"))
		ci.draw_arc(c, h * 0.3, 0.0, TAU, 24, _color(ci, "key_edge"), 2.0, true)
	else:
		var rect := Rect2(at - Vector2(0.0, h * 0.5), Vector2(w, h))
		var pill := glyph.begins_with("pill:")
		var box := _pill_box() if pill else _cap_box()
		box.bg_color = _color(ci, "pill_fill" if pill else "key_fill")
		box.border_color = _color(ci, "key_edge")
		box.draw(ci.get_canvas_item(), rect)
		_centred(ci, font, c, glyph.get_slice(":", 1), _font_size(h), _color(ci, "pill_text" if pill else "key_text"))
	return w


## The menu theme's colour `name` for glyphs drawn on `ci`.
static func _color(ci: CanvasItem, name: String) -> Color:
	var control := ci as Control
	if control != null and control.has_theme_color(name, "ButtonGlyph"):
		return control.get_theme_color(name, "ButtonGlyph")
	return DEFAULTS[name]


static func _font_size(h: float) -> int:
	return maxi(int(h * 0.46), 8)


static func _centred(ci: CanvasItem, font: Font, c: Vector2, text: String, size: int, color: Color) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var y := c.y + (font.get_ascent(size) - font.get_descent(size)) * 0.5
	ci.draw_string(font, Vector2(c.x - tw * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func _cap_box() -> StyleBoxFlat:
	if _cap == null:
		_cap = StyleBoxFlat.new()
		_cap.set_border_width_all(2)
		_cap.border_width_bottom = 4
		_cap.set_corner_radius_all(6)
	return _cap


static func _pill_box() -> StyleBoxFlat:
	if _pill == null:
		_pill = StyleBoxFlat.new()
		_pill.set_corner_radius_all(99)
	return _pill
