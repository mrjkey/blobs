@tool
class_name BoxRoom
extends Node2D
## A plain walled rectangle centred on this node: a floor to test things on.
## Blobs bounce off the inside of the walls. Resize it in the editor and it
## redraws live. Colours from the theme: room.floor, room.wall.

const WALL_COLOR := Color(0.55, 0.6, 0.8)

@export var size := Vector2(1000.0, 640.0):
	set(v):
		size = v
		queue_redraw()


func _enter_tree() -> void:
	add_to_group("blob_colliders")


func collide(b: Blob, feel: PhysicsFeel) -> void:
	var half := size * 0.5
	var p := b.global_position - global_position
	var r := b.radius
	if p.x < -half.x + r:
		_hit(b, Vector2.RIGHT, -half.x + r - p.x, feel)
	elif p.x > half.x - r:
		_hit(b, Vector2.LEFT, p.x - (half.x - r), feel)
	if p.y < -half.y + r:
		_hit(b, Vector2.DOWN, -half.y + r - p.y, feel)
	elif p.y > half.y - r:
		_hit(b, Vector2.UP, p.y - (half.y - r), feel)


func _hit(b: Blob, n: Vector2, depth: float, feel: PhysicsFeel) -> void:
	var impact := BlobPhysics.bounce(b, n, depth, feel.wall_restitution)
	if impact > 0.0:
		BlobPhysics.wall_feedback(b.global_position - n * b.radius, impact, GameTheme.current().value("room.wall", WALL_COLOR))


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw() # neon walls pulse with the music


func _draw() -> void:
	var theme := GameTheme.current()
	if theme.draw_override("room", self):
		return
	var st := theme.style
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, theme.value("room.floor", Color(0.19, 0.22, 0.31)))
	var wall := 14.0 * st.bold
	draw_rect(rect.grow(wall * 0.5), st.color(theme.value("room.wall", WALL_COLOR), 1.4 + 0.4 * st.kick(self)), false, wall)
