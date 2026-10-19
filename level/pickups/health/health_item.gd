@tool
class_name HealthItem
extends BeltPickup
## Something on Don't Get Fat!'s belt: junk (a burger, fries, cake, a donut, a
## soda, a lie-in in bed, a night in front of the TV) that makes the buddy
## heavier, or the good stuff (an apple, a carrot, broccoli, water, a dumbbell,
## a football) that slims it down, by FatSettings.weights for its kind. A blob
## that touches it catches it: it flies to the buddy (group "buddy") and
## lands with Buddy.feed(). While the buddy is golden, everything caught counts
## as good. Junk sits on a red spot, the good stuff on a green one (gold while
## golden). Drawn for the classic look (this mode only plays in classic for now).

signal caught(item: HealthItem, blob: Blob)

enum Kind { BURGER, FRIES, CAKE, DONUT, SODA, BED, TV, APPLE, CARROT, BROCCOLI, WATER, DUMBBELL, FOOTBALL }

const GOOD_COLOR := Color(0.3, 0.85, 0.4)
const BAD_COLOR := Color(1.0, 0.3, 0.25)
const GOLD_COLOR := Color(1.0, 0.82, 0.2)

@export var kind := Kind.BURGER:
	set(v):
		kind = v
		queue_redraw()

var _kg := 0.0 # what it does to the buddy, settled when caught
var _from := Vector2.ZERO # where it was caught
var _buddy: Buddy
var _s := 24.0 # drawing scale, for _r() and _v()
var _bob := 0.0 # drawing offset: it bobs up and down


## "burger", "apple"...: its key in FatSettings.weights.
func kind_name() -> String:
	return Kind.keys()[kind].to_lower()


func is_good() -> bool:
	return settings.weight_of(kind_name()) <= 0.0


func _caught(b: Blob) -> void:
	_buddy = get_tree().get_first_node_in_group("buddy") as Buddy
	_kg = settings.weight_of(kind_name())
	if _buddy != null and _buddy.golden():
		_kg = -absf(_kg)
	var good := _kg <= 0.0
	Juice.burst(global_position, GOOD_COLOR if good else BAD_COLOR, 12, 240.0)
	Sfx.play("good" if good else "junk", randf_range(0.95, 1.08), -3.0 if good else 0.0)
	b.body.swell_kick(4.0)
	if not good:
		b.body.flash = 0.7
	caught.emit(self, b)
	if _buddy == null:
		queue_free()
		return
	age = 0.0
	_from = global_position
	z_index = 3 # over the buddy


## Fly in an arc to the buddy's mouth, shrinking, then land.
func _carried(_delta: float) -> void:
	if not is_instance_valid(_buddy):
		queue_free()
		return
	var t := age / settings.fly_time
	if t >= 1.0:
		_buddy.feed(_kg)
		Juice.burst(_buddy.mouth(), GOOD_COLOR if _kg <= 0.0 else BAD_COLOR, 8, 180.0)
		queue_free()
		return
	var k := t * t * (3.0 - 2.0 * t)
	global_position = _from.lerp(_buddy.mouth(), k) + Vector2(0.0, -sin(t * PI) * 90.0)
	scale = Vector2.ONE * lerpf(1.0, 0.45, k)


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("health_item", self):
		return
	var st := theme.style
	_s = settings.item_size
	if not taken:
		_draw_spot(st)
	_bob = 0.0 if Engine.is_editor_hint() else sin(age * 3.0 + position.x * 0.05) * 2.0
	draw_set_transform(Vector2(0.0, _bob))
	match kind:
		Kind.BURGER: _draw_burger(st)
		Kind.FRIES: _draw_fries(st)
		Kind.CAKE: _draw_cake(st)
		Kind.DONUT: _draw_donut(st)
		Kind.SODA: _draw_soda(st)
		Kind.BED: _draw_bed(st)
		Kind.TV: _draw_tv(st)
		Kind.APPLE: _draw_apple(st)
		Kind.CARROT: _draw_carrot(st)
		Kind.BROCCOLI: _draw_broccoli(st)
		Kind.WATER: _draw_water(st)
		Kind.DUMBBELL: _draw_dumbbell(st)
		Kind.FOOTBALL: _draw_football(st)
	draw_set_transform(Vector2.ZERO)


