class_name HowToPlay
extends Control
## The HOW TO PLAY page: a game's goal (ModeInfo.goal), then a card per move
## blobs have there (MoveRules), each with a little looping picture of it,
## its name, what it does, and its buttons: the keys of this computer's
## keyboard players (or the whole keyboard's) and a controller's. Then the
## game's tips and the rules' (energy, shrinking), and `prompts` along the
## bottom (PromptBar prompts: what to press now). The lobby shows it once
## everyone's ready, in place of a READY banner; the pause menu on HOW TO
## PLAY. The pictures are in the game theme's style; the page in the menu
## theme's MenuPanel panel and LobbyCard colours (panel, text, dim), the
## title in TitleLabel's font colour. It animates even while the game is
## paused.

## Every move, in the order the cards go: [name, what it does]. A game can
## rename or explain one its own way (ModeInfo.move_texts).
const MOVES := {
	"move": ["MOVE", "Roll your blob around"],
	"push": ["PUSH", "Wind up, then blast every blob near you away"],
	"dash": ["DASH", "A quick burst: slam into whoever's in the way"],
	"ghost": ["GHOST DASH", "A quick burst that slips through blobs, pushes and lasers"],
	"slash": ["SLASH", "Swing a blade the way you face"],
	"spit": ["SPIT", "Fire a glob the way you face: it knocks back and slimes"],
	"shield": ["SHIELD", "A quick bubble: blocks pushes and slashes, sends spit back"],
}
const PAD_GLYPHS := {
	JOY_BUTTON_A: "a", JOY_BUTTON_B: "b", JOY_BUTTON_X: "x", JOY_BUTTON_Y: "y",
	JOY_BUTTON_LEFT_SHOULDER: "pill:LB", JOY_BUTTON_RIGHT_SHOULDER: "pill:RB",
	JOY_BUTTON_START: "pill:START", JOY_BUTTON_BACK: "pill:BACK",
}
const LOOP := 2.2 # seconds per picture loop
const GAP := 18.0 # between cards
const GLYPH_H := 32.0
const PAD := 28.0 # inside the page's edge
const MAX_CARD_H := 330.0

var info: ModeInfo
var rules: MoveRules
var keyboards: Array[InputProfile] = [] # this computer's players' keys; none: the whole keyboard's
var prompts: Array = []: # PromptBar prompts along the bottom
	set(value):
		prompts = value
		queue_redraw()
var pause_hint := true # also say which buttons open the pause menu (not in the pause menu itself)
var _t := 0.0

static var _box: StyleBoxFlat
var _panel: StyleBox # the theme's MenuPanel, made solid (it covers a menu)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # a paused game's menu shows it too
	mouse_filter = MOUSE_FILTER_STOP


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
		_panel = null
		queue_redraw()


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


## Show `game` with `move_rules` (ModeInfo.move_rules(), or the moves its blobs really have) and the keys in `keys`.
func show_game(game: ModeInfo, move_rules: MoveRules, keys: Array[InputProfile]) -> void:
	info = game
	rules = move_rules
	keyboards = keys
	queue_redraw()


## The moves blobs have under `r`, as keys of MOVES.
static func moves_in(r: MoveRules) -> Array[String]:
	var out: Array[String] = ["move"]
	if r.push:
		out.append("push")
	if r.dash == MoveRules.Dash.BUMP:
		out.append("dash")
	elif r.dash == MoveRules.Dash.GHOST:
		out.append("ghost")
	for m: String in ["slash", "spit", "shield"]:
		if r.get(m):
			out.append(m)
	return out


## A keyboard key as a ButtonGlyph: "key:J", "key:SPACE", "key:.".
static func key_glyph(k: Key) -> String:
	if k > 32 and k < 127:
		return "key:" + String.chr(k).to_upper()
	return "key:" + OS.get_keycode_string(k).to_upper()


## A gamepad button as a ButtonGlyph: "a", "pill:LB".
static func pad_glyph(b: JoyButton) -> String:
	return PAD_GLYPHS.get(b, "pill:%d" % b)


