@tool
class_name NeonTrailSkin
extends TrailSkin
## A glowing motion trail.


func draw(trail: BlobTrail) -> void:
	var blob := trail.blob
	var n := trail.points.size()
	for i in range(1, n):
		var f := float(i) / n
		trail.draw_line(trail.to_local(trail.points[i - 1]), trail.to_local(trail.points[i]),
			NeonLook.hdr(blob.color, 1.5, 0.35 * f), maxf(blob.radius * 1.3 * f, 1.0), true)
