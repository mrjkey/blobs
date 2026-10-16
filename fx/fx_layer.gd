class_name FxLayer
extends Node2D
## Throwaway particles and shockwave rings. Purely visual. Put one in a scene
## and Juice.burst() / Juice.shockwave() draw here; without one they do nothing.
## Freezes during hitstop because delta is 0 then.

var _parts: Array = []   # {pos, vel, life, max, size, color}
var _waves: Array = []   # {pos, from, to, age, dur, color}


func _enter_tree() -> void:
	add_to_group("fx")


func burst(pos: Vector2, col: Color, count: int, speed: float = 250.0) -> void:
	for i in count:
		var life := randf_range(0.25, 0.55)
		_parts.append({
			"pos": pos,
			"vel": Vector2.from_angle(randf() * TAU) * speed * randf_range(0.3, 1.0),
			"life": life,
			"max": life,
			"size": randf_range(2.5, 5.5),
			"color": col,
		})


func shockwave(pos: Vector2, from_r: float, to_r: float, col: Color, dur: float = 0.28) -> void:
	_waves.append({"pos": pos, "from": from_r, "to": to_r, "age": 0.0, "dur": dur, "color": col})


func _process(delta: float) -> void:
	for p in _parts:
		p["vel"] *= exp(-4.0 * delta)
		p["pos"] += p["vel"] * delta
		p["life"] -= delta
	_parts = _parts.filter(func(p): return p["life"] > 0.0)
	for w in _waves:
		w["age"] += delta
	_waves = _waves.filter(func(w): return w["age"] < w["dur"])
	queue_redraw()


func _draw() -> void:
	for w in _waves:
		var t: float = w["age"] / w["dur"]
		var e := 1.0 - pow(1.0 - t, 3.0)  # ease out
		var r := lerpf(w["from"], w["to"], e)
		var c: Color = w["color"]
		c.a = (1.0 - t) * 0.8
		draw_arc(w["pos"], r, 0.0, TAU, 64, c, 10.0 * (1.0 - t) + 1.0, true)
	for p in _parts:
		var k: float = p["life"] / p["max"]
		var c: Color = p["color"]
		c.a = k
		draw_circle(p["pos"], p["size"] * k, c)
