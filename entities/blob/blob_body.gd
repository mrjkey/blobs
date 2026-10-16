class_name BlobBody
extends Node2D
## Draws the parent Blob: the jelly spring (squash, stretch, swell), the body,
## eyes and status rings, painted in the theme's style. Only reads the Blob's
## state; the Blob never needs to know how it is drawn.

const SEGMENTS := 40

@onready var blob: Blob = get_parent()

# Jelly: a deformation tensor (xx, yy, xy) on a spring, plus a uniform "swell"
var deform := Vector3.ZERO
var deform_vel := Vector3.ZERO
var swell := -0.8              # start squished so blobs "pop" in
var swell_vel := 0.0
var draw_radius := 22.0
var look := Vector2.RIGHT
var flash := 0.0
var blink := 0.0 # > 0 while the eyes are shut
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

	blink = maxf(blink - delta, 0.0)
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		blink = 0.12
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
func xf(p: Vector2) -> Vector2:
	return Vector2(
		p.x - (deform.x * p.x + deform.z * p.y),
		p.y - (deform.z * p.x + deform.y * p.y))


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("blob", self):
		return
	var st := theme.style
	var r := draw_radius * (1.0 + swell)
	var pts := PackedVector2Array()
	for i in SEGMENTS:
		var a := TAU * i / SEGMENTS
		pts.append(xf(Vector2(cos(a), sin(a))) * r)
	st.body(self, pts, blob.color, flash, 1.0, 1.5, 3.0, true)
	if blob.windup > 0.0:
		st.outline(self, pts, st.color(Color.WHITE, 2.0), 3.5)
	if st.highlights:
		draw_circle(xf(Vector2(-0.38, -0.4)) * r, r * 0.22, Color(1, 1, 1, 0.3))
	_draw_eyes(st, r)
	_draw_status(st, r)


func _draw_eyes(st: ThemeStyle, r: float) -> void:
	var side := Vector2(-look.y, look.x)
	var dizzy := blob.stun > 0.0 or not blob.alive
	var mark := st.mark(blob.color)
	for s: float in [-1.0, 1.0]:
		var c := xf(look * 0.38 + side * (0.3 * s)) * r
		var er := r * 0.2
		if dizzy:
			var e := er * 0.7
			draw_line(c + Vector2(-e, -e), c + Vector2(e, e), mark, 2.5, true)
			draw_line(c + Vector2(-e, e), c + Vector2(e, -e), mark, 2.5, true)
		elif blink > 0.0:
			draw_line(c - side * er, c + side * er, mark, 2.5, true)
		else:
			draw_circle(c, er, st.color(Color.WHITE, 2.2))
			draw_circle(c + look * er * 0.4, er * 0.5, st.ink)
		if blob.windup > 0.0 or (blob.push_cooldown > blob.stats.push_cooldown - 0.15):
			# angry brows while pushing
			var brow_in := c + look * er * 0.9 - side * (er * 0.5 * s)
			var brow_out := c + look * er * 1.5 + side * (er * 0.9 * s)
			draw_line(brow_in, brow_out, mark, 3.0, true)


func _draw_status(st: ThemeStyle, r: float) -> void:
	if not blob.alive:
		return
	if blob.is_human():
		var ring_r := r + 8.0
		if blob.push_cooldown > 0.0:
			var frac := 1.0 - blob.push_cooldown / blob.stats.push_cooldown
			if frac > 0.01:
				st.ring(self, Vector2.ZERO, ring_r, Color.WHITE, 3.0, 1.2, 0.3, -PI / 2.0, -PI / 2.0 + TAU * frac)
		else:
			st.ring(self, Vector2.ZERO, ring_r, Color.WHITE, 2.0, 1.6, 0.6)
		var tip := Vector2(0.0, -r - 14.0)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-7, -10), tip + Vector2(7, -10)]), st.color(Color.WHITE, 2.5))
		if blob.tag != "":
			draw_string(ThemeDB.fallback_font, tip + Vector2(-30.0, -14.0), blob.tag,
				HORIZONTAL_ALIGNMENT_CENTER, 60.0, 16, st.color(Color.WHITE, 2.0))
	if blob.ring_danger > 0.0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
		st.ring(self, Vector2.ZERO, r + 4.0, Color(1.0, 0.25, 0.2), 4.0, 1.5 + 1.5 * pulse, 0.6 + 0.4 * pulse,
			-PI / 2.0, -PI / 2.0 + TAU * blob.ring_danger)
