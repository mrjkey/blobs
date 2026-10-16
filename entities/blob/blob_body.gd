class_name BlobBody
extends Node2D
## The parent Blob's look: runs the jelly spring (squash, stretch, swell), the
## blinking and where the eyes look, and has the current theme's BlobSkin draw
## it. Only reads the Blob's state; the Blob never needs to know how it is drawn.

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
	GameTheme.current().blob.draw(self)
