class_name LobbyCard
extends Control
## One seat in the lobby: who sits there (a player, a CPU or nobody), their
## colour as a little blob, READY, a hint for the player pointing at it, and
## the hand markers of everyone pointing at it (drawn just below the card).
## The lobby sets the fields; the card only draws them, in the theme's style.

const CLOSED_COLOR := Color(0.45, 0.45, 0.55)

var seat := 1 # 1..4
var slot: PlayerSlot # null = a closed seat
var player_ready := false # their own card: they pressed ready
var hint := "" # for whoever points at this card
var hands: Array = [] # [label, colour] of each player pointing here


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("lobby_card", self):
		return
	var st := theme.style
	var font := get_theme_default_font()
	var w := size.x
	var open := slot != null
	var human := open and slot.human
	var col := theme.palette_color(slot.color_index) if open else CLOSED_COLOR
	var text_col := st.color(col.lerp(Color.WHITE, 0.35), 1.6)

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.1, 0.88))
	draw_rect(Rect2(Vector2.ZERO, size), st.color(col, 1.8 if human else 0.7, 1.0 if open else 0.5), false,
		3.0 if human else 1.5)

	var header := "P%d" % seat if human else ("CPU" if open else "EMPTY")
	draw_string(font, Vector2(0, 46), header, HORIZONTAL_ALIGNMENT_CENTER, w, 32,
		text_col if open else Color(CLOSED_COLOR, 0.7))

	var centre := Vector2(w * 0.5, 130.0)
	if open:
		st.disc(self, centre, 46.0, col, 0.0, 1.0, 1.5, 3.0, true)
		for side: float in [-1.0, 1.0]:
			var eye := centre + Vector2(16.0 * side, -8.0)
			draw_circle(eye, 9.0, st.color(Color.WHITE, 2.2))
			draw_circle(eye + Vector2(0, 3), 4.5, st.ink)
		var line := slot.describe() if human else "<  %s  >" % slot.bot_level.display_name
		draw_string(font, Vector2(0, 216), line, HORIZONTAL_ALIGNMENT_CENTER, w, 17, text_col)
	else:
		st.ring(self, centre, 46.0, CLOSED_COLOR, 2.0, 0.6, 0.4)
		draw_string(font, centre + Vector2(-w * 0.5, 12), "+", HORIZONTAL_ALIGNMENT_CENTER, w, 40, Color(CLOSED_COLOR, 0.6))

	if player_ready:
		draw_rect(Rect2(0, 108, w, 44), Color(col.darkened(0.6), 0.92))
		draw_string(font, Vector2(0, 140), "READY", HORIZONTAL_ALIGNMENT_CENTER, w, 28, st.color(Color.WHITE, 2.0))

	if hint != "":
		draw_multiline_string(font, Vector2(8, size.y - 44), hint, HORIZONTAL_ALIGNMENT_CENTER, w - 16, 14, -1,
			Color(0.75, 0.78, 0.95))

	# Hand markers under the card: a little arrow and the player's label in their colour.
	var x := w * 0.5 - (hands.size() - 1) * 26.0
	for h: Array in hands:
		var tip := Vector2(x, size.y + 8.0)
		var hc: Color = h[1]
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-9, 13), tip + Vector2(9, 13)]), st.color(hc, 2.0))
		draw_string(font, tip + Vector2(-26, 32), h[0], HORIZONTAL_ALIGNMENT_CENTER, 52, 16, st.color(hc, 1.8))
		x += 52.0
