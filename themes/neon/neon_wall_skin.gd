@tool
class_name NeonWallSkin
extends WallSkin
## Neon walls: dark glass with a glowing edge. Kickers are pink and flash when they fire.


func draw(w: WallBlock) -> void:
	var r := Rect2(-w.size * 0.5, w.size)
	var col := kicker_color if w.kicker else wall_color
	w.draw_rect(r, Color(col.r * 0.1, col.g * 0.1, col.b * 0.15, 0.9))
	w.draw_rect(r, NeonLook.hdr(col, 1.6 + 2.5 * w.flash), false, 3.0, true)
	if w.kicker and w.size.x > 14.0 and w.size.y > 14.0:
		w.draw_rect(r.grow(-6.0), NeonLook.hdr(col, 0.9 + w.flash, 0.6), false, 1.5, true)
