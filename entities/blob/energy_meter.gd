class_name EnergyMeter
extends Node2D
## The parent Blob's energy bar, drawn next to it: a row of pips above or
## below it, or arcs around it, as the "meter" setting says ("meter_bots":
## on bots too). Only shown while the blob's rules use energy. The HUD
## version is EnergyHud; both draw with draw_pips(). Flashes red and shakes
## when a move is refused.

const DENIED_COLOR := Color(1.0, 0.25, 0.2)
const PIP := Vector2(13.0, 5.0)
const GAP := 3.0

@onready var blob: Blob = get_parent()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("energy", self):
		return
	if not blob.alive or blob.rules.energy == MoveRules.Energy.OFF:
		return
	if not blob.is_human() and GameSettings.choice("meter_bots") != "yes":
		return
	var st := theme.style
	var r := blob.body.draw_radius
	match GameSettings.choice("meter"):
		"above":
			var y := -r - 12.0
			if blob.is_human(): # clear of the pointer (and the P1/P2 tag)
				y = -r - (50.0 if blob.tag != "" else 34.0)
			draw_pips(self, st, blob, Vector2(0.0, y), PIP, GAP)
		"below":
			draw_pips(self, st, blob, Vector2(0.0, r + 13.0), PIP, GAP)
		"ring":
			draw_arcs(self, st, blob, r + 15.0, 3.0)


## The meter's colour: the blob's own, turning red while a move is refused.
static func meter_color(blob: Blob) -> Color:
	return blob.color.lerp(DENIED_COLOR, blob.energy_denied)


## A row of `pip`-sized segments centred on `centre`: full ones bright, the
## filling one partly lit, empty ones dim.
static func draw_pips(ci: CanvasItem, st: ThemeStyle, blob: Blob, centre: Vector2, pip: Vector2, gap: float) -> void:
	var n := blob.stats.energy_segments
	var col := meter_color(blob)
	var width := n * pip.x + (n - 1) * gap
	var shake := Vector2(sin(Time.get_ticks_msec() * 0.08) * pip.y * 0.6 * blob.energy_denied, 0.0)
	for i in n:
		var rect := Rect2(centre + shake + Vector2(-width * 0.5 + i * (pip.x + gap), -pip.y * 0.5), pip)
		var fill := clampf(blob.energy - i, 0.0, 1.0)
		ci.draw_rect(rect.grow(1.5), Color(0, 0, 0, 0.55)) # backing, so it reads on any floor
		ci.draw_rect(rect, st.color(col, 0.4, 0.22))
		if fill >= 1.0:
			ci.draw_rect(rect, st.color(col.lightened(0.25), 1.8))
		elif fill > 0.0:
			ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x * fill, rect.size.y)), st.color(col, 0.9, 0.5))


## The segments as arcs on a circle of radius `r`, the first one at the top.
static func draw_arcs(ci: CanvasItem, st: ThemeStyle, blob: Blob, r: float, width: float) -> void:
	var n := blob.stats.energy_segments
	var col := meter_color(blob)
	var span := TAU / n
	var gap := minf(0.35, span * 0.25)
	for i in n:
		var from := -PI / 2.0 - span * 0.5 + i * span + gap * 0.5
		var to := from + span - gap
		var fill := clampf(blob.energy - i, 0.0, 1.0)
		st.ring(ci, Vector2.ZERO, r, Color(0, 0, 0), width + 3.0, 1.0, 0.45, from, to)
		st.ring(ci, Vector2.ZERO, r, col, width, 0.4, 0.22, from, to)
		if fill >= 1.0:
			st.ring(ci, Vector2.ZERO, r, col.lightened(0.25), width, 1.8, -1.0, from, to)
		elif fill > 0.0:
			st.ring(ci, Vector2.ZERO, r, col, width, 0.9, 0.5, from, lerpf(from, to, fill))
