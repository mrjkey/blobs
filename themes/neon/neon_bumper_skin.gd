@tool
class_name NeonBumperSkin
extends BumperSkin
## Neon bumper: glowing rings that pop bigger when hit and pulse on the kick.


func draw(b: Bumper) -> void:
	var k := kick(b)
	var rr := b.radius * (1.0 + 0.25 * b.flash)
	b.draw_circle(Vector2.ZERO, rr, Color(0.08, 0.06, 0.0, 0.9))
	b.draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, NeonLook.hdr(color, 1.8 + 3.0 * b.flash + 0.4 * k), 4.0, true)
	b.draw_arc(Vector2.ZERO, rr * 0.6, 0.0, TAU, 32, NeonLook.hdr(color, 1.2 + 2.0 * b.flash, 0.7), 2.0, true)
	b.draw_circle(Vector2.ZERO, rr * 0.22, NeonLook.hdr(color, 1.5 + 3.0 * b.flash))
