class_name NeonFood
extends Food
## A spinning neon diamond that swells a little on each kick drum.


func _draw() -> void:
	var k := NeonLook.kick(get_tree())
	var pop := minf(age / 0.25, 1.0)
	var r := radius * (1.0 + 0.4 * sin(pop * PI)) * pop * (1.3 + 0.2 * k)
	var pts := PackedVector2Array()
	for j in 4:
		pts.append(Vector2.from_angle(age * 2.0 + _seed + j * PI / 2.0) * r)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_colored_polygon(pts, NeonLook.hdr(color, 0.5, 0.5))
	draw_polyline(outline, NeonLook.hdr(color, 2.5), 2.0, true)
