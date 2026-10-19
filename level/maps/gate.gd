@tool
class_name Gate
extends FinishLine
## The end of a Don't Get Fat! level: hedges across the track with a heavy
## door in the middle. Its opening fits the buddy at the top of the level's
## weight window (FatSettings.half_width_at), and the door only swings open
## for a buddy at least as heavy as the bottom of it. The mode stops the belt
## when the buddy reaches it: too heavy and it doesn't fit, too light and it
## can't push the door open, in the window and it walks through. The sign
## shows the window, coloured by where the buddy is (Buddy.window_color). The
## window is the map's FatRules, unless the mode sets `low` and `high` (the
## run's upgrades widen or narrow it). A FinishLine, so the map's editor
## drawing ends here. Colours from the theme: gate.hedge, gate.post.

const HEDGE_COLOR := Color(0.3, 0.65, 0.35)
const POST_COLOR := Color(0.88, 0.88, 0.92)
const DOOR_COLOR := Color(0.62, 0.42, 0.28)
const GOOD_COLOR := Color(0.3, 0.85, 0.4)
const BAD_COLOR := Color(1.0, 0.35, 0.3)
const LIGHT_COLOR := Color(0.55, 0.8, 1.0)

@export var fat: FatSettings = preload("res://modes/dont_get_fat/fat_settings.tres")

var low := 0.0 # the window in kg; 0 = the map's FatRules
var high := 0.0
var cheer := 0.0 # 1 -> 0 after the buddy gets through (set by the mode): the posts flash
var open := 0.0 # 0 = shut, 1 = swung wide open (the mode opens it for a buddy in the window)
var thud := 0.0 # 1 -> 0 after a buddy too light to open it pushed on it: the door shakes


func _rules() -> FatRules:
	var n := get_parent()
	while n != null and not n is Map:
		n = n.get_parent()
	return (n as Map).rules as FatRules if n != null else null


## The bottom of the window: lighter than this, the door won't open.
func window_low() -> float:
	if low > 0.0:
		return low
	var rules := _rules()
	return rules.window_low if rules != null else 72.0


## The top of the window: heavier than this, the buddy won't fit.
func window_high() -> float:
	if high > 0.0:
		return high
	var rules := _rules()
	return rules.window_high if rules != null else 78.0


## Half the opening's width.
func opening() -> float:
	return fat.half_width_at(window_high()) + 6.0


func _process(delta: float) -> void:
	cheer = maxf(cheer - delta * 1.5, 0.0)
	thud = maxf(thud - delta * 2.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("gate", self):
		return
	var st := theme.style
	var half := settings.track_width * 0.5
	var gap := opening()
	var hedge: Color = theme.value("gate.hedge", HEDGE_COLOR)
	for side: float in [-1.0, 1.0]:
		var r := Rect2(minf(side * gap, side * half), -20.0, half - gap, 40.0)
		st.box(self, r, hedge, 0.0, 0.9)
		var x := r.position.x + 12.0
		while x < r.end.x - 6.0:
			st.dot(self, Vector2(x, -18.0), 9.0, hedge.lightened(0.15))
			x += 22.0

	# The door: two heavy wooden leaves that swing up (away from the buddy) as it opens.
	var shake := sin(thud * 40.0) * 5.0 * thud
	for side: float in [-1.0, 1.0]:
		var hinge := Vector2(side * gap, 0.0)
		var leaf := Vector2(-side * gap, 0.0).rotated(side * open * 1.35) # from the hinge to the leaf's tip
		var tip := hinge + leaf + Vector2(shake, 0.0)
		st.line(self, hinge, tip, DOOR_COLOR, 18.0, 1.0)
		st.line(self, hinge.lerp(tip, 0.15), hinge.lerp(tip, 0.9), DOOR_COLOR.lightened(0.25), 4.0, 1.0, 0.7)

	var post: Color = theme.value("gate.post", POST_COLOR)
	for side: float in [-1.0, 1.0]:
		st.disc(self, Vector2(side * gap, 0.0), 17.0 + 5.0 * cheer, post, cheer, 1.0, 1.0 + 2.0 * cheer)

	# The sign over the opening, hung from the posts.
	var sign_col := Color.WHITE
	if not Engine.is_editor_hint():
		var buddy := get_tree().get_first_node_in_group("buddy") as Buddy
		if buddy != null:
			sign_col = LIGHT_COLOR if buddy.weight < window_low() else (GOOD_COLOR if buddy.weight <= window_high() else BAD_COLOR)
	var board := Rect2(-130.0, -122.0, 260.0, 52.0)
	for side: float in [-1.0, 1.0]:
		st.line(self, Vector2(side * gap, -12.0), Vector2(side * 110.0, board.end.y), post.darkened(0.3), 3.0)
	st.box(self, board, Color(0.2, 0.18, 0.25), 0.0, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(board.position.x, board.position.y + 38.0),
		"%d–%d kg" % [roundi(window_low()), roundi(window_high())], HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 32,
		st.color(sign_col, 1.8))
