extends "res://scripts/fx.gd"
## Neon particles: glowing streaks along their velocity instead of dots,
## and over-bright shockwave rings so they bloom.

const NT = preload("res://scripts/neon/neon_tuning.gd")


func _draw() -> void:
	for w in _waves:
		var t: float = w["age"] / w["dur"]
		var e := 1.0 - pow(1.0 - t, 3.0)
		var r := lerpf(w["from"], w["to"], e)
		var c: Color = w["color"]
		var k := 2.5 * (1.0 - t) * NT.BRIGHTNESS
		draw_arc(w["pos"], r, 0.0, TAU, 64, Color(c.r * k, c.g * k, c.b * k, 1.0 - t), 6.0 * (1.0 - t) + 1.0, true)
	for p in _parts:
		var k: float = p["life"] / p["max"]
		var c: Color = p["color"]
		var pos: Vector2 = p["pos"]
		var v: Vector2 = p["vel"]
		var glow := (1.0 + 2.0 * k) * NT.BRIGHTNESS
		draw_line(pos, pos - v * 0.045, Color(c.r * glow, c.g * glow, c.b * glow, k), maxf(p["size"] * 0.6 * k, 1.0), true)
