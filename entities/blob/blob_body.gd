class_name BlobBody
extends Node2D
## Draws the parent Blob: the jelly spring, the outline, eyes and status rings.
## Only reads the Blob's state; the Blob never needs to know how it is drawn.

const SEGMENTS := 40
const INK := Color(0.08, 0.08, 0.12)

@onready var blob: Blob = get_parent()

# Jelly: a deformation tensor (xx, yy, xy) on a spring, plus a uniform "swell"
var deform := Vector3.ZERO
var deform_vel := Vector3.ZERO
var swell := -0.8              # start squished so blobs "pop" in
var swell_vel := 0.0
var draw_radius := 22.0
var look := Vector2.RIGHT
var flash := 0.0
var _blink := 0.0
var _blink_timer := randf_range(1.0, 4.0)
var _breath_phase := randf() * TAU


func _ready() -> void:
	draw_radius = blob.radius


func _process(delta: float) -> void:
	var stats := blob.stats
	var speed := blob.vel.length()

	# Jelly spring: rest shape is stretched along the direction of travel.
	var rest := Vector3.ZERO
	if speed > 1.0:
		rest = _tensor(blob.vel / speed, -minf(speed * stats.move_stretch, stats.move_stretch_max))
	var acc := (rest - deform) * stats.jelly_stiffness - deform_vel * stats.jelly_damping
	deform_vel += acc * delta
	deform += deform_vel * delta
	deform = deform.limit_length(stats.squash_max)

	_breath_phase += delta * 3.0
	var swell_rest := -0.12 if blob.windup > 0.0 else 0.02 * sin(_breath_phase)
	var sacc := (swell_rest - swell) * stats.swell_stiffness - swell_vel * stats.swell_damping
	swell_vel += sacc * delta
	swell += swell_vel * delta

	draw_radius = lerpf(draw_radius, blob.radius, 1.0 - exp(-10.0 * delta))
	flash = maxf(flash - delta * 5.0, 0.0)

	var want_look := look
	if blob.move_dir.length() > 0.1:
		want_look = blob.move_dir.normalized()
	elif speed > 20.0:
		want_look = blob.vel / speed
	look = look.slerp(want_look, 1.0 - exp(-8.0 * delta)).normalized()

	_blink = maxf(_blink - delta, 0.0)
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 0.12
		_blink_timer = randf_range(1.5, 4.5)

	queue_redraw()


## Puff up (positive) or tense up (negative). Springs back on its own.
func swell_kick(amount: float) -> void:
	swell_vel += amount


## Squash along n. `impact_speed` is in px/s.
func bump(n: Vector2, impact_speed: float) -> void:
	deform_vel += _tensor(n, minf(impact_speed * blob.stats.squash_kick, blob.stats.squash_kick_max))


## Deformation that squashes along n by `amount` and bulges sideways.
func _tensor(n: Vector2, amount: float) -> Vector3:
	var k := blob.stats.jelly_bulge
	return Vector3(
		amount * (n.x * n.x - k * n.y * n.y),
		amount * (n.y * n.y - k * n.x * n.x),
		amount * n.x * n.y * (1.0 + k))


## Apply the current deformation to a point on the unit circle.
func _xf(p: Vector2) -> Vector2:
	return Vector2(
		p.x - (deform.x * p.x + deform.z * p.y),
		p.y - (deform.z * p.x + deform.y * p.y))


func _draw() -> void:
	var r := draw_radius * (1.0 + swell)
	var pts := PackedVector2Array()
	var shadow := PackedVector2Array()
	for i in SEGMENTS:
		var a := TAU * i / SEGMENTS
		var p := _xf(Vector2(cos(a), sin(a))) * r
		pts.append(p)
		shadow.append(p + Vector2(3.0, 6.0))

	draw_colored_polygon(shadow, Color(0, 0, 0, 0.28))
	draw_colored_polygon(pts, blob.color.lerp(Color.WHITE, flash * 0.7))
	var rim := pts.duplicate()
	rim.append(pts[0])
	var rim_col := blob.color.darkened(0.45)
	if blob.windup > 0.0:
		rim_col = Color.WHITE
	draw_polyline(rim, rim_col, 3.0, true)
	draw_circle(_xf(Vector2(-0.38, -0.4)) * r, r * 0.22, Color(1, 1, 1, 0.3))

	_draw_eyes(r)
	_draw_status(r)


func _draw_eyes(r: float) -> void:
	var side := Vector2(-look.y, look.x)
	var dizzy := blob.stun > 0.0 or not blob.alive
	for s: float in [-1.0, 1.0]:
		var c := _xf(look * 0.38 + side * (0.3 * s)) * r
		var er := r * 0.2
		if dizzy:
			var e := er * 0.7
			draw_line(c + Vector2(-e, -e), c + Vector2(e, e), INK, 2.5, true)
			draw_line(c + Vector2(-e, e), c + Vector2(e, -e), INK, 2.5, true)
		elif _blink > 0.0:
			draw_line(c - side * er, c + side * er, INK, 2.5, true)
		else:
			draw_circle(c, er, Color.WHITE)
			draw_circle(c + look * er * 0.4, er * 0.5, INK)
		if blob.windup > 0.0 or (blob.push_cooldown > blob.stats.push_cooldown - 0.15):
			# angry brows while pushing
			var brow_in := c + look * er * 0.9 - side * (er * 0.5 * s)
			var brow_out := c + look * er * 1.5 + side * (er * 0.9 * s)
			draw_line(brow_in, brow_out, INK, 3.0, true)


func _draw_status(r: float) -> void:
	if not blob.alive:
		return
	if blob.is_human():
		var ring_r := r + 8.0
		if blob.push_cooldown > 0.0:
			var frac := 1.0 - blob.push_cooldown / blob.stats.push_cooldown
			if frac > 0.01:
				draw_arc(Vector2.ZERO, ring_r, -PI / 2.0, -PI / 2.0 + TAU * frac, 48, Color(1, 1, 1, 0.3), 3.0, true)
		else:
			draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 48, Color(1, 1, 1, 0.6), 2.0, true)
		var tip := Vector2(0.0, -r - 14.0)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-7, -10), tip + Vector2(7, -10)]), Color.WHITE)
	if blob.ring_danger > 0.0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
		draw_arc(Vector2.ZERO, r + 4.0, -PI / 2.0, -PI / 2.0 + TAU * blob.ring_danger, 48,
			Color(1.0, 0.25, 0.2, 0.6 + 0.4 * pulse), 4.0, true)
