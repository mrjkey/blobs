class_name Buddy
extends Node2D
## The one the helpers look after in Don't Get Fat!: a big friendly blob
## walking along at the bottom of the screen. Caught items fly to it and change
## its `weight` (HealthItem calls feed()), and its size follows the weight
## (FatSettings.radius_at). What a catch really does (the plate, the treat
## meter, workouts, muscle, rest, the run's upgrades) is up to its `body`, a
## FatBody the mode gives it; muscle raises the top of the window (top()) and
## shows as bigger arms and a headband that changes colour, rest as z's. It holds the
## team's power-ups (PowerUp calls boost()): while golden, everything caught
## takes weight off; sneakers and a sugar crash change how fast the blobs run
## (the mode reads speed_factor()). Its tag shows the weight against the
## level's window (`low` to top()): light blue under it, green in it, red over
## it, when it also sweats: it won't fit through the gate. Group "buddy" (at
## most one). Colours from the theme: buddy.color, buddy.band.

const COLOR := Color(1.0, 0.74, 0.55)
const BAND_COLOR := Color(0.95, 0.25, 0.3)
const GOOD_COLOR := Color(0.3, 0.85, 0.4)
const BAD_COLOR := Color(1.0, 0.4, 0.25)
const LIGHT_COLOR := Color(0.55, 0.8, 1.0) # under the window
const GOLD_COLOR := Color(1.0, 0.82, 0.2)
const SWEAT_COLOR := Color(0.5, 0.8, 1.0)
const MUSCLE_COLOR := Color(1.0, 0.6, 0.85)
## The headband's colour by muscle: from this many points up.
const BAND_TIERS := [[60.0, Color(0.75, 0.4, 1.0)], [30.0, Color(1.0, 0.8, 0.2)], [10.0, Color(0.3, 0.75, 1.0)]]
const POPUP_LIFE := 1.1

@export var settings: FatSettings = preload("res://modes/dont_get_fat/fat_settings.tres")

var weight := 75.0
var low := 0.0 # the level's window in kg (0 to 0 = none)
var high := 0.0
var body := FatBody.new() # what it's eaten and built (the mode gives it one per level)
var walking := true
var boosts := {} # power-up -> seconds left: "golden", "sneakers", "sugar_crash"
var shown := 75.0 # the weight it's drawn at: catches up with `weight` quickly

## Worked out from `settings` every time, so editing the .tres resizes it live.
var radius: float:
	get:
		return settings.radius_at(shown)

var _swell := 0.0
var _swell_vel := 0.0
var _step := 0.0 # walk cycle
var _mood := 0.0 # > 0 just ate well, < 0 just ate junk; fades to 0
var _stuck := 0.0 # > 0 after bumping into a gate too narrow for it
var _popups: Array = [] # [text, colour, age] of each "+4 kg" rising off it


func _enter_tree() -> void:
	add_to_group("buddy")


func _ready() -> void:
	shown = weight


## Something caught for it, of HealthItem.Kind `kind` and Group `group`: it
## would add `kg` (`golden`: caught while golden), and fills `servings` of the
## plate. Its body says what it really does.
func feed(kg: float, group := -1, golden := false, kind := -1, servings := 1) -> void:
	var result := body.eat(self, kind, group, kg, golden, servings)
	var to: float = weight + result[0]
	kg = to - weight
	weight = clampf(to, settings.min_weight, settings.max_weight)
	var note: String = result[1]
	var col: Color = GOLD_COLOR if golden else (HealthItem.GROUP_COLORS[group] if group >= 0 else Color.WHITE)
	if absf(kg) >= 0.05:
		_popups.append([("+" if kg > 0.0 else "") + String.num(kg, 1) + " kg", col, 0.0])
	if note != "":
		_popups.append([note, MUSCLE_COLOR if note.ends_with("MUSCLE") else col.lightened(0.3), -0.25])
	var good := golden or group not in [HealthItem.Group.TREAT, HealthItem.Group.LAZY]
	_swell_vel += -3.0 if kg <= 0.0 else 6.0
	_mood = 1.0 if good else -1.0


## A team power-up for `seconds` (another one of the same kind starts it again).
func boost(kind: String, seconds: float) -> void:
	boosts[kind] = seconds