## `move`'s keys on `p` (one glyph: "key:WASD", "key:ARROWS", "key:SPACE"), or "" if it has none.
static func move_key(p: InputProfile, move: String) -> String:
	if move == "move":
		if p.up.is_empty() or p.left.is_empty() or p.down.is_empty() or p.right.is_empty():
			return ""
		var four := [p.up[0], p.left[0], p.down[0], p.right[0]]
		if four == [KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]:
			return "key:ARROWS"
		var text := ""
		for k: Key in four:
			text += key_glyph(k).get_slice(":", 1)
		return "key:" + text
	var keys: Array = p.get("dash" if move == "ghost" else move)
	return key_glyph(keys[0]) if not keys.is_empty() else ""


## `move`'s gamepad glyph.
static func move_button(p: InputProfile, move: String) -> String:
	if move == "move":
		return "stick"
	var buttons: Array = p.get("pad_" + ("dash" if move == "ghost" else move))
	return pad_glyph(buttons[0]) if not buttons.is_empty() else ""


func _texts(move: String) -> Array:
	var own: Variant = info.move_texts.get(move) if info != null else null
	if own is Array and own.size() == 2:
		return own
	return MOVES[move]


## The game's goal, then its tips and what the rules add.
func _tips() -> PackedStringArray:
	var out := PackedStringArray()
	if rules.energy == MoveRules.Energy.ALL:
		out.append("Every move uses energy (the bar by your blob); it fills back up.")
	elif rules.energy == MoveRules.Energy.DASH and rules.dash != MoveRules.Dash.NONE:
		out.append("The dash uses energy (the bar by your blob); it fills back up.")
	if info.mass_loss and rules.mass_decay > 0.0:
		out.append("You shrink as you go." + (" Spitting costs a little of you too." if rules.spit and rules.spit_mass > 0.0 else ""))
	out.append_array(info.tips)
	return out


func _draw() -> void:
	if info == null or rules == null:
		return
	var theme := GameTheme.current()
	var st := theme.style
	var font := get_theme_default_font()
	var ink := get_theme_color("text", "LobbyCard")
	var dim := get_theme_color("dim", "LobbyCard")
	if _panel == null:
		_panel = get_theme_stylebox("panel", "MenuPanel").duplicate()
		if _panel is StyleBoxFlat:
			_panel.bg_color.a = 1.0
	_panel.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	var w := size.x
	var y := PAD + 6.0
	_text(font, Vector2(w * 0.5, y), "HOW TO PLAY", 20, dim)
	y += 40.0
	_text(font, Vector2(w * 0.5, y), info.title, 48, get_theme_color("font_color", "TitleLabel"))
	y += 42.0
	for line in _wrap(font, info.goal if info.goal != "" else info.subtitle, 22, w - PAD * 4.0):
		_text(font, Vector2(w * 0.5, y), line, 22, ink)
		y += 29.0
	y += 6.0

	# The bottom, from the bottom up: the prompts (and the pause menu's buttons), the tips.
	var bottom := size.y - PAD
	_prompts(font, bottom, prompts + ([[["pill:START", "key:ESC"], "Pause menu"]] if pause_hint else []), ink)
	bottom -= 46.0
	var tips := _tips()
	for i in range(tips.size() - 1, -1, -1):
		_text(font, Vector2(w * 0.5, bottom), tips[i], 19, ink)
		bottom -= 27.0
	bottom -= 4.0

	var moves := moves_in(rules)
	var cols := mini(moves.size(), 3 if moves.size() > 4 or moves.size() == 3 else 4)
	var rows := ceili(moves.size() / float(cols))
	var card_w := minf((w - PAD * 2.0 - GAP * (cols - 1)) / cols, 420.0)
	var card_h := minf((bottom - y - GAP * (rows - 1)) / rows, MAX_CARD_H)
	var top := y + maxf((bottom - y - (card_h * rows + GAP * (rows - 1))) * 0.5, 0.0)
	for i in moves.size():
		var row := floori(float(i) / cols)
		var in_row := mini(cols, moves.size() - row * cols)
		var left := (w - (card_w * in_row + GAP * (in_row - 1))) * 0.5
		var rect := Rect2(left + (i % cols) * (card_w + GAP), top + row * (card_h + GAP), card_w, card_h)
		_card(theme, st, font, rect, moves[i], ink, dim)


