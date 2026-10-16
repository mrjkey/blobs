@tool
class_name WallSkin
extends ThemeSkin
## Classic walls: solid blocks with a drop shadow. Kickers are pink with an
## inner stripe, and flash white when they fire.

@export var wall_color := Color(0.55, 0.6, 0.8) # also the sparks when a blob hits a plain wall
@export var kicker_color := Color(1.0, 0.45, 0.7)


func draw(w: WallBlock) -> void:
	var r := Rect2(-w.size * 0.5, w.size)
	var col := kicker_color if w.kicker else wall_color
	w.draw_rect(Rect2(r.position + Vector2(3.0, 6.0), r.size), Color(0, 0, 0, 0.28))
	w.draw_rect(r, col.darkened(0.2).lerp(Color.WHITE, w.flash * 0.6))
	w.draw_rect(r, col.darkened(0.5), false, 3.0)
	if w.kicker and w.size.x > 14.0 and w.size.y > 14.0:
		w.draw_rect(r.grow(-6.0), col.lightened(0.35), false, 2.0)
