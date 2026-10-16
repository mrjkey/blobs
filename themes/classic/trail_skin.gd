@tool
class_name TrailSkin
extends ThemeSkin
## A motion trail: a tapering line through the blob's last few positions.
## Classic leaves its trail slot empty (no trails); this plain version is here
## for themes that want one without the glow.

@export var frames := 12 # trail length in frames


func draw(trail: BlobTrail) -> void:
	var blob := trail.blob
	var n := trail.points.size()
	for i in range(1, n):
		var f := float(i) / n
		trail.draw_line(trail.to_local(trail.points[i - 1]), trail.to_local(trail.points[i]),
			Color(blob.color, 0.35 * f), maxf(blob.radius * 1.3 * f, 1.0), true)
