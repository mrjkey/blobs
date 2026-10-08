extends Node2D
## A squishy bumper blob. game.gd drives the physics (so every blob steps in a
## fixed order); this script holds the blob's state, its push ability, and the
## jelly deformation + drawing.

const T = preload("res://scripts/tuning.gd")
const SEGMENTS := 40
const INK := Color(0.08, 0.08, 0.12)

var game                       # game.gd, set on spawn
var brain                      # ai_brain.gd, or null for the human player
var is_player := false
var display_name := "Blob"
var player_tag := ""           # "P1"/"P2" label in multiplayer
var color := Color.WHITE

# Physics
var vel := Vector2.ZERO
var mass := 1.0
var radius := T.BASE_RADIUS
var move_dir := Vector2.ZERO   # steering input, length <= 1

# Push ability
var push_buffer := 0.0         # > 0 means "push as soon as you can"
var push_cooldown := 0.0
var windup := 0.0
var stun := 0.0

# Ring
var outside_time := 0.0
var alive := true
var _death_t := 0.0

# Jelly: a deformation tensor (xx, yy, xy) on a spring, plus a uniform "swell"
var deform := Vector3.ZERO
var deform_vel := Vector3.ZERO
var swell := -0.8              # start squished so blobs "pop" in
var swell_vel := 0.0
var draw_radius := T.BASE_RADIUS
var look := Vector2.RIGHT
var flash := 0.0
var _blink := 0.0
var _blink_timer := randf_range(1.0, 4.0)
var _breath_phase := randf() * TAU


func _ready() -> void:
	set_process(false)  # only used for the death animation


func set_mass(m: float) -> void:
	mass = clampf(m, 0.5, T.MAX_MASS)
	radius = T.BASE_RADIUS * pow(mass, T.SIZE_RADIUS_EXP)


func max_speed() -> float:
	return T.BASE_SPEED / pow(mass, T.SIZE_SPEED_EXP)


func accel() -> float:
	return T.BASE_ACCEL / pow(mass, T.SIZE_ACCEL_EXP)


func push_power() -> float:
	return pow(mass, T.PUSH_MASS_EXP)


## Distance from this blob's centre that a push can reach.
func push_reach() -> float:
	return radius + T.PUSH_RANGE * pow(mass, T.PUSH_RANGE_MASS_EXP)


func push_ready() -> bool:
	return push_cooldown <= 0.0 and windup <= 0.0


func is_winding_up() -> bool:
	return windup > 0.0


func step_motion(h: float) -> void:
	var outside: bool = game.in_mud(position)
	var control := 1.0
	if stun > 0.0:
		control = T.STUN_CONTROL
	if outside:
		control *= T.OUTSIDE_CONTROL
	var top := max_speed()
	# Flying faster than you could run means you got launched: keep the momentum,
	# but bleed it off fast so hits read as a sharp shove, not a slow drift.
	var launched := vel.length() > top * 1.05
	if launched:
		control *= T.KNOCKBACK_CONTROL
	var target := move_dir * top
	var acc := accel()
	if move_dir.dot(vel) < 0.0:
		acc *= T.TURN_ACCEL_MULT  # snappy direction changes
	vel += (target - vel).limit_length(acc * control * h)
	var drag := T.KNOCKBACK_DRAG if launched else T.DRAG
	if outside:
		drag += T.OUTSIDE_DRAG
	vel *= exp(-drag * h)
	position += vel * h


func step_ability(delta: float) -> void:
	push_cooldown = maxf(push_cooldown - delta, 0.0)
	push_buffer = maxf(push_buffer - delta, 0.0)
	stun = maxf(stun - delta, 0.0)
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			windup = 0.0
			push_cooldown = T.PUSH_COOLDOWN
			swell_vel += T.PUSH_SWELL * 22.0
			game.do_push(self)
	elif push_buffer > 0.0 and push_cooldown <= 0.0:
		push_buffer = 0.0
		windup = T.PUSH_WINDUP
		swell_vel -= 3.0  # tense up before the blast


