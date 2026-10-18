class_name Slash
extends Node2D
## One swing of a blob's blade: a crescent that whips across
## `stats.slash_angle` either side of where it was aimed, out to
## `stats.slash_range` beyond the blob's edge. It lands at once, no windup:
## for `stats.slash_active` seconds every blob inside the arc is cut once,
## knocked along the swing, and the slasher recoils back off it. A blob with
## its shield up blocks it (Blob.try_block()) and the slasher staggers back
## instead. Spawned as a child of the blob, so it follows it; frees itself
## once the crescent has faded. Draws above the blobs (z_index 4 in its scene).

const FADE := 0.13 # the crescent lingers this long after the blade stops
const MARK_TIME := 0.16 # the white cut left on whoever was hit

var slasher: Blob
var stats: BlobStats
var dir := Vector2.RIGHT
var swing := 1.0 # 1 or -1: which way the blade sweeps (alternates, like a combo)
var power := 1.0
var age := 0.0

var _launched := false
var _hit: Array[Blob] = []
var _marks: Array = [] # {pos (global), n, age, blocked}


func _ready() -> void:
	process_physics_priority = 15 # after blobs move (0) and attack (10)


func launch(by: Blob, aim: Vector2, side: float, strength := 1.0) -> void:
	slasher = by
	stats = by.stats
	dir = aim.normalized()
	swing = side
	power = strength
	_launched = true
	_cut() # the first frame already hits: no delay between button and contact


func _physics_process(delta: float) -> void:
	if delta <= 0.0 or not _launched:
		return
	age += delta
	for m in _marks:
		m["age"] += delta
	if age <= stats.slash_active:
		_cut()
	if age >= stats.slash_active + FADE and age >= MARK_TIME:
		queue_free()


func reach() -> float:
	return slasher.radius + stats.slash_range


## Whether `b` is inside the arc right now.
func covers(b: Blob) -> bool:
	var rel := b.global_position - slasher.global_position
	var dist := rel.length()
	if dist - b.radius > reach():
		return false
	var slack := asin(minf(b.radius / maxf(dist, 0.001), 1.0))
	return absf(dir.angle_to(rel)) <= deg_to_rad(stats.slash_angle) + slack


func _cut() -> void:
	if not is_instance_valid(slasher) or not slasher.alive:
		return
	for b: Blob in get_tree().get_nodes_in_group("blobs"):
		if b == slasher or not b.alive or b.is_ghost() or _hit.has(b) or not covers(b):
			continue
		_hit.append(b)
		var rel := b.global_position - slasher.global_position
		var radial := rel.normalized() if rel.length() > 0.001 else dir
		var contact := b.global_position - radial * b.radius
		if b.try_block(slasher, contact):
			_blocked(b, radial, contact)
			return # the blade bounced off: the swing is over
		_land(b, radial, contact)


## A clean hit: knock `b` along the swing, the slasher recoils, freeze frame.
func _land(b: Blob, radial: Vector2, contact: Vector2) -> void:
	var js := Juice.settings
	var n := (dir * 0.65 + radial * 0.35).normalized()
	var dv := stats.slash_impulse * power / pow(b.mass, b.stats.push_resist_exp)
	b.take_hit(n, dv, b.stats.slash_stun)
	# Pogo-style recoil: lose the forward lunge and bounce back off the target.
	var fwd := slasher.vel.dot(dir)
	if fwd > 0.0:
		slasher.vel -= dir * fwd
	slasher.vel -= dir * stats.slash_recoil * clampf(b.mass / slasher.mass, 0.5, 2.0)
	slasher.bump(-dir, 300.0)
	_marks.append({"pos": contact, "n": n, "age": 0.0, "blocked": false})
	Juice.burst(contact, Color.WHITE, 10, dv * 0.9, n, 0.5)
	Juice.burst(contact, b.color.lightened(0.3), 8, dv * 0.6, n, 0.9)
	Juice.impact_at(contact, dv * 1.4)
	Juice.hitstop(js.hitstop_slash)
	Juice.shake(js.shake_slash)
	Sfx.play("slash_hit", randf_range(0.9, 1.1) / sqrt(b.mass), 2.0, 0.0)
	Sfx.play("boing", randf_range(0.6, 0.7), -2.0, 0.0)


