class_name FatHud
extends Control
## Don't Get Fat!'s two things to read during play, in the space beside the
## belt (right of the track): the scale (the buddy's weight against the
## level's window, its middle third in yellow for the Bull's-eye star) and the plate (servings of protein, grains, and fruit and
## veg against the line that fills each third) with the treat meter under it
## (one slot per treat the Light on treats star allows, then the star, which
## goes dark once the meter overflows). Then the team's running power-ups.
## The mode makes one, puts it in the Hud and fills in the fields every frame.

const PANEL_WIDTH := 330.0
const INK := Color(0.92, 0.93, 1.0)
const DIM := Color(0.62, 0.64, 0.78)
const SHADE := Color(0.03, 0.03, 0.08, 0.72)
const STAR_COLOR := Color(1.0, 0.85, 0.25)

var buddy: Buddy
var track_half := 350.0 # half the track's width, to find its right edge on screen
var low := 72.0
var high := 78.0
var plate_on := true
var target := 4 # servings per third
var treat_slots := 3
var progress := 0.0 # 0 -> 1 along the level: short thirds pulse near the end
var boosts: Array = [] # [[text, colour], ...]

var _seen: Array[int] = [0, 0, 0] # servings last frame, to flash a third that just filled
var _flash: Array[float] = [0.0, 0.0, 0.0]
var _treat_flash := 0.0
var _treats_seen := 0
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	if buddy != null:
		for i in 3:
			if buddy.plate[i] > _seen[i]:
				_flash[i] = 1.0
			_seen[i] = buddy.plate[i]
		if buddy.treats > _treats_seen:
			_treat_flash = 1.0
		_treats_seen = buddy.treats
	for i in 3:
		_flash[i] = maxf(_flash[i] - delta * 2.5, 0.0)
	_treat_flash = maxf(_treat_flash - delta * 2.5, 0.0)
	queue_redraw()


## The panel's left edge and width: right of the track, or along the screen's right edge if there's no room.
func _panel() -> Vector2:
	var view := get_viewport().get_canvas_transform()
	var edge := (view * Vector2(track_half + 20.0, 0.0)).x + 24.0
	var room := size.x - edge - 20.0
	if room >= 220.0:
		return Vector2(edge, minf(room, PANEL_WIDTH))
	return Vector2(size.x - 240.0, 220.0)


func _draw() -> void:
	if buddy == null:
		return
	var font := get_theme_default_font()
	var p := _panel()
	var x := p.x
	var w := p.y
	var y := 22.0
	y = _draw_scale(font, x, y, w)
	if plate_on:
		y = _draw_plate(font, x, y + 18.0, w)
		y = _draw_treats(font, x, y + 12.0, w)
	for b: Array in boosts:
		y += 34.0
		draw_string(font, Vector2(x, y), b[0], HORIZONTAL_ALIGNMENT_LEFT, w, 22, b[1])


func _box(rect: Rect2) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = SHADE
	box.set_corner_radius_all(12)
	box.draw(get_canvas_item(), rect)


