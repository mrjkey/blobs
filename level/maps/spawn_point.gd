@tool
class_name SpawnPoint
extends Node2D
## Where seat `seat` (P1..P4) starts in a map. Only drawn in the editor: a
## ghost blob with its seat number.

const COLORS := [Color(0.3, 0.8, 1.0), Color(1.0, 0.45, 0.4), Color(0.5, 1.0, 0.5), Color(1.0, 0.85, 0.3)]

@export_range(1, 4) var seat := 1:
	set(v):
		seat = v
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var col: Color = COLORS[(seat - 1) % COLORS.size()]
	draw_circle(Vector2.ZERO, 28.0, Color(col, 0.2))
	draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 40, col, 3.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(-30.0, 9.0), "P%d" % seat, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 24, col)
