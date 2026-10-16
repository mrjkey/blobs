class_name SideWalls
extends Node2D
## The treadmill's bed: two endless walls `settings.track_width` apart (centred
## on x = 0 of this node), the belt chevrons between them and the shaded zones
## outside where the ships fly. Drawn only for the span the camera can see.
## Put it at z_index -1, before the blobs, so trails draw over it.

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
		BlobPhysics.wall_feedback(b.global_position - n * b.radius, impact, settings.wall_color)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var view := GameCamera.view_of(self)
	if not view.has_area():
		view = Rect2(-500.0, -410.0, 1000.0, 820.0)
	view.position -= global_position
	var k := NeonLook.kick(get_tree())
	var half := settings.track_width * 0.5
	var y0 := view.position.y - 60.0
	var y1 := view.end.y + 60.0

	# Off-track zones where the ships fly.
	var shade := Color(0.03, 0.0, 0.06, 0.75)
	draw_rect(Rect2(-half - 800.0, y0, 800.0, y1 - y0), shade)
	draw_rect(Rect2(half, y0, 800.0, y1 - y0), shade)

	# Belt chevrons are fixed in the world, so they slide down the screen.
	var step := 120.0
	var yy := floorf(y0 / step) * step
	while yy < y1:
		for cx: float in [-half * 0.55, 0.0, half * 0.55]:
			var p := Vector2(cx, yy)
			draw_polyline(PackedVector2Array([p + Vector2(-26, -10), p + Vector2(0, 8), p + Vector2(26, -10)]),
				NeonLook.hdr(settings.belt_color, 0.8, 0.2), 3.0, true)
		yy += step

	# Side walls.
	for sx: float in [-half, half]:
		draw_line(Vector2(sx, y0), Vector2(sx, y1), NeonLook.hdr(settings.side_wall_color, 1.6 + 0.4 * k), 5.0, true)
		var inner := sx - signf(sx) * 10.0
		draw_line(Vector2(inner, y0), Vector2(inner, y1), NeonLook.hdr(settings.side_wall_color, 0.7, 0.4), 1.5, true)
