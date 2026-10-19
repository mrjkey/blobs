class_name LobbyCard
extends Control
## One player panel in the lobby's PLAYERS view. A player's own panel (HUMAN)
## shows their number, device, blob, their one choice (TEAM or COLOUR, with
## arrows while it can change), READY, and the buttons that work for them
## right now. A computer's seat (CPU) and a free seat (OPEN) show how to
## join. In a team mode a strip along the top names the team. `toast` is a
## short "no, because" note; `hold` fills a bar while a second keyboard
## player holds their key to join here.
## The lobby sets the fields; the card only draws them, in the theme's style.

enum Kind { HUMAN, CPU, OPEN }

const DIM := Color(0.45, 0.47, 0.6)
const INK := Color(0.82, 0.85, 1.0)
const BG := Color(0.045, 0.045, 0.11, 0.92)
const TOAST_BG := Color(0.24, 0.04, 0.1, 0.95)
const TOAST_EDGE := Color(1.0, 0.36, 0.54)
const GLYPH_H := 26.0
const PROMPT_FS := 17
const BAND := 28.0 # the team strip

var kind := Kind.OPEN
var title := "" # "P1", "CPU", "JOIN"
var detail := "" # under the title: the device, or the computer's level
var color := Color.WHITE # the colour the seat plays in
var team_name := "" # in a team mode, the seat's team
var team_color := Color.WHITE
var choice_label := "" # HUMAN: "TEAM" or "COLOUR"
var choice_value := "" # the team's name; "" draws a colour swatch instead
var player_ready := false
var prompts: Array = [] # [[glyphs, text], ...], stacked at the bottom
var toast := ""
var hold := 0.0 # 0..1
var hold_text := ""

static var _box: StyleBoxFlat


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("lobby_card", self):
		return
	var st := theme.style
	var font := get_theme_default_font()
	var w := size.x
	var human := kind == Kind.HUMAN
	var edge := color if kind != Kind.OPEN else DIM

	var box := _panel_box()
	box.bg_color = BG
	box.border_color = st.color(edge, 1.8 if human else 0.6, 1.0 if human else 0.55)
	box.set_border_width_all(4 if human else 2)
	box.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))

	if team_name != "":
		draw_rect(Rect2(4, 4, w - 8, BAND - 4), st.color(team_color, 1.3, 0.9 if human else 0.55))
		_text(font, Vector2(w * 0.5, 4 + (BAND - 4) * 0.5), team_name, 16, Color.WHITE)

	var head_col := st.color(color.lerp(Color.WHITE, 0.3), 1.6) if kind != Kind.OPEN else DIM
	_text(font, Vector2(w * 0.5, 64), title, 40, head_col if human else Color(head_col, 0.75))
	if detail != "":
		_text(font, Vector2(w * 0.5, 98), detail, 15, Color(INK, 0.8 if human else 0.6))

	var centre := Vector2(w * 0.5, 168)
	if kind == Kind.OPEN:
		st.ring(self, centre, 44.0, DIM, 2.0, 0.6, 0.4)
		_text(font, centre, "+", 44, Color(DIM, 0.8))
	else:
		st.disc(self, centre, 44.0, color, 0.0, 1.0 if human else 0.6, 1.5, 3.0, true)
		for side: float in [-1.0, 1.0]:
			var eye := centre + Vector2(15.0 * side, -8.0)
			draw_circle(eye, 8.5, st.color(Color.WHITE, 2.2))
			draw_circle(eye + Vector2(0, 3), 4.2, st.ink)

	var row := Rect2(14, 230, w - 28, 44)
	if human and player_ready:
		draw_rect(row, st.color(color, 1.4, 0.95))
		_text(font, row.get_center(), "READY", 26, st.ink)
	elif human:
		box.bg_color = Color(color.darkened(0.75), 0.9)
		box.border_color = st.color(color, 1.6)
		box.set_border_width_all(2)
		box.draw(get_canvas_item(), row)
		var y := row.get_center().y
		_text_left(font, Vector2(row.position.x + 12, y), choice_label, 16, Color(INK, 0.75))
		var right := row.end.x - 12
		var arrow := st.color(color.lerp(Color.WHITE, 0.4), 1.8)
		_arrow(Vector2(right, y), 1.0, arrow)
		if choice_value == "":
			draw_circle(Vector2(right - 30, y), 10.0, st.color(color, 1.6))
			_arrow(Vector2(right - 60, y), -1.0, arrow)
		else:
			var tw := font.get_string_size(choice_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			_text_left(font, Vector2(right - 20 - tw, y), choice_value, 20, Color.WHITE)
			_arrow(Vector2(right - 38 - tw, y), -1.0, arrow)

	if toast != "":
		var t := Rect2(10, 282, w - 20, 0)
		var lines := _wrap(font, toast, 15, t.size.x - 16)
		t.size.y = lines.size() * 19 + 12
		draw_rect(t, TOAST_BG)
		draw_rect(t, TOAST_EDGE, false, 1.5)
		for i in lines.size():
			_text(font, Vector2(w * 0.5, t.position.y + 15 + i * 19), lines[i], 15, Color(1.0, 0.85, 0.9))

	if hold > 0.0:
		var bar := Rect2(18, 296, w - 36, 10)
		draw_rect(bar, Color(DIM, 0.35))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(hold, 0.0, 1.0), bar.size.y)), st.color(Color.WHITE, 1.6))
		_text(font, Vector2(w * 0.5, 284), hold_text, 15, INK)

	# The prompts, bottom up.
	var y := size.y - 24.0
	for i in range(prompts.size() - 1, -1, -1):
		var p: Array = prompts[i]
		var pw := PromptBar.prompt_width(font, p, GLYPH_H, PROMPT_FS)
		PromptBar.draw_prompt(self, font, Vector2((w - pw) * 0.5, y), p, GLYPH_H, PROMPT_FS, INK)
		y -= 36.0


func _text(font: Font, centre: Vector2, text: String, fs: int, col: Color) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_text_left(font, Vector2(centre.x - tw * 0.5, centre.y), text, fs, col)


## `at` is the left end of the text's vertical centre line.
func _text_left(font: Font, at: Vector2, text: String, fs: int, col: Color) -> void:
	draw_string(font, Vector2(at.x, at.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## A small triangle at `at` pointing right (dir 1) or left (dir -1).
func _arrow(at: Vector2, dir: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at, at + Vector2(-dir * 10, -8), at + Vector2(-dir * 10, 8)]), col)


func _wrap(font: Font, text: String, fs: int, width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var next := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
			lines.append(line)
			line = word
		else:
			line = next
	lines.append(line)
	return lines


static func _panel_box() -> StyleBoxFlat:
	if _box == null:
		_box = StyleBoxFlat.new()
		_box.set_corner_radius_all(12)
	return _box
