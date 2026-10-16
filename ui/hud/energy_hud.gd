class_name EnergyHud
extends Control
## Energy bars on the HUD for the human blobs, when the "meter" setting puts
## them here: P1 top left and P2 top right ("corners"), or side by side at the
## top or the bottom ("top", "bottom"). Hidden while the rules don't use
## energy. Full screen and click-through: put it in a CanvasLayer. The
## in-world version is EnergyMeter.

const PIP := Vector2(44.0, 14.0)
const GAP := 6.0
const MARGIN := 28.0

@export var top := 28.0 # where the top bars start (move them clear of a status line)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("energy_hud", self):
		return
	var where := GameSettings.choice("meter")
	if where not in ["corners", "top", "bottom"]:
		return
	var humans: Array[Blob] = []
	for b: Blob in get_tree().get_nodes_in_group("blobs"):
		if b.alive and b.is_human() and b.rules.energy != MoveRules.Energy.OFF:
			humans.append(b)
	for i in humans.size():
		var b := humans[i]
		var centre := _bar_centre(where, i, humans.size(), b)
		var label := b.tag if b.tag != "" else b.display_name.to_upper()
		draw_string(ThemeDB.fallback_font, centre + Vector2(-150.0, -PIP.y * 0.5 - 8.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, 300.0, 16, theme.style.color(b.color, 1.5))
		EnergyMeter.draw_pips(self, theme.style, b, centre, PIP, GAP)


func _bar_centre(where: String, i: int, count: int, b: Blob) -> Vector2:
	var n := b.stats.energy_segments
	var width := n * PIP.x + (n - 1) * GAP
	if where == "corners":
		var side_x := MARGIN + width * 0.5 if i % 2 == 0 else size.x - MARGIN - width * 0.5
		return Vector2(side_x, top + 24.0 + floorf(i / 2.0) * 56.0)
	var x := size.x * 0.5 + (i - (count - 1) * 0.5) * (width + 60.0)
	var y := top + 24.0 if where == "top" else size.y - 80.0
	return Vector2(x, y)