func step_visuals(delta: float) -> void:
	var speed := vel.length()

	# Jelly spring: rest shape is stretched along the direction of travel.
	var rest := Vector3.ZERO
	if speed > 1.0:
		rest = _tensor(vel / speed, -minf(speed * T.MOVE_STRETCH, T.MOVE_STRETCH_MAX))
	var acc := (rest - deform) * T.JELLY_STIFFNESS - deform_vel * T.JELLY_DAMPING
	deform_vel += acc * delta
	deform += deform_vel * delta
	deform = deform.limit_length(T.SQUASH_MAX)

	_breath_phase += delta * 3.0
	var swell_rest := -0.12 if windup > 0.0 else 0.02 * sin(_breath_phase)
	var sacc := (swell_rest - swell) * T.SWELL_STIFFNESS - swell_vel * T.SWELL_DAMPING
	swell_vel += sacc * delta
	swell += swell_vel * delta

	draw_radius = lerpf(draw_radius, radius, 1.0 - exp(-10.0 * delta))
	flash = maxf(flash - delta * 5.0, 0.0)

	var want_look := look
	if move_dir.length() > 0.1:
		want_look = move_dir.normalized()
	elif speed > 20.0:
		want_look = vel / speed
	look = look.slerp(want_look, 1.0 - exp(-8.0 * delta)).normalized()

	_blink = maxf(_blink - delta, 0.0)
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 0.12
		_blink_timer = randf_range(1.5, 4.5)

	queue_redraw()


## Squash along n. `impact_speed` is in px/s.
func bump(n: Vector2, impact_speed: float) -> void:
	deform_vel += _tensor(n, minf(impact_speed * T.SQUASH_KICK, T.SQUASH_KICK_MAX))


func eat() -> void:
	set_mass(mass + T.FOOD_MASS)
	swell_vel += 5.0
	flash = 0.6


func die() -> void:
	alive = false
	_death_t = 0.0
	set_process(true)


func _process(delta: float) -> void:
	# Only runs once eliminated: spin, shrink and fade into the pit.
	_death_t += delta
	var k := _death_t / 0.45
	if k >= 1.0:
		queue_free()
		return
	position += vel * delta
	vel *= exp(-4.0 * delta)
	rotation += delta * 12.0
	scale = Vector2.ONE * (1.0 - k * k)
	modulate.a = 1.0 - k
	queue_redraw()


## Deformation that squashes along n by `amount` and bulges sideways.
static func _tensor(n: Vector2, amount: float) -> Vector3:
	var k := T.JELLY_BULGE
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
	draw_colored_polygon(pts, color.lerp(Color.WHITE, flash * 0.7))
	var rim := pts.duplicate()
	rim.append(pts[0])
	var rim_col := color.darkened(0.45)
	if windup > 0.0:
		rim_col = Color.WHITE
	draw_polyline(rim, rim_col, 3.0, true)
	draw_circle(_xf(Vector2(-0.38, -0.4)) * r, r * 0.22, Color(1, 1, 1, 0.3))

	_draw_eyes(r)
	_draw_status(r)


func _draw_eyes(r: float) -> void:
	var side := Vector2(-look.y, look.x)
	var dizzy := stun > 0.0 or not alive
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
		if windup > 0.0 or (push_cooldown > T.PUSH_COOLDOWN - 0.15):
			# angry brows while pushing
			var brow_in := c + look * er * 0.9 - side * (er * 0.5 * s)
			var brow_out := c + look * er * 1.5 + side * (er * 0.9 * s)
			draw_line(brow_in, brow_out, INK, 3.0, true)


func _draw_status(r: float) -> void:
	if not alive:
		return
	if is_player:
		var ring_r := r + 8.0
		if push_cooldown > 0.0:
			var frac := 1.0 - push_cooldown / T.PUSH_COOLDOWN
			if frac > 0.01:
				draw_arc(Vector2.ZERO, ring_r, -PI / 2.0, -PI / 2.0 + TAU * frac, 48, Color(1, 1, 1, 0.3), 3.0, true)
		else:
			draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 48, Color(1, 1, 1, 0.6), 2.0, true)
		var tip := Vector2(0.0, -r - 14.0)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-7, -10), tip + Vector2(7, -10)]), Color.WHITE)
	if outside_time > 0.0:
		var danger := clampf(outside_time / T.RING_OUT_TIME, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
		draw_arc(Vector2.ZERO, r + 4.0, -PI / 2.0, -PI / 2.0 + TAU * danger, 48,
			Color(1.0, 0.25, 0.2, 0.6 + 0.4 * pulse), 4.0, true)
