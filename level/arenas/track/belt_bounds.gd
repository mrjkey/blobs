class_name BeltBounds
extends Node2D
## Keeps blobs between two lines across the track: `top` px above this node
## and `bottom` px below it (Don't Get Fat! moves it along with the camera).
## Blobs bump softly off both. The bottom one, the edge of the helpers' zone,
## is drawn as a dashed line; pickups that get past it fade away untouched.
## Group "belt_bounds" (at most one). Colour from the theme: belt_bounds.color.

const COLOR := Color(1.0, 1.0, 1.0, 0.4)

@export var top := 545.0
@export var bottom := 300.0
@export var restitution := 0.3
@export var settings: TrackSettings = preload("res://level/arenas/track/track_settings.tres")


func _enter_tree() -> void:
	add_to_group("blob_colliders")
	add_to_group("belt_bounds")


func top_y() -> float:
	return global_position.y - top


func bottom_y() -> float:
	return global_position.y + bottom


func collide(b: Blob, _feel: PhysicsFeel) -> void:
	var y := b.global_position.y
	if y < top_y() + b.radius:
		BlobPhysics.bounce(b, Vector2.DOWN, top_y() + b.radius - y, restitution)
	elif y > bottom_y() - b.radius:
		BlobPhysics.bounce(b, Vector2.UP, y - (bottom_y() - b.radius), restitution)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("belt_bounds", self):
		return
	var st := theme.style
	var col: Color = theme.value("belt_bounds.color", COLOR)
	var half := settings.track_width * 0.5
	const DASH := 26.0
	var x := -half
	while x < half:
		st.line(self, Vector2(x, bottom), Vector2(minf(x + DASH, half), bottom), col, 4.0)
		x += DASH * 2.0
