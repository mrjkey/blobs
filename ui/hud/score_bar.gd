class_name ScoreBar
extends Control
## A scoreboard at the top centre of the HUD: a row of pieces of text, each
## in its own colour (team names, the score, the clock). Empty = not shown.
## Full screen and click-through, like EnergyHud. Set it with Hud.set_score().

const FONT_SIZE := 30
const GAP := 26.0

@export var top := 14.0

var pieces: Array = [] # [text, colour] each


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("score_bar", self) or pieces.is_empty():
		return
	var font := get_theme_default_font()
	var widths: Array[float] = []
	var total := -GAP
	for p: Array in pieces:
		var w := font.get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		widths.append(w)
		total += w + GAP
	var back := Rect2(Vector2((size.x - total) * 0.5 - 18.0, top), Vector2(total + 36.0, FONT_SIZE + 16.0))
	draw_rect(back, Color(0.0, 0.0, 0.05, 0.6))
	var x := (size.x - total) * 0.5
	for i in pieces.size():
		draw_string(font, Vector2(x, top + FONT_SIZE + 2.0), pieces[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE,
			theme.style.color(pieces[i][1], 1.8))
		x += widths[i] + GAP
