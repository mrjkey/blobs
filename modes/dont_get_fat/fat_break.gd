class_name FatBreak
extends Control
## Don't Get Fat!'s screens between levels, over the stopped game. The mode
## awaits each one:
##   await report(entry, picks): the level's report card. Its lines show one
##     by one: cleared or not, then the three stars (Balanced plate, Bull's-eye,
##     Light on treats), then how many upgrade picks that earns. Anyone's A
##     (or their push key) goes on.
##   await pick(...): one upgrade pick. The picker chooses one of three cards
##     with left and right on their own controls and takes it with A. Returns
##     the card's id.
##   await run_report(run, complete): the run's report card: every level
##     played with its stars, the upgrades, the total.
## Drawn by hand, in the HUD's font.

signal _done(value: Variant)

const INK := Color(0.93, 0.94, 1.0)
const DIM := Color(0.6, 0.62, 0.76)
const GOOD := Color(0.3, 0.85, 0.4)
const BAD := Color(1.0, 0.4, 0.35)
const STAR_ON := Color(1.0, 0.85, 0.25)
const STAR_OFF := Color(0.28, 0.28, 0.34)
const LINE_TIME := 0.45 # a report card line shows every this many seconds
const STAR_NAMES := ["BALANCED PLATE", "BULL'S-EYE", "LIGHT ON TREATS"]
const KIND_COLORS := {"BUDDY": Color(1.0, 0.75, 0.45), "WINDOW": Color(0.4, 0.9, 0.6), "PLATE": Color(1.0, 0.85, 0.3),
	"BELT": Color(0.4, 0.75, 1.0), "BLOB": Color(1.0, 0.5, 0.75), "POWER-UP": Color(0.75, 0.55, 1.0), "TEAM": Color(0.6, 0.95, 0.95)}

var inputs: Array[PlayerInput] = [] # every human's controls, for "go on"

var _mode := ""
var _t := 0.0
var _entry := {}
var _picks := -1
var _hand: Array[String] = []
var _choice := 1
var _who := ""
var _who_color := Color.WHITE
var _picker: PlayerInput
var _pick_n := 0
var _pick_of := 0
var _taken := {}
var _run: FatRun
var _complete := false
var _was_x := 0.0
var _ok := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	hide()


## The level's report card. `entry`: {title, cleared, why, weight, low, high,
## plate: [protein, grains, veg], target, treats, slots, has_plate, stars:
## [plate, bull's-eye, treats]}. `picks` < 0: no picks to show.
func report(entry: Dictionary, picks: int) -> void:
	_entry = entry
	_picks = picks
	await _open("report")


## One pick from `hand` (card ids) by `who`, steering with `input`; this is
## pick `n` of `of`; `taken`: the run's upgrades so far. `who` is "" when
## there's only one player. Returns the card's id.
func pick(hand: Array[String], who: String, color: Color, input: PlayerInput, n: int, of: int, taken: Dictionary) -> String:
	_hand = hand
	_choice = 1 if hand.size() > 1 else 0
	_who = who
	_who_color = color
	_picker = input
	_pick_n = n
	_pick_of = of
	_taken = taken
	return await _open("pick")


## The run's report card: `complete` if it got through every level.
func run_report(run: FatRun, complete: bool) -> void:
	_run = run
	_complete = complete
	await _open("run")


func _open(mode: String) -> Variant:
	_mode = mode
	_t = 0.0
	_was_x = 0.0
	show()
	Sfx.play("pop", 0.9)
	var v: Variant = await _done
	hide()
	_mode = ""
	return v


## Seconds until the card has shown every line.
func _reveal_time() -> float:
	return LINE_TIME * 5.0 if _mode == "report" else 0.3


func _process(delta: float) -> void:
	if _mode == "":
		return
	_t += delta
	queue_redraw()
	var ok := Input.is_action_just_pressed("ui_accept") and (_mode != "pick" or not is_instance_valid(_picker))
	for input in inputs:
		if is_instance_valid(input):
			var pressed := input.ok_pressed()
			ok = ok or (pressed and (_mode != "pick" or input == _picker))
	if _mode == "pick":
		_steer()
	if not ok:
		return
	if _t < _reveal_time():
		_t = _reveal_time() # skip the reveal
		return
	Sfx.play("good", 1.2)
	_done.emit(_hand[_choice] if _mode == "pick" else true)