func boosted(kind: String) -> bool:
	return boosts.get(kind, 0.0) > 0.0


func golden() -> bool:
	return boosted("golden")


## The blobs' speed, times this (sneakers, the sugar crash, Runner's high).
func speed_factor() -> float:
	var f := 1.0
	if boosted("sneakers"):
		f *= settings.sneakers_speed
	if boosted("sugar_crash"):
		f *= settings.crash_speed
	if boosted("runners_high"):
		f *= 1.25
	return f


## The top of the window: the level's, plus what its muscle adds.
func top() -> float:
	return high + body.muscle_room()


## Light blue under the window, green in it, red over it.
func window_color(kg: float) -> Color:
	return LIGHT_COLOR if kg < low else (GOOD_COLOR if kg <= top() else BAD_COLOR)


## Where caught items fly to.
func mouth() -> Vector2:
	return global_position + Vector2(0.0, -radius * 0.2)


## Walked into a gate it doesn't fit through.
func stick() -> void:
	walking = false
	_stuck = 1.0
	_swell_vel -= 8.0
	_mood = -1.0


func _physics_process(delta: float) -> void:
	for k: String in boosts.keys():
		boosts[k] = maxf(boosts[k] - delta, 0.0)
	shown = lerpf(shown, weight, 1.0 - exp(-6.0 * delta))
	var acc := -_swell * 220.0 - _swell_vel * 9.0
	_swell_vel += acc * delta
	_swell += _swell_vel * delta
	_mood = move_toward(_mood, 0.0, delta * 0.8)
	_stuck = maxf(_stuck - delta * 1.5, 0.0)
	if walking:
		_step += delta * 7.0
	for p: Array in _popups:
		p[2] += delta
	_popups = _popups.filter(func(p: Array) -> bool: return p[2] < POPUP_LIFE)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("buddy", self):
		return
	var st := theme.style
	var col: Color = theme.value("buddy.color", COLOR)
	var r := radius * (1.0 + _swell * 0.08)
	var heavy := settings.chubby(shown)
	var shake := Vector2(sin(_stuck * 60.0) * 6.0 * _stuck, 0.0)
	var c := shake
	var swing := sin(_step) if walking else 0.0

	# Feet under the body, stepping in turn; hands at the sides, swinging the other way.
	for s: float in [-1.0, 1.0]:
		var foot := c + Vector2(s * r * 0.45, r * 0.78 + s * swing * r * 0.12)
		st.body(self, _ellipse(foot, r * 0.22, r * 0.16), col.darkened(0.15))
	var buff := minf(body.muscle / 60.0, 1.0) # 0 -> 1: arms grow with muscle
	for s: float in [-1.0, 1.0]:
		var hand := c + Vector2(s * r * (1.12 + 0.12 * buff), -s * swing * r * 0.15)
		st.disc(self, hand, r * 0.17 * (1.0 + 0.7 * buff), col, 0.0, 0.95)

	var rx := r * (1.0 + 0.12 * heavy) # FatSettings.half_width_at(), swollen
	st.body(self, _ellipse(c, rx, r * 0.95), col, 0.0, 1.0, 1.5, 3.5)
	if heavy > 0.0: # a belly that grows with the weight
		draw_colored_polygon(_ellipse(c + Vector2(0.0, r * 0.32), rx * 0.55 * (0.6 + 0.4 * heavy), r * 0.42 * (0.6 + 0.4 * heavy)),
			st.fill_color(col.lightened(0.18)))
	# Sweatband round the front of its head.
	var band: Color = theme.value("buddy.band", BAND_COLOR)
	for tier: Array in BAND_TIERS:
		if body.muscle >= tier[0]:
			band = tier[1]
			break
	st.ring(self, c, r * 0.8, band, r * 0.13, 1.2, -1.0, -PI + 0.55, -0.55)

	_draw_face(st, c, r, heavy)
	if high > 0.0 and weight > top():
		_draw_sweat(st, c, r)
	if golden():
		var t := Time.get_ticks_msec() / 1000.0
		st.ring(self, c, r * 1.25, GOLD_COLOR, 4.0, 1.5, 0.7 + 0.3 * sin(t * 12.0))
		for i in 6:
			st.dot(self, c + Vector2.from_angle(t * 2.0 + TAU * i / 6.0) * r * 1.25, 5.0, GOLD_COLOR.lightened(0.4), 2.0)
	if body.rest > 0: # a z for each point of rest, up to three
		var font := ThemeDB.fallback_font
		for i in mini(body.rest, 3):
			draw_string(font, c + Vector2(-r * 0.9 - i * 16.0, -r * 0.7 - i * 18.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1,
				22 + i * 6, st.color(Color(0.6, 0.78, 1.0), 1.4))
	_draw_tag(st, c, r)
	_draw_popups(st, c, r)


func _draw_face(st: ThemeStyle, c: Vector2, r: float, heavy: float) -> void:
	for s: float in [-1.0, 1.0]:
		var eye := c + Vector2(s * r * 0.3, -r * 0.45)
		if _stuck > 0.0:
			var e := r * 0.1
			draw_line(eye + Vector2(-e, -e), eye + Vector2(e, e), st.ink, 3.0, true)
			draw_line(eye + Vector2(-e, e), eye + Vector2(e, -e), st.ink, 3.0, true)
		else:
			draw_circle(eye, r * 0.15, st.color(Color.WHITE, 2.2))
			draw_circle(eye + Vector2(0.0, -r * 0.05), r * 0.075, st.ink)
		draw_circle(c + Vector2(s * r * (0.55 + 0.05 * heavy), -r * 0.2), r * (0.11 + 0.04 * maxf(heavy, 0.0)),
			Color(1.0, 0.45, 0.45, 0.45))
	var m := c + Vector2(0.0, -r * 0.18)
	var w := r * 0.22
	if _mood < -0.2 or _stuck > 0.0: # yuck: a wobbly line
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(m + Vector2(lerpf(-w, w, i / 6.0), (3.0 if i % 2 == 0 else -3.0)))
		draw_polyline(pts, st.ink, 3.0, true)
	elif _mood > 0.2: # yum: a big open smile
		draw_colored_polygon(_arc_points(m, w, 0.0, PI), st.ink)
	else:
		draw_arc(m + Vector2(0.0, -w * 0.5), w, 0.4, PI - 0.4, 12, st.ink, 3.0, true)


## Two drops running down beside its head.
func _draw_sweat(st: ThemeStyle, c: Vector2, r: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for s: float in [-1.0, 1.0]:
		var k := fmod(t * 1.2 + (0.5 if s > 0.0 else 0.0), 1.0)
		var p := c + Vector2(s * r * 0.95, -r * 0.6 + k * r * 0.5)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0.0, -10.0), p + Vector2(5.0, 0.0), p + Vector2(0.0, 5.0),
			p + Vector2(-5.0, 0.0)]), st.color(SWEAT_COLOR, 1.5, 1.0 - k))


