@tool
class_name RushZone
extends Node2D
## A stretch of a Don't Get Fat! level where the belt surges: from this
## node's y up the belt for `length` px, the belt runs at its FatRules
## rush_speed (the mode eases in and out). Yellow chevrons along both edges
## of the track warn that it's coming. Group "rush_zones".

@export var length := 1500.0:
	set(v):
		length = v
		queue_redraw()
@export var settings: TrackSettings = preload("res://level/arenas/track/track_settings.tres")

const COLOR := Color(1.0, 0.8, 0.2)
const STEP := 90.0 # between chevrons


func _enter_tree() -> void:
	add_to_group("rush_zones")


## Whether world y `y` is inside the zone.
func covers(y: float) -> bool:
	return y <= global_position.y and y >= global_position.y - length


func _draw() -> void:
	var half := settings.track_width * 0.5
	if Engine.is_editor_hint():
		draw_rect(Rect2(-half, -length, half * 2.0, length), Color(COLOR, 0.08))
		draw_string(ThemeDB.fallback_font, Vector2(-half + 12.0, -14.0), "RUSH %d px" % roundi(length),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 28, COLOR)
	var y := -STEP * 0.5
	while y > -length:
		for side: float in [-1.0, 1.0]:
			var x := side * (half - 22.0)
			draw_polyline(PackedVector2Array([Vector2(x - 14.0, y + 10.0), Vector2(x, y - 6.0), Vector2(x + 14.0, y + 10.0)]),
				Color(COLOR, 0.75), 6.0, true)
		y -= STEP
