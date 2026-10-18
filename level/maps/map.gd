@tool
class_name Map
extends Node2D
## The root of a hand-made level: a scene under level/maps/<name>/. Its
## children are the pieces the generator uses (WallBlock, Bumper), placed by
## hand, plus markers: SpawnPoint, FoodSpot, FinishLine. A treadmill map's
## (0, 0) is the middle of the belt when the run starts; the finish is up
## (negative y). The treadmill loads one instead of generating its track (the
## lobby's TRACK option, or TreadmillGame.map_path).
##
## In the editor it draws the track bed (floor, side walls) from below the
## start up past the finish, and a ruler every RULER_STEP px marked in the
## HUD's metres, so the scene reads the way it plays. In the game the mode's
## own SideWalls draw the bed, so it draws nothing.

const RULER_STEP := 500.0

@export var settings: TrackSettings = preload("res://level/arenas/track/track_settings.tres")


## The spawn points, by seat.
func spawn_points() -> Array[SpawnPoint]:
	var out: Array[SpawnPoint] = []
	for n in find_children("*", "SpawnPoint", true, false):
		out.append(n as SpawnPoint)
	out.sort_custom(func(a: SpawnPoint, b: SpawnPoint): return a.seat < b.seat)
	return out


func finish() -> FinishLine:
	var found := find_children("*", "FinishLine", true, false)
	return found[0] as FinishLine if not found.is_empty() else null


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw() # follow pieces being dragged around


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var theme := GameTheme.current()
	var st := theme.style
	var half := settings.track_width * 0.5
	var fin := finish()
	var y0 := (fin.position.y if fin != null else -4000.0) - 400.0
	var y1 := settings.belt_height * 0.5 + 100.0
	var shade: Color = theme.value("track.shade", Color(0.11, 0.07, 0.1))
	draw_rect(Rect2(-half - settings.side_zone, y0, settings.side_zone, y1 - y0), shade)
	draw_rect(Rect2(half, y0, settings.side_zone, y1 - y0), shade)
	draw_rect(Rect2(-half, y0, half * 2.0, y1 - y0), theme.value("track.floor", Color(0.19, 0.22, 0.31)))
	var wall: Color = theme.value("track.wall", SideWalls.WALL_COLOR)
	for sx: float in [-half, half]:
		var x := sx + signf(sx) * 7.0
		st.line(self, Vector2(x, y0), Vector2(x, y1), wall, 14.0, 1.6)
	var font := ThemeDB.fallback_font
	var y := 0.0
	while y > y0:
		st.line(self, Vector2(-half, y), Vector2(half, y), Color.WHITE, 2.0, 0.5, 0.15)
		draw_string(font, Vector2(-half - settings.side_zone + 10.0, y - 6.0), "%d m" % int(-y / 10.0),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, Color(1.0, 1.0, 1.0, 0.5))
		y -= RULER_STEP
