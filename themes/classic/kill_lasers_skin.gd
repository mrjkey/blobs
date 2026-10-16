@tool
class_name KillLasersSkin
extends ThemeSkin
## Classic kill lasers: a flickering red line with a soft band and end caps.

@export var color := Color(1.0, 0.25, 0.2) # also the zap when a blob crosses


func draw(kl: KillLasers) -> void:
	var half := kl.settings.track_width * 0.5
	for y: float in [kl.kill_top(), kl.kill_bottom()]:
		var flicker := 0.85 + 0.15 * sin(kl.clock * 40.0 + y * 0.1)
		var a := kl.to_local(Vector2(-half, y))
		var b := kl.to_local(Vector2(half, y))
		kl.draw_line(a, b, Color(color, 0.18), 14.0, true)
		kl.draw_line(a, b, Color(color, flicker), 4.0, true)
		for end: Vector2 in [a, b]:
			kl.draw_circle(end, 7.0, color.darkened(0.3))