## WEIGHT, then a bar from a bit under the window to a bit over it: the window
## in green with the Bull's-eye in yellow, a marker with the buddy's weight.
func _draw_scale(font: Font, x: float, y: float, w: float) -> float:
	var h := 116.0
	_box(Rect2(x - 14.0, y - 8.0, w + 28.0, h))
	draw_string(font, Vector2(x, y + 22.0), "WEIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, DIM)
	var kg := buddy.shown
	var col := buddy.window_color(buddy.weight)
	draw_string(font, Vector2(x, y + 24.0), "%.1f kg" % buddy.weight, HORIZONTAL_ALIGNMENT_RIGHT, w, 30, col)
	var margin := maxf(high - low, 5.0) # zoomed in on the window, so the Bull's-eye is easy to see
	var lo := low - margin
	var hi := high + margin
	var bar := Rect2(x, y + 50.0, w, 18.0)
	draw_rect(bar, Color(1, 1, 1, 0.1))
	var band := Rect2(_on_bar(bar, low, lo, hi), bar.position.y, _on_bar(bar, high, lo, hi) - _on_bar(bar, low, lo, hi), bar.size.y)
	draw_rect(band, Color(Buddy.GOOD_COLOR, 0.55))
	var third := (high - low) / 3.0 # the Bull's-eye: the middle third of the window
	var bull_x := _on_bar(bar, low + third, lo, hi)
	draw_rect(Rect2(bull_x, bar.position.y, _on_bar(bar, high - third, lo, hi) - bull_x, bar.size.y), Color(STAR_COLOR, 0.85))
	draw_rect(bar, Color(1, 1, 1, 0.35), false, 2.0)
	var mx := _on_bar(bar, kg, lo, hi)
	draw_colored_polygon(PackedVector2Array([Vector2(mx - 9.0, bar.position.y - 12.0), Vector2(mx + 9.0, bar.position.y - 12.0),
		Vector2(mx, bar.position.y + 2.0)]), col)
	draw_line(Vector2(mx, bar.position.y), Vector2(mx, bar.end.y), col, 3.0)
	var under := bar.end.y + 24.0
	if band.size.x >= 56.0:
		draw_string(font, Vector2(band.position.x - 60.0, under), "%d" % roundi(low), HORIZONTAL_ALIGNMENT_CENTER, 120.0, 18, DIM)
		draw_string(font, Vector2(band.end.x - 60.0, under), "%d" % roundi(high), HORIZONTAL_ALIGNMENT_CENTER, 120.0, 18, DIM)
	else: # a narrow window: one label under its middle
		draw_string(font, Vector2(band.get_center().x - 60.0, under), "%d–%d" % [roundi(low), roundi(high)],
			HORIZONTAL_ALIGNMENT_CENTER, 120.0, 18, DIM)
	draw_string(font, Vector2(x, under), "too light", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(DIM, 0.7))
	draw_string(font, Vector2(x, under), "too heavy", HORIZONTAL_ALIGNMENT_RIGHT, w, 16, Color(DIM, 0.7))
	return y + h


## Where `kg` sits on the scale's `bar`, which runs from `lo` to `hi` kg.
func _on_bar(bar: Rect2, kg: float, lo: float, hi: float) -> float:
	return bar.position.x + clampf((kg - lo) / (hi - lo), 0.0, 1.0) * bar.size.x


## The plate: three thirds that fill outward to a dashed line, with a tick once full,
## and a legend under it with the servings.
func _draw_plate(font: Font, x: float, y: float, w: float) -> float:
	var r := minf(w * 0.34, 92.0)
	var h := r * 2.0 + 104.0
	_box(Rect2(x - 14.0, y - 8.0, w + 28.0, h))
	draw_string(font, Vector2(x, y + 22.0), "PLATE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, DIM)
	var c := Vector2(x + w * 0.5, y + 30.0 + r)
	var full_r := r * 0.8 # the dashed line
	var near_end := progress > 0.8
	draw_circle(c, r + 6.0, Color(0.96, 0.96, 1.0, 0.9))
	draw_circle(c, r, Color(0.86, 0.87, 0.94))
	for i in 3:
		var a0 := -PI * 0.5 + TAU * i / 3.0
		var col: Color = HealthItem.GROUP_COLORS[i]
		var servings: int = buddy.plate[i]
		var full := servings >= target
		var fill := minf(float(servings) / maxf(target, 1), 1.25) * full_r
		var k := 1.0 + 0.5 * _flash[i]
		if near_end and not full:
			k += 0.35 * (0.5 + 0.5 * sin(_t * 8.0))
		draw_colored_polygon(_wedge(c, r, a0, a0 + TAU / 3.0), Color(col, 0.18))
		if fill > 1.0:
			draw_colored_polygon(_wedge(c, minf(fill, r), a0, a0 + TAU / 3.0), Color(col.r * k, col.g * k, col.b * k, 0.95))
		if full:
			var mid := c + Vector2.from_angle(a0 + TAU / 6.0) * r * 0.5
			_tick(mid, 13.0, Color(0.05, 0.08, 0.05))
	for i in 3:
		var a := -PI * 0.5 + TAU * i / 3.0
		draw_line(c, c + Vector2.from_angle(a) * r, Color(1, 1, 1, 0.95), 3.0, true)
	var dash := 0.0
	while dash < TAU: # the line that fills a third
		draw_arc(c, full_r, dash, dash + 0.12, 4, Color(0.1, 0.1, 0.15, 0.8), 2.5, true)
		dash += 0.22
	var ly := c.y + r + 30.0
	var col_w := w / 3.0
	for i in 3:
		var col: Color = HealthItem.GROUP_COLORS[i]
		var lx := x + col_w * i
		var done: bool = buddy.plate[i] >= target
		draw_circle(Vector2(lx + 7.0, ly - 5.0), 6.0, col)
		draw_string(font, Vector2(lx + 18.0, ly), ["PROTEIN", "GRAINS", "VEG"][i], HORIZONTAL_ALIGNMENT_LEFT, col_w - 18.0, 13, DIM)
		draw_string(font, Vector2(lx + 18.0, ly + 22.0), "%d / %d" % [mini(buddy.plate[i], 99), target],
			HORIZONTAL_ALIGNMENT_LEFT, col_w - 18.0, 19, INK if done else DIM)
	return y + h


## One slot per treat allowed, then the Light on treats star: lit until the meter overflows.
func _draw_treats(font: Font, x: float, y: float, w: float) -> float:
	var h := 64.0
	_box(Rect2(x - 14.0, y - 8.0, w + 28.0, h))
	draw_string(font, Vector2(x, y + 32.0), "TREATS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, DIM)
	var over := buddy.treats > treat_slots
	var shake := sin(_t * 50.0) * 3.0 * _treat_flash if over else 0.0
	var sx := x + 100.0
	var cy := y + 24.0
	var gap := minf(34.0, (w - 170.0) / maxf(treat_slots, 1)) # room for the "+n" and the star
	var r := minf(13.0, gap * 0.4)
	var red: Color = HealthItem.GROUP_COLORS[HealthItem.Group.TREAT]
	for i in treat_slots:
		var c := Vector2(sx + i * gap + shake, cy)
		if i < buddy.treats:
			draw_circle(c, r, red.lightened(0.3 * _treat_flash))
		draw_arc(c, r, 0.0, TAU, 20, Color(1, 1, 1, 0.7), 2.0, true)
	if over:
		draw_string(font, Vector2(sx + treat_slots * gap - 8.0, cy + 8.0), "+%d" % (buddy.treats - treat_slots),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, red)
	var star := Vector2(x + w - 18.0, cy)
	_star(star, 17.0, Color(0.3, 0.3, 0.36) if over else STAR_COLOR)
	return y + h


func _wedge(c: Vector2, r: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array([c])
	for i in 17:
		pts.append(c + Vector2.from_angle(lerpf(a0, a1, i / 16.0)) * r)
	return pts


func _tick(at: Vector2, s: float, col: Color) -> void:
	draw_polyline(PackedVector2Array([at + Vector2(-s, 0.0), at + Vector2(-s * 0.3, s * 0.7), at + Vector2(s, -s * 0.8)]),
		Color.WHITE, 7.0, true)
	draw_polyline(PackedVector2Array([at + Vector2(-s, 0.0), at + Vector2(-s * 0.3, s * 0.7), at + Vector2(s, -s * 0.8)]),
		col, 3.5, true)


## A five-pointed star (shared with the report card).
func _star(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(star_points(c, r), col)


static func star_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(-PI * 0.5 + PI * i / 5.0) * rr)
	return pts
