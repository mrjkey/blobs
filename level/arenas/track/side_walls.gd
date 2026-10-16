class_name SideWalls
extends Node2D
## The treadmill's bed: two endless walls `settings.track_width` apart (centred
## on x = 0 of this node), drawn by the theme's TrackBedSkin (floor, belt
## chevrons, the zones outside where the ships fly) for the span the camera can
## see. Put it at z_index -1, before the blobs, so trails draw over it.

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
		BlobPhysics.wall_feedback(b.global_position - n * b.radius, impact, GameTheme.current().track_bed.spark_color)


## The visible stretch of track, as local (top, bottom) y with a margin.
func visible_span() -> Vector2:
	var view := GameCamera.view_of(self)
	if not view.has_area():
		view = Rect2(-500.0, -410.0, 1000.0, 820.0)
	return Vector2(view.position.y - global_position.y - 60.0, view.end.y - global_position.y + 60.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	GameTheme.current().track_bed.draw(self)
