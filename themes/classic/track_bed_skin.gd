@tool
class_name TrackBedSkin
extends ThemeSkin
## Classic treadmill bed: a flat floor between two thick walls, faint belt
## chevrons that slide down with the world, darker ground outside the walls.

@export var floor_color := Color(0.19, 0.22, 0.31)
@export var shade_color := Color(0.11, 0.07, 0.1) # outside the walls, where the ships fly
@export var belt_color := Color(1.0, 1.0, 1.0, 0.06)
@export var side_wall_color := Color(0.55, 0.6, 0.8)
@export var spark_color := Color(0.55, 0.6, 0.8) # sparks when a blob hits a side wall


func draw(bed: SideWalls) -> void:
	var span := bed.visible_span()
	var y0 := span.x
	var y1 := span.y
	var half := bed.settings.track_width * 0.5
	bed.draw_rect(Rect2(-half - 800.0, y0, 800.0, y1 - y0), shade_color)
	bed.draw_rect(Rect2(half, y0, 800.0, y1 - y0), shade_color)
	bed.draw_rect(Rect2(-half, y0, half * 2.0, y1 - y0), floor_color)
	_draw_chevrons(bed, y0, y1, half, belt_color, 4.0)
	for sx: float in [-half, half]:
		var x := sx + signf(sx) * 7.0
		bed.draw_line(Vector2(x, y0), Vector2(x, y1), side_wall_color, 14.0)


## Belt chevrons are fixed in the world, so they slide down the screen.
func _draw_chevrons(bed: SideWalls, y0: float, y1: float, half: float, color: Color, width: float) -> void:
	var step := 120.0
	var yy := floorf(y0 / step) * step
	while yy < y1:
		for cx: float in [-half * 0.55, 0.0, half * 0.55]:
			var p := Vector2(cx, yy)
			bed.draw_polyline(PackedVector2Array([p + Vector2(-26, -10), p + Vector2(0, 8), p + Vector2(26, -10)]),
				color, width, true)
		yy += step