## Green under the good stuff, red under junk, gold under everything while the buddy is golden.
func _draw_spot(st: ThemeStyle) -> void:
	var col := GOOD_COLOR if is_good() else BAD_COLOR
	var k := 1.0
	if not Engine.is_editor_hint():
		var buddy := get_tree().get_first_node_in_group("buddy") as Buddy
		if buddy != null and buddy.golden():
			col = GOLD_COLOR
			k = 0.8 + 0.4 * sin(age * 14.0)
	draw_colored_polygon(ellipse(Vector2(0.0, _s * 0.2), _s * 1.3, _s * 1.1), st.color(col, 1.0, 0.22 * k))
	st.outline(self, ellipse(Vector2(0.0, _s * 0.2), _s * 1.3, _s * 1.1), st.color(col, 1.2, 0.55 * k), 3.0)


## A filled shape with an outline; with `shadow`, a drop shadow under it too (in themes that have them).
func _shape(st: ThemeStyle, pts: PackedVector2Array, col: Color, shadow := false) -> void:
	if shadow:
		st.body(self, pts, col, 0.0, 1.0, 1.0, 2.0)
		return
	draw_colored_polygon(pts, st.fill_color(col))
	st.outline(self, pts, st.edge_color(col), 2.0)


## A rect in item units (multiples of item_size).
func _r(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(x * _s, y * _s, w * _s, h * _s)


## A point in item units.
func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y) * _s


