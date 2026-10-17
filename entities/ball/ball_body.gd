class_name BallBody
extends BlobBody
## Draws the parent Ball: a jelly disc (the same squash and stretch as a
## blob) with twelve patches that roll the way it moves. Colours from the
## theme: ball.color, and ball.patch (default: the theme's ink, or a glowing
## ball colour in glowing themes).

const COLOR := Color(0.95, 0.95, 0.9)
const PHI := 1.618034

## The patch centres: an icosahedron's corners on the unit sphere.
var _patches: Array[Vector3] = []
var _spin := Basis.IDENTITY


func _ready() -> void:
	super._ready()
	for a in [-1.0, 1.0]:
		for b in [-PHI, PHI]:
			_patches.append(Vector3(0.0, a, b).normalized())
			_patches.append(Vector3(a, b, 0.0).normalized())
			_patches.append(Vector3(b, 0.0, a).normalized())


func _process(delta: float) -> void:
	super._process(delta)
	var v := blob.vel
	var speed := v.length()
	if speed > 1.0 and draw_radius > 0.0:
		# Rolling on the floor: the top of the ball moves with the ball.
		_spin = Basis(Vector3(-v.y, v.x, 0.0) / speed, speed * delta / draw_radius) * _spin
		_spin = _spin.orthonormalized()


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("ball", self):
		return
	var st := theme.style
	var r := draw_radius * (1.0 + swell)
	var col: Color = theme.value("ball.color", COLOR)
	var pts := PackedVector2Array()
	for i in SEGMENTS:
		var a := TAU * i / SEGMENTS
		pts.append(xf(Vector2(cos(a), sin(a))) * r)
	st.body(self, pts, col, flash, 1.0, 1.5, 3.0, true)
	var patch: Color = theme.value("ball.patch", st.mark(col))
	for p0 in _patches:
		var p := _spin * p0
		if p.z <= 0.05:
			continue # on the far side
		draw_circle(xf(Vector2(p.x, p.y) * 0.78) * r, r * 0.24 * sqrt(p.z), patch)
	if st.highlights:
		draw_circle(xf(Vector2(-0.38, -0.4)) * r, r * 0.22, Color(1, 1, 1, 0.3))