## Its weight beside it: light blue under the window, green in it, red over it.
func _draw_tag(st: ThemeStyle, c: Vector2, r: float) -> void:
	var font := ThemeDB.fallback_font
	var text := "%d kg" % roundi(shown)
	var col := Color.WHITE
	if high > 0.0:
		col = window_color(weight)
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30)
	var at := c + Vector2(r * 1.3 + 24.0, -size.y * 0.5)
	draw_rect(Rect2(at - Vector2(10.0, 4.0), size + Vector2(20.0, 8.0)), Color(0.0, 0.0, 0.05, 0.6))
	draw_string(font, at + Vector2(0.0, size.y * 0.78), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, st.color(col, 1.8))


func _draw_popups(st: ThemeStyle, c: Vector2, r: float) -> void:
	var font := ThemeDB.fallback_font
	for p: Array in _popups:
		var age: float = p[2]
		var y := -r - 30.0 - age * 70.0
		var a := 1.0 - pow(age / POPUP_LIFE, 2.0)
		draw_string(font, c + Vector2(-140.0, y), p[0], HORIZONTAL_ALIGNMENT_CENTER, 280.0, 34 if p[0].ends_with("kg") else 26,
			st.color(p[1], 1.8, a))


static func _ellipse(centre: Vector2, rx: float, ry: float, segments := 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _arc_points(centre: Vector2, r: float, from: float, to: float, segments := 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments + 1:
		pts.append(centre + Vector2.from_angle(lerpf(from, to, float(i) / segments)) * r)
	return pts
