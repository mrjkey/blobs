@tool
class_name FinishLine
extends Node2D
## The end of a treadmill map: a chequered band across the track at this
## node's y. The treadmill stops scrolling once the belt's top laser is just
## past it, and the first blob across wins. Group "finish" (bots race for it).

@export var settings: TrackSettings = preload("res://level/arenas/track/track_settings.tres")


func _enter_tree() -> void:
	add_to_group("finish")


func _draw() -> void:
	var half := settings.track_width * 0.5
	const SQUARE := 25.0
	var light := Color(1.0, 1.0, 1.0, 0.7)
	var dark := Color(0.0, 0.0, 0.0, 0.5)
	var col := 0
	var x := -half
	while x < half:
		for row in 2:
			var c := light if (col + row) % 2 == 0 else dark
			draw_rect(Rect2(x, -SQUARE * (2 - row), minf(SQUARE, half - x), SQUARE), c)
		x += SQUARE
		col += 1
	var st := GameTheme.current().style
	st.line(self, Vector2(-half, 0.0), Vector2(half, 0.0), Color.WHITE, 3.0, 2.0)
