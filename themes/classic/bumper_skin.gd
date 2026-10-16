@tool
class_name BumperSkin
extends ThemeSkin
## Classic pinball bumper: a gold disc with a rim and a bright centre that pops
## bigger and whiter when hit.

@export var color := Color(1.0, 0.8, 0.25) # also the burst when anything kicks a blob


func draw(b: Bumper) -> void:
	var rr := b.radius * (1.0 + 0.25 * b.flash)
	var fill := color.darkened(0.15).lerp(Color.WHITE, b.flash * 0.5)
	b.draw_circle(Vector2(3.0, 6.0), rr, Color(0, 0, 0, 0.28))
	b.draw_circle(Vector2.ZERO, rr, fill)
	b.draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, color.darkened(0.5), 3.0, true)
	b.draw_arc(Vector2.ZERO, rr * 0.6, 0.0, TAU, 32, color.lightened(0.3), 2.0, true)
	b.draw_circle(Vector2.ZERO, rr * 0.22, Color.WHITE.lerp(color, 0.3))
