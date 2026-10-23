class_name NeonGrid
extends Node2D
## Geometry Wars style warping grid. Every grid point sits on a spring; hits
## kick nearby points outward, and the springs plus neighbour coupling turn
## that into ripples. Lines brighten where the grid is stretched and flash on
## the music's kick. Ripples come from Juice.impact, and from anything calling
## impulse() on group "grid" (lasers do). Draw it behind everything (z_index -10).
## The neon theme's backdrop; scrolling modes call follow_y() on group "grid".

@export var spacing := 40.0 # set before the scene runs
@export var half_size := Vector2(760, 460) # the grid covers ±this around the node
@export var stiffness := 70.0 # pull back to rest
@export var damping := 5.0
@export var coupling := 45.0 # how much ripples spread to neighbours
@export var color := Color(0.25, 0.2, 1.0)
@export var impact_scale := 0.35 # impact speed -> grid kick
@export var min_impact := 120.0 # weaker hits don't ripple the grid

var pulse := 0.0 # beat flash, 0..1

var _cols := 0
var _rows := 0
var _rest := PackedVector2Array()
var _disp := PackedVector2Array()
var _vel := PackedVector2Array()
var _shift := 0 # whole rows scrolled (scrolling levels only)


func _enter_tree() -> void:
	add_to_group("grid")
	add_to_group("net_local") # only animates: online, joined computers run it too


func _ready() -> void:
	_cols = int(half_size.x * 2.0 / spacing) + 1
	_rows = int(half_size.y * 2.0 / spacing) + 1
	for r in _rows:
		for c in _cols:
			_rest.append(Vector2(c, r) * spacing - half_size)
	_disp.resize(_rest.size())
	_vel.resize(_rest.size())
	Juice.impact.connect(_on_impact)


func _on_impact(pos: Vector2, strength: float) -> void:
	if strength >= min_impact:
		impulse(pos, strength * impact_scale, 60.0 + strength * 0.08)


## For scrolling levels: keep the grid centred on world y `center_y`. Moves
## whole rows so the ripples stay attached to the world as it scrolls.
func follow_y(center_y: float) -> void:
	var shift := int(floorf(center_y / spacing))
	var rows_moved := shift - _shift
	if rows_moved == 0:
		return
	_shift = shift
	var n := _rest.size()
	var disp := PackedVector2Array()
	var vel := PackedVector2Array()
	disp.resize(n)
	vel.resize(n)
	var step := Vector2(0.0, rows_moved * spacing)
	for i in n:
		_rest[i] = _rest[i] + step
		var src := i + rows_moved * _cols
		if src >= 0 and src < n:
			disp[i] = _disp[src]
			vel[i] = _vel[src]
	_disp = disp
	_vel = vel


## Push grid points away from world position `pos`. Negative strength pulls them in.
func impulse(pos: Vector2, strength: float, radius: float) -> void:
	var local := to_local(pos)
	var r2 := radius * radius
	for i in _rest.size():
		var d := _rest[i] + _disp[i] - local
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
		var acc := -_disp[i] * stiffness - _vel[i] * damping
		acc += (nb - _disp[i] * 4.0) * coupling
		_vel[i] += acc * delta
	for i in n:
		_disp[i] += _vel[i] * delta


func _process(_delta: float) -> void:
	pulse = Techno.current_kick(get_tree())
	queue_redraw()


func _draw() -> void:
	var center := Vector2(0.0, _shift * spacing)
	draw_rect(Rect2(center - half_size * 2.0, half_size * 4.0), Color(0.008, 0.0, 0.025))
	var dim := 0.22 + 0.12 * pulse
	# Rows
	for r in _rows:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for c in _cols:
			var i := r * _cols + c
			pts.append(_rest[i] + _disp[i])
			cols.append(_line_color(dim, _disp[i].length()))
		draw_polyline_colors(pts, cols, 1.5 if r % 4 != 0 else 2.5, true)
	# Columns
	for c in _cols:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for r in _rows:
			var i := r * _cols + c
			pts.append(_rest[i] + _disp[i])
			cols.append(_line_color(dim, _disp[i].length()))
		draw_polyline_colors(pts, cols, 1.5 if c % 4 != 0 else 2.5, true)


func _line_color(dim: float, stretch: float) -> Color:
	# Stretched parts of the grid light up past the glow threshold.
	var k := (dim + minf(stretch / 18.0, 2.2)) * GameTheme.current().style.brightness
	return Color(color.r * k, color.g * k, color.b * k, clampf(0.35 + stretch / 20.0, 0.35, 1.0))