func _card(theme: GameTheme, st: ThemeStyle, font: Font, rect: Rect2, move: String, ink: Color, dim: Color) -> void:
	var you := theme.palette_color(0)
	if _box == null:
		_box = StyleBoxFlat.new()
		_box.set_corner_radius_all(12)
	var box := _box
	box.bg_color = get_theme_color("panel", "LobbyCard")
	box.border_color = st.color(you, 0.9, 0.7)
	box.set_border_width_all(2)
	box.draw(get_canvas_item(), rect)
	var texts := _texts(move)
	# Room for the picture: what's left after the name, the text and the buttons.
	var glyph_y := rect.end.y - 14.0 - GLYPH_H * 0.5
	var lines := _wrap(font, texts[1], 17, rect.size.x - 28.0)
	var text_y := glyph_y - GLYPH_H * 0.5 - 14.0 - 22.0 * (lines.size() - 1) - 11.0
	var name_y := text_y - 34.0
	var pic := Rect2(rect.position.x + 10.0, rect.position.y + 8.0, rect.size.x - 20.0, name_y - 22.0 - rect.position.y - 8.0)
	if pic.size.y > 40.0:
		_picture(theme, st, pic, move)
	_text(font, Vector2(rect.get_center().x, name_y), texts[0], 28, st.color(you.lerp(Color.WHITE, 0.35), 1.5))
	for j in lines.size():
		_text(font, Vector2(rect.get_center().x, text_y + 22.0 * j), lines[j], 17, ink)
	# The buttons: each keyboard's key, then "or" and the controller's.
	var glyphs: Array = []
	var boards: Array = keyboards
	if boards.is_empty():
		boards = [PlayerSlot.KEYS_ALL]
	for p: InputProfile in boards:
		var g := move_key(p, move)
		if g != "" and not glyphs.has(g):
			glyphs.append(g)
	var pad := move_button(PlayerSlot.PAD_ONLY, move)
	var or_w := font.get_string_size("or", HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	var total := 0.0
	for g: String in glyphs:
		total += ButtonGlyph.width(font, g, GLYPH_H) + 6.0
	total += 8.0 + or_w + 14.0 + ButtonGlyph.width(font, pad, GLYPH_H)
	var x := rect.get_center().x - total * 0.5
	for g: String in glyphs:
		x += ButtonGlyph.draw(self, font, Vector2(x, glyph_y), g, GLYPH_H) + 6.0
	_text_left(font, Vector2(x + 8.0, glyph_y), "or", 17, dim)
	ButtonGlyph.draw(self, font, Vector2(x + 8.0 + or_w + 14.0, glyph_y), pad, GLYPH_H)


# --- The pictures -------------------------------------------------------------
# Each loops every LOOP seconds (k: 0..1 through the loop) inside `pic`: "you"
# (palette colour 0) doing the move, often to another blob (colour 1).

func _picture(theme: GameTheme, st: ThemeStyle, pic: Rect2, move: String) -> void:
	var you := theme.palette_color(0)
	var them := theme.palette_color(1)
	var k := fmod(_t / LOOP, 1.0)
	var c := pic.get_center()
	var r := minf(pic.size.y * 0.18, 30.0) # the push's blast (5.6 r across) just fits
	var span := minf(pic.size.x * 0.5 - r * 1.5, r * 5.0)
	match move:
		"move":
			# A figure of eight, looking where it goes, with a fading trail.
			for i in range(5, 0, -1):
				var p := _eight(k - i * 0.025, c, span, r)
				st.dot(self, p, r * (0.5 - i * 0.06), you, 1.2, 0.25 - i * 0.04)
			var at := _eight(k, c, span, r)
			_blob(st, at, r, you, (_eight(k + 0.01, c, span, r) - at).normalized())
		"push":
			var me := c - Vector2(span * 0.35, 0.0)
			var windup := _between(k, 0.1, 0.35)
			var blast := _between(k, 0.35, 0.7)
			var flown := _ease(_between(k, 0.35, 0.6)) * (1.0 - _between(k, 0.75, 1.0))
			var there := me + Vector2(r * 2.4 + span * 0.9 * flown, 0.0)
			if blast > 0.0 and blast < 1.0:
				st.ring(self, me, r * (1.2 + 1.6 * _ease(blast)), Color.WHITE, 4.0 * (1.0 - blast) + 1.0, 2.0, 1.0 - blast)
			_blob(st, there, r * 0.85, them, Vector2.LEFT, 0.0, flown > 0.05 and flown < 0.9)
			_blob(st, me, r * (1.0 + 0.15 * windup * (1.0 - blast)), you, Vector2.RIGHT, 0.0, false, windup > 0.0 and blast == 0.0)
		"dash", "ghost":
			var ghost := move == "ghost"
			var go := _ease(_between(k, 0.15, 0.32))
			var back := _between(k, 0.8, 1.0)
			var x := lerpf(lerpf(-span, span * (0.9 if ghost else 0.1), go), -span, back)
			var hit := _ease(_between(k, 0.3, 0.5)) * (1.0 - back) if not ghost else 0.0
			var them_at := c + Vector2(span * 0.1 + r * 2.0 + span * 0.5 * hit, 0.0)
			_blob(st, them_at, r * 0.85, them, Vector2.LEFT, 0.0, hit > 0.05 and hit < 0.95)
			var dashing := go > 0.0 and go < 1.0
			if dashing:
				for i in 4:
					var trail := c + Vector2(x - (i + 1) * r * 0.9, 0.0)
					st.ring(self, trail, r * (0.95 - i * 0.12), you, 3.0, 1.4, 0.45 - i * 0.1)
			if ghost and dashing: # see-through while it slips past
				st.ring(self, c + Vector2(x, 0.0), r, you, 3.0, 1.6, 0.8)
				_eyes(st, c + Vector2(x, 0.0), r, Vector2.RIGHT)
			else:
				_blob(st, c + Vector2(x, 0.0), r, you, Vector2.RIGHT, 0.0, false, dashing)
		"slash":
			var me := c - Vector2(span * 0.4, 0.0)
			var swing := _between(k, 0.25, 0.42)
			var fade := 1.0 - _between(k, 0.42, 0.62)
			var knocked := _ease(_between(k, 0.3, 0.55)) * (1.0 - _between(k, 0.75, 1.0))
			_blob(st, me + Vector2(r * 3.0, -r * 0.8 + r * 1.8 * knocked), r * 0.8, them, Vector2.LEFT, 0.0, knocked > 0.05 and knocked < 0.9)
			if swing > 0.0 and fade > 0.0:
				var from := -1.1
				var to := lerpf(-1.1, 1.1, _ease(swing))
				for i in 3:
					st.ring(self, me, r * (1.6 + 0.35 * i), Color.WHITE.lerp(you, 0.3 * i), 5.0 - i, 2.0, fade * (0.9 - 0.25 * i), from, to)
			_blob(st, me - Vector2(r * 0.25 * swing * fade, 0.0), r, you, Vector2.RIGHT, 0.0, false, swing > 0.0 and fade > 0.5)
		"spit":
			var me := c - Vector2(span * 0.8, 0.0)
			var target := c + Vector2(span * 0.8, 0.0)
			var fly := _between(k, 0.15, 0.45)
			var after := _between(k, 0.45, 0.95)
			var knocked := _ease(_between(k, 0.45, 0.65)) * (1.0 - _between(k, 0.8, 1.0))
			var them_at := target + Vector2(r * 0.8 * knocked, 0.0)
			_blob(st, them_at, r * 0.85, them, Vector2.LEFT)
			if after > 0.0 and after < 1.0: # slimed
				for a: float in [-2.4, -0.8, 0.9, 2.3]:
					st.dot(self, them_at + Vector2.from_angle(a) * r * 0.5, r * 0.18, you, 1.4, 0.7 * (1.0 - after))
			if fly > 0.0 and fly < 1.0:
				var glob := me.lerp(target, fly)
				for i in 4:
					st.dot(self, glob - Vector2((i + 1) * r * 0.35, 0.0), r * (0.22 - i * 0.04), you, 1.4, 0.5 - i * 0.1)
				st.dot(self, glob, r * 0.3, you, 1.8)
			_blob(st, me, r, you, Vector2.RIGHT, 0.0, false, k > 0.08 and k < 0.2)
		"shield":
			var me := c - Vector2(span * 0.3, 0.0)
			var up := _between(k, 0.1, 0.75)
			var come := _between(k, 0.15, 0.4)
			var away := _between(k, 0.4, 0.75)
			var edge := me + Vector2(r * 2.0, 0.0)
			var from := c + Vector2(span, 0.0)
			if come < 1.0 and come > 0.0:
				st.dot(self, from.lerp(edge, come), r * 0.3, them, 1.8)
			elif away > 0.0 and away < 1.0:
				st.dot(self, edge.lerp(from + Vector2(0.0, -r), away), r * 0.3, you, 1.8)
			_blob(st, me, r, you, Vector2.RIGHT)
			if up > 0.0 and up < 1.0:
				var pop := 1.0 - exp(-up * LOOP * 30.0) * cos(up * LOOP * 45.0)
				var flash := 1.0 - _between(k, 0.4, 0.55) if k >= 0.4 else 0.0
				var hex := PackedVector2Array()
				for i in 6:
					hex.append(me + Vector2.from_angle(up * 1.5 + TAU * i / 6.0) * (r + 16.0) * (0.8 + 0.2 * pop))
				draw_colored_polygon(hex, st.color(you.lerp(Color.WHITE, 0.5), 1.2, 0.16 + 0.3 * flash))
				st.outline(self, hex, st.color(you.lerp(Color.WHITE, 0.7 + 0.3 * flash), 2.5 + 2.0 * flash), 4.0)


## A blob like the game's: body, shine and eyes looking along `look`.
## `blur` squashes it along `look` (flying), `angry` adds a white rim (winding up, swinging).
func _blob(st: ThemeStyle, at: Vector2, r: float, col: Color, look: Vector2, flash := 0.0, blur := false, angry := false) -> void:
	var pts := PackedVector2Array()
	var along := look if look != Vector2.ZERO else Vector2.RIGHT
	for i in 32:
		var p := Vector2.from_angle(TAU * i / 32.0)
		if blur:
			p += along * p.dot(along) * 0.25
		pts.append(at + p * r)
	st.body(self, pts, col, flash, 1.0, 1.5, 3.0, true)
	if angry:
		st.outline(self, pts, st.color(Color.WHITE, 2.0), 3.5)
	if st.highlights:
		draw_circle(at + Vector2(-0.38, -0.4) * r, r * 0.22, Color(1, 1, 1, 0.3))
	_eyes(st, at, r, look)


func _eyes(st: ThemeStyle, at: Vector2, r: float, look: Vector2) -> void:
	var dir := look if look != Vector2.ZERO else Vector2.RIGHT
	var side := Vector2(-dir.y, dir.x)
	for s: float in [-1.0, 1.0]:
		var e := at + (dir * 0.38 + side * 0.3 * s) * r
		draw_circle(e, r * 0.2, st.color(Color.WHITE, 2.2))
		draw_circle(e + dir * r * 0.08, r * 0.1, st.ink)


## A point on a figure of eight around `c`, `k` of the way round.
static func _eight(k: float, c: Vector2, span: float, r: float) -> Vector2:
	var a := k * TAU
	return c + Vector2(sin(a) * span * 0.8, sin(a * 2.0) * r * 0.9)


## 0 before `a`, 1 after `b`, a straight line between.
static func _between(k: float, a: float, b: float) -> float:
	return clampf((k - a) / (b - a), 0.0, 1.0)


static func _ease(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)


# --- Text ---------------------------------------------------------------------

func _prompts(font: Font, y: float, list: Array, color: Color) -> void:
	var total := 0.0
	for p: Array in list:
		total += PromptBar.prompt_width(font, p, GLYPH_H, 20) + 36.0
	var x := (size.x - total + 36.0) * 0.5
	for p: Array in list:
		x += PromptBar.draw_prompt(self, font, Vector2(x, y), p, GLYPH_H, 20, color) + 36.0


func _text(font: Font, centre: Vector2, text: String, fs: int, col: Color) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_text_left(font, Vector2(centre.x - tw * 0.5, centre.y), text, fs, col)


## `at` is the left end of the text's vertical centre line.
func _text_left(font: Font, at: Vector2, text: String, fs: int, col: Color) -> void:
	draw_string(font, Vector2(at.x, at.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _wrap(font: Font, text: String, fs: int, width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var next := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
			lines.append(line)
			line = word
		else:
			line = next
	lines.append(line)
	return lines