## Hit a shield: the target barely moves, the slasher is thrown back and staggered.
func _blocked(b: Blob, radial: Vector2, contact: Vector2) -> void:
	slasher.take_hit(-radial, stats.slash_blocked_recoil, stats.slash_blocked_stun)
	b.take_hit(radial, stats.slash_impulse * stats.shield_absorb / pow(b.mass, b.stats.push_resist_exp), 0.0)
	_marks.append({"pos": contact, "n": radial, "age": 0.0, "blocked": true})
	age = maxf(age, stats.slash_active) # stop cutting, start fading


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("slash", self):
		return
	if not _launched or not is_instance_valid(slasher):
		return
	var st := theme.style
	var col := slasher.color
	var half := deg_to_rad(stats.slash_angle)
	var a := dir.angle()
	var start := a - half * swing
	# The blade whips across fast (ease out), then the tail catches up as it fades.
	var s := clampf(age / maxf(stats.slash_active, 0.001), 0.0, 1.0)
	var head := 0.7 + 0.3 * (1.0 - pow(1.0 - s, 3.0))
	var f := clampf((age - stats.slash_active) / FADE, 0.0, 1.0)
	var tail := f * f * head
	var outer := reach() + 6.0
	if head - tail > 0.02:
		var thick := (stats.slash_range * 0.55 + 8.0) * (1.0 - f * 0.6)
		_crescent(st.color(col.lerp(Color.WHITE, 0.2), 1.2, 0.5 * (1.0 - f)), start, half * 2.0 * swing,
			tail, head, outer + 4.0, thick * 1.25)
		_crescent(st.color(Color.WHITE, 1.8, 1.0 - f * f), start, half * 2.0 * swing,
			tail, head, outer, thick * 0.6)
		# The edge of the blade, a hair outside the crescent.
		var edge := PackedVector2Array()
		for i in 13:
			var t := lerpf(tail, head, i / 12.0)
			edge.append(Vector2.from_angle(start + half * 2.0 * swing * t) * (outer + 1.0))
		draw_polyline(edge, st.color(Color.WHITE, 2.0, 0.9 * (1.0 - f)), 2.5, true)
	for m in _marks:
		_draw_mark(st, m)


## A crescent between `tail` and `head` (0..1 along the sweep from `start`
## through `span` radians), thickest just behind the head.
func _crescent(c: Color, start: float, span: float, tail: float, head: float, outer: float, thick: float) -> void:
	var pts := PackedVector2Array()
	const N := 16
	for i in N + 1:
		pts.append(Vector2.from_angle(start + span * lerpf(tail, head, float(i) / N)) * outer)
	for i in N + 1:
		var k := 1.0 - float(i) / N
		var w := thick * pow(k, 0.6) * (1.0 - pow(k, 6.0)) # 0 at both ends, fat near the head
		pts.append(Vector2.from_angle(start + span * lerpf(tail, head, k)) * (outer - w))
	draw_colored_polygon(pts, c)


## The cut: a long thin white streak across the contact point that snaps
## open and thins out. Blocked hits leave a short bright star instead.
func _draw_mark(st: ThemeStyle, m: Dictionary) -> void:
	var k: float = m["age"] / MARK_TIME
	if k >= 1.0:
		return
	var p := to_local(m["pos"])
	var n: Vector2 = m["n"]
	var across := Vector2(-n.y, n.x)
	if m["blocked"]:
		var r := 14.0 + 18.0 * k
		for i in 4:
			var d := Vector2.from_angle(n.angle() + PI * 0.25 + i * PI * 0.5)
			st.line(self, p + d * r * 0.3, p + d * r, Color.WHITE, 3.0 * (1.0 - k), 2.0, 1.0 - k)
		st.ring(self, p, r * 0.6, Color.WHITE, 2.0, 2.0, 1.0 - k)
		return
	var length := 70.0 * (0.6 + 0.4 * minf(k * 4.0, 1.0))
	var width := 9.0 * (1.0 - k)
	var tilt := across.rotated(0.35 * swing)
	draw_colored_polygon(PackedVector2Array([p - tilt * length, p + n * width * 0.5, p + tilt * length, p - n * width * 0.5]),
		st.color(Color.WHITE, 2.5, 1.0 - k * k))
