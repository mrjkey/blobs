class_name FxLayer
extends Node2D
## Throwaway particles and shockwave rings. Purely visual. Put one in a scene
## and Juice.burst() / Juice.shockwave() draw here; without one they do nothing.
## Freezes during hitstop because delta is 0 then. The theme's FxSkin draws them.

var parts: Array = []   # {pos, vel, life, max, size, color}
var waves: Array = []   # {pos, from, to, age, dur, color}


func _enter_tree() -> void:
	add_to_group("fx")


func burst(pos: Vector2, col: Color, count: int, speed: float = 250.0) -> void:
	for i in count:
		var life := randf_range(0.25, 0.55)
		parts.append({
			"pos": pos,
			"vel": Vector2.from_angle(randf() * TAU) * speed * randf_range(0.3, 1.0),
			"life": life,
			"max": life,
			"size": randf_range(2.5, 5.5),
			"color": col,
		})


func shockwave(pos: Vector2, from_r: float, to_r: float, col: Color, dur: float = 0.28) -> void:
	waves.append({"pos": pos, "from": from_r, "to": to_r, "age": 0.0, "dur": dur, "color": col})


func _process(delta: float) -> void:
	for p in parts:
		p["vel"] *= exp(-4.0 * delta)
		p["pos"] += p["vel"] * delta
		p["life"] -= delta
	parts = parts.filter(func(p): return p["life"] > 0.0)
	for w in waves:
		w["age"] += delta
	waves = waves.filter(func(w): return w["age"] < w["dur"])
	queue_redraw()


func _draw() -> void:
	GameTheme.current().fx.draw(self)
