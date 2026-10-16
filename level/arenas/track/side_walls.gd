class_name SideWalls
extends Node2D
## The treadmill's bed: two endless walls `settings.track_width` apart (centred
## on x = 0 of this node), with the floor, the belt chevrons and the zones
## outside where the ships fly, drawn for the span the camera can see. Colours
## from the theme: track.floor, track.shade, track.belt, track.wall. Put it at
## z_index -1, before the blobs, so trails draw over it.

const WALL_COLOR := Color(0.55, 0.6, 0.8)

@export var settings: TrackSettings = preload("res://level/arenas/track/track_settings.tres")


func _enter_tree() -> void:
	add_to_group("blob_colliders")


func collide(b: Blob, feel: PhysicsFeel) -> void:
	var half := settings.track_width * 0.5
	var x := b.global_position.x - global_position.x
	if x < -half + b.radius:
		_hit(b, Vector2.RIGHT, -half + b.radius - x, feel)
	elif x > half - b.radius:
		_hit(b, Vector2.LEFT, x - (half - b.radius), feel)


func _hit(b: Blob, n: Vector2, depth: float, feel: PhysicsFeel) -> void:
	var impact := BlobPhysics.bounce(b, n, depth, feel.wall_restitution)
	if impact > 0.0:
		BlobPhysics.wall_feedback(b.global_position - n * b.radius, impact, GameTheme.current().value("track.wall", WALL_COLOR))


## The visible stretch of track, as local (top, bottom) y with a margin.
func visible_span() -> Vector2:
	var view := GameCamera.view_of(self)
	if not view.has_area():
		view = Rect2(-500.0, -410.0, 1000.0, 820.0)
	return Vector2(view.position.y - global_position.y - 60.0, view.end.y - global_position.y + 60.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("track_bed", self):
		return
	var st := theme.style
	var span := visible_span()
	var y0 := span.x
	var y1 := span.y
	var half := settings.track_width * 0.5
	var shade: Color = theme.value("track.shade", Color(0.11, 0.07, 0.1))
	draw_rect(Rect2(-half - 800.0, y0, 800.0, y1 - y0), shade)
	draw_rect(Rect2(half, y0, 800.0, y1 - y0), shade)
	draw_rect(Rect2(-half, y0, half * 2.0, y1 - y0), theme.value("track.floor", Color(0.19, 0.22, 0.31)))

	# Belt chevrons are fixed in the world, so they slide down the screen.
	var belt: Color = theme.value("track.belt", Color(1.0, 1.0, 1.0, 0.06))
	var step := 120.0
	var yy := floorf(y0 / step) * step
	while yy < y1:
		for cx: float in [-half * 0.55, 0.0, half * 0.55]:
			var p := Vector2(cx, yy)
			draw_polyline(PackedVector2Array([p + Vector2(-26, -10), p + Vector2(0, 8), p + Vector2(26, -10)]),
				st.color(belt, 0.8), 4.0, true)
		yy += step

	# Side walls.
	var wall := 14.0 * st.bold
	for sx: float in [-half, half]:
		var x := sx + signf(sx) * wall * 0.5
		st.line(self, Vector2(x, y0), Vector2(x, y1), theme.value("track.wall", WALL_COLOR), wall, 1.6 + 0.4 * st.kick(self))
