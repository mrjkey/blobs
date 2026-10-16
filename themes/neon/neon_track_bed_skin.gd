@tool
class_name NeonTrackBedSkin
extends TrackBedSkin
## Neon treadmill bed: glowing side walls that brighten on the kick, dim belt
## chevrons, shaded zones outside the walls; the grid shows through the floor.


func draw(bed: SideWalls) -> void:
	var span := bed.visible_span()
	var y0 := span.x
	var y1 := span.y
	var half := bed.settings.track_width * 0.5
	var k := kick(bed)

	# Off-track zones where the ships fly.
	bed.draw_rect(Rect2(-half - 800.0, y0, 800.0, y1 - y0), shade_color)
	bed.draw_rect(Rect2(half, y0, 800.0, y1 - y0), shade_color)

	_draw_chevrons(bed, y0, y1, half, NeonLook.hdr(belt_color, 0.8, 0.2), 3.0)

	# Side walls.
	for sx: float in [-half, half]:
		bed.draw_line(Vector2(sx, y0), Vector2(sx, y1), NeonLook.hdr(side_wall_color, 1.6 + 0.4 * k), 5.0, true)
		var inner := sx - signf(sx) * 10.0
		bed.draw_line(Vector2(inner, y0), Vector2(inner, y1), NeonLook.hdr(side_wall_color, 0.7, 0.4), 1.5, true)
