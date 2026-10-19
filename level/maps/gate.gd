@tool
class_name Gate
extends FinishLine
## The end of a Don't Get Fat! level: hedges across the track with a gate in
## the middle whose opening fits the buddy at the level's weight limit (its
## map's FatRules.max_weight; FatSettings.half_width_at). The mode stops the
## belt when the buddy reaches it: it walks through, or it's too big and the
## level is failed. The sign shows the limit, green while the buddy is under
## it and red while it's over. A FinishLine, so the map's editor drawing ends
## here. Colours from the theme: gate.hedge, gate.post.

const HEDGE_COLOR := Color(0.3, 0.65, 0.35)
const POST_COLOR := Color(0.88, 0.88, 0.92)
const GOOD_COLOR := Color(0.3, 0.85, 0.4)
const BAD_COLOR := Color(1.0, 0.35, 0.3)

@export var fat: FatSettings = preload("res://modes/dont_get_fat/fat_settings.tres")

var cheer := 0.0 # 1 -> 0 after the buddy gets through (set by the mode): the posts flash


## The weight limit: from the map's FatRules, or 90 kg without one.
func limit() -> float:
	var n := get_parent()
	while n != null and not n is Map:
		n = n.get_parent()
	var rules := (n as Map).rules as FatRules if n != null else null
	return rules.max_weight if rules != null else 90.0


## Half the opening's width.
func opening() -> float:
	return fat.half_width_at(limit()) + 6.0


func _process(delta: float) -> void:
	cheer = maxf(cheer - delta * 1.5, 0.0)
	queue_redraw()


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("gate", self):
		return
	var st := theme.style
	var half := settings.track_width * 0.5
	var open := opening()
	var hedge: Color = theme.value("gate.hedge", HEDGE_COLOR)
	for side: float in [-1.0, 1.0]:
		var r := Rect2(minf(side * open, side * half), -20.0, half - open, 40.0)
		st.box(self, r, hedge, 0.0, 0.9)
		var x := r.position.x + 12.0
		while x < r.end.x - 6.0:
			st.dot(self, Vector2(x, -18.0), 9.0, hedge.lightened(0.15))
			x += 22.0

	const SQUARE := 16.0 # a chequered strip across the opening
	var col := 0
	var x := -open
	while x < open:
		for row in 2:
			var c := Color(1.0, 1.0, 1.0, 0.7) if (col + row) % 2 == 0 else Color(0.0, 0.0, 0.0, 0.45)
			draw_rect(Rect2(x, -SQUARE + row * SQUARE, minf(SQUARE, open - x), SQUARE), c)
		x += SQUARE
		col += 1

	var post: Color = theme.value("gate.post", POST_COLOR)
	for side: float in [-1.0, 1.0]:
		st.disc(self, Vector2(side * open, 0.0), 17.0 + 5.0 * cheer, post, cheer, 1.0, 1.0 + 2.0 * cheer)

	# The sign over the opening, hung from the posts.
	var sign_col := Color.WHITE
	if not Engine.is_editor_hint():
		var buddy := get_tree().get_first_node_in_group("buddy") as Buddy
		if buddy != null:
			sign_col = GOOD_COLOR if buddy.weight <= limit() else BAD_COLOR
	var board := Rect2(-110.0, -122.0, 220.0, 52.0)
	for side: float in [-1.0, 1.0]:
		st.line(self, Vector2(side * open, -12.0), Vector2(side * 96.0, board.end.y), post.darkened(0.3), 3.0)
	st.box(self, board, Color(0.2, 0.18, 0.25), 0.0, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(board.position.x, board.position.y + 38.0), "MAX %d kg" % roundi(limit()),
		HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 32, st.color(sign_col, 1.8))
