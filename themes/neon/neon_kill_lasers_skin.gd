@tool
class_name NeonKillLasersSkin
extends KillLasersSkin
## Neon kill lasers: a bright flickering beam that pulses on the kick.


func draw(kl: KillLasers) -> void:
	var k := kick(kl)
	var half := kl.settings.track_width * 0.5
	for y: float in [kl.kill_top(), kl.kill_bottom()]:
		var flicker := 0.85 + 0.15 * sin(kl.clock * 40.0 + y * 0.1)
		var a := kl.to_local(Vector2(-half, y))
		var b := kl.to_local(Vector2(half, y))
		kl.draw_line(a, b, NeonLook.hdr(color, 0.9, 0.25), 14.0, true)
		kl.draw_line(a, b, NeonLook.hdr(color, (2.2 + 0.5 * k) * flicker), 3.0, true)
		for end: Vector2 in [a, b]:
			kl.draw_circle(end, 6.0, NeonLook.hdr(color, 2.5))
