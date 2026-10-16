@tool
class_name FxSkin
extends ThemeSkin
## Classic effects: shockwave rings and round sparks that shrink and fade.


func draw(layer: FxLayer) -> void:
	for w in layer.waves:
		var t: float = w["age"] / w["dur"]
		var e := 1.0 - pow(1.0 - t, 3.0)  # ease out
		var r := lerpf(w["from"], w["to"], e)
		var c: Color = w["color"]
		c.a = (1.0 - t) * 0.8
		layer.draw_arc(w["pos"], r, 0.0, TAU, 64, c, 10.0 * (1.0 - t) + 1.0, true)
	for p in layer.parts:
		var k: float = p["life"] / p["max"]
		var c: Color = p["color"]
		c.a = k
		layer.draw_circle(p["pos"], p["size"] * k, c)
