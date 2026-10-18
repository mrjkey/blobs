class_name Spit
extends Shot
## A glob of blob, flying straight. Knocks back the first blob it touches,
## slimes it (Blob.slime(): slippery, and drained of some energy) and splats;
## fizzles out after `stats.spit_range`. Reflected by a shield, it
## turns round at the shooter, takes the shield blob's colour and gets a
## white ring for each reflection. Draws itself stretched along its flight, with a short trail.

const TRAIL := 6

var _travelled := 0.0
var _trail: Array[Vector2] = []


func time_to_reach(b: Blob) -> float:
	var rel := b.global_position - global_position
	var along := rel.dot(dir)
	if along < -b.radius or along - b.radius > stats.spit_range - _travelled:
		return INF
	if (rel - dir * along).length() > b.radius + stats.spit_radius + 6.0:
		return INF
	return maxf(along - b.radius - stats.spit_radius, 0.0) / speed


func _base_speed() -> float:
	return stats.spit_speed


func _advance(delta: float) -> void:
	_trail.push_front(global_position)
	if _trail.size() > TRAIL:
		_trail.pop_back()
	var step := dir * speed * delta
	global_position += step
	_travelled += step.length()


func _touches(b: Blob) -> bool:
	return b.global_position.distance_to(global_position) < b.radius + stats.spit_radius


func _hit_blob(b: Blob) -> void:
	var js := Juice.settings
	var dv := stats.spit_impulse * power / pow(b.mass, b.stats.push_resist_exp)
	b.take_hit(dir, dv, b.stats.spit_stun)
	b.slime(color)
	Juice.burst(global_position, color.lightened(0.4), 12, dv * 0.6)
	Juice.impact_at(global_position, dv)
	Juice.hitstop(js.hitstop_push * 0.6)
	Juice.shake(js.shake_push * 0.6)
	Sfx.play("boing", randf_range(0.9, 1.0), 0.0, 0.0)
	_done = true


func _reflect(by: Blob) -> void:
	dir = _aim_back(by)
	shooter = by
	color = by.color
	reflections += 1
	power *= stats.reflect_boost
	speed = minf(speed * stats.reflect_speedup, stats.shot_max_speed)
	_travelled = 0.0
	_skip.clear()
	_trail.clear()
	global_position = by.global_position + dir * (by.radius + stats.spit_radius)


func _spent() -> bool:
	return _travelled >= stats.spit_range


func _fizzle() -> void:
	if not _done:
		Juice.burst(global_position, color.lightened(0.3), 5, 120.0)


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("spit", self):
		return
	if not _launched:
		return
	var st := theme.style
	var r := stats.spit_radius
	modulate.a = clampf((stats.spit_range - _travelled) / (stats.spit_range * 0.15), 0.0, 1.0)
	for i in _trail.size():
		var k := 1.0 - float(i + 1) / (TRAIL + 1)
		st.dot(self, _trail[i] - global_position, r * (0.3 + 0.5 * k), color, 1.5, 0.4 * k)
	var stretch := 1.0 + clampf(speed / 1500.0, 0.0, 0.6)
	var wobble := 0.08 * sin(age * 40.0)
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a) * r * (stretch + wobble), sin(a) * r * (1.0 / stretch - wobble)).rotated(dir.angle()))
	st.body(self, pts, color, 0.0, 1.0, 1.8, 2.0, true)
	for i in mini(reflections, 3):
		st.ring(self, Vector2.ZERO, r + 4.0 + i * 4.0, Color.WHITE, 2.0, 2.5, 0.8)
