class_name FxLayer
extends Node2D
## Throwaway particles and shockwave rings. Purely visual. Put one in a scene
## and Juice.burst() / Juice.shockwave() draw here; without one they do nothing.
## Freezes during hitstop because delta is 0 then. Sparks are dots, or streaks
## when the theme's `style.spark_streak` is set.

var parts: Array = []   # {pos, vel, life, max, size, color}
var waves: Array = []   # {pos, from, to, age, dur, color}


func _enter_tree() -> void:
	add_to_group("fx")


## With a `dir`, the sparks spray that way, `spread` radians either side.
func burst(pos: Vector2, col: Color, count: int, speed: float = 250.0, dir := Vector2.ZERO, spread := PI) -> void:
	var aimed := dir.length() > 0.001
	for i in count:
		var life := randf_range(0.25, 0.55)
		var a := dir.angle() + randf_range(-spread, spread) if aimed else randf() * TAU
		parts.append({
			"pos": pos,
			"vel": Vector2.from_angle(a) * speed * randf_range(0.3, 1.0),
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
	var theme := GameTheme.current()
	if theme.draw_override("fx", self):
		return
	var st := theme.style
	for w in waves:
		var t: float = w["age"] / w["dur"]
		var e := 1.0 - pow(1.0 - t, 3.0)  # ease out
		var r := lerpf(w["from"], w["to"], e)
		st.ring(self, w["pos"], r, w["color"], 10.0 * (1.0 - t) + 1.0, 2.5 * (1.0 - t), (1.0 - t) * 0.8)
	for p in parts:
		var k: float = p["life"] / p["max"]
		var pos: Vector2 = p["pos"]
		if st.spark_streak > 0.0:
			var v: Vector2 = p["vel"]
			st.line(self, pos, pos - v * st.spark_streak, p["color"], maxf(p["size"] * 0.6 * k, 1.0), 1.0 + 2.0 * k, k)
		else:
			st.dot(self, pos, p["size"] * k, p["color"], 1.0 + 2.0 * k, k)
