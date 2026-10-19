@tool
class_name BeltSign
extends Node2D
## A sign painted across the belt, read as it scrolls past: the warm-up level
## names each new idea with one ("CATCH THE FOOD"). Drawn in the editor and
## the game, under the items (z_index -1).

@export var text := "SIGN":
	set(v):
		text = v
		queue_redraw()
@export var color := Color(1.0, 0.9, 0.4):
	set(v):
		color = v
		queue_redraw()
@export var settings: TrackSettings = preload("res://level/arenas/track/track_settings.tres")


func _ready() -> void:
	z_index = -1


func _draw() -> void:
	var half := settings.track_width * 0.5 - 30.0
	var board := Rect2(-half, -42.0, half * 2.0, 84.0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.05, 0.1, 0.55)
	box.border_color = Color(color, 0.8)
	box.set_border_width_all(4)
	box.set_corner_radius_all(16)
	box.draw(get_canvas_item(), board)
	draw_string(ThemeDB.fallback_font, Vector2(-half, 16.0), text, HORIZONTAL_ALIGNMENT_CENTER, half * 2.0, 44, color)