func _poly(units: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p: Vector2 in units:
		pts.append(p * _s)
	return pts


func _draw_burger(st: ThemeStyle) -> void:
	var bun := Color(0.93, 0.62, 0.3)
	_shape(st, round_rect(_r(-0.9, 0.35, 1.8, 0.42), 0.18 * _s), bun, true)
	_shape(st, round_rect(_r(-1.0, 0.04, 2.0, 0.36), 0.16 * _s), Color(0.45, 0.24, 0.14))
	_shape(st, _poly([Vector2(-0.95, -0.04), Vector2(0.95, -0.04), Vector2(0.95, 0.08), Vector2(0.45, 0.08),
		Vector2(0.3, 0.3), Vector2(0.15, 0.08), Vector2(-0.95, 0.08)]), Color(1.0, 0.8, 0.2))
	var leaf := PackedVector2Array()
	for i in 11:
		leaf.append(_v(lerpf(-1.0, 1.0, i / 10.0), -0.08 + (0.07 if i % 2 == 0 else -0.05)))
	draw_polyline(leaf, st.color(Color(0.35, 0.8, 0.3)), 0.14 * _s, true)
	var top := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		top.append(_v(cos(a) * 0.95, -0.12 + sin(a) * 0.72))
	_shape(st, top, bun)
	for p: Vector2 in [Vector2(-0.45, -0.45), Vector2(0.0, -0.62), Vector2(0.42, -0.44), Vector2(-0.15, -0.3), Vector2(0.25, -0.27)]:
		draw_colored_polygon(ellipse(p * _s, 0.08 * _s, 0.05 * _s, 8), st.color(Color(1.0, 0.95, 0.8)))


func _draw_fries(st: ThemeStyle) -> void:
	var tops := [-0.75, -0.98, -0.85, -1.02, -0.72]
	for i in 5:
		var x := lerpf(-0.46, 0.46, i / 4.0)
		_shape(st, _poly([Vector2(x - 0.09, tops[i]), Vector2(x + 0.09, tops[i]), Vector2(x + 0.08, 0.1), Vector2(x - 0.08, 0.1)]),
			Color(1.0, 0.85, 0.3))
	_shape(st, _poly([Vector2(-0.72, -0.18), Vector2(0.72, -0.18), Vector2(0.56, 0.9), Vector2(-0.56, 0.9)]),
		Color(0.9, 0.2, 0.2), true)
	st.line(self, _v(-0.62, 0.3), _v(0.62, 0.3), Color(1.0, 0.85, 0.3), 0.1 * _s)


func _draw_cake(st: ThemeStyle) -> void:
	_shape(st, round_rect(_r(-0.85, -0.25, 1.7, 1.0), 0.08 * _s), Color(0.96, 0.82, 0.6), true)
	draw_rect(_r(-0.83, 0.22, 1.66, 0.12), st.color(Color(1.0, 0.96, 0.9)))
	_shape(st, round_rect(_r(-0.92, -0.45, 1.84, 0.34), 0.15 * _s), Color(1.0, 0.55, 0.72))
	for p: Vector2 in [Vector2(-0.5, -0.1), Vector2(0.1, -0.06), Vector2(0.6, -0.12)]:
		draw_colored_polygon(ellipse(p * _s, 0.11 * _s, 0.17 * _s, 12), st.fill_color(Color(1.0, 0.55, 0.72)))
	st.line(self, _v(0.0, -0.62), _v(0.18, -0.98), Color(0.3, 0.5, 0.2), 0.07 * _s)
	st.disc(self, _v(0.0, -0.62), 0.2 * _s, Color(0.85, 0.1, 0.15), 0.0, 1.0, 1.0, 2.0)


func _draw_donut(st: ThemeStyle) -> void:
	if st.shadows:
		draw_arc(Vector2(3.0, 6.0), 0.62 * _s, 0.0, TAU, 40, Color(0, 0, 0, 0.28), 0.66 * _s, true)
	var dough := Color(0.85, 0.58, 0.32)
	draw_arc(Vector2.ZERO, 0.62 * _s, 0.0, TAU, 40, st.fill_color(dough), 0.66 * _s, true)
	var icing := Color(1.0, 0.5, 0.72)
	var wavy := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		wavy.append(Vector2.from_angle(a) * _s * (0.84 + 0.05 * sin(a * 7.0)))
	draw_colored_polygon(wavy, st.fill_color(icing))
	draw_circle(Vector2.ZERO, 0.4 * _s, st.fill_color(dough))
	st.ring(self, Vector2.ZERO, 0.95 * _s, st.edge_color(dough), 2.0)
	var hole: Color = GameTheme.current().value("track.floor", Color(0.19, 0.22, 0.31))
	draw_circle(Vector2.ZERO, 0.28 * _s, hole)
	st.ring(self, Vector2.ZERO, 0.28 * _s, st.edge_color(dough), 2.0)
	var sprinkles := [Color.WHITE, Color(1.0, 0.9, 0.3), Color(0.4, 0.7, 1.0), Color(0.5, 0.9, 0.4)]
	for i in 9:
		var a := TAU * i / 9.0 + 0.3
		var p := Vector2.from_angle(a) * _s * (0.55 if i % 2 == 0 else 0.7)
		var d := Vector2.from_angle(a * 2.3) * 0.09 * _s
		st.line(self, p - d, p + d, sprinkles[i % sprinkles.size()], 0.07 * _s)


func _draw_soda(st: ThemeStyle) -> void:
	st.line(self, _v(0.12, -0.7), _v(0.38, -1.15), Color(1.0, 0.35, 0.4), 0.14 * _s)
	_shape(st, _poly([Vector2(-0.56, -0.55), Vector2(0.56, -0.55), Vector2(0.42, 0.92), Vector2(-0.42, 0.92)]),
		Color(0.25, 0.5, 0.95), true)
	draw_colored_polygon(_poly([Vector2(-0.53, 0.0), Vector2(0.53, -0.1), Vector2(0.5, 0.18), Vector2(-0.5, 0.28)]),
		st.color(Color.WHITE, 1.0, 0.9))
	_shape(st, round_rect(_r(-0.66, -0.74, 1.32, 0.22), 0.08 * _s), Color(0.88, 0.88, 0.92))


## Sleeping in: someone tucked up in bed, with the z's.
func _draw_bed(st: ThemeStyle) -> void:
	_shape(st, round_rect(_r(-0.75, -1.0, 1.5, 2.0), 0.14 * _s), Color(0.62, 0.42, 0.25), true)
	_shape(st, round_rect(_r(-0.65, -0.9, 1.3, 1.78), 0.1 * _s), Color(0.95, 0.95, 0.98))
	_shape(st, round_rect(_r(-0.5, -0.84, 1.0, 0.4), 0.16 * _s), Color(1.0, 1.0, 1.0))
	st.disc(self, _v(0.0, -0.6), 0.27 * _s, Buddy.COLOR, 0.0, 1.0, 1.0, 2.0)
	for sx: float in [-0.1, 0.1]:
		draw_arc(_v(sx, -0.62), 0.06 * _s, 0.2, PI - 0.2, 6, st.ink, 2.0, true)
	_shape(st, round_rect(_r(-0.72, -0.36, 1.44, 1.3), 0.1 * _s), Color(0.35, 0.45, 0.9))
	st.line(self, _v(-0.68, -0.22), _v(0.68, -0.22), Color(0.55, 0.65, 1.0), 0.1 * _s)
	var font := ThemeDB.fallback_font
	var z := Color(0.6, 0.78, 1.0)
	draw_string(font, _v(0.62, -0.78), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.6 * _s), st.color(z))
	draw_string(font, _v(0.85, -1.05), "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.85 * _s), st.color(z))


## Up all night in front of the TV.
func _draw_tv(st: ThemeStyle) -> void:
	var dark := Color(0.3, 0.3, 0.36)
	for sx: float in [-1.0, 1.0]:
		st.line(self, _v(0.0, -0.6), _v(sx * 0.45, -1.1), dark, 0.07 * _s)
		st.dot(self, _v(sx * 0.45, -1.1), 0.07 * _s, dark)
		st.line(self, _v(sx * 0.6, 0.7), _v(sx * 0.75, 0.98), dark, 0.1 * _s)
	_shape(st, round_rect(_r(-1.0, -0.62, 2.0, 1.38), 0.16 * _s), dark, true)
	var screen := Color(0.4, 0.7, 1.0)
	draw_colored_polygon(round_rect(_r(-0.84, -0.46, 1.34, 1.04), 0.1 * _s), st.color(screen))
	var flick := 0.0 if Engine.is_editor_hint() else 0.5 + 0.5 * sin(age * 9.0)
	st.line(self, _v(-0.75, -0.2), _v(0.4, -0.2), Color.WHITE, 0.06 * _s, 1.0, 0.25 + 0.3 * flick)
	st.line(self, _v(-0.75, 0.15), _v(0.2, 0.15), Color.WHITE, 0.06 * _s, 1.0, 0.25 + 0.3 * (1.0 - flick))
	for y: float in [-0.2, 0.15]:
		st.dot(self, _v(0.76, y), 0.09 * _s, Color(0.7, 0.7, 0.75))


func _draw_apple(st: ThemeStyle) -> void:
	var red := Color(0.9, 0.15, 0.15)
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		var dip := 0.14 * maxf(-sin(a), 0.0) * maxf(cos(a * 2.0), 0.0) # the dent at the top
		pts.append(_v(cos(a) * 0.9, 0.1 + sin(a) * (0.82 - dip)))
	_shape(st, pts, red, true)
	st.line(self, _v(0.0, -0.55), _v(0.08, -0.95), Color(0.45, 0.28, 0.15), 0.12 * _s)
	var leaf := PackedVector2Array()
	for p in ellipse(Vector2.ZERO, 0.3 * _s, 0.13 * _s, 12):
		leaf.append(_v(0.34, -0.85) + p.rotated(-0.5))
	_shape(st, leaf, Color(0.35, 0.8, 0.3))
	if st.highlights:
		draw_circle(_v(-0.38, -0.15), 0.15 * _s, Color(1, 1, 1, 0.55))


func _draw_carrot(st: ThemeStyle) -> void:
	draw_set_transform(Vector2(0.0, _bob), 0.4)
	var green := Color(0.35, 0.75, 0.3)
	for p: Vector2 in [Vector2(-0.32, -1.05), Vector2(0.0, -1.18), Vector2(0.32, -1.05)]:
		st.line(self, _v(0.0, -0.55), p * _s, green, 0.16 * _s)
	var orange := Color(1.0, 0.55, 0.15)
	_shape(st, _poly([Vector2(-0.42, -0.5), Vector2(-0.3, -0.66), Vector2(0.3, -0.66), Vector2(0.42, -0.5),
		Vector2(0.07, 0.98), Vector2(-0.07, 0.98)]), orange, true)
	for l: Array in [[-0.3, -0.2, 0.0], [0.05, 0.15, 0.25], [-0.15, 0.5, 0.0]]:
		st.line(self, _v(l[0], l[1]), _v(l[0] + 0.2, l[1] + 0.03), orange.darkened(0.35), 0.06 * _s)
	draw_set_transform(Vector2(0.0, _bob))


func _draw_broccoli(st: ThemeStyle) -> void:
	_shape(st, _poly([Vector2(-0.22, -0.05), Vector2(0.22, -0.05), Vector2(0.32, 0.92), Vector2(-0.32, 0.92)]),
		Color(0.62, 0.86, 0.45), true)
	var green := Color(0.2, 0.62, 0.25)
	for f: Array in [[-0.5, -0.12, 0.4, 0.9], [0.5, -0.12, 0.4, 0.9], [-0.22, -0.52, 0.42, 1.0],
			[0.25, -0.54, 0.42, 1.05], [0.0, -0.16, 0.38, 1.1]]:
		st.disc(self, _v(f[0], f[1]), f[2] * _s, green, 0.0, f[3], 1.0, 2.0)


func _draw_water(st: ThemeStyle) -> void:
	var glass := Color(0.62, 0.86, 1.0)
	_shape(st, round_rect(_r(-0.24, -0.84, 0.48, 0.4), 0.06 * _s), glass, true)
	_shape(st, round_rect(_r(-0.44, -0.6, 0.88, 1.56), 0.22 * _s), glass, true)
	_shape(st, round_rect(_r(-0.27, -1.04, 0.54, 0.24), 0.06 * _s), Color(0.15, 0.4, 0.9))
	draw_rect(_r(-0.42, 0.02, 0.84, 0.42), st.color(Color.WHITE))
	var wave := PackedVector2Array()
	for i in 9:
		wave.append(_v(lerpf(-0.36, 0.36, i / 8.0), 0.23 + 0.06 * sin(i * 1.6)))
	draw_polyline(wave, st.color(Color(0.15, 0.45, 0.95)), 0.07 * _s, true)
	if st.highlights:
		st.line(self, _v(-0.26, -0.4), _v(-0.26, -0.1), Color.WHITE, 0.09 * _s, 1.0, 0.6)


func _draw_dumbbell(st: ThemeStyle) -> void:
	draw_set_transform(Vector2(0.0, _bob), -0.4)
	st.line(self, _v(-0.98, 0.0), _v(0.98, 0.0), Color(0.72, 0.72, 0.78), 0.2 * _s)
	var plate := Color(0.28, 0.28, 0.34)
	for sx: float in [-1.0, 1.0]:
		_shape(st, round_rect(_r(sx * 0.55 - 0.14, -0.55, 0.28, 1.1), 0.08 * _s), plate, true)
		_shape(st, round_rect(_r(sx * 0.82 - 0.11, -0.4, 0.22, 0.8), 0.06 * _s), plate)
	draw_set_transform(Vector2(0.0, _bob))


func _draw_football(st: ThemeStyle) -> void:
	st.disc(self, Vector2.ZERO, 0.92 * _s, Color(0.97, 0.97, 0.97), 0.0, 1.0, 1.0, 2.0)
	var black := Color(0.14, 0.14, 0.18)
	var spin := 0.0 if Engine.is_editor_hint() else age * 1.5
	var centre := PackedVector2Array()
	for i in 5:
		centre.append(Vector2.from_angle(spin - PI * 0.5 + TAU * i / 5.0) * 0.3 * _s)
	draw_colored_polygon(centre, black)
	for i in 5: # half-hidden patches round the edge, between the centre one's corners
		var a := spin - PI * 0.5 + TAU * i / 5.0 + PI / 5.0
		var patch := PackedVector2Array()
		for j in 5:
			var p := Vector2.from_angle(a) * 0.82 * _s + Vector2.from_angle(a + TAU * j / 5.0) * 0.2 * _s
			patch.append(p.limit_length(0.9 * _s))
		draw_colored_polygon(patch, black)
	st.ring(self, Vector2.ZERO, 0.92 * _s, st.edge_color(Color(0.97, 0.97, 0.97)), 2.0)
