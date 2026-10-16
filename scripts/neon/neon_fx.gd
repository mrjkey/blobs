extends "res://scripts/fx.gd"
## Neon particles: glowing streaks along their velocity instead of dots,
## and over-bright shockwave rings so they bloom.

const NeonLook = preload("res://scripts/neon/neon_look.gd")


func _draw() -> void:
	for w in _waves:
		var t: float = w["age"] / w["dur"]
		var e := 1.0 - pow(1.0 - t, 3.0)
		var r := lerpf(w["from"], w["to"], e)
		draw_arc(w["pos"], r, 0.0, TAU, 64, NeonLook.hdr(w["color"], 2.5 * (1.0 - t), 1.0 - t), 6.0 * (1.0 - t) + 1.0, true)
	for p in _parts:
		var k: float = p["life"] / p["max"]
		var pos: Vector2 = p["pos"]
		var v: Vector2 = p["vel"]
		draw_line(pos, pos - v * 0.045, NeonLook.hdr(p["color"], 1.0 + 2.0 * k, k), maxf(p["size"] * 0.6 * k, 1.0), true)