func _steer() -> void:
	var x := _picker.steer().x if is_instance_valid(_picker) else Input.get_axis("ui_left", "ui_right")
	var step := 0
	if x > 0.5 and _was_x <= 0.5:
		step = 1
	elif x < -0.5 and _was_x >= -0.5:
		step = -1
	_was_x = x
	if step != 0 and not _hand.is_empty():
		_choice = clampi(_choice + step, 0, _hand.size() - 1)
		Sfx.play("pop", 1.1 + 0.1 * _choice)


func _draw() -> void:
	if _mode == "":
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.04, 0.72))
	var font := get_theme_default_font()
	match _mode:
		"report": _draw_report(font)
		"pick": _draw_pick(font)
		"run": _draw_run(font)


func _panel(w: float, h: float) -> Rect2:
	var r := Rect2((size - Vector2(w, h)) * 0.5, Vector2(w, h))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.07, 0.14, 0.97)
	box.border_color = Color(0.45, 0.45, 0.7)
	box.set_border_width_all(3)
	box.set_corner_radius_all(18)
	box.draw(get_canvas_item(), r)
	return r


func _text(font: Font, at: Vector2, text: String, fs: int, col: Color, w := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(font, at, text, align, w, fs, col)


func _prompt(font: Font, r: Rect2, text: String) -> void:
	var a := 0.6 + 0.4 * sin(_t * 4.0)
	_text(font, Vector2(r.position.x, r.end.y - 26.0), text, 22, Color(INK, a), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_report(font: Font) -> void:
	var e := _entry
	var r := _panel(760.0, 600.0)
	var x := r.position.x + 48.0
	var w := r.size.x - 96.0
	var y := r.position.y + 60.0
	_text(font, Vector2(x, y), e.title, 26, DIM, w, HORIZONTAL_ALIGNMENT_CENTER)
	y += 58.0
	_text(font, Vector2(x, y), "LEVEL CLEAR!" if e.cleared else "LEVEL FAILED", 52, GOOD if e.cleared else BAD, w,
		HORIZONTAL_ALIGNMENT_CENTER)
	y += 40.0
	_text(font, Vector2(x, y), e.why, 22, INK, w, HORIZONTAL_ALIGNMENT_CENTER)
	y += 56.0
	var lines := [
		["IN THE WINDOW", "%.1f kg, window %d–%d" % [e.weight, e.low, e.high], e.cleared, false],
		[STAR_NAMES[0], ("protein %d · grains %d · veg %d of %d" % [e.plate[0], e.plate[1], e.plate[2], e.target])
			if e.has_plate else "no plate this level", e.stars[0], true],
		[STAR_NAMES[1], "stop in the middle of the window: %.1f to %.1f kg" % [e.mid - e.bull, e.mid + e.bull], e.stars[1], true],
		[STAR_NAMES[2], "%d treats, %d allowed" % [e.treats, e.slots], e.stars[2], true],
	]
	for i in lines.size():
		var line: Array = lines[i]
		var shown := clampf((_t - LINE_TIME * (i + 1)) / 0.2, 0.0, 1.0)
		if shown <= 0.0:
			break
		var col_a := Color(1, 1, 1, shown)
		var mark := Vector2(x + 22.0, y - 9.0)
		if line[3]:
			draw_colored_polygon(FatHud.star_points(mark, 20.0 * (1.0 + 0.4 * (1.0 - shown))), (STAR_ON if line[2] else STAR_OFF) * col_a)
		else:
			draw_circle(mark, 16.0, (GOOD if line[2] else BAD) * col_a)
			_text(font, mark + Vector2(-16.0, 8.0), "✓" if line[2] else "✗", 22, Color(0.05, 0.05, 0.1, shown), 32.0,
				HORIZONTAL_ALIGNMENT_CENTER)
		_text(font, Vector2(x + 60.0, y), line[0], 26, (INK if line[2] else DIM) * col_a)
		_text(font, Vector2(x + 60.0, y + 26.0), line[1], 18, DIM * col_a)
		if line[2] and _picks >= 0:
			_text(font, Vector2(x, y), "+1 PICK", 20, STAR_ON * col_a, w, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 68.0
	if _t >= LINE_TIME * 5.0 and _picks >= 0:
		_text(font, Vector2(x, y + 18.0), "%d UPGRADE PICK%s" % [_picks, "" if _picks == 1 else "S"], 30, STAR_ON, w,
			HORIZONTAL_ALIGNMENT_CENTER)
	if _t >= _reveal_time():
		_prompt(font, r, "A / Space: continue")


func _draw_pick(font: Font) -> void:
	var r := _panel(1000.0, 640.0)
	var x := r.position.x
	var w := r.size.x
	_text(font, Vector2(x, r.position.y + 62.0), "PICK AN UPGRADE" if _who == "" else "%s PICKS AN UPGRADE" % _who, 40,
		_who_color, w, HORIZONTAL_ALIGNMENT_CENTER)
	_text(font, Vector2(x, r.position.y + 98.0), "pick %d of %d" % [_pick_n, _pick_of], 22, DIM, w, HORIZONTAL_ALIGNMENT_CENTER)
	var cw := 270.0
	var ch := 300.0
	var gap := 34.0
	var left := x + (w - cw * _hand.size() - gap * (_hand.size() - 1)) * 0.5
	for i in _hand.size():
		var id := _hand[i]
		var card: Array = FatRun.CARDS[id]
		var on := i == _choice
		var lift := (14.0 + 4.0 * sin(_t * 5.0)) if on else 0.0
		var cr := Rect2(left + i * (cw + gap), r.position.y + 140.0 - lift, cw, ch)
		var kind_col: Color = KIND_COLORS.get(card[1], INK)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.13, 0.13, 0.24) if on else Color(0.1, 0.1, 0.17)
		box.border_color = _who_color if on else Color(0.3, 0.3, 0.45)
		box.set_border_width_all(5 if on else 2)
		box.set_corner_radius_all(16)
		box.draw(get_canvas_item(), cr)
		var ix := cr.position.x + 20.0
		var iw := cw - 40.0
		_text(font, Vector2(ix, cr.position.y + 40.0), card[1], 18, kind_col, iw)
		var have: int = _taken.get(id, 0)
		if have > 0:
			_text(font, Vector2(ix, cr.position.y + 40.0), "you have %d" % have, 16, DIM, iw, HORIZONTAL_ALIGNMENT_RIGHT)
		draw_multiline_string(font, Vector2(ix, cr.position.y + 84.0), card[0], HORIZONTAL_ALIGNMENT_LEFT, iw, 28, 2,
			INK if on else Color(INK, 0.8))
		draw_multiline_string(font, Vector2(ix, cr.position.y + 176.0), card[2], HORIZONTAL_ALIGNMENT_LEFT, iw, 20, 5,
			INK if on else DIM)
	var names: Array[String] = []
	for id: String in _taken:
		names.append(FatRun.CARDS[id][0] + ("" if _taken[id] == 1 else " ×%d" % _taken[id]))
	_text(font, Vector2(x + 40.0, r.end.y - 72.0), "Upgrades: " + (", ".join(names) if not names.is_empty() else "none yet"),
		18, DIM, w - 80.0, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt(font, r, ("" if _who == "" else _who + ": ") + "left / right to choose · A / push key: take it")


func _draw_run(font: Font) -> void:
	var rows := _run.report.size()
	var r := _panel(820.0, 300.0 + rows * 52.0 + 60.0)
	var x := r.position.x + 60.0
	var w := r.size.x - 120.0
	var y := r.position.y + 70.0
	_text(font, Vector2(x, y), "RUN COMPLETE!" if _complete else "RUN OVER", 48, GOOD if _complete else BAD, w,
		HORIZONTAL_ALIGNMENT_CENTER)
	y += 40.0
	_text(font, Vector2(x, y), "The run's report card", 20, DIM, w, HORIZONTAL_ALIGNMENT_CENTER)
	y += 54.0
	for i in rows:
		var e: Dictionary = _run.report[i]
		_text(font, Vector2(x, y), e.title, 26, INK if e.cleared else BAD)
		if e.cleared:
			for s in 3:
				draw_colored_polygon(FatHud.star_points(Vector2(x + w - 100.0 + s * 40.0, y - 9.0), 16.0),
					STAR_ON if e.stars[s] else STAR_OFF)
		else:
			_text(font, Vector2(x, y), "FAILED", 22, BAD, w, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 52.0
	y += 14.0
	_text(font, Vector2(x, y), "%d STARS" % _run.stars(), 34, STAR_ON, w, HORIZONTAL_ALIGNMENT_CENTER)
	y += 44.0
	var names: Array[String] = []
	for id: String in _run.upgrades:
		names.append(FatRun.CARDS[id][0] + ("" if _run.upgrades[id] == 1 else " ×%d" % _run.upgrades[id]))
	draw_multiline_string(font, Vector2(x, y), "Upgrades: " + (", ".join(names) if not names.is_empty() else "none"),
		HORIZONTAL_ALIGNMENT_CENTER, w, 18, 3, DIM)
	_prompt(font, r, "A / Space: new run · Start / Esc: quit")
