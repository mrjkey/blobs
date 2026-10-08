extends Node2D
## Geometry Wars style warping grid. Every grid point sits on a spring; hits
## kick nearby points outward, and the springs plus neighbour coupling turn
## that into ripples. Lines brighten where the grid is stretched.

const NT = preload("res://scripts/neon/neon_tuning.gd")

var pulse := 0.0                    # set by neon_game every frame (beat flash)

var _cols := 0
var _rows := 0
var _rest := PackedVector2Array()
var _disp := PackedVector2Array()
var _vel := PackedVector2Array()


func _ready() -> void:
	_cols = int(NT.GRID_HALF_SIZE.x * 2.0 / NT.GRID_SPACING) + 1
	_rows = int(NT.GRID_HALF_SIZE.y * 2.0 / NT.GRID_SPACING) + 1
	for r in _rows:
		for c in _cols:
			_rest.append(Vector2(c, r) * NT.GRID_SPACING - NT.GRID_HALF_SIZE)
	_disp.resize(_rest.size())
	_vel.resize(_rest.size())


## Push grid points away from `pos`. Negative strength pulls them in.
func impulse(pos: Vector2, strength: float, radius: float) -> void:
	var r2 := radius * radius
	for i in _rest.size():
		var d := _rest[i] + _disp[i] - pos
		var l2 := d.length_squared()
		if l2 >= r2 or l2 < 0.01:
			continue
		var fall := 1.0 - sqrt(l2) / radius
		_vel[i] += d.normalized() * strength * fall * fall


func _physics_process(delta: float) -> void:
	var n := _rest.size()
	for i in n:
		var c := i % _cols
		var r: int = i / _cols
		# Average of the four neighbours (edges are pinned to rest).
		var nb := Vector2.ZERO
		nb += _disp[i - 1] if c > 0 else Vector2.ZERO
		nb += _disp[i + 1] if c < _cols - 1 else Vector2.ZERO
		nb += _disp[i - _cols] if r > 0 else Vector2.ZERO
		nb += _disp[i + _cols] if r < _rows - 1 else Vector2.ZERO
		var acc := -_disp[i] * NT.GRID_STIFFNESS - _vel[i] * NT.GRID_DAMPING
		acc += (nb - _disp[i] * 4.0) * NT.GRID_COUPLING
		_vel[i] += acc * delta
	for i in n:
		_disp[i] += _vel[i] * delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-NT.GRID_HALF_SIZE * 2.0, NT.GRID_HALF_SIZE * 4.0), Color(0.008, 0.0, 0.025))
	var base := NT.GRID_COLOR
	var dim := 0.22 + 0.12 * pulse
	# Rows
	for r in _rows:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for c in _cols:
			var i := r * _cols + c
			pts.append(_rest[i] + _disp[i])
			cols.append(_line_color(base, dim, _disp[i].length()))
		draw_polyline_colors(pts, cols, 1.5 if r % 4 != 0 else 2.5, true)
	# Columns
	for c in _cols:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for r in _rows:
			var i := r * _cols + c
			pts.append(_rest[i] + _disp[i])
			cols.append(_line_color(base, dim, _disp[i].length()))
		draw_polyline_colors(pts, cols, 1.5 if c % 4 != 0 else 2.5, true)


func _line_color(base: Color, dim: float, stretch: float) -> Color:
	# Stretched parts of the grid light up past the glow threshold.
	var k := dim + minf(stretch / 18.0, 2.2)
	return Color(base.r * k, base.g * k, base.b * k, clampf(0.35 + stretch / 20.0, 0.35, 1.0))
