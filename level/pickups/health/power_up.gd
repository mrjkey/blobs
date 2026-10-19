@tool
class_name PowerUp
extends BeltPickup
## A bubble on Don't Get Fat!'s belt that works the moment a blob touches it:
##   GOLDEN APPLE (good): for a while everything caught takes weight off.
##   SNEAKERS (good): every blob runs faster for a while.
##   SUGAR CRASH (bad): every blob is sluggish for a while.
## The buddy holds them for the team (Buddy.boost()); the times are
## in FatSettings, lengthened or shortened by the run's upgrades (FatRun).
## The mode hears `collected` to show what it was. So players spot it among
## the food, it chimes as it comes on screen and then floats:
## it comes down slower than the belt (FatSettings.power_float). Drawn for
## the classic look as a glowing bubble, with its name under it.

signal collected(power_up: PowerUp, blob: Blob)

enum Kind { GOLDEN, SNEAKERS, SUGAR_CRASH }

const NAMES := ["GOLDEN APPLE", "SNEAKERS", "SUGAR CRASH"]
const COLORS: Array[Color] = [Color(1.0, 0.8, 0.2), Color(0.3, 0.85, 0.4), Color(0.75, 0.35, 0.95)]

@export var kind := Kind.GOLDEN:
	set(v):
		kind = v
		queue_redraw()

var _seen := false # it has come on screen (and chimed)
var _belt_y := NAN # where the belt was last frame


func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint() and not taken:
		_float()
	super(delta)


## Once on screen, ride up with the belt (BeltBounds moves with it) by
## `power_float` of its speed.
func _float() -> void:
	var bounds := get_tree().get_first_node_in_group("belt_bounds") as BeltBounds
	var view := GameCamera.view_of(self)
	if bounds == null or not view.has_area():
		return
	var belt := bounds.global_position.y
	if not _seen and global_position.y > view.position.y - settings.item_size:
		_seen = true
		Sfx.play("chime", 0.7 if kind == Kind.SUGAR_CRASH else 1.0)
	if _seen and not is_nan(_belt_y):
		home.y += (belt - _belt_y) * settings.power_float
	_belt_y = belt


func title() -> String:
	return NAMES[kind]


func color() -> Color:
	return COLORS[kind]


func _caught(b: Blob) -> void:
	var buddy := get_tree().get_first_node_in_group("buddy") as Buddy
	match kind:
		Kind.GOLDEN:
			if buddy != null:
				buddy.boost("golden", settings.golden_time + 3.0 * FatRun.count("golden_hour"))
				for i in 3: # Chef's special: a serving of everything
					buddy.body.plate[i] += FatRun.count("chefs_special")
		Kind.SNEAKERS:
			if buddy != null:
				buddy.boost("sneakers", settings.sneakers_time + 3.0 * FatRun.count("fresh_sneakers"))
		Kind.SUGAR_CRASH:
			if buddy != null:
				buddy.boost("sugar_crash", settings.crash_time * pow(0.5, FatRun.count("sugar_proof")))
	Juice.burst(global_position, color(), 22, 340.0)
	Juice.shockwave(global_position, 10.0, 110.0, color().lightened(0.3), 0.3)
	Sfx.play("power", 0.6 if kind == Kind.SUGAR_CRASH else 1.0)
	b.body.swell_kick(6.0)
	collected.emit(self, b)
	queue_free()


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("power_up", self):
		return
	var st := theme.style
	var s := settings.item_size
	var col := color()
	var pulse := 0.0 if Engine.is_editor_hint() else sin(age * 5.0)
	var r := s * (1.3 + 0.07 * pulse)
	for i in 3: # the glow
		draw_circle(Vector2.ZERO, r * (2.1 - 0.3 * i) + 4.0 * pulse, Color(col, 0.07 + 0.03 * i))
	draw_circle(Vector2.ZERO, r, st.color(col, 1.0, 0.25))
	st.ring(self, Vector2.ZERO, r, col, 4.0, 1.4)
	for i in 4:
		var a := age * 1.5 + TAU * i / 4.0
		st.dot(self, Vector2.from_angle(a) * (r + 8.0), 3.0, col.lightened(0.5), 2.0)
	match kind:
		Kind.GOLDEN: _draw_golden(st, s)
		Kind.SNEAKERS: _draw_sneaker(st, s)
		Kind.SUGAR_CRASH: _draw_candy(st, s)
	if st.highlights:
		draw_circle(Vector2(-r, -r) * 0.45, r * 0.16, Color(1, 1, 1, 0.5))
	draw_string(ThemeDB.fallback_font, Vector2(-80.0, r + 24.0), title(), HORIZONTAL_ALIGNMENT_CENTER, 160.0, 17,
		st.color(col.lightened(0.3), 1.5))


func _draw_golden(st: ThemeStyle, s: float) -> void:
	var gold := Color(1.0, 0.78, 0.15)
	st.disc(self, Vector2(0.0, 0.08 * s), 0.52 * s, gold, 0.0, 1.0, 1.0, 2.0)
	st.line(self, Vector2(0.0, -0.4 * s), Vector2(0.06 * s, -0.66 * s), Color(0.45, 0.28, 0.15), 0.1 * s)
	draw_colored_polygon(ellipse(Vector2(0.24 * s, -0.6 * s), 0.2 * s, 0.09 * s, 10), st.color(Color(0.35, 0.8, 0.3)))
	if st.highlights:
		draw_circle(Vector2(-0.2, -0.08) * s, 0.12 * s, Color(1, 1, 1, 0.7))


func _draw_sneaker(st: ThemeStyle, s: float) -> void:
	for y: float in [-0.15, 0.05]:
		st.line(self, Vector2(-0.95, y) * s, Vector2(-0.68, y) * s, Color.WHITE, 0.06 * s, 1.0, 0.7)
	var upper := PackedVector2Array()
	for p: Vector2 in [Vector2(-0.55, 0.15), Vector2(-0.52, -0.28), Vector2(-0.18, -0.32), Vector2(0.08, -0.05),
			Vector2(0.55, 0.02), Vector2(0.62, 0.18)]:
		upper.append(p * s)
	draw_colored_polygon(upper, st.fill_color(Color(0.3, 0.75, 0.4)))
	st.outline(self, upper, st.edge_color(Color(0.3, 0.75, 0.4)), 2.0)
	draw_rect(Rect2(Vector2(-0.6, 0.15) * s, Vector2(1.26, 0.16) * s), st.color(Color.WHITE))
	for i in 3:
		var x := -0.3 + i * 0.13
		st.line(self, Vector2(x, -0.24 + i * 0.08) * s, Vector2(x + 0.12, -0.18 + i * 0.08) * s, Color.WHITE, 0.05 * s)


func _draw_candy(st: ThemeStyle, s: float) -> void:
	var pink := Color(0.95, 0.4, 0.75)
	for sx: float in [-1.0, 1.0]:
		var wrap := PackedVector2Array([Vector2(sx * 0.3, 0.0) * s, Vector2(sx * 0.72, -0.28) * s, Vector2(sx * 0.72, 0.28) * s])
		draw_colored_polygon(wrap, st.fill_color(pink.lightened(0.2)))
		st.outline(self, wrap, st.edge_color(pink), 2.0)
	st.disc(self, Vector2.ZERO, 0.36 * s, pink, 0.0, 1.0, 1.0, 2.0)
	for i in 3:
		var x := (-0.18 + i * 0.18) * s
		st.line(self, Vector2(x - 0.06 * s, -0.3 * s), Vector2(x + 0.06 * s, 0.3 * s), Color.WHITE, 0.07 * s, 1.0, 0.8)
